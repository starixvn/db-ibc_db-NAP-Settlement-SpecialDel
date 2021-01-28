/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210125@July
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBTXN-bodb02
*/

USE bodb02
GO
/***** UPDATE column RequestDetailId into dbo.TicketVoiding_RequestDetailTicket_Single *****/
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) s
	SET RequestDetailId = rd.Id
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
		  ON s.RequestId = rd.RequestId AND s.MatchId = rd.MatchId
	WHERE s.RequestDetailId IS NULL

	IF @@ROWCOUNT = 0 BREAK
END

GO

/***** UPDATE column RequestDetailId, MainTransId into dbo.TicketVoiding_RequestDetailTicket_SubParlay*****/
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) rp
	SET rp.RequestDetailId = rd.Id
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
		  ON rp.RequestId = rd.RequestId AND rp.MatchId = rd.MatchId
	WHERE rp.RequestDetailId IS NULL

	IF @@ROWCOUNT = 0 BREAK
END
GO

WHILE (1 = 1)
BEGIN

	UPDATE TOP (3000) rp
	SET rp.MainTransId = b.transid
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
		  ON rp.RequestId = rd.RequestId AND rp.MatchId = rd.MatchId
	INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON rp.TransId = bm.transid
	INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
	WHERE rp.MainTransId IS NULL

	IF @@ROWCOUNT = 0 BREAK
END

GO

-- Insert queue manual into table service
INSERT INTO dbo.Ticketvoiding_VoidBetAutomation_Service (RequestID, VoidingHistory, statusID, matchID, createdDate, ModifiedDate, IsRunExternalService)
SELECT   q.QueueId
		,q.VoidingHistoryId
		,12
		,q.MatchId
		,q.Starttime
		,q.Exectime
		,1
FROM dbo.TicketVoiding_Queue q WITH(NOLOCK)
INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON q.RequestId = r.RequestId
WHERE NOT EXISTS ( SELECT 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) WHERE s.RequestID = q.RequestID)

WHILE (1 = 1)
BEGIN
	UPDATE TOP (1) s
	SET s.SessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1
	FROM Ticketvoiding_VoidBetAutomation_Service s WITH (ROWLOCK, UPDLOCK)
	WHERE SessionID IS NULL

	IF @@ROWCOUNT = 0 BREAK
END
GO

-- 1. NegativeBalanceUsers (TicketVoiding_Queue) --> Ticketvoiding_VoidBetAutomation_Service
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) s 
	SET s.NegativeBalanceUsers = q.NegativeBalanceUsers
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.TicketVoiding_Queue q WITH (NOLOCK) ON s.RequestID = q.RequestId AND s.VoidingHistory = q.VoidingHistoryId
		INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON s.RequestId = r.RequestId
	WHERE (s.NegativeBalanceUsers is null or s.NegativeBalanceUsers = '')
		AND q.NegativeBalanceUsers IS NOT NULL 
		AND q.NegativeBalanceUsers <> ''

	IF @@ROWCOUNT = 0 BREAK
END
GO

-- 2. Update statusID (2) -> (12)
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) s 
	SET s.statusID = 12 -- Completed
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (ROWLOCK, UPDLOCK)
	WHERE s.statusID = 2

	IF @@ROWCOUNT = 0 BREAK
END
GO

-- 3. Update (No ticket found.%) statusID = 3(Failed) -> 2 (Completed)
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) q 
	SET q.StatusId = 2
	FROM dbo.TicketVoiding_Queue q WITH (ROWLOCK, UPDLOCK)
	WHERE q.ErrMsg LIKE '%No ticket found.%'
		AND q.StatusId = 3
	IF @@ROWCOUNT = 0 BREAK
END

GO