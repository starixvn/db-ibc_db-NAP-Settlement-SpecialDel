ALTER PROCEDURE [dbo].[NAP_VoidMetricGaming_Sel]
	@MatchId			INT,
	@BetTypes			VARCHAR(1000)	= '',		
	@Event801			VARCHAR(2000) 	= '',--801 
	@Event803			VARCHAR(2000) 	= '',--803 	
	@Event804			VARCHAR(2000) 	= '',--804 
	@Event805			VARCHAR(2000) 	= ''--805 
AS
BEGIN
/*
    Created by: 20150624@Dominic
	Date: 
	Original: 
	Task: Select Metric Gaming tickets for delete
	DB: DBTXN/BODB02

	Revisions:
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20160401@Bobby: #55354 - Update changes for new message structure
	
	Explanation's Param:


*/
	SET NOCOUNT ON
	CREATE TABLE #SpecialDeleteBets (
		transid				BIGINT,
		refno				BIGINT,
		custid				INT,
		username			VARCHAR(30),
		username2			NVARCHAR(50),
		odds				MONEY, 
		OddsType			INT, 
		transdate			DATETIME,
		bettype				SMALLINT, 
		betteam				NVARCHAR(10),
		betcheck			NVARCHAR(50),
		hdp1				SMALLMONEY, 
		hdp2				SMALLMONEY,
		IsLiveIndicator		BIT,
		livehomescore 		SMALLINT, 
		liveawayscore 		SMALLINT,
		creator				VARCHAR(30),
		Stake				MONEY,
		CurrencyName		VARCHAR(10),
		IsDeposit			TINYINT,
		status				NVARCHAR(10), 
		mrecommend			INT, 
		recommend			INT, 
		SecAcceptFlag		BIT,
		betid				BIGINT,
		transdesc			NVARCHAR(300)
	)
	DECLARE @Event801Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event801Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event801, '^')
	
	DECLARE @Event803Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event803Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event803, '^')
	
	DECLARE @Event804Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event804Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event804, '^')
	
	DECLARE @Event805Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event805Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event805, '^')
		
	INSERT INTO #SpecialDeleteBets
	SELECT
		b.translogID transid,
		b.translogID refno,
		b.custid,
		c.username,
		c.username2,
		b.odds,   
		b.custom1 OddsType,  
		b.transdate,
		b.GameID,
		NULL betteam,
		NULL betcheck,
		0 hdp1,
		0 hdp2,
		b.liveindicator liveindicator,
		NULL livehomescore,
		NULL liveawayscore,
		cr.username AS creator,	
		b.stake,
		b.CurrencyName, 
		CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
		b.status,
		b.mrecommend,
		b.recommend,
		NULL SecAcceptFlag,
		NULL betid,
		b.transdesc
	FROM 
		translog b WITH (NOLOCK)
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
		INNER JOIN custDB.dbo.customer cr WITH (NOLOCK) ON cr.custid = b.creator
		INNER JOIN dbo.strSplit(@BetTypes,'^') s ON s.val = b.gameID
		INNER JOIN dbo.match mat WITH(NOLOCK) ON mat.matchid = b.EventID		
	WHERE
		b.EventID=@MatchId 
		AND b.gameid IN (801,803,804,805,806) --AND bs.refno IS NULL	
		AND b.statusID NOT IN (101,102 ) -- reject, void
		AND 1 = CASE WHEN b.GameID IN (801,803,804,805) THEN CASE 
								WHEN b.GameID = 801
									AND EXISTS(
											SELECT TOP 1 1
											FROM @Event801Tbl rs
											WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
										)
									THEN 1
								WHEN b.GameID = 803
									AND EXISTS(
											SELECT TOP 1 1
											FROM @Event803Tbl rs
											WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
										)
									THEN 1
								WHEN b.GameID = 804
									AND EXISTS(
											SELECT TOP 1 1
											FROM @Event804Tbl rs
											WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
										)
									THEN 1
								WHEN b.GameID = 805
									AND EXISTS(
											SELECT TOP 1 1
											FROM @Event805Tbl rs
											WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
										)
									THEN 1
								ELSE 0
								END
					ELSE 1
					END	 
	
	--1. For Normal bets
	SELECT transid	, refno	
		   ,custid		
		   ,username	
		   ,username2	
		   ,odds		
		   ,OddsType	
		   ,transdate	
		   ,bettype		
		   ,betteam		
		   ,betcheck
		   ,hdp1		
		   ,hdp2		
		   ,IsLiveIndicator
		   ,livehomescore
		   ,liveawayscore
		   ,creator		
		   ,Stake		
		   ,CurrencyName
		   ,IsDeposit		
		   ,status		
		   ,mrecommend	
		   ,recommend	
		   ,SecAcceptFlag	
		   ,betid
		   ,transdesc		 
	FROM #SpecialDeleteBets
	WHERE custid NOT IN ( SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- Betdaq
	AND username <> '12EU' -- 12EU
	AND IsDeposit = 0
	AND mrecommend NOT IN (105181, 118473, 105183) -- MHC
	AND recommend NOT IN (11196380, 13423967) -- Foobet, 1E
	AND custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	ORDER BY transid
	
	--2. For Deposit bets
	SELECT transid	, refno	
		   ,custid		
		   ,username	
		   ,username2	
		   ,odds		
		   ,OddsType	
		   ,transdate	
		   ,bettype		
		   ,betteam		
		   ,betcheck
		   ,hdp1		
		   ,hdp2		
		   ,IsLiveIndicator
		   ,livehomescore
		   ,liveawayscore
		   ,creator		
		   ,Stake		
		   ,CurrencyName
		   ,status		
		   ,mrecommend	
		   ,recommend	
		   ,SecAcceptFlag	
		   ,betid
		   ,transdesc
	FROM #SpecialDeleteBets
	WHERE custid NOT IN ( SELECT CustID FROM  [f_GetBetDaqCustomer] (1))
	AND username <> '12EU'
	AND IsDeposit = 1	
	AND mrecommend NOT IN (105181, 118473, 105183)
	AND recommend NOT IN (11196380, 13423967) -- Foobet: 11196380, 1E: 13423967
	AND custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	ORDER BY transid
		
	--7: For Betfair
	SELECT transid	, refno	
		   ,custid		
		   ,username	
		   ,username2	
		   ,odds		
		   ,OddsType	
		   ,transdate	
		   ,bettype		
		   ,betteam		
		   ,betcheck
		   ,hdp1		
		   ,hdp2		
		   ,IsLiveIndicator
		   ,livehomescore
		   ,liveawayscore
		   ,creator		
		   ,Stake		
		   ,CurrencyName
		   ,status		
		   ,mrecommend	
		   ,recommend	
		   ,SecAcceptFlag	
		   ,betid
		   ,transdesc
	FROM #SpecialDeleteBets 
	WHERE custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	ORDER BY IsDeposit desc, transid

	DROP TABLE #SpecialDeleteBets

	SET NOCOUNT OFF
/*
*/
END
GO
GRANT EXECUTE ON [dbo].[NAP_VoidMetricGaming_Sel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_VoidMetricGaming_Sel] TO [vnteam] AS [dbo]