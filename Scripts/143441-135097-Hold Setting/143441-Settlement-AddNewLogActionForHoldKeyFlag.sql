/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20201026@Louisa
	Task : Insert new LogAction 81019 for turn on/off settlement status - HoldKey [Redmine:#143441]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

BEGIN

	BEGIN TRY
		INSERT INTO LogAction
		(
			 [ActionID]		
			,[SPName]		
			,[ActionNameEN]
			,[ActionNameCH]
		)
		VALUES ( 81019, 'NAP_Set_SettlementStatusUpd', 'Turn On/Off Hold Key'	  , 'Turn On/Off Hold Key' )
	
		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
END