/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Select]
(
	@VoidingHistoryId	INT = NULL
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RetryTime INT = 120
		,@ErrMsgLockMatch VARCHAR(300) = '1000000'

	IF @VoidingHistoryId IS NULL
	BEGIN
		SELECT TOP (1) @VoidingHistoryId = q.VoidingHistoryId
		FROM	dbo.TicketVoiding_Queue q WITH(ROWLOCK)
		WHERE q.StatusId = 1
			AND 1 = CASE 
					WHEN ErrMsg = @ErrMsgLockMatch AND DATEADD(SECOND, @RetryTime, DATEADD(MS, duration, Exectime)) > GETDATE() THEN 0
					ELSE 1
				END
		ORDER BY CASE WHEN ErrMsg = @ErrMsgLockMatch THEN DATEADD(SECOND, @RetryTime, DATEADD(MS, duration, Exectime)) ELSE Starttime END
				,q.VoidingHistoryId

		IF @@ROWCOUNT = 0
			RETURN
	
		IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_Queue v WITH (NOLOCK) WHERE v.VoidingHistoryId = @VoidingHistoryId AND v.StatusId = 99)
		BEGIN
			SELECT	RequestId
					,QueueId
					,MatchId
					,VoidingTypeId
					,TransIds
					,UserId
					,IP
					,@VoidingHistoryId AS VoidingHistoryId
					,StatusId
					,NegativeBalanceUsers
			FROM	dbo.TicketVoiding_Queue WITH(NOLOCK)
			WHERE	VoidingHistoryId = @VoidingHistoryId
		END
	END
	ELSE
	BEGIN
		SELECT	RequestId
					,QueueId
					,MatchId
					,VoidingTypeId
					,TransIds
					,UserId
					,IP
					,@VoidingHistoryId AS VoidingHistoryId
					,StatusId
					,NegativeBalanceUsers
			FROM	dbo.TicketVoiding_Queue WITH(NOLOCK)
			WHERE	VoidingHistoryId = @VoidingHistoryId
	END
END
GO

