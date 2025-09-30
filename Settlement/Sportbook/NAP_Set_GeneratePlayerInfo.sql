/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GeneratePlayerInfo
	@MatchId INT
AS
/*
    Created by: 20250822@Louisa
    Task: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
    
    Revisions:            
		- 20250822@Louisa: Basketball Player Prop [Redmine:#233012]

	@ListResourceIDs = '6750102,66901' --use for Basketball early

*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @tmp_Offer TABLE ( ResourceID VARCHAR(50), bettype SMALLINT, betChoice VARCHAR(20), OddsInfo VARCHAR(500), PlayerId BIGINT, RelatedBettype VARCHAR(200) )
	DECLARE @tmp_MainResource TABLE ( MainResourceID VARCHAR(50), RelatedBettype SMALLINT, PlayerId BIGINT)

	INSERT INTO @tmp_Offer ( ResourceID, bettype, betChoice, OddsInfo, PlayerId, RelatedBettype)
	SELECT	DISTINCT s.ResourceID, o.bettype, f.betChoice, f.OddsInfo
			, JSON_VALUE(f.OddsInfo,'$."pid"') AS PlayerId ,JSON_VALUE(s.APSetting,'$."relatedBettype"') AS RelatedBettype
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
					AND	o.matchid = 83807922
					AND ISNULL(o.IsDeleted,0) = 0
					AND ISNULL(f.IsDeleted,0) = 0
					AND s.SettleType = 'EAR'
					
	INSERT INTO @tmp_MainResource ( MainResourceID, RelatedBettype, PlayerId )	
	SELECT DISTINCT o.ResourceID	
			,v.RelatedBettype	
			,o.PlayerId 
	FROM @tmp_Offer o
		CROSS APPLY (SELECT v.value AS RelatedBettype FROM STRING_SPLIT(RelatedBettype, ',')v)v
	WHERE ISNULL(o.RelatedBettype,'')<> ''
	select * from @tmp_MainResource
	
	DELETE m
	FROM @tmp_MainResource m
	WHERE EXISTS (SELECT 1 FROM @tmp_Offer o WHERE ISNULL(o.RelatedBettype,'') = '' AND o.PlayerId = m.PlayerId)

END
 