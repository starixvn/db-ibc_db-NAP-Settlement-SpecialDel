/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE NAP_Set_ToggleAutoInstant_OWP
    @MatchList NVARCHAR(MAX)
AS
/*
    Created by: 20250828@Hughie
    Task: Auto turn ON/OFF instant settlement [Redmine:#236714]
    DB: DBPRO/BODB02 
    
    Revisions:   
		- 20250828@Hughie: Created [Redmine:#236714]

	Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;

   CREATE TABLE #MatchTable (
        RowID INT IDENTITY(1,1) PRIMARY KEY,
        matchId BIGINT,
        enable BIT
    );

    CREATE NONCLUSTERED INDEX IX_MatchTable_matchId ON #MatchTable(matchId);

    INSERT INTO #MatchTable (matchId, enable)
    SELECT
        matchId,
        enable
    FROM OPENJSON(@MatchList)
    WITH (
        matchId BIGINT '$.matchId',
        enable BIT '$.enable'
    );

    DECLARE @BatchSize	INT = 1000
			,@StartRow	INT = 1
			,@EndRow	INT
			,@RowCount	INT = 1

    WHILE @RowCount > 0
    BEGIN
        SET @EndRow = @StartRow + @BatchSize - 1;
        
        UPDATE m
        SET AutoSetting = CASE
                           WHEN mt.enable = 1 THEN COALESCE(m.AutoSetting, l.AutoSetting, 0) | 2
                           WHEN mt.enable = 0 THEN COALESCE(m.AutoSetting, l.AutoSetting, 0) & ~2
                           ELSE m.AutoSetting
                         END
        FROM match m WITH (ROWLOCK, UPDLOCK)
        INNER JOIN League l WITH (NOLOCK) ON m.leagueid = l.leagueid
        INNER JOIN #MatchTable mt ON m.matchid = mt.matchId
        WHERE mt.RowID BETWEEN @StartRow AND @EndRow;
        
        SET @RowCount = @@ROWCOUNT;
        
        SET @StartRow = @EndRow + 1;
        
        IF @RowCount = 0 BREAK;
        
        WAITFOR DELAY '00:00:00.100';
    END

    SET @StartRow = 1;
    SET @RowCount = 1;
    
    WHILE @RowCount > 0
    BEGIN
        SET @EndRow = @StartRow + @BatchSize - 1;
        
        DELETE a
        FROM dbo.ProviderResultDetail a WITH (ROWLOCK, UPDLOCK)
        INNER JOIN #MatchTable mt ON a.matchid = mt.matchid
        WHERE a.IsConfirmed = 0
        AND a.SourceId = 100
        AND mt.enable = 0
        AND mt.RowID BETWEEN @StartRow AND @EndRow;
        
        SET @RowCount = @@ROWCOUNT;
        
        SET @StartRow = @EndRow + 1;
        
        IF @RowCount = 0 BREAK;
        
        WAITFOR DELAY '00:00:00.100';
    END
END