/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Queue_Insert]
(
	@RequestIdList VARCHAR(MAX)
	,@UserId INT = 0
	,@IP VARCHAR(50) = ''
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpRequests (RequestId INT)

	INSERT INTO #tmpRequests (RequestId)
	SELECT DISTINCT value AS RequestId
	FROM STRING_SPLIT(@RequestIdList, ',')

	INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP)
	SELECT t.RequestId, 0, 'MixParlay', 100, @UserId, GETDATE(), @IP
	FROM #tmpRequests t
	
	DROP TABLE #tmpRequests
END		
GO


