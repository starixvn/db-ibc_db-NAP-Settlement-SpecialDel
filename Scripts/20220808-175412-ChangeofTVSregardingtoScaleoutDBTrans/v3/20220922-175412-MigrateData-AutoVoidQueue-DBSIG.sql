/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220808@Max
	Task: Migrate old data TicketVoiding_AutoVoidRequest_Queue on DBSIG - [Redmine:#175412]  
	DB: DBSIG-bodb02
*/

USE bodb02
GO

DECLARE @batch INT = 3000;

--Migrate Cancel, MixParlay(99) queue to compepleted for consistency with new web service
UPDATE TOP (@batch) q	
	SET q.StatusId = 2, ErrMsg = 'No ticket found.'
FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK, UPDLOCK)
WHERE q.QueueId = 23




