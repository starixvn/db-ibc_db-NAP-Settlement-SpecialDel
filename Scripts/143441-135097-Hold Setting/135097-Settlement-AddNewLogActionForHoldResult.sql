/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20201113@Louisa
	Task : Insert new LogAction 81021 for turn on/off ResultSetting [Redmine:#135097]
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
		VALUES ( 81021, 'NAP_Set_ResultDetailSettingUpd', 'Turn On/Off Hold Result'	  , 'Turn On/Off Hold Result' )
	
		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
END