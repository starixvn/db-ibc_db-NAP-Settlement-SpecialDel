/*<info serverAlias="DBMSG-bodb_Message" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: Kathy
	Date: 20200822
	Task : Delete duplicated data in table MsgTarget [Redmine:#140141]
	DB: DBMSG/bodb_Message
*/

USE bodb_Message
GO

SELECT *
INTO #Msg
FROM dbo.msg WITH(NOLOCK)
WHERE MsgContentsType = 103
and MsgType = 1
and IsBatch = 1
and CreateTime > '2020-08-21'
and CreatorName = 'StarixIt'

SELECT *
INTO #VoidingHistory
FROM DBTXN.bodb02.dbo.TicketVoiding_VoidingHistory WITH(NOLOCK)
WHERE CreatedDate > '2020-08-21'

SELECT *
INTO MsgTargetDeleted_bk_20200821
FROM dbo.MsgTarget m with(nolock)
WHERE messageid in (select messageid from #Msg)
AND messageid not in (select messageid from #VoidingHistory)

WHILE (1 = 1)
BEGIN
	DELETE	TOP (2000)
	FROM dbo.MsgTarget WITH(ROWLOCK, UPDLOCK)
	WHERE MsgTargetId IN (SELECT MsgTargetId FROM MsgTargetDeleted_bk_20200821)

	IF @@ROWCOUNT < 2000
		BREAK
END

 



