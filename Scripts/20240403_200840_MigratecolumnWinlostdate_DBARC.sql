/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*
    Created: 20240403@July
	Task: [TVS] SP tuning for EC2024 [Redmine: #200840]
	DB: DBARC/bodb_Archive
*/

USE bodb_Archive
GO

/***** UPDATE column Winlostdate into dbo.TicketVoiding_RequestDetailTicket_Single_bk *****/
WHILE (1 = 1)
BEGIN
	UPDATE TOP (3000) s
	SET s.Winlostdate = bk.winlostdate
	FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.bettrans_bk bk WITH (NOLOCK) 
		  ON s.TransId = bk.TransId 
	WHERE s.MatchId IN (9, 29, 2799, 10449)
		AND s.Winlostdate IS NULL

	IF @@ROWCOUNT = 0 BREAK
END
GO
