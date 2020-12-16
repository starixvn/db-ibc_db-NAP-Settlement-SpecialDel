/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_Sel]
(
	@RequestId INT = 0,
	@VoidingHistoryID INT = 0
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200215@Max: Create new SP [Redmine: #128359]
		- 20201203@Charles: Optimize Voiding Workflow [Redmine: #145719]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	IF (@RequestId = 0)
	BEGIN		
		DECLARE @Session INT = 0

		SELECT @Session = (SELECT MIN(SessionID) 
							FROM dbo.Ticketvoiding_VoidBetAutomation_Service vbs WITH(NOLOCK) 
							WHERE statusID = 12 AND NOT EXISTS (
								SELECT TOP 1 1
								FROM dbo.Ticketvoiding_VoidBetAutomation_Service temp WITH(NOLOCK)
								WHERE vbs.SessionID = temp.SessionID AND temp.statusID = 3
							))
	
		IF @Session IS NULL
		BEGIN
			RETURN
		END
	
		SELECT tvs.matchID
			, tvs.RequestID
			, tvs.SessionID
			, tvs.statusID
			, tvs.NegativeBalanceUsers
			, tvs.VoidingHistory
		FROM dbo.Ticketvoiding_VoidBetAutomation_Service tvs WITH (NOLOCK)
		WHERE tvs.SessionID = @Session 
	END
	ELSE
	BEGIN
		SELECT RequestID
			,VoidingHistory AS VoidingHistoryId
			,statusID
		FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH(NOLOCK) 
		WHERE RequestID = @RequestId AND VoidingHistory = @VoidingHistoryID
	END
END