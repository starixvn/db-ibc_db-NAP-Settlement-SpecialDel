/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20240110@Louisa
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 2024011@Louisa: Insert new LogAction for Hold match [Redmine:#198710]

*/
USE bodb_CustomerLog
GO

BEGIN
	SET NOCOUNT ON;

	INSERT INTO LogAction
		(
			 [ActionID]		
			,[SPName]		
			,[ActionNameEN]
		)
		VALUES ( 81049, 'NAP_Set_SettlementStatusUpd', 'Turn On/Off hold match'	)

END
GO