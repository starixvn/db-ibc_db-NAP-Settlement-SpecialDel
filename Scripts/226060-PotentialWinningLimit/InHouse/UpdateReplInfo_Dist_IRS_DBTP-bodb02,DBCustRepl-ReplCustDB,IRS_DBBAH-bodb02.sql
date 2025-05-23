/*<info serverAlias="IRS_DBTP-bodb02,DBCustRepl-ReplDB,IRS_DBBAH-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250521@Louisa	
	Task: In-House
	DB: IRS_DBTP-bodb02,DBCustRepl-ReplCustDB
	
	Revisions:
		- 20250521@Louisa: Created [RedmineID: #226060]

	Example:			
*/
IF EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'CustWinLimitBet')
BEGIN
	UPDATE RepInfo
	SET active = 1
	WHERE [group] = 0
		AND [name] =  'CustWinLimitBet'
END
ELSE
BEGIN  
	SELECT 'CustWinLimitBet not exists !!!'
END
GO
/***************************************************************************/
IF EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'CustWinLimitBet_History')
BEGIN
	UPDATE RepInfo
	SET active = 1
	WHERE [group] = 0
		AND [name] =  'CustWinLimitBet_History'
END
ELSE
BEGIN  
	SELECT 'CustWinLimitBet_History not exists !!!'
END
GO
/***************************************************************************/



