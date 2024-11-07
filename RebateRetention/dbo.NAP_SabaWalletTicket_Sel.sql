/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SabaWalletTicket_Sel]		
	  @CustID		INT	
	 ,@FromDate		DATETIME
	 ,@ToDate		DATETIME
	 ,@StatusID		TINYINT
	 ,@WalletId		TINYINT				
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBACC-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]

	Param's Explanation: 
		- Saba Wallet Ticket List: StatusID = 1, WalletID = 2
*/
BEGIN	
	SET NOCOUNT ON

	SELECT Transid, Amount, ProgramID, APaymentDate, IsComplaint
	FROM SabaWalletTicket WITH(NOLOCK)
	WHERE CustID = @CustID
	    AND StatusId = @StatusID
		AND WalletID = @WalletId
		AND (APaymentDate BETWEEN @FromDate AND @ToDate OR  IsComplaint = 1)

END