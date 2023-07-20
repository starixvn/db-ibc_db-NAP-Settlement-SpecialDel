/*<info serverAlias="DBRPT-bodb_Report" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_DuplicateTickets_Select]
(
	@TransIds VARCHAR(MAX) = NULL
)
AS
/*	
	Created by:20230717@Max
	Task: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
	DB: DBRPT/bodb_Report
	
	Revisions: 
		- 20230717@Max: Create new SP [Redmine:#187835]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FromDate DATETIME
		, @ToDate DATETIME
		, @CurrentDate DATETIME
		, @TransInfoJson	VARBINARY(MAX)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)

	SELECT @CurrentDate = CAST(GETDATE() AS DATE)

	SELECT @FromDate = DATEADD(MI, -5, @CurrentDate)
		, @ToDate = DATEADD(DD, 1, @CurrentDate)

	IF @TransIds <> ''
	BEGIN
		

	INSERT INTO #transIdTemp (transid)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''

		SET @TransInfoJson = COMPRESS((SELECT b.custid
				,b.odds
				,b.stake
				,b.balance
				,b.statusID
				,b.bettype
				,b.winlostdate
				,b.username
				,b.transid
				,CONVERT(BIGINT,(CASE WHEN b.Bettype IN (901,902,903,904,911) THEN b.RefNo WHEN b.Bettype = 29 THEN b.hdp1 ELSE 0 END)) AS refnoGroup
				,b.transdate
				,b.matchid
				,b.ip
				,ISNULL(CAST(b.WalletType AS SMALLINT),-1) AS WalletType
				,b.betteam
				,b.oddsid
				,b.SiteDBGroupID
			FROM	dbo.DuplicatedTicket t WITH (NOLOCK)	
				INNER JOIN #transIdTemp tmp ON tmp.transid = t.TransId
				INNER JOIN bodb02.dbo.Bettrans b WITH (NOLOCK)	
						ON b.TransID = t.TransID
			WHERE	t.Transdate >= @FromDate 
				AND t.Transdate < @ToDate
				AND b.statusID NOT IN (101,102,103)
				AND b.bettype NOT IN (500) -- exclude 500 - charged commission
				AND b.betfrom <> 'p'
			ORDER BY b.custid, b.odds, b.stake, b.balance, b.bettype, b.winlostdate, b.Username,b.refno, b.transid, b.transdate, b.statusID
		FOR JSON PATH))
	END
	ELSE
	BEGIN
		SET @TransInfoJson = COMPRESS((SELECT b.custid
				,b.odds
				,b.stake
				,b.balance
				,b.statusID
				,b.bettype
				,b.winlostdate
				,b.username
				,b.transid
				,CONVERT(BIGINT,(CASE WHEN b.Bettype IN (901,902,903,904,911) THEN b.RefNo WHEN b.Bettype = 29 THEN b.hdp1 ELSE 0 END)) AS refnoGroup
				,b.transdate
				,b.matchid
				,b.ip
				,ISNULL(CAST(b.WalletType AS SMALLINT),-1) AS WalletType
				,b.betteam
				,b.oddsid
				,b.SiteDBGroupID
			FROM	dbo.DuplicatedTicket t WITH (NOLOCK)	
				INNER JOIN bodb02.dbo.Bettrans b WITH (NOLOCK)	
						ON b.TransID = t.TransID
			WHERE	t.Transdate >= @FromDate 
				AND t.Transdate < @ToDate
				AND b.statusID NOT IN (101,102,103)
				AND b.bettype NOT IN (500) -- exclude 500 - charged commission
				AND b.betfrom <> 'p'
			ORDER BY b.custid, b.odds, b.stake, b.balance, b.bettype, b.winlostdate, b.Username,b.refno, b.transid, b.transdate, b.statusID
		FOR JSON PATH))
	END

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

	DROP TABLE #transIdTemp
END		
GO


