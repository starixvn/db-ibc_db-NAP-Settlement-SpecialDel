/*<info serverAlias="DBLOG-bodbCustomerLog" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210126@kathy
    Task: New log action for cricket [Redmine:#148870]
    DB: DBLOG/bodbCustomerLog
	
*/

USE bodb_CustomerLog
GO
--- Log Move Ticket ( written by SP Move ticket)
IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81025)
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81025, 'Move Tickets Settled Results', 'NAP_Settlement_MoveTicket')

GO

--- Log Move Ticket ( written error message by Web )
IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81026)
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81026, 'Move Tickets Settled Results', 'NAP_Settlement_MoveTicket')

GO