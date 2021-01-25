/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210125@July
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestDetailId)
SELECT rd.Id
FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
	INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) 
		ON r.RequestId = rd.RequestId
	INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)	
		ON s.RequestId = rd.RequestId AND s.MatchId = rd.MatchId
WHERE s.RequestDetailId IS NULL

GO
/***** INSERT column RequestDetailId, MainTransId into dbo.TicketVoiding_RequestDetailTicket_SubParlay*****/

INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (RequestDetailId)
SELECT rd.Id
FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
	INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) 
		ON r.RequestId = rd.RequestId
	INNER JOIN dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH(NOLOCK)	
		ON rp.RequestId = rd.RequestId AND rp.MatchId = rd.MatchId
WHERE rp.RequestDetailId IS NULL

GO

INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (MainTransId)
SELECT tmp.transid
FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
	INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) 
		ON r.RequestId = rd.RequestId
	CROSS APPLY (
				SELECT   b.transid,rp.MainTransId
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
					INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
					INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
				WHERE  rd.RequestId = rp.RequestId
				)tmp
WHERE tmp.MainTransId IS NULL

GO

-- NegativeBalanceUsers (TicketVoiding_Queue) --> Ticketvoiding_VoidBetAutomation_Service
UPDATE s  WITH (ROWLOCK, UPDLOCK)
SET s.NegativeBalanceUsers = CASE WHEN s.NegativeBalanceUsers <> '' AND s.NegativeBalanceUsers IS NOT NULL THEN s.NegativeBalanceUsers
																	   ELSE CASE WHEN  q.NegativeBalanceUsers IS NOT NULL AND q.NegativeBalanceUsers <> '' THEN q.NegativeBalanceUsers
																			ELSE NULL END END 
FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
	INNER JOIN dbo.TicketVoiding_Queue q WITH (NOLOCK) ON s.RequestID = q.RequestId AND s.VoidingHistory = q.VoidingHistoryId
WHERE (s.NegativeBalanceUsers <> ''AND s.NegativeBalanceUsers IS NOT NULL) OR (q.NegativeBalanceUsers IS NOT NULL AND q.NegativeBalanceUsers <> '')

GO

--Update statusID (2) -> (12)
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) s WITH (ROWLOCK, UPDLOCK)
	SET s.statusID = 12 -- Completed
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service s
	WHERE s.statusID = 2

	IF @@ROWCOUNT = 0 BREAK
END

GO

-- Update (No ticket found.%) statusID = 3(Failed) -> 2 (Completed)
UPDATE q WITH (ROWLOCK, UPDLOCK)
SET q.StatusId = 2
FROM dbo.TicketVoiding_Queue q (nolock)
WHERE q.ErrMsg LIKE '%No ticket found.%'

GO

--- Update Transid (TicketVoiding_VoidingHistory) = NULL apply for issue type (except Abnormal Bet)
UPDATE vh WITH (ROWLOCK, UPDLOCK)
SET vh.TransIds = NULL
FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) 
INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON vh.RequestId = r.RequestId
WHERE (TransIds IS NOT NULL  OR  TransIds <> '') AND r.IssueTypeId <> 11 

GO