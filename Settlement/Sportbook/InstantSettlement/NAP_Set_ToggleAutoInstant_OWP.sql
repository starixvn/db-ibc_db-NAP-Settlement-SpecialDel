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
	@MatchList = '
	[{"matchId": 123, "enable": true}, {"matchId": 456, "enable": false}]
	'
*/
BEGIN
    SET NOCOUNT ON;

   CREATE TABLE #MatchTable (
        RowID INT IDENTITY(1,1) PRIMARY KEY,
        matchId BIGINT,
        enable BIT
    );

    CREATE NONCLUSTERED INDEX IX_MatchTable_matchId ON #MatchTable(matchId);

    CREATE TABLE #MatchChange(
        matchId BIGINT PRIMARY KEY,
        oldAutoSetting INT,
        newAutoSetting INT
    )

    INSERT INTO #MatchTable (matchId, enable)
    SELECT
        matchId,
        enable
    FROM OPENJSON(@MatchList)
    WITH (
        matchId BIGINT '$.matchId',
        enable BIT '$.enable'
    );

    DECLARE  @Threshold INT  
			,@StartRow	INT 
			,@StopRow	INT
			,@MaxRow    INT

    SET @MaxRow = (SELECT MAX(RowID) FROM #MatchTable)
    SET @Threshold = 1000

    IF @Threshold >= @MaxRow
	    SET @Threshold = @MaxRow

    -- SET for first batch
    SELECT @StartRow = 1, @StopRow = @Threshold

    WHILE (@MaxRow IS NOT NULL)
    BEGIN

        UPDATE m
        SET AutoSetting = CASE
                           WHEN mt.enable = 1 THEN COALESCE(m.AutoSetting, l.AutoSetting, 0) | 2
                           WHEN mt.enable = 0 THEN COALESCE(m.AutoSetting, l.AutoSetting, 0) & ~2
                           ELSE m.AutoSetting
                         END
        OUTPUT 
        deleted.matchid,
        deleted.AutoSetting AS OldSetting,
        inserted.AutoSetting AS NewSetting
        INTO #MatchChange(matchId, oldAutoSetting, newAutoSetting)
        FROM match m WITH (ROWLOCK, UPDLOCK)
        LEFT JOIN League l WITH (NOLOCK) ON m.leagueid = l.leagueid
        INNER JOIN #MatchTable mt ON m.matchid = mt.matchId
        WHERE mt.RowID BETWEEN @StartRow AND @StopRow;

        DELETE a
        FROM dbo.ProviderResultDetail a WITH (ROWLOCK, UPDLOCK)
        INNER JOIN #MatchTable mt ON a.matchid = mt.matchid
        WHERE a.IsConfirmed = 0
        AND a.SourceId = 100
        AND mt.enable = 0
        AND mt.RowID BETWEEN @StartRow AND @StopRow;
        
        IF @StopRow = @MaxRow BREAK
        
        WAITFOR DELAY '00:00:00.100'

        SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
    END

    SELECT matchid
	FROM #MatchChange 
	WHERE oldAutoSetting <> newAutoSetting

	DROP TABLE #MatchTable
	DROP TABLE #MatchChange
END