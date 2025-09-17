/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250822@Louisa: Auto Payout Basketball Player Prop [Redmine:#233012]
*/
 
USE bodb02
GO

BEGIN
 
	DECLARE @tmp_Setting	 TABLE	(MainFormat VARCHAR(20), RelatedFormat VARCHAR(20) )
	DECLARE @tmp_AllResource TABLE	(MainResourceID VARCHAR(20), RelatedResourceID VARCHAR(MAX) )

	INSERT INTO @tmp_Setting (MainFormat, RelatedFormat)
	SELECT '669__', RelatedResourceID FROM ( VALUES('653__'),('656__'),('659__')) t(RelatedResourceID)
	UNION ALL
	SELECT '671__', RelatedResourceID FROM ( VALUES('656__'),('659__')) t(RelatedResourceID)
	UNION ALL
	SELECT '673__', RelatedResourceID FROM ( VALUES('653__'),('659__')) t(RelatedResourceID)
	UNION ALL
	SELECT '674__', RelatedResourceID FROM ( VALUES('665__'),('667__')) t(RelatedResourceID)
	UNION ALL
	SELECT '680__', RelatedResourceID FROM ( VALUES('653__')) t(RelatedResourceID)
	UNION ALL
	SELECT '681__', RelatedResourceID FROM ( VALUES('659__')) t(RelatedResourceID)
	UNION ALL
	SELECT '682__', RelatedResourceID FROM ( VALUES('667__')) t(RelatedResourceID)
	UNION ALL
	SELECT '683__', RelatedResourceID FROM ( VALUES('656__')) t(RelatedResourceID)
	UNION ALL
	SELECT '684__', RelatedResourceID FROM ( VALUES('662__')) t(RelatedResourceID)
	
	UNION ALL
	SELECT  m.MainResourceID,r.RelatedResourceID FROM (VALUES('675____'),( '676____'),('678____'))m(MainResourceID) 
	CROSS APPLY (
					SELECT RelatedResourceID FROM ( VALUES('653__'),('656__'),('659__'),('662__'),('00')) r(RelatedResourceID)
						
				)r
	
	UNION ALL
	SELECT  m.MainResourceID,r.RelatedResourceID FROM (VALUES('677__'),( '679__'))m(MainResourceID) 
	CROSS APPLY (
					SELECT RelatedResourceID FROM ( VALUES('653__'),('656__'),('659__'),('665__'),('667__')) r(RelatedResourceID)
						
				)r
 
	;WITH cte_Main (MainFormat, MainResourceID) AS
	(	 SELECT DISTINCT r.MainFormat, sp.ResourceID AS MainResourceID
		  FROM @tmp_Setting r 
			INNER JOIN  SettlementSpecialBettypeProfile sp WITH(NOLOCK) ON sp.ResourceId LIKE r.MainFormat 
		  WHERE  sp.Sporttype = 2 
	)
	,cte_Relate (MainFormat, RelatedResourceID) AS
	(	 SELECT DISTINCT  r.MainFormat, sp.ResourceID AS RelatedResourceID
		 FROM @tmp_Setting r 
			INNER JOIN  SettlementSpecialBettypeProfile sp WITH(NOLOCK) ON sp.ResourceId LIKE r.RelatedFormat
		  WHERE  sp.Sporttype = 2 
	)

	---6160  rows
	INSERT INTO @tmp_AllResource (MainResourceID, RelatedResourceID)
	SELECT MainResourceID, STRING_AGG(RelatedResourceID,',') AS RelatedResourceID
	FROM (	SELECT DISTINCT  m.MainResourceID, r.RelatedResourceID
			FROM cte_Main m
			INNER JOIN  cte_Relate r
			ON m.MainFormat = r.MainFormat
			WHERE  ( SUBSTRING(m.MainResourceID,4,2) = RIGHT(RelatedResourceID,2) OR ( r.MainFormat IN( '675____','676____','678____') AND RelatedResourceID = '00'))
		)r
	GROUP BY MainResourceID

	UPDATE sp
	SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', r.RelatedResourceID)
	FROM SettlementSpecialBettypeProfile sp
	INNER JOIN @tmp_AllResource r ON sp.ResourceID = r.MainResourceID
	WHERE SportType = 2
END
GO
 