/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: Raymond
	Date: 20201119
	Task : Delete duplicated data in table TicketVoiding_VoidedTransaction [Redmine:#145102]
	DB: DBTXN/bodb02
*/

USE bodb02
GO

DECLARE @Message TABLE (MessageId INT)

INSERT INTO @Message (MessageId)
SELECT DISTINCT vt.MessageId
FROM dbo.TicketVoiding_VoidedTransaction vt with(nolock)
WHERE CreatedDate > '2020-11-18'
and IssueTypeID = 1
and matchid = 0
and messageid <> 0
and not exists (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory vh with(nolock) WHERE vh.MessageId = vt.MessageId)

UNION 
SELECT DISTINCT vt.MessageId
FROM dbo.TicketVoiding_VoidedTransaction vt with(nolock)
WHERE CreatedDate > '2020-11-18'
and IssueTypeID = 1
and matchid = 39849685
and messageid <> 0
and not exists (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory vh with(nolock) WHERE vh.MessageId = vt.MessageId)

WHILE (1 = 1)
BEGIN
	DELETE TOP (2000)
	FROM dbo.TicketVoiding_VoidedTransaction with(rowlock, updlock)
	WHERE messageid in (select messageid from @Message)

	IF @@ROWCOUNT < 2000
		BREAK
END



