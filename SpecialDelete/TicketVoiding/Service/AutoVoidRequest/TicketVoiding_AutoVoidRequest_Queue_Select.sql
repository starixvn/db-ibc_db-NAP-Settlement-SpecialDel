/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Queue_Select]
(
	@BroadcastSessionId VARCHAR(50) = NULL
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221007@Max: [TVS] Tuning SP of Auto Void Queue picking [Redmine: #178869]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Max_QueueId		INT = 0
			,@Min_QueueId		INT = 0

	SELECT @Max_QueueId = MAX(q.QueueId)
		  ,@Min_QueueId = MIN(q.QueueId)
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH (NOLOCK)
	WHERE q.StatusId IN (0)

	IF @BroadcastSessionId IS NOT NULL
	BEGIN
		SELECT TOP(1) q.QueueId, q.matchid, q.RequestId, q.BroadcastSessionId, q.Action, q.StatusId
		FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(NOLOCK)
		WHERE q.BroadcastSessionId =  @BroadcastSessionId
		ORDER BY q.Action DESC, Starttime
	END
	ELSE
	BEGIN
		SELECT TOP(1) q.QueueId, q.matchid, q.RequestId, q.BroadcastSessionId, q.Action, q.StatusId
		FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(NOLOCK)
			LEFT JOIN dbo.match m WITH (NOLOCK) ON m.matchid = q.MatchId
		WHERE StatusId IN (0)
			AND 1 = CASE WHEN q.Action = 'MixParlay' AND DATEADD(SECOND,600,q.Starttime) <= GETDATE() THEN 1 --AbnormalBet MixParay (case all event completed)
						WHEN q.RequestId = 0 AND DATEADD(SECOND,300,Starttime) <= GETDATE() THEN 1  --Settletment signal
						WHEN q.RequestId > 0 AND q.Action IN ('AddRequest','VoidInstant','VoidInstantNopolicy') THEN 1 --Void Instant Abnormal Bet, AB, AA
						WHEN q.RequestId > 0 AND q.Action IN ('VoidInstant5m','VoidInstant10m') AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 0 THEN 1 --AB
						WHEN q.RequestId > 0 AND q.Action = 'VoidInstant5m' AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 5 THEN 1 --AB
						WHEN q.RequestId > 0 AND q.Action = 'VoidInstant10m' AND DATEDIFF(MINUTE, GETDATE(), m.GlobalShowTime) <= 10 THEN 1 --AB
					ELSE 0 END
			AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
			AND q.BroadcastSessionId IS NOT NULL
		ORDER BY q.Action DESC, Starttime
	END	
END		
GO


