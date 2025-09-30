/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_PlayerInfoSel
	@MatchId INT
	,@Sporttype SMALLINT = 50
	,@ListResourceIDs VARCHAR(MAX) = ''
AS
/*
    Created by: 20220207@Kathy
    Task: get player info [Redmine:#166335]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20220207@Kathy: get player info [Redmine:#166335]
		- 20220719@Louisa: Remove select via linked server [Redmine:#175251]
		- 20250822@Max: [Settlement] - Integration - Player Props AIO for Basketball [Redmine: #233012]

	@ListResourceIDs = '6750102,66901' --use for Basketball early

*/
BEGIN
	IF @Sporttype = 50 --Cricket
	BEGIN
		SELECT	s.ResourceID, o.bettype, f.betChoice, f.OddsInfo, '' AS RelatedBettype
		FROM	dbo.oddsOS o WITH(NOLOCK)
			INNER JOIN dbo.oddsOS_flex f WITH(NOLOCK)
				ON o.oddsid = f.oddsid
			INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCk)
					ON o.bettype = s.BetType
		WHERE	s.SportType = 50
				AND (s.betid = 0 OR s.ResourceID LIKE '%' + CAST(o.Resourceid AS VARCHAR))
				AND	o.matchid = @matchId
				AND ISNULL(o.IsDeleted,0) = 0
				AND ISNULL(f.IsDeleted,0) = 0
	END
	ELSE IF @Sporttype = 2 --Basketball player props
	BEGIN
		SELECT	DISTINCT s.ResourceID, o.bettype, f.betChoice, f.OddsInfo, JSON_VALUE(s.APSetting,'$."relatedBettype"') AS RelatedBettype
		FROM	dbo.odds o WITH(NOLOCK)
			INNER JOIN dbo.odds_flex f WITH(NOLOCK)
				ON o.oddsid = f.oddsid
			INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCk)
					ON o.bettype = s.BetType
		WHERE	s.SportType = 2
				AND (s.betid = 0 
						OR ( s.bettype NOT IN (675,676,678 ) AND s.ResourceID LIKE '%' + CAST(o.Resourceid AS VARCHAR)) 
						OR ( s.bettype IN (675,676,678 ) AND s.ResourceID = CAST(o.bettype AS VARCHAR(3)) + o.ResourceID + f.betChoice )
					)
				AND	o.matchid = @matchId
				AND ISNULL(o.IsDeleted,0) = 0
				AND ISNULL(f.IsDeleted,0) = 0
				AND s.SettleType = 'EAR'
				AND (ISNULL(@ListResourceIDs,'') = '' OR EXISTS(SELECT 1 FROM STRING_SPLIT(@ListResourceIDs,',') tmp WHERE tmp.value = s.ResourceID) )
	END
END
GO

