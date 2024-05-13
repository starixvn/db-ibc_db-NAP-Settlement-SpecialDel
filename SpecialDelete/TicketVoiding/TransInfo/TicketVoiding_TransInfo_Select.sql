/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_Select] 
(
	@IssueTypeId		  INT
	,@KickOffInfo	      VARCHAR(MAX) = NULL
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo  VARCHAR(MAX) = NULL
	,@RedCardInfo		  VARCHAR(MAX) = NULL
	,@WrongHDPInfo		  VARCHAR(MAX) = NULL
	,@Wrong1stHDPInfo	  VARCHAR(MAX) = NULL
	,@WrongOUInfo		  VARCHAR(MAX) = NULL
	,@Wrong1stOUInfo	  VARCHAR(MAX) = NULL
	,@AbnormalBetTransIds VARCHAR(MAX) = NULL
	,@AbnormalAccounts	  VARCHAR(MAX) = NULL
	,@ArchivedTransIds	  VARCHAR(MAX) = NULL
	,@WrongOddsInfo       VARCHAR(MAX) = NULL
	,@ReducedOverInfo	  VARCHAR(MAX) = NULL
	,@NotParticipateInfo  VARCHAR(MAX) = NULL
	,@RecoverTicketInfo   VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240424@Max: [TVS] Abnormal Bet - Remove some auto void actions & Remove AB (Real Member) issue type [Redmine: #202949]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	/*---DangerAccept---*/
	IF @IssueTypeId = 1
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_DA_Select
			@DangerAcceptedInfo = @DangerAcceptedInfo
	END
	/*-----------------*/

	/*---WrongOdds---*/
	IF @IssueTypeId = 2
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_WO_Select
			@WrongOddsInfo = @WrongOddsInfo
	END
	/*-----------------*/

	/*---WrongScore---*/
	IF @IssueTypeId = 3
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_WC_Select
			@WrongScoreInfo = @WrongScoreInfo
	END
	/*-----------------*/

	/*---WrongHDP---*/
	IF @IssueTypeId = 4
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_HDP_Select
			@WrongHDPInfo = @WrongHDPInfo
	END
	/*-----------------*/

	/*---Wrong1sHDP---*/
	IF @IssueTypeId = 5
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_1sHDP_Select
			@Wrong1stHDPInfo = @Wrong1stHDPInfo
	END
	/*-----------------*/

	/*---WrongOU---*/
	IF @IssueTypeId = 6
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_OU_Select
			@WrongOUInfo = @WrongOUInfo
	END
	/*-----------------*/

	/*---Wrong1sOU---*/
	IF @IssueTypeId = 7
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_1sOU_Select
			@Wrong1stOUInfo = @Wrong1stOUInfo
	END
	/*-----------------*/
	 
	/*---EKO / WrongKOTime---*/
	IF @IssueTypeId IN (8,9)
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_KO_Select
			@KickOffInfo = @KickOffInfo
	END
	/*-----------------*/

	/*---RedCard---*/
	IF @IssueTypeId = 10
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_RC_Select
			@RedCardInfo = @RedCardInfo
	END
	/*-----------------*/

	/*---AbnormalBet---*/
	IF @IssueTypeId IN (11)
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_AB_Select
			@AbnormalBetTransIds = @AbnormalBetTransIds
	END
	/*-----------------*/

	/*---AbnormalAccount---*/
	IF @IssueTypeId = 13
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_ACC_Select
			@AbnormalAccounts = @AbnormalAccounts
	END
	/*-----------------*/

	/*---Archived Ticket---*/
	IF @IssueTypeId = 17
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_ARC_Select
			@ArchivedTransIds = @ArchivedTransIds
	END
	/*-----------------*/

	/*---Reduced Over / Abandoned---*/
	IF @IssueTypeId IN (19,23)
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_RO_Select
			@ReducedOverInfo = @ReducedOverInfo
	END
	/*-----------------*/

	/*---Not Participate---*/
	IF @IssueTypeId = 21
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_NP_Select
			@NotParticipateInfo = @NotParticipateInfo
	END
	/*-----------------*/

	/*---Recover Ticket---*/
	IF @IssueTypeId = 22
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_RT_Select
			@RecoverTicketInfo = @RecoverTicketInfo
	END
	/*-----------------*/

END

GO

