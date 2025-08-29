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

    DECLARE @MatchTable TABLE (
        matchId BIGINT
        ,enable BIT
    );

    DECLARE @OutputResults TABLE (
        matchid BIGINT
        ,oldAutoSetting INT
        ,newAutoSetting INT
        ,action NVARCHAR(50)
        ,Description NVARCHAR(100)
        ,Bit2Status BIT
    );

    INSERT INTO @MatchTable (matchId, enable)
    SELECT
        matchId,
        enable
    FROM OPENJSON(@MatchList)
    WITH (
        matchId BIGINT '$.matchId',
        enable BIT '$.enable'
    );

    UPDATE m WITH (ROWLOCK, UPDLOCK)
    SET AutoSetting = CASE
                        WHEN mt.enable = 1 THEN COALESCE(m.AutoSetting, l.AutoSetting, 0) | 2
                        WHEN mt.enable = 0 THEN COALESCE(m.AutoSetting, l.AutoSetting, 0) & ~2
                        ELSE m.AutoSetting
                      END
    OUTPUT
        inserted.matchid
        ,deleted.AutoSetting AS oldAutoSetting
        ,inserted.AutoSetting AS newAutoSetting
        ,CASE mt.enable
            WHEN 1 THEN 'ENABLE'
            WHEN 0 THEN 'DISABLE'
        END AS action
        ,CASE mt.enable
            WHEN 1 THEN 'Bit 2 turned on'
            WHEN 0 THEN 'Bit 2 turned off'
        END AS Description
        ,(inserted.AutoSetting & 2) AS Bit2Status
    INTO @OutputResults
    FROM match m
	INNER JOIN League l WITH (NOLOCK) ON m.leagueid = l.leagueid
    INNER JOIN @MatchTable mt ON m.matchid = mt.matchId;

    SELECT matchid
		  ,oldAutoSetting
		  ,newAutoSetting
		  ,action
		  ,Description
		  ,Bit2Status
		FROM @OutputResults;

    SELECT
        'Summary' AS Info,
        COUNT(1) AS TotalRecords,
        SUM(CASE WHEN enable = 1 THEN 1 ELSE 0 END) AS EnableCount,
        SUM(CASE WHEN enable = 0 THEN 1 ELSE 0 END) AS DisableCount
    FROM @MatchTable;
END