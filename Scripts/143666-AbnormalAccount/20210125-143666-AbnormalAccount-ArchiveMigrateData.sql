/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210125@July
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBARC/bodb_Archive
*/
USE bodb_Archive

GO

INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single_bk (RequestDetailId)
SELECT rd.Id
FROM dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) 
	INNER JOIN dbo.TicketVoiding_Request_bk r WITH (NOLOCK) 
		ON r.RequestId = rd.RequestId
	INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK)	
		ON s.RequestId = rd.RequestId AND s.MatchId = rd.MatchId
WHERE s.RequestDetailId IS NULL

GO

/***** INSERT column RequestDetailId, MainTransId into dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk *****/
INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk (RequestDetailId)
SELECT rd.Id
FROM dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) 
	INNER JOIN dbo.TicketVoiding_Request_bk r WITH (NOLOCK) 
		ON r.RequestId = rd.RequestId
	INNER JOIN dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk rp WITH(NOLOCK)	
		ON rp.RequestId = rd.RequestId AND rp.MatchId = rd.MatchId
WHERE rp.RequestDetailId IS NULL

GO

INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (MainTransId)
SELECT tmp.transid
FROM dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) 
	INNER JOIN dbo.TicketVoiding_Request_bk r WITH (NOLOCK) 
		ON r.RequestId = rd.RequestId
	CROSS APPLY (
				SELECT   b.transid,rp.MainTransId
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk rp WITH (NOLOCK)
					INNER JOIN bodb02.dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
					INNER HASH JOIN bodb02.dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
				WHERE  rd.RequestId = rp.RequestId
				)tmp
WHERE tmp.MainTransId IS NULL
