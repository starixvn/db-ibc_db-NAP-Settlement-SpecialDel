/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20210810@Kathy
    Task: Insert new LogAction for Bitcoin [Readmine:#159714]
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 20210810@Kathy:  Insert new LogAction for Bitcoin [Readmine:#159714]

*/
USE bodb_CustomerLog
GO

BEGIN

	BEGIN TRY
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction l WITH(ROWLOCK) WHERE l.ActionID = 81033 )
		BEGIN
			INSERT INTO LogAction
			(
				 [ActionID]		
				,[SPName]		
				,[ActionNameEN]
				,[ActionNameCH]
			)
			VALUES ( 81033, 'NAP_Admin_Settlement_s175', 'Bitcoin - Calculate'	  , 'Bitcoin - Calculate' )
		END
	
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction l WITH(ROWLOCK) WHERE l.ActionID = 81034 )
		BEGIN
			INSERT INTO LogAction
			(
				 [ActionID]		
				,[SPName]		
				,[ActionNameEN]
				,[ActionNameCH]
			)
			VALUES ( 81034, 'NAP_Admin_Settlement_s175', 'Bitcoin - Refund'	  , 'Bitcoin - Refund' )
		END

		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
END

