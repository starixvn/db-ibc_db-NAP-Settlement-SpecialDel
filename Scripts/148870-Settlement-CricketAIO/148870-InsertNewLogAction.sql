/*<info serverAlias="DBLOG-bodbCustomerLog" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210126@kathy
    Task: New log action for cricket [Redmine:#148870]
    DB: DBLOG/bodbCustomerLog
	
*/

USE bodb_CustomerLog
GO
IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81025)
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81025, 'Move Tickets Settled Results', 'NAP_Settlement_MoveTicket')

GO