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
SELECT s.TransId, s.MatchId, s.CustId, s.Bettype, GETDATE(), 0
FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
	LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON s.MatchId = m.MatchId AND s.TransId = m.TransId
WHERE IssueTypeId IN (8,9) AND m.TransId IS NULL

--Mark subparly
INSERT INTO dbo.MarkedTransaction ( TransId, MatchId, CustId, bettype, UserId, CreatedDate, MarkType)
SELECT rp.MainTransId, rp.MatchId, bm.CustId, bm.Bettype, GETDATE(), 0
FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH(NOLOCK)
	INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.transid = rp.TransId AND rp.MatchId = bm.matchid
	LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON rp.MatchId = m.MatchId AND rp.TransId = m.TransId
WHERE IssueTypeId IN (8,9) AND m.TransId IS NULL