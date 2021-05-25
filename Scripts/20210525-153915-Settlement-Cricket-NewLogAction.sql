/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20210525@Louisa
    Task: Insert new LogAction for Cricket [Readmine:#153915]
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 20210525@Louisa:  Insert new LogAction for Cricket [Readmine:#153915]

*/
USE bodb_CustomerLog
GO

BEGIN

	BEGIN TRY
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction l WITH(ROWLOCK) WHERE l.ActionID = 81027 )
		BEGIN
			INSERT INTO LogAction
			(
				 [ActionID]		
				,[SPName]		
				,[ActionNameEN]
				,[ActionNameCH]
			)
			VALUES ( 81027, 'NAP_Set_ExternalResultDetailESIns', 'Save Trader Score'	  , 'Save Trader Score' )
		END
	
		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
END

