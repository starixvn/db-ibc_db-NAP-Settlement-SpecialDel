/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20250819@Louisa
    Task: Insert new LogAction for JT CO [Redmine:#235508]
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 20250819@Louisa:  Insert new LogAction for JT CO [Redmine:#235508]

*/

USE bodb_CustomerLog
GO

BEGIN

	BEGIN TRY
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction l WITH(ROWLOCK) WHERE l.ActionID = 81062 )
		BEGIN
			INSERT INTO LogAction
			(
				 [ActionID]		
				,[SPName]		
				,[ActionNameEN]
				,[ActionNameCH]
			)
			VALUES ( 81062, 'NAP_Settlement_1_CashoutSel', 'CashOut JackTime  Result API'	  , 'CashOut JackTime  Result API' )
		END
	
		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
END
