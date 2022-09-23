/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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

	DECLARE @IsCentral BIT
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	/*---DangerAccept---*/
	IF @IssueTypeId = 1
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_DA_Select
			@DangerAcceptedInfo = @DangerAcceptedInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---WrongScore---*/
	IF @IssueTypeId = 3
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_WC_Select
			@WrongScoreInfo = @WrongScoreInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---WrongHDP---*/
	IF @IssueTypeId = 4
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_HDP_Select
			@WrongHDPInfo = @WrongHDPInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---Wrong1sHDP---*/
	IF @IssueTypeId = 5
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_1sHDP_Select
			@Wrong1stHDPInfo = @Wrong1stHDPInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---WrongOU---*/
	IF @IssueTypeId = 6
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_OU_Select
			@WrongOUInfo = @WrongOUInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---Wrong1sOU---*/
	IF @IssueTypeId = 7
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_1sOU_Select
			@Wrong1stOUInfo = @Wrong1stOUInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/
	 
	/*---EKO / WrongKOTime---*/
	IF @IssueTypeId IN (8,9)
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_KO_Select
			@KickOffInfo = @KickOffInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---RedCard---*/
	IF @IssueTypeId = 10
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_RC_Select
			@RedCardInfo = @RedCardInfo
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---AbnormalBet / AB RealMember---*/
	IF @IssueTypeId IN (11,15)
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_AB_Select
			@AbnormalBetTransIds = @AbnormalBetTransIds
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---AbnormalAccount---*/
	IF @IssueTypeId = 13
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_ACC_Select
			@AbnormalAccounts = @AbnormalAccounts
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

	/*---Archived Ticket---*/
	IF @IssueTypeId = 17
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_ARC_Select
			@ArchivedTransIds = @ArchivedTransIds
			,@IsCentral = @IsCentral
	END
	/*-----------------*/

END

GO

