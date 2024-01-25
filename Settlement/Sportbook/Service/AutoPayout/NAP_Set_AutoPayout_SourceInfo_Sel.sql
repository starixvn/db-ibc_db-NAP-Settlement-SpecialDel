/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoPayout_SourceInfo_Sel
	 @Sporttype		SMALLINT
AS
/*	Creator: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider
	DB: DBPRO/BODB02
	
	Revisions:
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON
    
	SELECT p.SourceId
		  ,p.SourceName
	FROM ProviderGameTypeMapping AS m WITH (NOLOCK)
		INNER JOIN ProviderInfo AS p WITH (NOLOCK) ON p.SourceId = m.SourceId
	WHERE m.sporttype = @Sporttype
		AND m.isActive = 1
		AND p.SourceID < 1001 
		AND p.SourceID NOT IN (98,99,100) 
		AND p.isActive = 1
	ORDER BY m.OrderNo ASC

END
GO