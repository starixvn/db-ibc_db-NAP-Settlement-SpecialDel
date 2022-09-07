/*<info serverAlias="DBCTG-msdb" executers="" viewers="" isFunction="0"></info>*/

/*
	Created: 20220906@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBCTG/bodb02
 	
	Revisions:
		- 20220906@Louisa: grant permission send email to account bodbAdminNet  [Redmine:#175251]
 
*/

USE msdb
GO

IF NOT EXISTS ( SELECT TOP 1 1 FROM sys.sysusers WHERE name  = 'bodbAdminNet' )
BEGIN
	CREATE USER [bodbadminNet] FOR LOGIN [bodbadminNet]
END
GO

GRANT EXEC ON sp_send_dbmail TO [bodbadminNet] 
GO