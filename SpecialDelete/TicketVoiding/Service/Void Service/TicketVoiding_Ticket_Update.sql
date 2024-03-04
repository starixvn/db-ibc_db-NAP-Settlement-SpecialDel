/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Ticket_Update]
(
	@RequestId			INT
	,@MatchId			INT
	,@TransIds			VARCHAR(MAX)
	,@VoidingHistoryId	INT
	,@VoidingTypeId		TINYINT
	,@UserId			INT
	,@IP				VARCHAR(50)
	,@IssueTypeId		TINYINT = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = ''	OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX)	= NULL	OUTPUT
	,@ResettledTransIds   VARCHAR(MAX)	= NULL	OUTPUT
)
AS
/*	Created by: 20181212@Kathy
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20210501@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210401@Kathy:  Enhance Auto Void Retry process [Redmine:#152581]
		- 20210622@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20211115@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]
		- 20211202@Max: TVS - Void Archived Tickets [Redmine: #140180]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230517@Max: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835] 
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	IF (@IssueTypeId = 17) OR (@IssueTypeId = 13 AND @VoidingTypeId = 5) --Void 14
	BEGIN
		EXEC dbo.TicketVoiding_VoidHistorical_Update
			@RequestId				= @RequestId
			,@MatchId				= @MatchId
			,@VoidingHistoryId		= @VoidingHistoryId
			,@TransIds				= @TransIds
			,@UserId				= @UserId
			,@IP					= @IP
			,@IssueTypeId			= @IssueTypeId
			,@FailedTransIds		= @FailedTransIds OUTPUT
			,@ErrCode				= @ErrCode	OUTPUT
			,@ErrMsg				= @ErrMsg	OUTPUT
			,@NegativeBalanceUsers  = @NegativeBalanceUsers	OUTPUT
			,@MoveBetMatchIds		= @MoveBetMatchIds OUTPUT
	END
	ELSE IF (@VoidingTypeId IN (1,4) OR (@VoidingTypeId = 2 AND @IssueTypeId IN (11,13,20)))-- Single
	BEGIN
		EXEC dbo.TicketVoiding_SingleType_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId	
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@IssueTypeId = @IssueTypeId
			,@ErrCode = @ErrCode OUTPUT	
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			,@MoveBetMatchIds = @MoveBetMatchIds OUTPUT
	END
	ELSE IF @VoidingTypeId = 2 -- subParlay
	BEGIN
		EXEC dbo.TicketVoiding_ParlayType_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@IssueTypeId = @IssueTypeId
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
	END
	ELSE IF @VoidingTypeId = 3 --Cancel CashOut
	BEGIN
		EXEC dbo.TicketVoiding_CancelCashOutType_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
	END

	/*-----------RECOVER------------*/
	ELSE IF @VoidingTypeId IN (11) --Single ticket
	BEGIN
		EXEC dbo.TicketVoiding_RecoverSingleType_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			,@ResettledTransIds	= @ResettledTransIds	OUTPUT
	END
	ELSE IF @VoidingTypeId IN (12) --Parlay ticket
	BEGIN
		EXEC dbo.TicketVoiding_RecoverMainParlayType_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			,@ResettledTransIds	= @ResettledTransIds	OUTPUT
	END
	ELSE IF @VoidingTypeId IN (14) --Cricket ticket
	BEGIN
		EXEC dbo.TicketVoiding_RecoverSingleType_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			,@ResettledTransIds	= @ResettledTransIds	OUTPUT
	END
	ELSE IF @VoidingTypeId IN (17) --Cricket14 ticket
	BEGIN
		EXEC dbo.TicketVoiding_RecoverHistorical_Single_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			,@ResettledTransIds	= @ResettledTransIds	OUTPUT
	END
	ELSE IF @VoidingTypeId IN (15) --Single14 ticket
	BEGIN
		EXEC dbo.TicketVoiding_RecoverHistorical_Single_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			,@ResettledTransIds	= @ResettledTransIds	OUTPUT
	END
	ELSE IF @VoidingTypeId IN (16) --Parlay14 ticket
	BEGIN
		EXEC dbo.TicketVoiding_RecoverHistorical_MainParlay_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			,@ResettledTransIds	= @ResettledTransIds	OUTPUT
	END

END
GO

