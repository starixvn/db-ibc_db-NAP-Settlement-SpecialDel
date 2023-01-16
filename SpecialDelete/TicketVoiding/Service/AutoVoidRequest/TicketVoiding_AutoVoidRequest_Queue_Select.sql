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
		- 20221007@Max: [TVS] Tuning SP of Auto Void Queue picking [Redmine: #178869]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Max_QueueId		INT = 0
			,@Min_QueueId		INT = 0

	SELECT @Max_QueueId = MAX(q.QueueId)
		  ,@Min_QueueId = MIN(q.QueueId)
	FROM TicketVoiding_AutoVoidQueue q WITH (NOLOCK)
	WHERE q.StatusId IN (0)

	SELECT TOP(1) q.QueueId, q.matchid, q.RequestIds, q.Action, q.StatusId, BroadcastSessionId
	FROM dbo.TicketVoiding_AutoVoidQueue q WITH(NOLOCK)
		LEFT JOIN dbo.match m WITH (NOLOCK) ON m.matchid = q.MatchId
	WHERE StatusId IN (0)
		AND 1 = CASE WHEN q.Action = 'CAL' AND DATEADD(SECOND,180,CreatedDate) <= GETDATE() THEN 1  --Settletment signal
					WHEN q.Action IN ('VoidInstant','VoidInstantNopolicy') THEN 1 --Void Instant Abnormal Bet, AB, AA
					WHEN q.Action IN ('VoidInstant5m','VoidInstant10m') AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 0 THEN 1 --AB
					WHEN q.Action = 'VoidInstant5m' AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 5 THEN 1 --AB
					WHEN q.Action = 'VoidInstant10m' AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 10 THEN 1 --AB
				ELSE 0 END
		AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
	ORDER BY q.Action DESC, CreatedDate
END		
GO


