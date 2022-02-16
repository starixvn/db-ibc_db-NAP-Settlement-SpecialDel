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
	SELECT	s.ResourceID, o.bettype, f.betChoice, f.OddsInfo
	FROM	dbo.oddsOS o WITH(NOLOCK)
		INNER JOIN dbo.oddsOS_flex f WITH(NOLOCK)
			ON o.oddsid = f.oddsid
		INNER JOIN DBTXN.bodb02.dbo.SettlementSpecialBettypeProfile s WITH(NOLOCk)
				ON o.bettype = s.BetType
	WHERE	s.SportType = 50
			AND (s.betid = 0 OR s.ResourceID LIKE '%' + CAST(o.Resourceid AS VARCHAR))
			AND	o.matchid = @matchId

END
GO

