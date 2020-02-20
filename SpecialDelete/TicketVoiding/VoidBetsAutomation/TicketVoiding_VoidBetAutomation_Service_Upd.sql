/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_Upd]
(
	@SessionId INT
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200215@Max: Create new SP [Redmine: #128359]	
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET statusID = 2
			, ModifiedDate = GETDATE()
	WHERE SessionID = @SessionId

END