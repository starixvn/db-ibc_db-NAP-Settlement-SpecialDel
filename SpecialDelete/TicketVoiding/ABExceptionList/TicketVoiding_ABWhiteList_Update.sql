/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ABWhiteList_Update]
(
	  @CustIds			NVARCHAR(MAX) = ''
	 ,@UserId			INT
	 ,@IP				VARCHAR(50) = NULL
)
AS
/*
	Created by: Max
	Task : [TVS] Implement AB Whitelist
	DB: DBCTG/bodb02

	Revisions:
		- 20211005@Max: Create new SP - [Redmine:#161659]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
		   ,@EndTime			DATETIME
		   ,@LogData			VARCHAR(MAX)
		   ,@LogActionId		INT
		   ,@SB_Error			BIT

	CREATE TABLE #tmpCustId (custid INT)
	DECLARE @tmpCustIdBatch AS TABLE (CustId INT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90005 
	SET @SB_Error = 0

	INSERT INTO #tmpCustId (custid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@CustIds, ',')
	WHERE value <> ''

	WHILE (1=1)
	BEGIN
		DELETE @tmpCustIdBatch

		DELETE TOP(1000) t OUTPUT DELETED.custid INTO @tmpCustIdBatch
		FROM #tmpCustId t

		IF @@ROWCOUNT = 0
			BREAK

		DELETE c
		FROM dbo.TicketVoiding_ABWhiteList c
		WHERE c.Custid IN (SELECT Custid FROm @tmpCustIdBatch)

	END

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'							
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.'
							+ ', @CustIds: ' + CAST(@CustIds AS NVARCHAR(MAX))
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))


	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tmpCustId

	SET NOCOUNT OFF
END
GO
