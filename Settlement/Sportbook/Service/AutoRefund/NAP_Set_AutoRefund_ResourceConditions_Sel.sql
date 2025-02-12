/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoRefund_ResourceConditions_Sel] 
	@ResourceInfo	VARCHAR(MAX)
AS
/*	Creator: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
        - @ResourceInfo = '[{"sportType":1,"resourceId":"376","matchType":2,"childMatchType":202,"ruleId":0}]'
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Resource TABLE (Sporttype SMALLINT, ResourceID VARCHAR(20), MatchType TINYINT, ChildMatchType	TINYINT, RuleID	TINYINT)

	INSERT INTO @Resource (Sporttype, ResourceID, MatchType, ChildMatchType,RuleID)
	SELECT tbl.sportType
		  ,tbl.resourceId
		  ,tbl.matchType
          ,tbl.childMatchType
          ,tbl.ruleId
	FROM OPENJSON(@ResourceInfo) WITH (
			sportType		SMALLINT
		   ,resourceId		VARCHAR(20)	
		   ,matchType		TINYINT
           ,childMatchType	TINYINT
           ,ruleId          TINYINT
	) AS tbl

	SELECT ar.ID
          ,ar.Sporttype
          ,ar.ResourceID
          ,t.matchType  
          ,t.childMatchType 
          ,tt.[id] AS RuleID
          ,tt.[name] AS RuleName
          ,ttt.[action] AS sourceAction
          ,ttt.sourceMatchType
          ,ttt.sourceChildMatchType  
          ,ttt.sourceResource
          ,ttt.conditions 
    FROM AutoRefundSetting AS ar WITH(NOLOCK)
        OUTER APPLY OPENJSON(ar.Conditions)
            WITH (   
                      matchType                     TINYINT         '$.matchType'
                     ,childMatchType                VARCHAR(MAX)    '$.childMatchType'
                     ,conditions                    NVARCHAR(MAX)   AS JSON  
            ) AS t
        OUTER APPLY OPENJSON(t.Conditions)
            WITH (   
                      id                            VARCHAR(MAX)    '$.id'
                     ,name                          VARCHAR(MAX)    '$.name'
                     ,conditions                    NVARCHAR(MAX)   AS JSON  
            ) AS tt
       OUTER APPLY OPENJSON(tt.Conditions)
            WITH (   
                     sourceMatchType                VARCHAR(MAX)   '$.sourceMatchType'
                    ,sourceChildMatchType           VARCHAR(MAX)   '$.sourceChildMatchType'
                    ,sourceResource                 VARCHAR(MAX)   '$.sourceResource'
                    ,action                         VARCHAR(MAX)   '$.action'
                    ,conditions                     VARCHAR(MAX)   '$.conditions'
            ) AS ttt
    WHERE EXISTS (
        SELECT TOP 1 1 
        FROM @Resource AS r
        WHERE ar.Sporttype = r.Sporttype
            AND ar.ResourceID = r.ResourceID
            AND t.matchType = r.matchType
            AND t.childMatchType = r.childMatchType
            AND tt.id = IIF(r.RuleID IS NULL OR r.RuleID  = 0,tt.id, r.RuleID)
    )
END
GO
