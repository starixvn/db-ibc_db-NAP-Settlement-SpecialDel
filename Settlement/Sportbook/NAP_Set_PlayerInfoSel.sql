/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_PlayerInfoSel
	@MatchId INT
AS
/*
    Created by: 20220207@Kathy
    Task: get player info [Redmine:#166335]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20220207@Kathy: get player info [Redmine:#166335]
		
*/
BEGIN
	CREATE TABLE #tmpPlayerInfo (ResourceId VARCHAR(20), bettype SMALLINT, betChoice VARCHAR(20), OddsInfo VARCHAR(200))

	INSERT INTO #tmpPlayerInfo (bettype, betChoice, OddsInfo)
	SELECT	o.bettype, f.betChoice, f.OddsInfo
	FROM	dbo.odds o WITH(NOLOCK)
		INNER JOIN dbo.odds_flex f WITH(NOLOCK)
			ON o.oddsid = f.oddsid
	WHERE	matchid = @matchId

	IF @@ROWCOUNT <> 0
		UPDATE t 
			SET ResourceId = s.ResourceID
		FROM	#tmpPlayerInfo t	
			INNER JOIN DBTXN.bodb02.dbo.SettlementSpecialBettypeProfile s WITH(NOLOCk)
				ON t.bettype = s.BetType
		WHERE	s.SportType = 50
				AND s.BetID = 0

	SELECT	ResourceId, bettype, betChoice, OddsInfo
	FROM	#tmpPlayerInfo
END
GO
