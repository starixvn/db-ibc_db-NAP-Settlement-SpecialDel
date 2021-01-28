/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210125@July
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBARC/bodb_Archive
*/
USE bodb_Archive

GO

/***** UPDATE column RequestDetailId into dbo.TicketVoiding_RequestDetailTicket_Single_bk *****/
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) s
	SET RequestDetailId = rd.Id
	FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) 
		  ON s.RequestId = rd.RequestId AND s.MatchId = rd.MatchId\

	IF @@ROWCOUNT = 0 BREAK
END
GO

/***** UPDATE column RequestDetailId, MainTransId into dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk *****/
WHILE (1 = 1)
BEGIN
	UPDATE rp
	SET rp.RequestDetailId = rd.Id
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk rp WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) 
		  ON rp.RequestId = rd.RequestId AND rp.MatchId = rd.MatchId
	WHERE rp.RequestDetailId IS NULL

	IF @@ROWCOUNT = 0 BREAK
END
GO
WHILE (1 = 1)
BEGIN
	UPDATE rp
	SET rp.MainTransId = b.transid
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk rp WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) 
		  ON rp.RequestId = rd.RequestId AND rp.MatchId = rd.MatchId
	INNER JOIN bodb02.dbo.bettransm bm WITH (NOLOCK) ON rp.TransId = bm.transid
	INNER HASH JOIN bodb02.dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
	WHERE rp.MainTransId IS NULL

	IF @@ROWCOUNT = 0 BREAK
END
GO