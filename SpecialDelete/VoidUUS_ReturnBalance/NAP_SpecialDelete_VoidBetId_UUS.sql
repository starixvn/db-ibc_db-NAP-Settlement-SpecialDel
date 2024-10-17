/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetId_UUS]
(
	@TransIds			VARCHAR(MAX)
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(200) = '' OUTPUT
)
AS 
/* 
	Created by: 20210519@Max
	Task: Void UUS ticket return balance [Redmine:#149927]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20210519@Max: Create new SP [Redmine:#154974]
		- 20210813@Max: Fix CO issue [Redmine: #149927]
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20220926@Max: Hot fix - void by bet id not Rep to Central DB [Redmine: #178197]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230717@July: [SD] Integrate Virtual Sports 3 (Leap Gaming) [Redmine: #189556]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]

	 Param's Explanation:  
	 Sample Execution: EXEC [dbo].[NAP_SpecialDelete_VoidBetId_UUS] @TransIds = '110595939664,110595939665,110595939666'
*/
BEGIN
	SET NOCOUNT ON	
	
	DECLARE	@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistNG					BIT = 0
			,@isExistVS					BIT = 0
			,@IsExistVS3 				BIT = 0
			,@IsExistVS4 				BIT = 0

	SELECT @ErrCode				= 0
		, @ErrMsg				= ''
	
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange
		
	CREATE TABLE #balanceGameBefore (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #balanceGameAfter (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	
	
	CREATE TABLE #BetDelete (
		GroupTransId	BIGINT -- parent Id (translog.traslogid | bettrans.transid)
		,transid		BIGINT PRIMARY KEY --bettrans.transid
		,matchid		INT
		,Bettype		SMALLINT
		,betid			BIGINT
		,stake			MONEY
		,odds			MONEY
		,refno			BIGINT 
		,betfrom		NVARCHAR(4)
		,statusid		TINYINT
		,betdaqid		BIGINT		
		,winlostdate	SMALLDATETIME
		,status			VARCHAR(10)
		,oddstype		TINYINT
		,transdate		DATETIME
		,betteam		NVARCHAR(10)
		,betcheck		NVARCHAR(50)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,winlost		MONEY
		,playercomm		MONEY
		,currency		TINYINT
		,transdesc		NVARCHAR(1000)
		,custid			INT
		,creator		INT
		,homeid			INT DEFAULT (0)
		,awayid			INT DEFAULT (0)
		,matchcode		NVARCHAR(50)
		,eventdate		DATETIME
		,leagueid		INT DEFAULT (0)
		,isNeutral		BIT
		,showtime		NVARCHAR(50)
		,username		VARCHAR(30)
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,sporttype		SMALLINT
		,oddsid			INT
		,ExtraInfo		VARCHAR(1000)
		,awinlost		MONEY
		,CurrencyName	NVARCHAR(50)
		,modds			SMALLMONEY
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT
		,IsFinish		BIT
		,actual_stake   MONEY
	)
	
	CREATE TABLE #tblMatch (matchid INT)
	
	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@TransIds,',')		
		
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = 'Invalid TransIds.'										
		
		RETURN
	END CATCH		
		
	INSERT INTO #BetDelete(
		GroupTransId	
		,transid			
		,matchid		
		,Bettype		
		,betid			
		,stake			
		,odds	
		,refno			
		,betfrom		
		,statusid				
		,betdaqid		
		,winlostdate
		,status		
		,oddstype		
		,transdate		
		,betteam		
		,betcheck		
		,hdp1			
		,hdp2			
		,livehomescore	
		,liveawayscore	
		,liveindicator	
		,winlost		
		,playercomm		
		,currency	
		,transdesc		
		,custid			
		,creator	
		,recommend
		,mrecommend
		,srecommend
		,eventdate
		,oddsid
		,ExtraInfo
		,awinlost
		,CurrencyName
		,modds
		,WalletType
		,RefCode
		,BonusID
		,actual_stake
	)
	SELECT	
		b.transid AS groupTransId
		,b.transid
		,b.matchid
		,b.bettype
		,b.betid
		,b.stake
		,b.odds
		,b.refno
		,b.betfrom
		,b.statusID
		,b.betdaqid
		,b.winlostdate
		,b.status
		,b.oddstype
		,b.transdate
		,b.betteam
		,b.betcheck
		,b.hdp1
		,b.hdp2
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.winlost - b.actual_stake
		,b.playercomm
		,b.currency
		,b.transdesc
		,b.custid
		,b.creator
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,b.winlostdate
		,b.oddsid
		,b.ExtraInfo
		,b.awinlost
		,b.CurrencyName
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,b.actual_stake
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransIds t
			ON b.transid = t.transid
	WHERE b.bettype < 19001
		AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND b.bettype NOT BETWEEN 801 AND 806-- MG
		AND b.bettype NOT BETWEEN 1501 AND 1599	-- NOT IN Keno
		AND b.statusID NOT IN (101, 102)
		AND b.currency = 20
	
	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #BetDelete WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE	b
		SET homeid 		= m.homeid
			,awayid 	= m.awayid
			,matchcode 	= m.matchcode
			,eventdate 	= m.eventdate
			,leagueid 	= m.leagueid
			,isNeutral 	= ISNULL(m.IsNeutral,CAST(0 AS BIT))
			,showtime 	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') 
			,sporttype 	= m.sporttype
		FROM	#BetDelete b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #BetDelete WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET homeid 		= o.teamid
			,awayid 	= 0
			,matchcode 	= o.matchcode
			,eventdate 	= o.eventdate
			,leagueid 	= l.leagueid
			,IsNeutral  = 0
			,showtime 	= '' 
			,sporttype	= l.sporttype
		FROM	#BetDelete b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
		WHERE bettype IN (10)
	END
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #BetDelete WHERE bettype IN (1231,1232,1233,1237,1238,2770,2771)))
	BEGIN
		UPDATE b
		SET homeid 		= o.RacerID
			,awayid 	= 0
			,matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
			,eventdate	= o.eventdate
			,leagueid 	= r.leagueid
			,IsNeutral  = 0
			,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
			,sporttype 	= r.sporttype
		FROM	#BetDelete b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #BetDelete b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- UPDATE Sportype, Endtime for Bitcoin 
	IF(EXISTS(SELECT TOP 1 1 FROM #BetDelete WHERE bettype BETWEEN 11050 AND 11099))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
			,eventdate  = m.EventDate
		FROM #BetDelete d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
	END
	
	-- remove un-supported sports & bettype
	DELETE bd
	FROM #BetDelete bd
	WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	IF EXISTS(SELECT TOP 1 1 FROM #BetDelete WHERE Bettype BETWEEN 1101 AND 1199 AND StatusID BETWEEN 0 AND 1)  
	BEGIN  
		DELETE 
		FROM	#BetDelete 
		WHERE	Bettype BETWEEN 1101 AND 1199 AND StatusID BETWEEN 0 AND 1 -- Not allowed to settle the running Live CS bet   
	END  
	
	-- gather match Ids
	INSERT INTO #tblMatch (matchid)
	SELECT	matchid
	FROM	#BetDelete
	GROUP BY matchid
	
	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)
	BEGIN
 			SELECT	@ErrCode = 99
 					,@ErrMsg = 'No ticket found.' 									
		
		RETURN
	END
	
	SELECT @IsExistParlayVSBetradar		= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 OR sporttype IN (177) THEN 1 ELSE 0 END)
			,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@IsExistVS3				= MAX (CASE WHEN bettype BETWEEN 5302 AND 5399 THEN 1 ELSE 0 END)
			,@IsExistVS4				= MAX (CASE WHEN sporttype IN(188,147) THEN 1 ELSE 0 END)
	FROM	#BetDelete b
	
	-- STEP 1 : BackUp bettrans
	-- 1.1  backup for normal tickets
	INSERT INTO zzzbettrans (
		transid
		,custid
		,transdate
		,oddsid
		,hdp1
		,hdp2
		,odds
		,stake
		,STATUS
		,winlost
		,livehomescore
		,liveawayscore
		,liveindicator
		,betteam
		,creator
		,refno
		,winlostdate
		,betfrom
		,betcheck
		,checktime
		,matchid
		,bettype
		,SiteDBGroupID
		,RepUpdateTime
		)
	SELECT main.transid
		,main.custid
		,CURRENT_TIMESTAMP
		,main.oddsid
		,main.hdp1
		,main.hdp2
		,main.odds
		,main.stake
		,main.STATUS
		,main.winlost
		,main.livehomescore
		,main.liveawayscore
		,main.liveindicator
		,main.betteam
		,main.creator
		,main.refno
		,main.winlostdate
		,main.betfrom
		,main.betcheck
		,main.checktime
		,main.matchid
		,main.bettype
		,main.SiteDBGroupID
		,NULL --do not need to IH-Rep from SiteDB to Central because central already inserted too
	FROM dbo.bettrans AS main WITH (NOLOCK)
		INNER JOIN #tblMatch tm 
		ON main.matchid = tm.matchid
		INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK) 
		ON	main.transid = tmpmain.transid 
		AND main.matchid = tmpmain.matchid		
	
	--Get data before update
	IF(@isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @IsExistVS3 = 1 OR @IsExistVS4 = 1)
	BEGIN
		INSERT INTO #balanceGameBefore(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END AS groupId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #BetDelete tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 1600 AND 1610
			OR b.Bettype BETWEEN 1201 AND 1299 --VS
			OR b.bettype BETWEEN 2700 AND 2899 --VS2 (Betradar)
			OR b.bettype BETWEEN 5302 AND 5399 --VS3 (Leap Gaming)
			OR b.bettype BETWEEN 10400 AND 10449 --VS4 (Edge Gaming)
			OR b.bettype BETWEEN 11050 AND 11099 --VS5
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120THEN 81
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END
	--capture balance before
	INSERT INTO @BeforeUpd (
		 matchid
		,custid
		,balanceType
		,BonusID
		,WalletType
		,balance
	)
	SELECT matchid
		 , custid
		 , CASE 
				WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) AS balance
	FROM
	(
		-- normal ticket
		SELECT tmpmain.custid
			 , main.BonusID
			 , main.WalletType
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	main.transid = tmpmain.transid
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = tmpmain.matchid
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		     END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets


	/**********************************************   *************************************************************/
	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, BetId BIGINT)
	DECLARE @TransIds_tmp VARCHAR(MAX) = ''

	-- STEP 2 : Update bettrans/translog
	-- 2.1. Update bettrans	for normal ticket
	WHILE (1=1)
	BEGIN
		DELETE @tmpTransIDBatch

		UPDATE TOP(2000) t
			SET IsFinish = 1
		OUTPUT  DELETED.transid
			   ,DELETED.BetID
		INTO @tmpTransIDBatch (TransId, BetId)
		FROM #BetDelete t
			INNER JOIN #tblMatch tm ON t.matchid = tm.matchid
		WHERE IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK
		SELECT @TransIds_tmp = CAST((SELECT     m.TransId AS '@transid'
											   ,m.BetId AS '@betid'
									FROM @tmpTransIDBatch m
									FOR XML PATH('r')
										,ROOT('root')
								) AS VARCHAR(MAX));

		EXEC dbo.TicketVoiding_Admin_VoidingTransId
			@TransIds = @TransIds_tmp,
			@UserId = 10278938, --StarixIT
			@IssueTypeId = -1

		SET @TransIds_tmp = ''

	END	

	--Get data after update
	IF(@isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @IsExistVS3 = 1 OR @IsExistVS4 = 1)
	BEGIN
		INSERT INTO #balanceGameAfter(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #BetDelete tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR tmp.bettype BETWEEN 81 AND 120 OR tmp.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 1600 AND 1610
			OR b.Bettype BETWEEN 1201 AND 1299 --VS
			OR b.bettype BETWEEN 2700 AND 2899 --VS2 (Betradar)
			OR b.bettype BETWEEN 5302 AND 5399 --VS3 (Leap Gaming)
			OR b.bettype BETWEEN 10400 AND 10449 --VS4 (Edge Gaming)
			OR b.bettype BETWEEN 11050 AND 11099 --VS5
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END
	--capture balance after
	INSERT INTO @AfterUpd (
			 matchid
			,custid
			,balanceType
			,BonusID
			,WalletType
			,balance
		)
	SELECT matchid	
		 , custid
		 , CASE 
				WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) balance
	FROM
	(
		-- normal ticket
		SELECT tmpmain.custid
			 , main.BonusID
			 , main.WalletType
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	main.transid = tmpmain.transid
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = tmpmain.matchid
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
			 END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets
	
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @BeforeUpd
		, @BalanceWalletAfter	= @AfterUpd
		, @ActionId				= 0
	
	IF(@isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @IsExistVS3 = 1)
	BEGIN
		
		CREATE TABLE #balanceGameChange (
			custid 			INT
			,winlostdate 	SMALLDATETIME
			,balance 		MONEY
			,bettype		SMALLINT
			,gametypeid		SMALLINT			
			,Increased 		BIT
		)

		INSERT INTO #balanceGameChange (custid, winlostdate, balance, bettype, gametypeid, Increased)
		SELECT	b.custid
				,b.winlostdate
				,a.winlost - b.winlost
				,a.groupid
				,a.gametypeid
				,CASE WHEN a.winlost > b.winlost THEN 1 ELSE 0 END
		FROM	#balanceGameBefore b
			INNER JOIN #balanceGameAfter a 
				ON	b.custid 		= a.custid
				AND b.winlostdate 	= a.winlostdate
				AND a.gametypeid = b.gametypeid
				AND a.groupid = b.groupid
		WHERE	b.winlost <> a.winlost
		
		INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,ABS(balance)
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 0

		INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,balance
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 1
		
		DROP TABLE #balanceGameChange
	END		 
		
	DROP TABLE #balanceGameBefore
	DROP TABLE #balanceGameAfter
	DROP TABLE #tblTransIds
	DROP TABLE #BetDelete
	DROP TABLE #tblMatch

	RETURN
END
GO
