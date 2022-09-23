/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220922@Max
	Task: Update data - [Redmine:#175412]  
	DB: DBSIG-bodb02
*/

USE bodb02
GO

INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, BroadcastSessionId)
SELECT t.RequestId, t.MatchId, t.Action, 0, 10278938, GETDATE(), '125.227.140.97', t.BroadcastSessionId --insert by migrate process
FROM DBCTG.bodb02.dbo.TicketVoiding_AutoVoidRequest_Queue t WITH (NOLOCK)
WHERE t.QueueId IN (7237813,7237514)


