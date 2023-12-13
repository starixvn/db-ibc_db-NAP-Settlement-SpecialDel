/*<info serverAlias="DBTXN-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*	
	Created: 20231213@Louisa
	Task: create user [Redmind:#198307]
	DB: DBTXN-bodb_CustomerLog

*/

USE [bodb_CustomerLog]
GO

IF NOT EXISTS ( SELECT * FROM SYS.sysusers WHERE name = 'Dot_Intg')
BEGIN
	CREATE USER [Dot_Intg] FOR LOGIN [Dot_Intg] WITH DEFAULT_SCHEMA=[dbo]
END
GO