/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221012@July
	Task: TVS - Wrong HDP/ 1H HDP - Migrate old data TicketVoiding_RequestDetail_bk - [Redmine:#172486]  
	DB: DBARC-bodb_Archive
*/

USE bodb_Archive
GO

CREATE TABLE #tmpRequest ( RequestId INT, LiveIndicator BIT)
INSERT INTO #tmpRequest (RequestId, LiveIndicator )
SELECT r.RequestId, s.liveindicator
FROM dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
 CROSS APPLY ( 
            SELECT DISTINCT s.RequestId, b.liveindicator
            FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK)
            INNER JOIN dbo.bettrans_bk b WITH(NOLOCK) on s.TransId = b.transid AND s.MatchId = b.matchid AND s.CustId = s.CustId
            WHERE r.RequestId = s.RequestId
            )s
WHERE r.IssueTypeId IN (4,5) 

INSERT INTO #tmpRequest (RequestId, LiveIndicator)
SELECT r.RequestId, s.liveindicator
FROM dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
 CROSS APPLY ( 
            SELECT DISTINCT s.RequestId, b.liveindicator
            FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk s WITH(NOLOCK)
            INNER JOIN dbo.bettransm b WITH(NOLOCK) on s.TransId = b.transid AND s.MatchId = b.matchid
            WHERE r.RequestId = s.RequestId
            )s
WHERE r.IssueTypeId IN (4,5) 
AND NOT EXISTS ( SELECT TOP 1 1 FROM #tmpRequest tmp WHERE s.RequestId = tmp.RequestId AND s.liveindicator = tmp.LiveIndicator)

UPDATE rd WITH (ROWLOCK,UPDLOCK)
SET rd.IssueDetail = rd.IssueDetail + ';LiveGameEarlySingleCount:' +  CAST(rd.SingleCount AS VARCHAR(20)) + ';PoolHouseSingleCount:0;PoolHouseMainParlayCount:' +  CAST(rd.MainParlayCount AS VARCHAR(20))
   ,rd.TransIds = SUBSTRING(rd.TransIds,0, LEN(rd.TransIds) - 1) +'LiveIndicator ="' + CAST(tmp.LiveIndicator AS VARCHAR(20)) + '" IsLinkGroup1X2="0" IsLinkGroupAIO="0" PoolHouseCheckedBetTypes="" />'
FROM dbo.TicketVoiding_RequestDetail_bk rd
	INNER JOIN #tmpRequest tmp ON rd.RequestId = tmp.RequestId
WHERE rd.IssueDetail NOT LIKE '%LiveGameEarlySingleCount%' AND rd.TransIds NOT LIKE '%IsLinkGroup1X2%'
AND rd.TransIds IS NOT NULL

DROP TABLE #tmpRequest