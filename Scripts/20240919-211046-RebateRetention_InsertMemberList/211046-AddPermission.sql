/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" isFunction="0"></info>*/
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBLOG-bodb_CustomerLog
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]

	Param's Explanation:  					
*/
USE bodb_CustomerLog
GO
GRANT EXECUTE ON [dbo].[WriteLog_UserLog_RunSP] TO [wsv_nap]