/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Get_RelatedResourceId]
	@SportType     INT
	,@ResourceIDs	VARCHAR(MAX)
AS
/*
    Created by: 20250822@Louisa
    Task: 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/BODB02 
    
    Revisions: 
		- 20250822@Louisa: Basketball Player Prop [Redmine:#233012]

	ResourceIDs VARCHAR(MAX)  = '66901,67102'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmp_ResourceId TABLE (ResourceID VARCHAR(20), RelatedCalResourceID VARCHAR(20), OrdNo BIGINT, SettleType VARCHAR(3))

	;WITH cte_related AS
	(	SELECT  r.value AS ResourceID 
			,JSON_VALUE(sp.APSetting,'$."relatedBettype"')  AS  RelatedBettype
			FROM string_split(@ResourceIDs,',') r
				INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
					ON r.value = sp.ResourceID
			WHERE sp.sporttype = @SportType
	)
	INSERT INTO @tmp_ResourceId ( ResourceID, RelatedCalResourceID, OrdNo, SettleType)
	SELECT r.ResourceID, l.RelatedResourceId, sp.OrdNo, sp.SettleType
	FROM cte_related r
	CROSS APPLY( SELECt v.value AS RelatedResourceId FROM string_split(r.RelatedCalResourceIds,',') v )l
	CROSS APPLY (	SELECT MAX(sp.OrdNo) AS OrdNo, MAX(SettleType) AS SettleType
					 FROM dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
					 WHERE sp.ResourceID = l.RelatedResourceId
						AND sp.SportType = @SportType
				)sp

	SELECT ResourceID, RelatedCalResourceID, OrdNo, SettleType
	FROM @tmp_ResourceId

END
GO
 