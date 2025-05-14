/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoRefundResult_Select
	  @ResourceInfo	VARCHAR(MAX)
AS
/*
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
        - @ResourceInfo = '[{"matchId":1,"resourceId":"376"}]'
 
			
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Resource TABLE (MatchId INT,resourceId VARCHAR(20))

	INSERT INTO @Resource (MatchId,resourceId)
	SELECT tbl.MatchId
          ,tbl.resourceId
	FROM OPENJSON(@ResourceInfo) WITH (
            matchId		        INT
           ,resourceId		    VARCHAR(20)	
	) AS tbl

	SELECT ar.matchId
		  ,ar.resourceId
		  ,ar.statusId
	FROM dbo.AutoRefundResult AS ar WITH(NOLOCK) 
		INNER JOIN @Resource AS r ON r.matchId = ar.matchId AND ar.resourceId =  r.resourceId AND ar.TypeId = 7

END
GO
