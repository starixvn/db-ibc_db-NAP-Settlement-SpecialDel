/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelSpecialDel_NumberGame] 
	@Option			BIT = 0
	,@MatchID		INT
	,@FromTransdate DATETIME = NULL
	,@ToTransdate	DATETIME = NULL
	,@BetTypes		VARCHAR(100) = ''
	,@BallSequence	VARCHAR(200)	= ''	
	,@TransIds		VARCHAR(4000) = NULL
		
AS
/*  

	Created by: Kathy
	Date:   20131010
	Original: 
	Task: Select bets transaction need to delete (Number Game) [Redmine:#6627]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02  

	Revisions: 
		- 20140217@Kathy: Enhancement to Void Number Game Bet [Redmine:#11992]
		- 20141104@Kathy: Change size of username2 to nvarchar(50)
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20160401@Bobby: #55354 - Update changes for new message structure
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20181121@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20200811@Charles: Implement Next R/B bet type for NG Color Ball - [128215]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220910@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20241125@Lani: [TVS] Change join type on 'recommend' and 'custid' columns [Redmine: #213451]

	Param's Explanation:
			- @Opition: 
			0: By MatchID
			1: By BetID(s)


	*/
BEGIN
	SET NOCOUNT ON

	DECLARE @today				SMALLDATETIME
			,@InvalidTransIds	VARCHAR(MAX) = '' 
			,@SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	SET @today = CONVERT(NVARCHAR(10), CURRENT_TIMESTAMP, 120)

	CREATE TABLE #SpecialDeleteBets (
		transid			BIGINT
		,custid			INT
		,username		VARCHAR(30)
		,username2		NVARCHAR(50)
		,odds			SMALLMONEY
		,OddsType		INT
		,transdate		DATETIME
		,bettype		SMALLINT
		,betfrom		NVARCHAR(4)
		,betteam		NVARCHAR(10)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,IsLiveIndicator BIT
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,creator		VARCHAR(30)
		,stake			MONEY
		,winlost		MONEY
		,comm			MONEY
		,CurrencyName	NVARCHAR(50)
		,IsDeposit		BIT
		,SITE			VARCHAR(10)
		,STATUS			NVARCHAR(10)
		,mrecommend		INT
		,recommend		INT
		,betid			BIGINT
		,MatchCode		NVARCHAR(50)
		,ShowTime		NVARCHAR(50)
		,BallSequence	TINYINT
		,SportTypeId	INT
		,modds			SMALLMONEY
	)

	DECLARE @tblTransIds TABLE (transid BIGINT PRIMARY KEY)
	
	CREATE TABLE #TmpBallSequence (Seq TINYINT)
	INSERT INTO #TmpBallSequence(Seq)
	SELECT  value
	FROM STRING_SPLIT(@BallSequence, ',')

	IF @Option = 0
	BEGIN 
		-- Select Happy 5
		IF(EXISTS(SELECT TOP 1 1 FROM dbo.match m WHERE m.matchid = @MatchID AND m.sporttype = 164))
		BEGIN 
			INSERT INTO #SpecialDeleteBets
			SELECT b.transid
				,b.custid
				,c.username
				,c.username2
				,b.odds
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betfrom
				,betteam
				,hdp1
				,hdp2
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,cr.username AS creator
				,stake
				,b.winlost - b.actual_stake AS winlost
				,b.playercomm AS comm
				,b.CurrencyName
				,CASE 
					WHEN b.srecommend IN (
							SELECT custid
							FROM CustDB.dbo.Dep_CustSuper WITH (NOLOCK)
							) THEN 1
					ELSE 0
					END AS IsDeposit
				,c.site
				,CASE 
					WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS
					END AS STATUS
				,b.mrecommend
				,b.recommend
				,b.betid
				,m.matchcode
				,m.showtime
				,null
				,m.sporttype
				,b.modds
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.customer cr WITH (NOLOCK) ON cr.custid = b.creator
				INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON b.custid = c.custid
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid						
			WHERE b.matchid = @matchid 
				AND b.transdate BETWEEN @FromTransdate AND @ToTransdate
				AND statusID NOT IN (101, 102, 121) ---- Void, Reject, 121: dummy ticket
				AND b.bettype IN (SELECT CONVERT(SMALLINT,value) FROM STRING_SPLIT(@BetTypes, ','))
				AND b.SiteDBGroupID = @SiteDBGroupID
		END

		-- Select Number Game
		ELSE
		BEGIN
			INSERT INTO #SpecialDeleteBets
			SELECT b.transid
				,b.custid
				,c.username
				,c.username2
				,b.odds
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betfrom
				,betteam
				,hdp1
				,hdp2
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,cr.username AS creator
				,stake
				,b.winlost - b.actual_stake AS winlost
				,b.playercomm AS comm
				,b.CurrencyName
				,CASE 
					WHEN b.srecommend IN (
							SELECT custid
							FROM CustDB.dbo.Dep_CustSuper WITH (NOLOCK)
							) THEN 1
					ELSE 0
					END AS IsDeposit
				,c.site
				,CASE 
					WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS
					END AS STATUS
				,b.mrecommend
				,b.recommend
				,b.betid
				,m.matchcode
				,m.showtime
				,BS_tmp.BallSequence
				,m.sporttype
				,b.modds
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.customer cr WITH (NOLOCK) ON cr.custid = b.creator
				INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON b.custid = c.custid
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				OUTER APPLY (SELECT BallSequence 
							FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore)
							WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
							) AS BS_tmp							
			WHERE b.matchid = @matchid 
				AND b.transdate BETWEEN @FromTransdate AND @ToTransdate
				AND statusID NOT IN (101, 102, 121) ---- Void, Reject, 121: dummy ticket
				AND b.bettype IN (SELECT CONVERT(SMALLINT,value) FROM STRING_SPLIT(@BetTypes, ','))			
				AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WHERE Seq = BS_tmp.BallSequence)-- Filter for BallSequence
				AND b.SiteDBGroupID = @SiteDBGroupID
		END
	END
	ELSE -- @Option = 1
	BEGIN
		INSERT INTO @tblTransIds(transid)
		SELECT DISTINCT (s.value)
		FROM STRING_SPLIT(isnull(@TransIds, 0), ',') s
		
		INSERT INTO #SpecialDeleteBets
		SELECT b.transid
			,b.custid
			,c.username
			,c.username2
			,b.odds
			,b.OddsType
			,b.transdate
			,b.bettype
			,b.betfrom
			,betteam
			,hdp1
			,hdp2
			,b.liveindicator
			,b.livehomescore
			,b.liveawayscore
			,cr.username AS creator
			,stake
			,b.winlost - b.actual_stake AS winlost
			,b.playercomm AS comm
			,b.CurrencyName
			,CASE 
				WHEN b.srecommend IN (
						SELECT custid
						FROM CustDB.dbo.Dep_CustSuper WITH (NOLOCK)
						) THEN 1
				ELSE 0
				END AS IsDeposit
			,c.site
			,CASE 
				WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS
				END AS STATUS
			,b.mrecommend
			,b.recommend
			,b.betid
			,m.matchcode
			,m.showtime
			,BS_tmp.BallSequence
			,m.sporttype
			,b.modds
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN CustDB.dbo.customer cr WITH (NOLOCK) ON cr.custid = b.creator
			INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON b.custid = c.custid
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			OUTER APPLY (SELECT BallSequence 
						FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore)
						WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
						) AS BS_tmp
						
		WHERE b.transid IN (SELECT [@tblTransIds].transid FROM @tblTransIds ) 
			AND statusID NOT IN (101, 102, 121) ---- Void, Reject, 121: dummy ticket
			AND winlostdate = @today AND m.eventdate = @today AND m.sporttype IN (161, 164)
			AND b.SiteDBGroupID = @SiteDBGroupID
	END

	------------------------------------------------------------------------------
	/* --1. Table invald/moved transid	*/
	IF @Option = 0
		SELECT '' AS InvalidTransIds
	ELSE IF @Option = 1
	BEGIN
		SELECT @InvalidTransIds = @InvalidTransIds + CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + CAST(t.transid AS VARCHAR(50))
		FROM @tblTransIds t
		WHERE t.transid NOT IN (SELECT r.transid FROM #SpecialDeleteBets r)

		SELECT @InvalidTransIds AS InvalidTransIds
	END
	
	/* --2. Table get tickets */
	--0. For Normal bets  
	SELECT transid
		,username
		,username2
		,transdate
		,bettype
		,betfrom
		,betid
		,odds
		,stake
		,winlost
		,CurrencyName
		,STATUS
		,creator
		,hdp1
		,hdp2
		,IsLiveIndicator
		,livehomescore
		,liveawayscore
		,OddsType
		,betteam
		,comm
		,matchcode
		,showtime
		,BallSequence
		,'Credit' AS GroupName
		,SportTypeId
		,@SiteDBGroupID AS SiteDBGroupID
		,modds AS MasterOdds
	FROM #SpecialDeleteBets WITH (NOLOCK)
	WHERE custid NOT IN (
			SELECT CustID
			FROM [f_GetBetDaqCustomer](1)
			) AND username <> '12EU' AND IsDeposit = 0 AND mrecommend NOT IN (105181, 118473, 105183) AND recommend <> 11196380
	UNION ALL
	--1. For Deposit bets  
	SELECT s.transid
		,s.username
		,s.username2
		,s.transdate
		,s.bettype
		,betfrom
		,s.betid
		,s.odds
		,s.stake
		,s.winlost
		,s.CurrencyName
		,s.STATUS
		,s.creator
		,s.hdp1
		,s.hdp2
		,s.IsLiveIndicator
		,s.livehomescore
		,s.liveawayscore
		,s.OddsType
		,s.betteam
		,s.comm
		,s.matchcode
		,s.showtime
		,BallSequence
		,'Deposit' AS GroupName
		,SportTypeId
		,@SiteDBGroupID AS SiteDBGroupID
		,modds AS MasterOdds
	FROM #SpecialDeleteBets s WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = s.custid
	WHERE c.custid NOT IN (
			SELECT CustID
			FROM [f_GetBetDaqCustomer](1)
			) AND s.username <> '12EU' AND s.IsDeposit = 1 AND s.mrecommend NOT IN (105181, 118473, 105183) AND s.recommend <> 11196380

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TmpBallSequence
	
END
GO