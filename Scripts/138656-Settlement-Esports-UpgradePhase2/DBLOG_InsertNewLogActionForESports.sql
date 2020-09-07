/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20200819@Louisa
    Task: Insert new LogAction for ESports [Redmine:#138656]
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 20200819@Louisa: Insert new LogAction for ESports [Redmine:#138656]

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
		VALUES ( 81016, 'NAP_Set_ExternalResultDetailESIns', 'Save Score'	  , 'Save Score' )
	
		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
END

