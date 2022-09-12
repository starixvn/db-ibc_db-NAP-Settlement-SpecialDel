/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLogDel] 
AS  
/* 
	 Creator: 20220912@Kathy  
	 Task: Delete Log
	
	 Revisions:  
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	 Param's Explanation:  
    
    
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @FromDate DATETIME
			,@LogId BIGINT
			,@batchNo INT

	SET @FromDate = DATEADD(DAY,-7,GETDATE())
	SET @batchNo = 3000

	SELECT	TOP 1 @LogId = LogId
	FROM	dbo.SiteDB_SettlementService_LastLog WITH(NOLOCK)
	WHERE	Endtime < @FromDate
	ORDER BY LogId DESC

	WHILE (1=1)
	BEGIN
		DELETE	TOP (@batchNo)
		FROM	dbo.SiteDB_SettlementService_CalculationLog WITH(ROWLOCK,UPDLOCK)
		WHERE	LogId <= @LogId

		IF @@ROWCOUNT < @batchNo
			BREAK
	END

	WHILE (1=1)
	BEGIN
		DELETE	TOP (@batchNo)
		FROM	dbo.SiteDB_SettlementService_LastLog WITH(ROWLOCK,UPDLOCK)
		WHERE	LogId <= @LogId

		IF @@ROWCOUNT < @batchNo
			BREAK
	END
END  
GO