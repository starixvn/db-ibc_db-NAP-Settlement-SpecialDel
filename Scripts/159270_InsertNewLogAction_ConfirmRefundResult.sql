/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210811@Louisa
	Task : Insert new LogAction 81032 to turn on/off "Confirm Refund Result" for Tennis, E-Sports [Redmine:#159270]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

SET NOCOUNT ON

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction l WITH(ROWLOCK, UPDLOCK) WHERE l.ActionId = 81032 )
	BEGIN
		
		INSERT INTO LogAction
		(
			[ActionID]		
			,[SPName]		
			,[ActionNameEN]
			,[ActionNameCH]
		)
		VALUES ( 81032, 'NAP_Set_ResultDetailSettingUpd', 'Confirm Refund - Turn On/Off'	  , 'Confirm Refund - Turn On/Off' )
	
	END 
GO
