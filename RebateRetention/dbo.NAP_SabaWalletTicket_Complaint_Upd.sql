/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SabaWalletTicket_Complaint_Upd	
	  @CustID		INT	
	 ,@IsComplaint	BIT
	 ,@Transid		BIGINT	
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]

	Param's Explanation: 
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @tmp TABLE (IsComplaint BIT);

	UPDATE  SabaWalletTicket
	SET  IsComplaint = @IsComplaint
		,RepUpdateTime = SYSDATETIME()
	OUTPUT DELETED.IsComplaint 
	INTO @tmp(IsComplaint)
	WHERE TransID = @Transid
		AND CustID = @CustID

	SELECT IsComplaint
	FROM @tmp

END