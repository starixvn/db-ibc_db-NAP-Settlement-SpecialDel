/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverByBetId_Select]
	@TransIds			VARCHAR(MAX),
	@InvalidTransIds	VARCHAR(MAX) OUTPUT,
	@MovedTransIds		VARCHAR(MAX) OUTPUT
AS

/*
	Created: Paul
	Task: Get tickets to recover
	DB: DBTXN.bodb02
	Original: 

	Revisions:
		- 20170720@Paul: Create new [RedmineID: #77175]

*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #RecoverBet (
		transid			BIGINT,
		refno			BIGINT,
		custid			INT,
		username		VARCHAR(50),
		transdate		DATETIME,
		odds			MONEY,
		stake			MONEY,
		winlost			MONEY,
		STATUS			NVARCHAR(10),
		bettype			SMALLINT,
		matchcode		NVARCHAR(50),
		OddsType		TINYINT,
		betteam			NVARCHAR(10),
		betcheck		NVARCHAR(50),
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		leagueid		INT,
		IsLiveIndicator BIT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		betid			BIGINT,
		transdesc		NVARCHAR(300),
		sporttype		SMALLINT,
		homeid			INT,
		awayid			INT,
		srecommend		INT,
		IsNeutral		BIT,
		CurrencyName	NVARCHAR(50)
	);

	CREATE TABLE #TransIds (transid BIGINT PRIMARY KEY);

	CREATE TABLE #InvalidTransIds (transid BIGINT, IsMoved BIT);

	DECLARE @before_yesterday SMALLDATETIME;

	SELECT @before_yesterday = CONVERT(VARCHAR(10), DATEADD(DAY, -2, GETDATE()), 120);

	--Parse trans ID string
	INSERT INTO #TransIds(transid)
	SELECT DISTINCT ss.val
	FROM dbo.f_SplitString(@TransIds, ',') ss
	OPTION (maxrecursion 0);

	--Get tickets from zzzbettrans
	INSERT INTO #RecoverBet(
		transid,
		refno,
		username,	
		transdate,	
		odds,
		stake,
		winlost,
		STATUS,
		bettype,
		matchcode,
		OddsType,					
		betteam,		
		betcheck,		
		hdp1,			
		hdp2,		
		srecommend,		
		IsLiveIndicator,
		livehomescore,	
		liveawayscore,						
		betid,
		transdesc,
		leagueid,
		sporttype,
		homeid,
		awayid,
		custid,
		IsNeutral,
		CurrencyName
	)
	SELECT	z.transid,
			z.refno,
			b.Username,		
			b.transdate,
			z.odds,
			z.stake,
			z.winlost - b.actual_stake,
			z.STATUS,
			z.bettype,
			m.matchcode,
			b.oddstype,				
			z.betteam,
			z.betcheck,
			z.hdp1,
			z.hdp2,
			b.srecommend,
			z.liveindicator,
			z.livehomescore,
			z.liveawayscore,	
			b.betid,
			b.transdesc,
			m.leagueid,
			m.sporttype,
			m.homeid,
			m.awayid,
			z.custid,
			m.IsNeutral,
			b.CurrencyName
	FROM dbo.zzzbettrans z WITH(NOLOCK)
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON z.transid = b.transid
				AND z.custid = b.custid
				AND z.matchid = b.matchid					
				AND z.bettype = b.bettype
		INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
	WHERE b.transid IN (SELECT s.transid FROM #TransIds s)	
		AND z.winlostdate >= @before_yesterday	
		AND m.sporttype = 160
		AND b.betfrom <> 'p';

	CREATE CLUSTERED INDEX ix_RecoverBet_cl ON #RecoverBet(transid);

	SELECT	CASE WHEN d.custid IS NULL THEN 'Credit' ELSE 'Deposit' END AS GroupName,
			t.transid,
			t.refno,
			t.username,
			t.transdate,
			t.odds,
			t.stake,
			t.winlost,
			t.STATUS,
			t.bettype,
			t.OddsType,
			t.betteam,
			t.betcheck,
			t.hdp1,
			t.hdp2,
			t.leagueid,
			t.IsLiveIndicator,
			t.livehomescore,
			t.liveawayscore,
			t.betid,
			t.transdesc,
			t.sporttype AS SportTypeId,
			t.homeid,
			t.awayid,
			t.matchcode,
			t.IsNeutral,
			t.CurrencyName
	FROM #RecoverBet t
		LEFT JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) ON t.srecommend = d.custid
	ORDER BY GroupName, transid;

	INSERT INTO #InvalidTransIds(transid, IsMoved)
	SELECT	t.transid,
			CASE WHEN b.transid IS NOT NULL THEN 1 
				ELSE 0 END AS IsMoved
	FROM #TransIds t
		LEFT JOIN dbo.bettrans14 b WITH(NOLOCK) ON t.transid = b.transid
	WHERE NOT EXISTS (SELECT 1 FROM #RecoverBet r WHERE r.transid = t.transid);

	SELECT @InvalidTransIds = STUFF(
									(
										SELECT ',' + CAST(transid AS VARCHAR(MAX))
										FROM #InvalidTransIds
										WHERE IsMoved = 0
										FOR XML PATH('')
									), 1, 1, '');									

	SELECT @MovedTransIds = STUFF(
									(
										SELECT ',' + CAST(transid AS VARCHAR(MAX))
										FROM #InvalidTransIds
										WHERE IsMoved = 1
										FOR XML PATH('')
									), 1, 1, '');	

	SET NOCOUNT OFF;
END
GO