/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Queue_Select]
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
	DECLARE @Max_QueueId		INT = 0
			,@Min_QueueId		INT = 0

	SELECT @Max_QueueId = MAX(q.QueueId)
		  ,@Min_QueueId = MIN(q.QueueId)
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH (NOLOCK)
	WHERE q.StatusId = 0
		
	IF EXISTS(SELECT TOP 1 1 FROM dbo.TicketVoiding_AutoVoidRequest_Queue WHERE StatusId = 1)
		RETURN

	SELECT TOP(1) q.QueueId, q.matchid, q.RequestId, q.BroadcastSessionId, q.Action
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH(NOLOCK)
		LEFT JOIN dbo.TempVariableNumber t WITH (NOLOCK) ON q.MatchId = t.KeyValue AND t.KeyID = 1
		LEFT JOIN dbo.match m WITH (NOLOCK) ON m.matchid = q.MatchId
		OUTER APPLY (
				SELECT TOP 1 r.ActionId
				FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
					INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = r.RequestId AND rd.FilterBy IS NULL
				WHERE r.RequestId = q.RequestId
			)r
	WHERE StatusId = 0 
		AND t.KeyID IS NULL -- waiting
		AND 1 = CASE WHEN q.RequestId = 0 AND DATEADD(SECOND,300,Starttime) <= GETDATE() THEN 1 
					WHEN q.RequestId > 0 AND r.ActionId IN (1,4,8) THEN 1 --Void Instant Abnormal Bet, AB, AA
					WHEN q.RequestId > 0 AND r.ActionId IN (6,7) AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 0 THEN 1 --AB
					WHEN q.RequestId > 0 AND r.ActionId = 6 AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 5 THEN 1 --AB
					WHEN q.RequestId > 0 AND r.ActionId = 7 AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 10 THEN 1 --AB
				ELSE 0 END
		AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId	
	ORDER BY q.Action DESC, Starttime
	
END		
GO


