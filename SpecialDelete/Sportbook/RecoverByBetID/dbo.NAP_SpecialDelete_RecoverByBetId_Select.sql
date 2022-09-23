/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverByBetId_Select]
	@TransIds			VARCHAR(MAX) = ''
AS

/*
	Created: Paul
	Task: Get tickets to recover
	DB: DBTXN.bodb02
	Original: 

	Revisions:
		- 20170720@Paul: Create new [RedmineID: #77175]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220825@July: Change of TVS regarding to Scale out DBTrans - Support NumberGame  [Redmine: #175412]

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON;
	DECLARE @SiteDBGroupID		SMALLINT = 0
	        ,@MovebetDate		DATETIME
			,@InvalidTransIds   VARCHAR(MAX) = ''
			,@MovedTransIds     VARCHAR(MAX) = ''
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #RecoverBet (
		transid			BIGINT,
		refno			BIGINT,
		custid			INT,
		username		VARCHAR(50),
		transdate		DATETIME,
		odds			SMALLMONEY,
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
		transdesc		NVARCHAR(1000),
		sporttype		SMALLINT,
		homeid			INT,
		awayid			INT,
		srecommend		INT,
		IsNeutral		BIT,
		CurrencyName	NVARCHAR(50),
		GroupName		VARCHAR(50),
		EventDate		DATETIME,
		matchid			INT, 
		endtime			DATETIME
	);

	CREATE TABLE #TempBet (
		custid			INT,
		matchid			INT,
		bettype			SMALLINT,
		transid			BIGINT,
		username		NVARCHAR(50),
		actual_stake	MONEY,
		oddstype		TINYINT,
		srecommend		INT,
		betid			BIGINT,
		transdesc		NVARCHAR(1000),
		CurrencyName	NVARCHAR(50),
		matchcode		NVARCHAR(50),
		leagueid		INT,
		homeid			INT,
		awayid			INT,
		IsNeutral		BIT,
		sporttype		SMALLINT,
		transdate		DATETIME,
		eventdate		DATETIME,
		endtime			DATETIME
	);

	CREATE TABLE #TempBettrans (
		custid			INT,
		matchid			INT,
		bettype			SMALLINT,
		transid			BIGINT,
		username		NVARCHAR(50),
		actual_stake	MONEY,
		oddstype		TINYINT,
		srecommend		INT,
		betid			BIGINT,
		transdesc		NVARCHAR(1000),
		CurrencyName	NVARCHAR(50),
		transdate		DATETIME
	);
	CREATE INDEX ix_TempBettrans ON #TempBettrans(matchid);
	CREATE CLUSTERED INDEX ix_TempBet_cl ON #TempBet(custid, matchid, bettype);
	CREATE CLUSTERED INDEX ix_RecoverBet_cl ON #RecoverBet(transid);

	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY);
	CREATE TABLE #InvalidTransIds (transid BIGINT, IsMoved BIT);

	CREATE TABLE #SupportedSports (SportType SMALLINT);
	INSERT INTO #SupportedSports(SportType)
	VALUES (175), --Bitcoin 
		   (161), (164) --Number game

	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT)

	--Get Movebetdate
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	--Parse trans ID string
	INSERT INTO #tblTransIds(transid)
	SELECT s.value
	FROM STRING_SPLIT(@TransIds, ',') s
	WHERE s.value <> ''

	--Get tickets from zzzbettrans
	INSERT INTO #TempBettrans(
		custid,
		matchid,
		bettype,
		transid,
		username,
		actual_stake,
		oddstype,
		srecommend,
		betid,
		transdesc,
		CurrencyName,
		transdate
	)
	SELECT	b.custid,
			b.matchid,
			b.bettype,
			b.transid,
			b.username,
			b.actual_stake,
			b.oddstype,
			b.srecommend,
			b.betid,
			b.transdesc,
			b.CurrencyName,
			b.transdate
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #tblTransIds t WHERE t.transid = b.transid)
		AND b.winlostdate >= @MovebetDate	
		AND b.betfrom <> 'p'
		AND b.SiteDBGroupID = @SiteDBGroupID

	INSERT INTO #TempBet(
		custid,
		matchid,
		bettype,
		transid,
		username,
		actual_stake,
		oddstype,
		srecommend,
		betid,
		transdesc,
		CurrencyName,
		matchcode,
		leagueid,
		homeid,
		awayid,
		IsNeutral,
		sporttype,
		transdate,
		eventdate,
		endtime
	)
	------159948 - Support Bitcoin
	SELECT	b.custid,
			b.matchid,
			b.bettype,
			b.transid,
			b.username,
			b.actual_stake,
			b.oddstype,
			b.srecommend,
			b.betid,
			b.transdesc,
			b.CurrencyName,
			m.MatchNo AS matchcode,
			m.League3rdId AS leagueid,
			m.HomeId,
			m.AwayId,
			NULL AS IsNeutral,
			m.sporttype,
			b.transdate,
			m.eventdate,
			m.EndTime
	FROM #TempBettrans b
		INNER JOIN dbo.Match3rd m WITH(NOLOCK) ON m.Match3rdId = b.matchid
	WHERE EXISTS (SELECT 1 FROM #SupportedSports s WHERE s.SportType = m.sporttype)
	UNION ALL 
	------175412 - Support NumberGame
	SELECT	b.custid,
			b.matchid,
			b.bettype,
			b.transid,
			b.username,
			b.actual_stake,
			b.oddstype,
			b.srecommend,
			b.betid,
			b.transdesc,
			b.CurrencyName,
			m.matchcode,
			m.leagueid,
			m.HomeId,
			m.AwayId,
			m.IsNeutral ,
			m.sporttype,
			b.transdate,
			m.eventdate,
			NULL AS EndTime
	FROM #TempBettrans b
		INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
	WHERE EXISTS (SELECT 1 FROM #SupportedSports s WHERE s.SportType = m.sporttype);

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
		CurrencyName,
		EventDate,
		matchid,
		endtime
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
			b.matchcode,
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
			b.leagueid,
			b.sporttype,
			b.homeid,
			b.awayid,
			z.custid,
			b.IsNeutral,
			b.CurrencyName,
			b.EventDate,
			b.matchid,
			b.endtime
	FROM dbo.zzzbettrans z WITH(NOLOCK)
		INNER JOIN #TempBet b
			ON z.transid = b.transid
				AND z.custid = b.custid
				AND z.matchid = b.matchid					
				AND z.bettype = b.bettype
	WHERE z.SiteDBGroupID = @SiteDBGroupID

	UPDATE t
	SET GroupName = CASE WHEN d.custid IS NULL THEN 'Credit' ELSE 'Deposit' END
	FROM #RecoverBet t
		LEFT JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) ON t.srecommend = d.custid;
		
	/*Modify the way to get move bet date*/
	IF EXISTS (SELECT TOP 1 1 FROM #RecoverBet WHERE EventDate <= @MovebetDate)
	BEGIN
		DELETE 
		FROM #RecoverBet
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE EventDate <= @MovebetDate
	END

	------------------------------------------------------------------------------
	--1. Table invald/moved transid
	INSERT INTO #InvalidTransIds(transid, IsMoved)
	SELECT	t.transid,
			CASE WHEN b.transid IS NOT NULL THEN 1
				 WHEN m.TransId IS NOT NULL THEN 1
				ELSE 0 END AS IsMoved
	FROM #tblTransIds t
		LEFT JOIN dbo.bettrans14 b WITH(NOLOCK) ON t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
		LEFT JOIN @tmpTransIdMoveBet m ON t.transid = m.TransId
	WHERE NOT EXISTS (SELECT 1 FROM #RecoverBet r WHERE r.transid = t.transid)
	
	SELECT @InvalidTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
									 FROM #InvalidTransIds
									 WHERE IsMoved = 0
									 FOR XML PATH('')), 1, 1, '');									

	SELECT @MovedTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
								   FROM #InvalidTransIds
								   WHERE IsMoved = 1
								   FOR XML PATH('')), 1, 1, '');	

	SELECT @InvalidTransIds AS InvalidTransIds
	      ,@MovedTransIds AS MovedTransIds
	
	--2. Table get tickets
	SELECT	t.GroupName,
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
			t.CurrencyName,
			t.matchid, 
			t.endtime,
			@SiteDBGroupID AS SiteDBGroupID
	FROM #RecoverBet t
	ORDER BY GroupName, transid;

	DROP TABLE #RecoverBet
	DROP TABLE #TempBet
	DROP TABLE #TempBettrans
	DROP TABLE #InvalidTransIds
	DROP TABLE #tblTransIds
	DROP TABLE #SupportedSports

	SET NOCOUNT OFF;
END
GO