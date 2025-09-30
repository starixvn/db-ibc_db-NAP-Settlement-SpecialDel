/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250822@Louisa: Setting releated bettype for Auto Settle and display on popup [Redmine:#233012]
*/
 
USE bodb02
GO

BEGIN
 
	DECLARE @tmp_AllResource TABLE	(MainResourceID VARCHAR(20), RelatedBettype VARCHAR(MAX) )

	;WITH cte_Setting (MainFormat, RelatedBettype ) AS
	(
		SELECT '669__' AS MainFormat, '653,656,659' AS RelatedBettype
		UNION ALL
		SELECT '671__', '656,659'
		UNION ALL
		SELECT '673__', '653,659'
		UNION ALL
		SELECT '674__', '665,667'
		UNION ALL
		SELECT '680__', '653'
		UNION ALL
		SELECT '681__', '659'
		UNION ALL
		SELECT '682__', '667'
		UNION ALL
		SELECT '683__', '656'
		UNION ALL
		SELECT '684__', '662'
	
		UNION ALL
		SELECT  m.MainResourceID,r.RelatedBettype FROM (VALUES('675____'),( '676____'),('678____'))m(MainResourceID) 
		CROSS APPLY (	SELECT RelatedBettype FROM ( VALUES('653,656,659,662,00')) r(RelatedBettype))r
	
		UNION ALL
		SELECT  m.MainResourceID,r.RelatedBettype FROM (VALUES('677__'),( '679__'))m(MainResourceID) 
		CROSS APPLY (	SELECT RelatedBettype FROM ( VALUES('653,656,659,665,667')) r(RelatedBettype) )r
	 )

	INSERT INTO @tmp_AllResource (MainResourceID, RelatedBettype)
	SELECT DISTINCT sp.ResourceID, r.RelatedBettype
	FROM cte_Setting r 
	INNER JOIN  SettlementSpecialBettypeProfile sp WITH(NOLOCK) ON sp.ResourceId LIKE r.MainFormat 
	WHERE  sp.Sporttype = 2 


	UPDATE sp
	SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedBettype', r.RelatedBettype)
	FROM SettlementSpecialBettypeProfile sp
	INNER JOIN @tmp_AllResource r ON sp.ResourceID = r.MainResourceID
	WHERE SportType = 2


END
GO
