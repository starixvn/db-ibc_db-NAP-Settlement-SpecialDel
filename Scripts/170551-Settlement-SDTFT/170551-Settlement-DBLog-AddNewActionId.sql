/*<info serverAlias="DBLOG-bodbCustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220413@Kathy
	Task	: Add new action [Redmine:#170551]

*/
USE [bodb_CustomerLog]
GO 

IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81037)
	INSERT INTO dbo.LogAction (ActionID, SPName, ActionNameEN) VALUES (81037,'NAP_Admin_Settlement_1_Instant', 'Calculate HT SDT(FT)')
