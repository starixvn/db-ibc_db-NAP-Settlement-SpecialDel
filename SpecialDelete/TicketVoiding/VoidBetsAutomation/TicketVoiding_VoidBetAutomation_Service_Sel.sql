/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_Sel]
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
	DECLARE @Session INT = 0

	SELECT @Session = (SELECT MIN(SessionID) 
						FROM dbo.Ticketvoiding_VoidBetAutomation_Service  
						WHERE statusID = 0)
	
	IF @Session IS NULL
		RETURN
	
	SELECT tvs.matchID
		, tvs.RequestID
		, tvs.SessionID
		, tvs.statusID
		, tvs.NegativeBalanceUsers
		, tvs.VoidingHistory
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service tvs WITH (NOLOCK)
	WHERE tvs.SessionID = @Session 

END