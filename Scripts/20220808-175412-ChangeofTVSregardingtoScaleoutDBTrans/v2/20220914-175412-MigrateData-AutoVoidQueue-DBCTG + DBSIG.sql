/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220808@Max
	Task: Migrate old data TicketVoiding_AutoVoidRequest_Queue - [Redmine:#175412]  
	DB: DBCTG-bodb02,DBSIG-bodb02
*/

USE bodb02
GO

DECLARE @batch INT = 3000;

--Migrate Cancel, MixParlay(99) queue to compepleted for consistency with new web service
WHILE (1 = 1)
BEGIN
	UPDATE TOP (@batch) q	
		SET q.StatusId = 2
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK, UPDLOCK)
	WHERE q.StatusId IN (4, 99)

	IF @@ROWCOUNT = 0 BREAK

	WAITFOR DELAY '00:00:00.100'
END

--Initial session for waiting/running queue before release
WHILE (1 = 1)
BEGIN
	UPDATE TOP (@batch) q	
		SET q.BroadcastSessionId = NEWID()
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK, UPDLOCK)
	WHERE q.StatusId IN (0, 1)

	IF @@ROWCOUNT = 0 BREAK

	WAITFOR DELAY '00:00:00.100'
END




