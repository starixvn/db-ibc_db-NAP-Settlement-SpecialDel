/*<info serverAlias="IRS_DBTP-bodb02,DBCustRepl-ReplDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250521@Louisa	
	Task: In-House
	DB: IRS_DBTP-bodb02,DBCustRepl-ReplCustDB
	
	Revisions:
		- 20250521@Louisa: Created [RedmineID: #226060]

	Example:			
*/

IF NOT EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'CustWinLimitBet')
BEGIN
	INSERT INTO RepInfo ([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size) 
	SELECT 0,'CustWinLimitBet',0,'repupdatetime',0,'CustID|Sporttype|Bettype','Repl_GetCustWinLimitBet','Repl_PutCustWinLimitBet_Dist',1000,10,60000,0
END
ELSE
BEGIN  
	SELECT 'CustWinLimitBet exists !!!'
END
GO
/***************************************************************************/
IF NOT EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'CustWinLimitBet_History')
BEGIN
	INSERT INTO RepInfo ([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size) 
	SELECT 0,'CustWinLimitBet_History',0,'repupdatetime',0,'ID','Repl_GetCustWinLimitBet_History','Repl_PutCustWinLimitBet_History_Dist',1000,10,60000,0
END
ELSE
BEGIN  
	SELECT 'CustWinLimitBet_History exists !!!'
END
GO
/***************************************************************************/



