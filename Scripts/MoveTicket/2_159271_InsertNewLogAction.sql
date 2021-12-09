/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

/*	
	Creator: Louisa
	Date: 20210930
	Task: Move ticket
	DB: DBLOG/bodb_CustomerLog

	Revisions:
		- 20210930@Louisa: Insert new LogAction  [Redmine:#159271]

*/

USE bodb_CustomerLog
GO

SET NOCOUNT ON

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction l WITH(ROWLOCK, UPDLOCK) WHERE l.ActionId = 81035 )
	BEGIN
		
		INSERT INTO LogAction
		(
			[ActionID]		
			,[SPName]		
			,[ActionNameEN]
			,[ActionNameCH]
		)
		VALUES ( 81035, 'NAP_Admin_Settlement_MoveTicket', 'Move Running Tickets'	  , 'Move Running Tickets' )
	
	END 
GO
