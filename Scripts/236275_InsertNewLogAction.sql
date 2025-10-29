/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20251010@Louisa
    Task: Basketball Player Prop [Redmine:#236275]
    DB: DBPRO/bodb02
    
    Revisions:            
		- 20251010@Louisa: Insert new LogAction [Redmine:#236275]

*/
 
USE bodb_CustomerLog
GO

BEGIN

	BEGIN TRY
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction l WITH(ROWLOCK) WHERE l.ActionID = 81066 )
		BEGIN
			INSERT INTO LogAction
			(
				 [ActionID]		
				,[SPName]		
				,[ActionNameEN]
				,[ActionNameCH]
			)
			VALUES ( 81066, '', 'Clear Confirm Status' , 'Clear Confirm Status' )
		END
	
		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
END