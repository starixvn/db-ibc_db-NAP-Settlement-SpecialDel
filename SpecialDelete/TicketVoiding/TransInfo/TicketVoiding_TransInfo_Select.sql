/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_Select] 
(
	@IssueTypeId			INT
	,@AbnormalBetTransIds	VARCHAR(MAX) = NULL
	,@ArchivedTransIds		VARCHAR(MAX) = NULL
	,@RecoverTicketInfo		VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240424@Max: [TVS] Abnormal Bet - Remove some auto void actions & Remove AB (Real Member) issue type [Redmine: #202949]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240916@Max: [TVS] Support void wrong odds for Sportsbook [Redmine: #186029]
		- 20240925@July: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
		- 20241021@Max: [TVS] New Issue Type - Other Issues [Redmine: #211913]
		- 20241021@Max: [TVS] New Issue Type - Other Issues [Redmine: #211913]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	/*---AbnormalBet---*/
	IF @IssueTypeId IN (11)
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_AB_Select
			@AbnormalBetTransIds = @AbnormalBetTransIds
	END
	/*-----------------*/

	/*---Archived Ticket---*/
	IF @IssueTypeId = 17
	BEGIN
		EXEC dbo.TicketVoiding_TransInfo_ARC_Select
			@ArchivedTransIds = @ArchivedTransIds
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
