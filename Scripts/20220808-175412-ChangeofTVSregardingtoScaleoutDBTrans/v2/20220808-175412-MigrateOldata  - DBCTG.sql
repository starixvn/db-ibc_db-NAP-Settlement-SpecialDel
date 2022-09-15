/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220913@July
	Task: Migrate column SiteDBGroupID [Redmine:#175412]  
	DB: DBCTG-bodb02
		   
*/
USE bodb02
GO

DECLARE @batch INT = 3000;
/***** UPDATE column SiteDBGroupID into dbo.TicketVoiding_RequestDetailTicket_Single *****/
WHILE (1 = 1)
BEGIN
	UPDATE TOP (@batch) s
	SET s.SiteDBGroupID = ISNULL(b.SiteDBGroupID,0)
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(ROWLOCK, UPDLOCK)
		LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON s.TransId = b.TransId AND s.MatchId = b.matchid
	WHERE s.SiteDBGroupID IS NULL

	IF @@ROWCOUNT = 0 BREAK
END

/***** UPDATE column SiteDBGroupID into dbo.TicketVoiding_RequestDetailTicket_SubParlay*****/
WHILE (1 = 1)
BEGIN
	UPDATE TOP (@batch) rp
	SET rp.SiteDBGroupID = ISNULL(bm.SiteDBGroupID,0)
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH(ROWLOCK, UPDLOCK)
		LEFT JOIN dbo.bettransm bm WITH (NOLOCK) ON rp.TransId = bm.TransId AND rp.MatchId = bm.matchid
	WHERE rp.SiteDBGroupID IS NULL
	IF @@ROWCOUNT = 0 BREAK
END
GO