/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoPayout_SourceInfo_Sel
	  @Sporttype	SMALLINT
	 ,@LeagueId		INT			= 0
AS
/*	Creator: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider
	DB: DBPRO/BODB02
	
	Revisions:
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]
		
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON

	DECLARE @GameType TINYINT  = 0

	SELECT @GameType =  ISNULL(MAX(CASE WHEN l.Sporttype = 43 THEN l.OverTimeSession ELSE 0 END),0)
	FROM League l WITH(NOLOCK)
	WHERE l.LeagueId = @LeagueId
    
	SELECT p.SourceId
		  ,p.SourceName
          ,MIN(m.OrderNo) AS OrderNo
	FROM ProviderGameTypeMapping AS m WITH (NOLOCK)
		INNER JOIN ProviderInfo AS p WITH (NOLOCK) ON p.SourceId = m.SourceId
	WHERE m.sporttype = @Sporttype
		AND m.isActive = 1
		AND p.SourceID < 1001 
		AND p.SourceID NOT IN (98,99,100) 
		AND p.isActive = 1
		AND m.GameType = @GameType
    GROUP BY p.SourceId,p.SourceName
	ORDER BY MIN(m.OrderNo) ASC

END
GO