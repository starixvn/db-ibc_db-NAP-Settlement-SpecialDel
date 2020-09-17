/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20200914@Max
	Task: [TVS] Enhance Void by Accept Time in Void Single Bet and TVS Danger Accept - [Redmine: #141127]
	DB: bodb02 - DBTRANS
*/

USE bodb02
GO

UPDATE dbo.TicketVoiding_RequestDetail WITH (ROWLOCK, UPDLOCK)
 SET FilterBy = IsFilterByTransTime
WHERE IsFilterByTransTime IS NOT NULL