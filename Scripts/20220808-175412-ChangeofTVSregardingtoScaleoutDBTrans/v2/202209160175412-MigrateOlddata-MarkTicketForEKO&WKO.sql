/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220916@July
	Task: Migrate old data - Mark ticket for EKO&WKO issuetype  [Redmine:#175412]  
	DB: DBCTG-bodb02
		   
*/
USE bodb02
GO

--Mark single
INSERT INTO dbo.MarkedTransaction ( TransId, MatchId, CustId, bettype, UserId, CreatedDate, MarkType)
SELECT DISTINCT s.TransId, s.MatchId, ISNULL(s.CustId, b.custid), ISNULL(s.Bettype, b.Bettype), 10278938, GETDATE(), 0
FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
	INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = s.TransId AND s.MatchId = b.matchid
	LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON s.MatchId = m.MatchId AND s.TransId = m.TransId
WHERE IssueTypeId IN (8,9) AND m.TransId IS NULL

--Mark subparly
INSERT INTO dbo.MarkedTransaction ( TransId, MatchId, CustId, bettype, UserId, CreatedDate, MarkType)
SELECT DISTINCT rp.MainTransId, rp.MatchId, bm.CustId, bm.Bettype, 10278938, GETDATE(), 0
FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH(NOLOCK)
	INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.transid = rp.TransId AND rp.MatchId = bm.matchid
	LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON rp.MatchId = m.MatchId AND rp.MainTransId = m.TransId
WHERE IssueTypeId IN (8,9) AND m.TransId IS NULL 

