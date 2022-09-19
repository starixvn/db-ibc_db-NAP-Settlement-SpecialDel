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
WHILE (1 = 1)
BEGIN
	UPDATE TOP (@batch) q	
		SET q.StatusId = 2
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK, UPDLOCK)
	WHERE q.StatusId IN (4, 99)

	IF @@ROWCOUNT = 0 BREAK
END

--Initial session for waiting/running queue before release, use link server to DBCTG to get the same Session
DECLARE @tmp_session AS TABLE (MatchId INT, RequestId INT, BroadcastSessionId VARCHAR(100), Action VARCHAR(100))
INSERT INTO @tmp_session (MatchId, RequestId, BroadcastSessionId, Action)
SELECT q1.MatchId, q1.RequestId, q1.BroadcastSessionId, q1.Action
FROM DBCTG.bodb02.dbo.TicketVoiding_AutoVoidRequest_Queue q1 WITH (NOLOCK) 
WHERE q1.StatusId IN (0, 1)

IF @@ROWCOUNT > 0
BEGIN
	WHILE (1 = 1)
	BEGIN
		UPDATE TOP (@batch) q	
			SET q.BroadcastSessionId = t.BroadcastSessionId
		FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmp_session t ON t.MatchId = q.MatchId AND t.RequestId = q.RequestId AND q.Action = t.Action
		WHERE q.StatusId IN (0, 1)
			AND q.BroadcastSessionId IS NULL

		IF @@ROWCOUNT = 0 BREAK
	END

	INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, BroadcastSessionId)
	SELECT t.RequestId, t.MatchId, t.Action, 0, 10278938, GETDATE(), '125.227.140.97', t.BroadcastSessionId --insert by migrate process
	FROM @tmp_session t
		LEFT JOIN dbo.TicketVoiding_AutoVoidRequest_Queue q WITH (NOLOCK) ON q.MatchId = t.MatchId AND q.RequestId = t.RequestId AND q.Action = t.Action
	WHERE q.MatchId IS NULL
END




