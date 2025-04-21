/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]
		- 20250415@Aries: Credit Reward - PROD - Give reward to member - Apr 2025 [Redmine: #224160]

	Param's Explanation:  					
*/
USE bodb02
GO
UPDATE dbo.SabaWalletTicket
SET Amount = 320,
	RepUpdateTime  = [dbo].[f_GetDateTime2]()
WHERE TransId  IN (378909183166119946,378909183166119960,378909183166119975,378909183166120049,378909183166120318)
