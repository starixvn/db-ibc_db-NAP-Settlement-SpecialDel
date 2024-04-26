/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
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
		- 20230814@Max: [TVS] Reduced Over - Update rule for action "auto void" [Redmine: #191762]
		- 20231102@Max: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240424@Max: [TVS] Abnormal Bet - Remove some auto void actions & Remove AB (Real Member) issue type [Redmine: #202949]

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

	SELECT TOP(1) q.QueueId, q.MatchId, q.RequestIds, q.Action, q.StatusId, q.BroadcastSessionId
	FROM dbo.TicketVoiding_AutoVoidQueue q WITH(NOLOCK)
	WHERE StatusId IN (0)
		AND 1 = CASE WHEN q.Action IN ('CAL','VoidResultKeyed') AND DATEADD(SECOND,180,CreatedDate) <= GETDATE() THEN 1  --Settletment signal
					WHEN q.Action IN ('VoidInstant','VoidInstantNopolicy','VoidInstantPolicy','RecoverInstant') THEN 1 --Void Instant Abnormal Bet, AB, AA; Recover ticket
				ELSE 0 END
		AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
	ORDER BY q.Action DESC, CreatedDate
END		
GO


