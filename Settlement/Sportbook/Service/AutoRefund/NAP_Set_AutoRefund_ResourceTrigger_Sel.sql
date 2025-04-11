/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoRefund_ResourceTrigger_Sel] 
	 @SportType			SMALLINT
	,@ChildMatchType	TINYINT
	,@Action			VARCHAR(50)
	,@ResourceIds		VARCHAR(MAX)
    ,@IsTest            BIT = 0
AS
/*	Creator: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Resource TABLE (ResourceId	VARCHAR(20), PRIMARY KEY (ResourceId))

	INSERT INTO @Resource(ResourceId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ResourceIds,',')
	WHERE value != ''

	SELECT ar.ID
          ,ar.Sporttype
          ,ar.ResourceID
          ,t.[Action]                      
          ,t.matchType  
          ,t.childMatchType  
          ,t.conditions      
          ,t.targetIsCrrMatch               AS TargetIsCrrMatch
          ,t.targetIsCrrResource            AS TargetIsCrrResource  
          ,t.targetResourceChildMatchType
          ,t.targetResource                 AS TargetResource
    FROM AutoRefundSetting AS ar WITH(NOLOCK)
        OUTER APPLY OPENJSON([Trigger])
            WITH (   
                  [action]                      VARCHAR(MAX)    '$.action'
                 ,matchType                     TINYINT         '$.matchType'
                 ,childMatchType                VARCHAR(MAX)    '$.childMatchType'
                 ,conditions                    VARCHAR(MAX)    '$.conditions'

                 ,targetIsCrrMatch              VARCHAR(MAX)    '$.targetIsCrrMatch'
                 ,targetIsCrrResource           VARCHAR(MAX)    '$.targetIsCrrResource'
                 ,targetResource                VARCHAR(MAX)    '$.targetResource'
                 ,targetResourceChildMatchType  VARCHAR(MAX)    '$.targetResourceChildMatchType'

                 ,isTest                        BIT             '$.isTest'
            ) AS t
    WHERE ar.Sporttype = @SportType
        AND 1 = CASE WHEN @ChildMatchType = 0 AND t.matchType = 1 THEN 1
                     WHEN @ChildMatchType != 0 AND t.childMatchType = @ChildMatchType THEN 1
                     ELSE 0
                END
        AND @Action = t.[Action]  
        AND ar.ResourceId IN (SELECT r.ResourceId FROM @Resource AS r)
        AND ISNULL(t.isTest,0) = @IsTest
END
GO
