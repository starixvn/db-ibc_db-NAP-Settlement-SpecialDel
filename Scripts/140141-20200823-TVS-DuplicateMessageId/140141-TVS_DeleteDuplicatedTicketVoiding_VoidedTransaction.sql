/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: Kathy
	Date: 20200822
	Task : Delete duplicated data in table TicketVoiding_VoidedTransaction [Redmine:#140141]
	DB: DBTXN/bodb02
*/

USE bodb02
GO

SELECT DISTINCT messageid
into #msg
FROM dbo.TicketVoiding_VoidedTransaction vt with(nolock)
WHERE CreatedDate > '2020-08-21'
and IssueTypeID = 11
and matchid = 0
and messageid <> 0
and not exists (SELECT TOP 1 1 FROM TicketVoiding_VoidingHistory vh with(nolock) WHERE vh.MessageId = vt.MessageId)

WHILE (1 = 1)
BEGIN
	DELETE TOP (2000)
	FROM dbo.TicketVoiding_VoidedTransaction with(rowlock, updlock)
	WHERE messageid in (select messageid from #msg)

	IF @@ROWCOUNT < 2000
		BREAK
END



