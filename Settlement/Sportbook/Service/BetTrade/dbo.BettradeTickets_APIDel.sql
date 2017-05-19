 ALTER PROCEDURE [dbo].[BettradeTickets_APIDel]	
	@session NVARCHAR(50),
	@numTicket INT
 AS
	/*
		Created: Johnson
		Date: 2015-09-14
		Task: remove list tickets of bettrade have been sent by API
		DB: DBTXN/bodb02
		
		Revisions:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON 
	
	DELETE TOP (@numTicket) BettradeAPI WITH(UPDLOCK,ROWLOCK)
	WHERE session = @session
END
GO
GRANT EXECUTE ON [dbo].[BettradeTickets_APIDel] TO [bodbAdminNet]