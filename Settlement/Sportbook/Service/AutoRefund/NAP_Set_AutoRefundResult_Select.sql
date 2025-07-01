/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoRefundResult_Select
	  @ResourceInfo	VARCHAR(MAX)
AS
/*
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
		- 20250623@Hughie: Auto Refund- Fast Market & Time Machine- Support Special Session [Redmine:#225889]

	Param's Explanation:
        - @ResourceInfo = '[{"matchId":1,"resourceId":"376"}]'
 
			
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Resource TABLE (MatchId INT, resourceId VARCHAR(20), TypeId TINYINT, OtherInfo VARCHAR(MAX))

	INSERT INTO @Resource (MatchId, resourceId, TypeId, OtherInfo)
	SELECT tbl.MatchId
          ,tbl.resourceId
		  ,tbl.TypeId
		  ,tbl.OtherInfo
	FROM OPENJSON(@ResourceInfo) WITH (
            matchId		        INT
           ,resourceId		    VARCHAR(20)	
		   ,TypeId				TINYINT
		   ,OtherInfo			VARCHAR(MAX)
	) AS tbl

	SELECT ar.matchId
		  ,ar.resourceId
		  ,ar.statusId
	FROM dbo.AutoRefundResult AS ar WITH(NOLOCK) 
		INNER JOIN @Resource AS r ON r.matchId = ar.matchId AND ar.TypeId = r.TypeId
	WHERE 1 = CASE WHEN r.TypeId = 11 AND ar.OtherInfo = r.OtherInfo AND ar.ResourceId = r.resourceId THEN 1
	                WHEN ar.TypeId = 7 AND ar.resourceId =  r.resourceId THEN 1
					ELSE 0
					END

END
GO
