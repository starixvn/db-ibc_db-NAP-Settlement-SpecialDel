 ALTER PROCEDURE [dbo].[BettradeTickets_APIGet]
 
 AS
 /*
	Created: Johnson
	Date: 2015-09-10
	Task: get list tickets of bettrade and send by API
	DB: DBTXN/bodb02
	
	Revisions:
	
	Parameter's Explanation:
 */ 
 BEGIN
	SET NOCOUNT ON
	DECLARE @session NVARCHAR(50), @action NVARCHAR(50), @reason NVARCHAR(300)
	
	SELECT top (1) @session = session, @action = action, @reason = remark
	FROM BettradeAPI WITH(NOLOCK)
	ORDER BY id ASC
			
	SELECT 		
		matchid,
		transid as TicketID,
		BuyBackNo,
		Payout		
	FROM BettradeAPI WITH(NOLOCK)	
	WHERE session = @session
		
	
	SELECT @session as session, @action action, @reason as reason, @@rowcount as numTicket
 END
 GO
 GRANT EXECUTE ON [dbo].[BettradeTickets_APIGet] TO [bodbAdminNet]
 
 