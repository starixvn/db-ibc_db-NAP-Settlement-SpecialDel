/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SabaProgram_PendingBalance_Sel]
	  @CustID		INT					
	 ,@WalletId		TINYINT
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBSIC-bodb02,DBACC-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]
		- 20250425@Aries: Update curreny code [Redmine: #224807]

	Param's Explanation:  					
*/
BEGIN	
	;WITH CTE AS (
		SELECT SUM(Amount) AS Amount,MAX(CurrencyID) AS CurrencyID, MAX(TransDate) AS LatestTransdate
		FROM SabaWalletTicket WITH(NOLOCK)
		WHERE CustID = @CustID
			AND WalletId = @WalletId
			AND StatusId = 0
	) 
	SELECT c.Amount, e.Code AS CurrencyCode, c.LatestTransdate
	FROM CTE AS c
		INNER JOIN dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = c.CurrencyID
END