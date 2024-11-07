/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SabaWalletTicket_Validation
	  @CustIDs			VARCHAR(MAX)	
	 ,@SiteDBGroupID	SMALLINT
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBACC-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]

	Param's Explanation: 
*/
BEGIN	
	SET NOCOUNT ON

	SELECT ss.value AS CustId
	FROM STRING_SPLIT(@CustIDs,',') AS ss
		LEFT JOIN dbo.Customer AS c WITH(NOLOCK) ON c.custid = ss.value
		LEFT JOIN dbo.Site AS s WITH(NOLOCK) ON s.Site = c.Site AND s.SiteDBGroupID = @SiteDBGroupID
	WHERE s.Site IS NULL

END