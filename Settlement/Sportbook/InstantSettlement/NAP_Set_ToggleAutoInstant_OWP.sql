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
    FROM match m
	INNER JOIN League l WITH (NOLOCK) ON m.leagueid = l.leagueid
    INNER JOIN @MatchTable mt ON m.matchid = mt.matchId;

	DELETE a
	FROM 	dbo.ProviderResultDetail a
		INNER JOIN @MatchTable mt ON a.matchid = mt.matchid
	WHERE 	 a.IsConfirmed = 0
			AND a.SourceId = 100
			AND mt.enable = 0
END