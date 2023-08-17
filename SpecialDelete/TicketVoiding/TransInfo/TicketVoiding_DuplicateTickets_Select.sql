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

	CREATE TABLE #tmpTransInfo (
		custid INT
		,odds SMALLMONEY
		,stake MONEY
		,balance MONEY
		,statusID TINYINT
		,bettype SMALLINT
		,winlostdate SMALLDATETIME
		,transid BIGINT
		,refnoGroup BIGINT
		,transdate DATETIME
		,matchid INT
		,ip VARCHAR(45)
		,WalletType SMALLINT
		,betteam NVARCHAR(10)
		,oddsid INT
		,SiteDBGroupID SMALLINT
		,IsMoved14 BIT DEFAULT(0)
	)

	SELECT @CurrentDate = CAST(GETDATE() AS DATE)

	SELECT @FromDate = DATEADD(MI, -5, @CurrentDate)
		, @ToDate = DATEADD(DD, 1, @CurrentDate)

	IF @TransIds <> ''
	BEGIN
		INSERT INTO #transIdTemp (transid)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''

		INSERT INTO #tmpTransInfo (custid 
			,odds 
			,stake 
			,balance 
			,statusID 
			,bettype 
			,winlostdate 
			,transid 
			,refnoGroup 
			,transdate 
			,matchid 
			,ip 
			,WalletType 
			,betteam 
			,oddsid 
			,SiteDBGroupID
		)
		SELECT b.custid AS 'c'
			,b.odds AS 'o'
			,b.stake AS 'stake'
			,b.balance AS 'balance'
			,b.statusID AS 'sid'
			,b.bettype AS 'btype' 
			,b.winlostdate AS 'wld'
			,b.transid AS 't'
			,CONVERT(BIGINT,(CASE WHEN b.Bettype IN (901,902,903,904,911) THEN b.RefNo WHEN b.Bettype = 29 THEN b.hdp1 ELSE 0 END)) AS 'refgr'
			,b.transdate AS 'tdate'
			,b.matchid AS 'mid'
			,b.ip AS 'ip'
			,ISNULL(CAST(b.WalletType AS SMALLINT),-1) AS 'wt' 
			,b.betteam AS 'bteam'
			,b.oddsid AS 'oid'
			,b.SiteDBGroupID AS 'sitedb'
		FROM dbo.DuplicatedTicket t WITH (NOLOCK)	
			INNER JOIN #transIdTemp tmp ON tmp.transid = t.TransId
			INNER JOIN bodb02.dbo.Bettrans b WITH (NOLOCK)	
					ON b.TransID = t.TransID
		WHERE b.statusID NOT IN (101,103)
			AND b.bettype NOT IN (500) -- exclude 500 - charged commission
			AND b.betfrom <> 'p'

		IF EXISTS (SELECT TOP 1 1 FROM #transIdTemp t
						INNER JOIN  bodb02.dbo.bettrans14 b WITH (NOLOCK)	
					ON b.TransID = t.TransID
				)
		BEGIN
			INSERT INTO #tmpTransInfo (custid 
				,odds 
				,stake 
				,balance 
				,statusID 
				,bettype 
				,winlostdate 
				,transid 
				,refnoGroup 
				,transdate 
				,matchid 
				,ip 
				,WalletType 
				,betteam 
				,oddsid 
				,SiteDBGroupID
				,IsMoved14
			)
			SELECT b.custid AS 'c'
				,b.odds AS 'o'
				,b.stake AS 'stake'
				,b.balance AS 'balance'
				,b.statusID AS 'sid'
				,b.bettype AS 'btype' 
				,b.winlostdate AS 'wld'
				,b.transid AS 't'
				,CONVERT(BIGINT,(CASE WHEN b.Bettype IN (901,902,903,904,911) THEN b.RefNo WHEN b.Bettype = 29 THEN b.hdp1 ELSE 0 END)) AS 'refgr'
				,b.transdate AS 'tdate'
				,b.matchid AS 'mid'
				,b.ip AS 'ip'
				,ISNULL(CAST(b.WalletType AS SMALLINT),-1) AS 'wt' 
				,b.betteam AS 'bteam'
				,b.oddsid AS 'oid'
				,b.SiteDBGroupID AS 'sitedb'
				,1 AS IsMoved14
			FROM dbo.DuplicatedTicket t WITH (NOLOCK)	
				INNER JOIN #transIdTemp tmp ON tmp.transid = t.TransId
				INNER JOIN bodb02.dbo.Bettrans14 b WITH (NOLOCK)	
						ON b.TransID = t.TransID
			WHERE b.statusID NOT IN (101,103)
				AND b.bettype NOT IN (500) -- exclude 500 - charged commission
				AND b.betfrom <> 'p'
		END

		--delete  child match cricket (Sporttype = 50)
		IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransInfo WHERE bettype NOT IN (9, 29, 2799)))
		BEGIN
			DELETE d
			FROM #tmpTransInfo d
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON	d.matchid = m.matchid AND m.sporttype = 50 AND m.ChildMatchType = 200
			WHERE d.bettype NOT IN (9, 29, 2799)
		END

		SET @TransInfoJson = COMPRESS((SELECT b.custid AS 'c'
				,b.odds AS 'o'
				,b.stake AS 'stake'
				,b.balance AS 'balance'
				,b.statusID AS 'sid'
				,b.bettype AS 'btype' 
				,b.winlostdate AS 'wld'
				,b.transid AS 't'
				,b.refnoGroup AS 'refgr'
				,b.transdate AS 'tdate'
				,b.matchid AS 'mid'
				,b.ip AS 'ip'
				,b.WalletType AS 'wt' 
				,b.betteam AS 'bteam'
				,b.oddsid AS 'oid'
				,b.SiteDBGroupID AS 'sitedb'
				,b.IsMoved14 AS 'isM'
			FROM #tmpTransInfo b
			ORDER BY b.custid, b.odds, b.stake, b.balance, b.bettype, b.winlostdate, b.transid, b.transdate, b.statusID
		FOR JSON PATH))
	END
	ELSE
	BEGIN
		SET @TransInfoJson = COMPRESS((SELECT b.custid AS 'c'
				,b.odds AS 'o'
				,b.stake AS 'stake'
				,b.balance AS 'balance'
				,b.statusID AS 'sid'
				,b.bettype AS 'btype' 
				,b.winlostdate AS 'wld'
				,b.transid AS 't'
				,CONVERT(BIGINT,(CASE WHEN b.Bettype IN (901,902,903,904,911) THEN b.RefNo WHEN b.Bettype = 29 THEN b.hdp1 ELSE 0 END)) AS 'refgr'
				,b.transdate AS 'tdate'
				,b.matchid AS 'mid'
				,b.ip AS 'ip'
				,ISNULL(CAST(b.WalletType AS SMALLINT),-1) AS 'wt' 
				,b.betteam AS 'bteam'
				,b.oddsid AS 'oid'
				,b.SiteDBGroupID AS 'sitedb'
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
	DROP TABLE #tmpTransInfo
END		
GO


