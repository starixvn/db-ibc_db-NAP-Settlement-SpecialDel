/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210206@Max
	Task: TVS - Lock TempVariableNumber and can't void cash out ticket - [Redmine: #150176]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

UPDATE b SET b.Status = 'Confirm'
FROM dbo.BetTradeSelling b WITH (ROWLOCK, UPDLOCK)
WHERE b.TicketID = 111073419149
	AND b.MatchID = 41366872
	AND b.Status = 'BeginVoid'

GO

