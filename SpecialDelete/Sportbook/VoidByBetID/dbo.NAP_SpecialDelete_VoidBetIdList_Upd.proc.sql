/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetIdList_Upd]  
	@TransIds			VARCHAR(MAX)
	,@TransIdSolds		VARCHAR(MAX)	= '' -- just for BetTrade's subticket (transid of bettype 901)  
	,@UserName			VARCHAR(30) --login username
	,@Password			VARCHAR(50)
	,@UserId			INT = 0 -- custid of Admin
	,@IP				VARCHAR(15)
	,@Reason			NVARCHAR(500) = ''
	,@ReasonSC			NVARCHAR(500) = ''
	,@IsAbnormalBet		BIT = 0
	,@FilterUserName	VARCHAR(30) = NULL -- input username
	,@Products			VARCHAR(50)	= NULL
	,@StatusIds			VARCHAR(50) = NULL
	,@FromDate			DATETIME	= NULL	
	,@ToDate			DATETIME	= NULL
	,@InvalidTransIds	VARCHAR(MAX)	= ''	OUTPUT -- invalid trans of BTrade
	,@ReCalcMatches		VARCHAR(MAX) = '' OUTPUT --Lucky 3 matches need recalculation
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(200) = '' OUTPUT
AS 
	/* Created by: Jamie  
	 Task:  VOID BY BET ID (Running & Settled tickets)  
	 DB: DBTXN/bodb02  
	 Original: NAP_BettransSpecialDelBetID_Del
	   
	 Revisions:  
	  - 20141125@Kathy: Add betid column [Redmine:##26489]  
	  - 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]  
	  - 20150606@Kathy: Migrate custDB to new server DBCust(Get credit from DBCust.CustDB) [Redmine:#36216]   
	  - 20150615@Dominic: BetTrade Integration  [Redmine:#36964]  
	  - 20150623@Dominic: Add Metric Gaming Super Live [Redmine:##38200]  
	  - 20150804@Patrick: Adjust Balance Credit/Debit Game value for LiveCS #40736
	  - 20150907@Patrick: Support LiveCS
	  - 20150810@Kathy: Using new balance table (BalCreditSports,BalDebitSports) [Redmine:#40125]
	  - 20150917@Patrick: #43565: Show error-message in case user clicks void button but no tickets are found
	  - 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]
	  - 20151102@Kathy: Enhance performance [Redmine:#43233]
	  - 20151209@Kathy: get translog.siteid for MG API [Redmine:#49019]
	  - 20150712@Kathy: Database - Change datatype [Redmine: #48660]
	  - 20160112@Patrick: Support Cricket [Redmine: #50688]
	  - 20160301@Bobby: #53123 - Enhance SP void bet by Id list (allow transId up to 1000 rows)
	  - 20160314@Bobby: #53935 - Update changes for multiple bet trade transaction
	  - 20160318@bobby.nguyen: 
			+ #54311 - Correct checking process on match with specific product/sport
			+ #52003 - Wrong balance game calculation for LiveCasino ticket
	  - 20160401@Bobby: #55354 - Update changes for new message structure
	  - 20160810@Bobby: #62223 - Apply new business terms for VOID bet function
	  - 20160914@Kent: Add logic for suporting void system parlay [Redmine:#63202]
	  - 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
	  - 20161124@Kent: Include phone betting tickets [Redmine:#67751]
	  - 20161221@Kathy: Release lock after voiding tickets [Redmine:#68960]
	  - 20170104@Kent: Add Column SportType to output tables [Redmine:#69816]
	  - 20161201@Kathy: Company win limit [Redmine:#66599]
	  - 20170302@Kent: Fix show time for virtual sport [Redmine:#72475]
	  - 20170315@Kent: Integrate cash-out [Redmine:#72059]
	  - 20170417@Kent: Tune performance [Redmine:#72059]
	  - 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
	  - 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
	  - 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]	  
	  - 20170703@Kent: Integrate Company Win Limit For Betradar Virtual Sports [Redmine:#77177]
	  - 20170718@Paul: Integrate Lucky 3 [Redmine:#77175]
	  - 20170724@Kathy: Allow User to Void Settled Parlay Tickets [Redmine:#80135]
	  - 20170503@Kent: Integrate bonus [Redmine:#72790]
	  - 20171127@Kent: Integrate BullFighting [Redmine:#86832]
	  - 20180309@Helen: Hotfix MG [Redmine:#91543]
	  - 20180306@Kathy: get Refcode value [Redmine:#91461]
	  - 20180301@Benjamin: Add oddsspread and DateTime Column Remove- Fast Markets Phase 2 [Redmine:#90667]
	  - 20180305@Helen: Betradar VS2 - [Redmine:90153]
	  - 20180507@Benjamin: Correct Ruben, actual_stake: 0 when INSERT TO BETTRANS[Redmine: #94603]
	  - 20180509@Alan: Change result for new template email [Redmine:#93296]
	  - 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
	  - 20181017@Alan: Write log new reason chinese simplified [102918]
	  - 20181004@Alan: Add new column SettlementStatus [102423]
	  - 20181120@Alan: Incorporate Happy 5 into Number Game [102845]
	  - 20190219@Alan: Support New Ticket Status Abnormal Bet [106654]
	  - 20190419@Kathy: Mark Ticket for Settlement Exclusion [Redmine:#108826]
	  - 20190718@Charles: Drop table #CTE_CustInfo [115870]
	  - 20190228@Alan: Implement Bet Builder - [106898]
	  - 20190812@Charles: Add new column IsMarked [118437]
	  - 20190909@Kathy: Do not update statuswinlost when voiding ticket [Redmine:#115376]
	  - 20191101@Charles: Remove column IsMarked [122187]
	  - 20191106@Charles: Implement NPM Promotion [122187]
	  - 20200303@Charles: Copy 'epositiontaking' value from translog into bettrans [128921]
	  - 20200609@Charles: Remove notify when void tickets [131865]
	  - 20200810@Charles: Offer Saba Loyalty for Saba Promotion [139255]
	  - 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
	  - 20201014@July: TVS - Enhance void by Bet ID to support void by customer [Redmine: #142010]
	  - 20201126@Charles: God of fortune [Redmine: #146053]
	  - 20201214@Charles: TVS - Enhance letstalk notification for settled tickets [Redmine: #145103]

	 Param's Explanation:   
	*/
BEGIN
	SET NOCOUNT ON	
	
	DECLARE	@LogData					NVARCHAR(500) = ''
			,@isITAdmin					BIT = 0
			,@winlostdate				DATETIME
			,@isExistMatch				BIT = 0
			,@isExistMG					BIT = 0
			,@isExistFM					BIT = 0
			,@isExistParlay				BIT = 0
			,@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistOutright			BIT = 0
			,@isExistNG					BIT = 0
			,@isExistBT					BIT = 0
			,@isExistCashOut			BIT = 0
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
			,@IsExistBB					BIT = 0
			,@Remark					VARCHAR (500) = ''
			,@startTime					DATETIME
			,@isExistLucky3				BIT = 0
			,@Lucky3TransIDs			VARCHAR(MAX)
			,@Lucky3Matches				VARCHAR(MAX) = ''
			,@isExistFM2				BIT = 0
			
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))					
	
	SELECT @InvalidTransIds		= '' 
		, @ErrCode				= 0
		, @ErrMsg				= ''
	
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange
		
	--get balance game for livecs
	CREATE TABLE #balanceGameBefore (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #balanceGameAfter (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	
	
	-- BT transaction
	CREATE TABLE #tblTransIdSolds (grouptransid BIGINT, transid BIGINT PRIMARY KEY)
	CREATE TABLE #BTTransActive (
		custid			INT
		, refno			BIGINT
		, matchid		INT
		, bettype		SMALLINT
		, transId		BIGINT
		, awinlost		MONEY
		, betdaqid		BIGINT
		, ExtraInfo		VARCHAR(1000)
		, WalletType	TINYINT
		, RefCode		BIGINT
		, BonusID		INT
		, MainTransId	BIGINT
	)
	
	-- Cash-out transaction
	CREATE TABLE #CashOutTransActive (		
		transId				BIGINT PRIMARY KEY,
		matchid				INT,
		bettype				SMALLINT,
		sporttype			SMALLINT,
		OriginalBetType		SMALLINT,
		MainCashoutId		BIGINT,
		matchcode			NVARCHAR(50),
		homeid				INT,
		awayid				INT,
		leagueid			INT,
		isNeutral			BIT,
		showtime			NVARCHAR(50),
		MainTransId			BIGINT,
		refno				BIGINT,
		betid				BIGINT,
		IsFinish			BIT
	) -- store 911,912,913
	
	-- store invalid BT transid
	DECLARE @tblInvalidTrans TABLE (transid BIGINT) 
	DECLARE @tblCustBT902 TABLE (custid INT, matchid INT) --store BT's custid 	
	DECLARE @tblCustCashOut912 TABLE (custid INT, matchid INT) --store Cash-Out's custid
	
	CREATE TABLE #BetDelete (
		GroupTransId	BIGINT -- parent Id (translog.traslogid | bettrans.transid)
		,transid		BIGINT PRIMARY KEY --bettrans.transid
		,matchid		INT
		,Bettype		SMALLINT
		,OriginalBetType SMALLINT
		,betid			BIGINT
		,stake			MONEY
		,odds			MONEY
		,oddsspread 	MONEY
		,refno			BIGINT -- translog.traslogid | bettrans.transid
		,betfrom		NVARCHAR(10)
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
		,username2		VARCHAR(50)
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,sporttype		SMALLINT
		,IsHideComm		BIT DEFAULT(0)
		,oddsid			INT
		,ExtraInfo		VARCHAR(1000)
		,IsBetTrade		BIT DEFAULT 0
		,IsCashOutMemberTicket BIT DEFAULT 0
		,MainCashoutId	BIGINT
		,awinlost		MONEY
		,SiteId			VARCHAR(7)
		,CurrencyName	NVARCHAR(50)
		,IsMetricGaming	BIT
		,modds			SMALLMONEY
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT
		,MainTransId	BIGINT
		,IsFinish		BIT
		,actual_stake   MONEY
	)

	CREATE TABLE #tmpRefCodeSummary (
		RefCode		BIGINT
		,custid		INT
		,matchid	INT
		,bettype	SMALLINT
		,transid	BIGINT
	)

	CREATE INDEX IX_BetDelete_RefCode ON #BetDelete(RefCode)		
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	
	
	CREATE TABLE #tblMatch (matchid INT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)

	CREATE TABLE #Lucky3Matches
	(
		MatchID				INT PRIMARY KEY,
		Has1stPrize			BIT,
		NumberOf1stPrize	INT DEFAULT(0),
		NumberOf2ndPrize	INT DEFAULT(0),
		NumberOf3rdPrize	INT DEFAULT(0)
	)
	
	IF NOT EXISTS (SELECT 1 FROM CustDB.dbo.Customer WITH(NOLOCK) WHERE userpwd = @password AND custid = @userId AND roleid >=5)
	BEGIN
		SELECT @ErrMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!'  
				,@ErrCode = 101  
		
		SELECT @LogData = 'Try to delete transaction for custid: ' + cast(@UserID AS VARCHAR(10)) + ' betlist: ' 
							+ cast(@TransIds AS VARCHAR(8000)) + ' - Username: ' + @username + ' - reason: ' + @reason  
		  
		EXEC [dbo].[WriteLog_UserLog] @UserID = @UserID ,@Doing = @LogData				
		
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds,',')	
		OPTION (maxrecursion 0)	
		
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
		,oddsspread
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
		,SiteId
		,CurrencyName			
		,IsMetricGaming
		,modds
		,actual_stake
	)
	-- MG tickets (running) in translog
	SELECT	tl.translogid AS groupTransId
			,tl.translogid AS transid
			,tl.eventID
			,tl.gameID
			,0 AS betid
			,tl.stake
			,tl.odds
			,0 AS oddsspread
			,tl.translogid AS refno
			,tl.betfrom
			,tl.statusID
			,-1 AS betdaqid -- normal ticket	
			,tl.winlostdate	
			,tl.status	
			,tl.custom1 AS oddstype
			,tl.transdate
			,NULL AS betteam
			,NULL AS betcheck
			,0 hdp1
			,0 hdp2
			,NULL livehomescore
			,NULL liveawayscore
			,0 liveindicator
			,-tl.actual_stake AS winlost
			,0 AS playercomm
			,tl.currency
			,tl.transdesc
			,tl.custid
			,tl.creator
			,tl.recommend
			,tl.mrecommend
			,tl.srecommend
			,tl.winlostdate	
			,tl.SiteId
			,tl.CurrencyName		
			,1 AS IsMetricGaming
			,NULL AS modds
			,tl.actual_stake
	FROM	dbo.translog tl WITH(NOLOCK)
		INNER JOIN #tblTransIds t
			ON	tl.translogid = t.transid
	WHERE tl.gameID BETWEEN 801 AND 806
		AND tl.statusID = 0					
	
	
	/* Products & bettype
	-- SB/NG/LC/BT
	-- MG - settled ticket
	-- Parlay vs Outright ticket 
	*/
	INSERT INTO #BetDelete(
		GroupTransId	
		,transid			
		,matchid		
		,Bettype		
		,betid			
		,stake			
		,odds	
		,oddsspread		
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
		,IsHideComm
		,eventdate
		,oddsid
		,ExtraInfo
		,MainCashoutId
		,awinlost
		,IsBetTrade
		,SiteId
		,CurrencyName
		,IsMetricGaming
		,modds
		,WalletType
		,RefCode
		,BonusID
		,actual_stake
	)
	SELECT	
		b.refno AS groupTransId
		,b.transid
		,b.matchid
		,b.bettype
		,b.betid
		,b.stake
		,b.odds
		,b.oddsspread
		,b.refno
		,b.betfrom
		,b.statusID
		,-1 AS betdaqid
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
		,0 AS IsHideComm
		,b.winlostdate
		,b.oddsid
		,b.ExtraInfo
		,CASE
			WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
					THEN b.transid
			ELSE NULL
		 END AS MainCashoutId
		,b.awinlost
		,CAST(0 AS BIT) AS IsBetTrade
		,tl.SiteId
		,b.CurrencyName
		,1 AS IsMetricGaming
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,tl.actual_stake
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON b.custid 	= tl.custid
			AND b.refno 	= tl.translogid
			AND b.matchid 	= tl.eventid
		INNER JOIN #tblTransIds t
			ON tl.translogid = t.transid
	WHERE tl.gameID BETWEEN 801 AND 806 
		AND b.statusID NOT IN (0, 101, 102)
		
	UNION ALL
	SELECT	
		b.transid AS groupTransId
		,b.transid
		,b.matchid
		,b.bettype
		,b.betid
		,b.stake
		,b.odds
		,b.oddsspread
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
		,CASE 
			WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1 			 
			ELSE 0 
		 END AS IsHideComm
		,b.winlostdate
		,b.oddsid
		,b.ExtraInfo
		,CASE
			WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
					THEN b.transid
			ELSE NULL
		 END AS MainCashoutId
		,b.awinlost
		,CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsBetTrade
		,NULL AS SiteId
		,b.CurrencyName
		,0 AS IsMetricGaming
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
		AND b.bettype NOT IN (901, 902, 903, 904) -- BT subticket
		AND b.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
		AND b.bettype NOT BETWEEN 1501 AND 1599	-- NOT IN Keno
		AND b.statusID NOT IN (101, 102)													
	
	-- Insert more bonus or cash ticket in case only one ticket appears in #BetDelete	
	INSERT INTO #tmpRefCodeSummary (RefCode, custid, matchid, bettype, transid)
	SELECT RefCode, custid, matchid, bettype, MAX(transid) as transid
	FROM #BetDelete
	WHERE RefCode IS NOT NULL	
	GROUP BY RefCode, custid, matchid, bettype
	HAVING COUNT(*) = 1	
	
	IF @@ROWCOUNT > 0
	BEGIN
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
			,IsHideComm
			,eventdate
			,oddsid		
			,ExtraInfo
			,MainCashoutId
			,awinlost
			,IsBetTrade
			,SiteId
			,IsMetricGaming
			,modds		
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
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
			,CASE WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1 ELSE 0 END AS IsHideComm
			,b.winlostdate
			,b.oddsid		
			,b.ExtraInfo
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
						THEN b.transid
				ELSE NULL
			 END AS MainCashoutId
			,b.awinlost
			,CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsBetTrade
			,NULL AS SiteId
			,0 AS IsMetricGaming
			,b.modds		
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,r.transid AS MainTransId
			,b.actual_stake
		FROM #tmpRefCodeSummary r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON b.RefCode = r.RefCode
						AND b.transid <> r.transid					
						AND b.custid = r.custid
						AND b.matchid = r.matchid
						AND b.bettype = r.bettype	
		WHERE b.statusID NOT IN (101,102 ) -- reject, void
	END
	
	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #BetDelete WHERE bettype NOT IN (9, 29, 2799)))
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
		
		WHERE bettype NOT IN (9, 29, 2799)
			
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
	IF(EXISTS (SELECT 1 FROM #BetDelete WHERE bettype IN (1231,1232,1233,1237,1238)))
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
	
	-- remove un-supported sports & bettype
	DELETE bd
	FROM #BetDelete bd
	WHERE bettype NOT IN (9, 29, 2799)
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
	
	IF ISNULL(@TransIdSolds,'') <> ''
	BEGIN
		
		INSERT INTO #tblTransIdSolds(grouptransid, transid)
		SELECT  
			sub.refno
			, sub.transid
		
		FROM dbo.bettrans sub WITH(NOLOCK)
			INNER JOIN #tblMatch tm 
			ON sub.matchid 	= tm.matchid
			
		WHERE sub.bettype 	= 901
			AND EXISTS (
				SELECT TOP 1 1 
				FROM dbo.strSplit(@TransIdSolds,',') 
				WHERE val = sub.transid
			) 
	END
	
	
	-- delete main ticket if it's BT but subticket is not exists in SOLD list
	DELETE
	FROM	#BetDelete
	OUTPUT	DELETED.grouptransid
	INTO	@tblInvalidTrans (transid)
	WHERE	betdaqid = 0 
			AND extrainfo is null
			AND transid NOT IN (SELECT grouptransid FROM #tblTransIdSolds)
	
	-- delete main ticket if it's not BT but have subticket in SOLD list
	DELETE
	FROM	#BetDelete
	OUTPUT	DELETED.grouptransid
	INTO	@tblInvalidTrans
	WHERE	betdaqid = -1
			AND extrainfo is null 
			AND transid IN (SELECT grouptransid FROM #tblTransIdSolds)
	
	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid)
	SELECT transid
	FROM #BetDelete	
	WHERE betdaqid = 0 
	  AND charindex ('p25',extrainfo)> 0
	
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
		  , @Action = 'Void'
		  , @IsReleased = 0
	
	DELETE bd
	FROM #BetDelete bd
		 INNER JOIN #tblCashOutProcess rp
				 ON bd.TransId = rp.transid							
					AND rp.IsAvailable = 0	
	
	-- return invalid transId	
	SELECT @InvalidTransIds = @InvalidTransIds + CAST(T.transid AS VARCHAR(20)) + ','
	FROM (
			SELECT transid
			FROM @tblInvalidTrans
			UNION ALL
			SELECT transid
			FROM #tblCashOutProcess
			WHERE IsAvailable = 0
		 ) AS T
		
	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)
	BEGIN
		IF @InvalidTransIds = ''
 			SELECT	@ErrCode = 99
 					,@ErrMsg = 'No ticket found.' 						
		
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1 				
		
		RETURN
	END
	
	SELECT @winlostdate 				= MIN (winlostdate)
			,@isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
			,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistBT 				= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
			,@isExistCashOut			= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
			,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistLucky3		= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
			,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM	#BetDelete b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	--- CHECKING SETTLEMENT PROCESS IN PROGRESS OR NOT ?????  
	DECLARE @avaiableProcess BIT
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		, CASE 
			WHEN Bettype NOT IN (9, 29, 2799, 10, 38) 
					AND Bettype NOT BETWEEN 801 AND 899
					AND f.GroupId IS NULL
					AND Bettype NOT IN (1231,1232,1233)
				THEN 1 --SB,NG,LC
			WHEN Bettype = 10 THEN 2	-- Outright
			WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
			WHEN f.GroupId = 1 THEN 6 -- FM
			WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
			WHEN Bettype = 38 THEN 5 -- Bet Builder
			WHEN f.GroupId = 2 THEN 7 -- FM 228
			ELSE 0
		END AS KeyID
	FROM #BetDelete b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistParlay 				= @isExistParlay
		, @isExistOutright 			= @isExistOutright
		, @isExistMG				= @isExistMG
		, @isExistFM				= @isExistFM
		, @isExistMatch				= @isExistMatch
		, @isExistNG				= @isExistNG
		, @isExistVS				= @isExistVS
		, @isExistBB				= @isExistBB
		, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
		, @isExistFM2				= @isExistFM2
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1
		
		RETURN
	END
		
	DELETE 
	FROM	#tblTransIdSolds 
	WHERE	grouptransid IN (SELECT transid FROM @tblInvalidTrans)
	
	-- INSERT  BT sub tickets
	IF (@isExistBT = 1)
	BEGIN
		--Insert multiple Bet trade transaction (901,902,903)
		INSERT INTO #BTTransActive (custid, refno, matchid, bettype, transId, awinlost, betdaqid, extrainfo
								  , WalletType, RefCode, BonusID, MainTransId)
		SELECT bt.custid, bt.refno, bt.matchid, bt.bettype, bt.transId, bt.awinlost, bt.betdaqid, bt.ExtraInfo
			 , bt.WalletType, bt.RefCode, bt.BonusID, bt.MainTransId
		FROM (
			SELECT sub.custid
				, sub.refno
				, sub.matchid
				, sub.bettype
				, sub.transId
				, sub.awinlost
				, sub.betdaqid
				, sub.extrainfo
				, sub.WalletType
				, sub.RefCode
				, sub.BonusID
				, main.transid AS MainTransId
				, ROW_NUMBER() OVER ( PARTITION  BY sub.custid, sub.refno, sub.matchid, sub.bettype ORDER BY sub.transId DESC ) AS BTNo 
				
			FROM dbo.bettrans sub WITH(NOLOCK)
				INNER JOIN #tblMatch tm 
				ON sub.matchid 		= tm.matchid
				
				INNER JOIN #BetDelete main
				ON sub.refno		= main.transId
				AND tm.matchid		= main.matchid
					
			WHERE sub.bettype 		BETWEEN 901 AND 910
				AND sub.statusID 	IN (111,112,113,103)
				AND main.betdaqid	= 0
				AND main.extrainfo is null
		) AS bt
		WHERE bt.BTNo = 1
		
		-- insert 901		
		INSERT INTO #BetDelete (
				GroupTransId	
				,transid			
				,matchid		
				,Bettype
				,OriginalBetType		
				,betid			
				,stake			
				,odds	
				,oddsspread				
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
				,homeid
				,awayid
				,matchcode
				,eventdate
				,leagueid
				,isNeutral
				,showtime
				,sporttype
				,ExtraInfo					
				,awinlost	
				,IsHideComm	
				,IsBetTrade
				,modds	
				,CurrencyName
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,actual_stake
		)
		SELECT	tmpmain.transid
				,sub.transid
				,tmpmain.matchid
				,sub.Bettype
				,tmpmain.Bettype AS OriginalBetType
				,tmpmain.Bettype AS betid
				,tmpmain.stake
				,tmpmain.odds
				,tmpmain.oddsspread
				,sub.refno
				,tmpmain.betfrom
				,sub.statusID
				,sub.betdaqid
				,tmpmain.winlostdate
				,'SOLD' AS status
				,tmpmain.oddstype
				,sub.transdate
				,tmpmain.betteam
				,tmpmain.betcheck
				,tmpmain.hdp1
				,tmpmain.hdp2
				,tmpmain.livehomescore
				,tmpmain.liveawayscore
				,tmpmain.liveindicator
				,sub.winlost - sub.actual_stake
				,sub.playercomm
				,tmpmain.currency
				,tmpmain.transdesc
				,sub.custid
				,sub.creator
				,sub.recommend
				,sub.mrecommend
				,sub.srecommend
				,tmpmain.homeid
				,tmpmain.awayid
				,tmpmain.matchcode
				,tmpmain.eventdate
				,tmpmain.leagueid
				,tmpmain.IsNeutral
				,tmpmain.showtime
				,tmpmain.sporttype
				,sub.ExtraInfo				
				,sub.awinlost
				,1 AS IsHideComm
				,CAST(1 AS BIT) AS IsBetTrade
				,tmpmain.modds
				,sub.CurrencyName
				,bt.WalletType
				,bt.RefCode
				,bt.BonusID
				,bt.MainTransId
				,tmpmain.actual_stake
		FROM dbo.bettrans sub WITH(NOLOCK)
			INNER JOIN #BTTransActive bt
				ON sub.matchid 	= bt.matchid
				AND sub.bettype	= bt.bettype
				AND sub.transId	= bt.transId				
			INNER JOIN #BetDelete tmpmain 
				ON	bt.refno 	= tmpmain.transid
				AND bt.matchid 	= tmpmain.matchid							
		WHERE bt.bettype		= 901
		AND tmpmain.betdaqid 	= 0
		AND tmpmain.extrainfo is null
		
		--insert custBT 
		INSERT INTO @tblCustBT902( custid, matchid )
		SELECT sub902.custid, sub902.matchid
		FROM dbo.bettrans sub902 WITH (NOLOCK)
			INNER JOIN #BetDelete tmpmain with(NOLOCK)
			ON	sub902.refno = tmpmain.transid
			AND sub902.matchid 	= tmpmain.matchid			
		WHERE sub902.bettype 		= 902
			AND tmpmain.betdaqid 	= 0
			AND tmpmain.extrainfo is null
		GROUP BY sub902.custid, sub902.matchid
		
	END
	
	-- INSERT  Cash-out sub tickets
	IF (@isExistCashOut = 1)
	BEGIN
		-- insert 911
		INSERT INTO #BetDelete (
				GroupTransId	
				,transid			
				,matchid		
				,Bettype
				,OriginalBetType		
				,betid			
				,stake			
				,odds
				,oddsspread				
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
				,homeid
				,awayid
				,matchcode
				,eventdate
				,leagueid
				,isNeutral
				,showtime
				,sporttype
				,ExtraInfo	
				,MainCashoutId	
				,awinlost
				,IsHideComm	
				,IsBetTrade
				,modds
				,CurrencyName	
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,actual_stake		
		)
		OUTPUT inserted.transid
			 , inserted.bettype
			 , inserted.matchid
			 , inserted.sporttype
			 , inserted.OriginalBetType
			 , inserted.MainCashoutId
			 , inserted.matchcode
			 , inserted.homeid
			 , inserted.awayid
			 , inserted.leagueid
			 , inserted.isNeutral
			 , inserted.showtime
			 , inserted.MainTransId
			 , inserted.refno
			 , inserted.betid
				INTO #CashOutTransActive(transid
									   , bettype
									   , matchid
									   , sporttype
									   , OriginalBetType
									   , MainCashoutId
									   , matchcode
									   , homeid
									   , awayid
									   , leagueid
									   , isNeutral
									   , showtime
									   , MainTransId
									   , refno
									   , betid)
		SELECT	tmpmain.transid
				,sub.transid
				,tmpmain.matchid
				,sub.Bettype
				,tmpmain.Bettype AS OriginalBetType
				,tmpmain.Bettype AS betid
				,sub.stake
				,tmpmain.odds
				,tmpmain.oddsspread
				,sub.refno
				,tmpmain.betfrom
				,sub.statusID
				,sub.betdaqid
				,tmpmain.winlostdate
				,'Cash out' AS status
				,tmpmain.oddstype
				,sub.transdate
				,tmpmain.betteam
				,tmpmain.betcheck
				,tmpmain.hdp1
				,tmpmain.hdp2
				,tmpmain.livehomescore
				,tmpmain.liveawayscore
				,tmpmain.liveindicator
				,sub.winlost - sub.actual_stake
				,sub.playercomm
				,tmpmain.currency
				,tmpmain.transdesc
				,sub.custid
				,sub.creator
				,sub.recommend
				,sub.mrecommend
				,sub.srecommend
				,tmpmain.homeid
				,tmpmain.awayid
				,tmpmain.matchcode
				,tmpmain.eventdate
				,tmpmain.leagueid
				,tmpmain.IsNeutral
				,tmpmain.showtime
				,tmpmain.sporttype
				,sub.ExtraInfo
				,tmpmain.transid AS MainCashoutId
				,sub.awinlost
				,1 AS IsHideComm
				,CAST(0 AS BIT) AS IsBetTrade
				,tmpmain.modds
				,sub.CurrencyName
				,sub.WalletType
				,sub.RefCode
				,sub.BonusID
				,tmpmain.transid AS MainTransId
				,tmpmain.actual_stake
		FROM dbo.bettrans sub WITH(NOLOCK)
			 INNER JOIN #BetDelete tmpmain
					 ON	sub.refno = tmpmain.transid
						AND sub.matchid = tmpmain.matchid	
						AND sub.custid = tmpmain.custid						
						AND tmpmain.betdaqid = 0
						AND charindex ('p25',tmpmain.extrainfo)> 0			
						AND sub.bettype = 911								
		WHERE sub.statusID NOT IN (102, 101) -- VOID, REJECT
		
		-- insert cash-out member bet tickets
		INSERT INTO #BetDelete(
				GroupTransId	
				,transid			
				,matchid		
				,Bettype
				,OriginalBetType		
				,betid			
				,stake			
				,odds	
				,oddsspread				
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
				,MainCashoutId
				,IsCashOutMemberTicket
				,awinlost
				,matchcode
				,homeid
				,awayid
				,leagueid
				,sporttype
				,IsNeutral
				,showtime
				,IsHideComm
				,IsBetTrade
				,modds
				,CurrencyName
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,actual_stake
			)
		SELECT	
				b.transid AS groupTransId
				,b.transid
				,b.matchid
				,b.bettype
				,sub911.OriginalBetType
				,b.betid
				,b.stake
				,b.odds
				,b.oddsspread
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
				,sub911.MainCashoutId
				,1 AS IsCashOutMemberTicket
				,b.awinlost
				,sub911.matchcode
				,sub911.homeid
				,sub911.awayid
				,sub911.leagueid
				,sub911.sporttype
				,sub911.IsNeutral
				,sub911.showtime
				,1 AS IsHideComm
				,CAST(0 AS BIT) AS IsBetTrade
				,b.modds
				,b.CurrencyName
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,sub911.MainTransId
				,b.actual_stake
		FROM #BetDelete sub911
			 CROSS APPLY (
							  SELECT b.transid
							  		,b.matchid
									,b.bettype
									,b.betid
									,b.stake
									,b.odds
									,b.oddsspread
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
									,b.winlost
									,b.actual_stake
									,b.playercomm
									,b.currency
									,b.transdesc
									,b.custid
									,b.creator
									,b.recommend
									,b.mrecommend
									,b.srecommend				
									,b.oddsid
									,b.ExtraInfo
									,b.awinlost
									,b.modds
									,b.CurrencyName
									,b.WalletType
									,b.RefCode
									,b.BonusID
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID NOT IN (102, 101) -- VOID, REJECT
						 ) AS b
		WHERE sub911.bettype = 911		 
		
		--Insert multiple cash-out transaction (912,913)
		INSERT INTO #CashOutTransActive(bettype, transId, matchid, sporttype
									  , MainTransId, refno, betid)
		SELECT sub_912_913.bettype, sub_912_913.transId, sub_912_913.matchid, m.sporttype
			 , sub911.MainTransId
			 , sub_912_913.refno
			 , sub_912_913.betid
		FROM #CashOutTransActive sub911
			INNER JOIN dbo.bettrans sub_912_913 WITH(NOLOCK)					
					ON sub911.transId = sub_912_913.refno						
					   AND sub911.matchid = sub_912_913.matchid					   					
					   AND sub_912_913.bettype IN (912,913)
					   AND sub_912_913.statusID NOT IN (102, 101) -- VOID, REJECT
			INNER JOIN match m (NOLOCK)
					ON sub_912_913.matchid = m.matchid															
			
		--insert custCashOut912	
		INSERT INTO @tblCustCashOut912( custid, matchid )
		SELECT DISTINCT custid, matchid
		FROM #BetDelete
		WHERE IsCashOutMemberTicket = 1									
	END
	
	--Insert ticket of MGSL in translog: 801,803,804,805,806 
	--MetricGaming
	IF(@isExistMG = 1)
	BEGIN	
		INSERT INTO [bodb02].[dbo].[bettrans]  (
			[custid]  
			,[transdate]  
			,[oddsid]  
			,[hdp1]  
			,[hdp2]  
			,[odds]  
			,[stake]  
			,[status]  
			,[winlost]  
			,[awinlost]  
			,[mwinlost]  
			,[playercomm]  
			,[comm]  
			,[acomm]  
			,[apositiontaking]  
			,[mpositiontaking]  
			,[tpositiontaking]  
			,[playerdiscount]  
			,[discount]  
			,[adiscount]  
			,[livehomescore]  
			,[liveawayscore]  
			,[liveindicator]  
			,[betteam]  
			,[creator]  
			,[refno]  
			,[comstatus]  
			,[winlostdate]  
			,[betfrom]  
			,[betcheck]  
			,[checktime]  
			,[oddsspread]  
			,[actualrate]  
			,[matchid]  
			,[recommend]  
			,[mrecommend]  
			,[ruben]  
			,[betid]  
			,[statuswinlost]  
			,[modds]  
			,[bettype]  
			,[betdaqid]  
			,[actual_stake]  
			,[currency]  
			,[ip]  
			,[transdesc]  
			,[sdiscount]  
			,[scomm]  
			,[spositiontaking]  
			,[swinlost]  
			,[srecommend]  
			,[Username]  
			,[CurrencyName]  
			,[virtualrate]  
			,[oddstype]  
			,[statusID]  
			,[currency2]  
			,[balance]  
			,[SecAcceptFlag]  
			,[transid2]  
			,[RecommDate]
			,[epositiontaking]
	)  
	SELECT	b.[custid]  
			,b.[transdate]  
			,0 [oddsid]  
			,0 [hdp1]  
			,0 [hdp2]  
			,b.[odds]  
			,b.[stake]  
			,b.[status]  
			,0 [winlost]  
			,0 [awinlost]  
			,0 [mwinlost]  
			,0 [playercomm]  
			,0 [comm]  
			,0 [acomm]  
			,b.[apositiontaking]  
			,b.[mpositiontaking]  
			,b.[tpositiontaking]  
			,b.[playerdiscount]  
			,b.[discount]  
			,b.[adiscount]  
			,0 [livehomescore]  
			,0 [liveawayscore]  
			,b.[liveindicator]  
			,SUBSTRING(b.[transdesc],11,CHARINDEX(';BettypeTime',b.[transdesc],0) - 11) [betteam]  
			,b.[creator]  
			,b.translogid [refno]  
			,b.custom2 [comstatus]  
			,b.[winlostdate]  
			,b.[betfrom]  
			,b.transdate [betcheck]  
			,NULL [checktime]  
			,0 [oddsspread]  
			,b.[actualrate]  
			,b.EventID  
			,b.[recommend]  
			,b.[mrecommend]  
			--,1 [ruben]  
			,0 [ruben] --#94603
			,CASE WHEN ISNULL(b.custom3,'') = '' THEN NULL ELSE CAST(b.custom3 AS BIGINT) END [betid]  
			,NULL [statuswinlost]  
			,0 [modds]  
			,b.GameID [bettype]  
			,NULL [betdaqid]  
			--,b.[actual_stake] --#94603 
			,0 [actual_stake]
			,b.[currency]  
			,b.[ip]  
			,b.[transdesc]  
			,b.[sdiscount]  
			,0 [scomm]  
			,b.[spositiontaking]  
			,0 [swinlost]  
			,b.[srecommend]  
			,b.[Username]  
			,b.[CurrencyName]  
			,b.[virtualrate]  
			,b.custom1 [oddstype]  
			,b.[statusID]  
			,NULL [currency2]  
			,b.[balance]  
			,0 [SecAcceptFlag]  
			,0 [transid2]  
			,NULL [RecommDate]
			,b.[epositiontaking]
				
		FROM dbo.translog b WITH(NOLOCK)  
			INNER JOIN #BetDelete tmp
			ON b.translogid = tmp.refno
		WHERE NOT EXISTS (
				SELECT TOP 1 1 
				FROM dbo.bettrans WITH(NOLOCK) 
				WHERE custid = b.custid 
					AND refno = b.translogid 
					AND matchid = b.eventID
			)
			AND tmp.bettype BETWEEN 801 AND 806
			AND tmp.statusID = 0
			
		 --Update new transid
		UPDATE	tmpmain
		SET	tmpmain.TransID 		= main.TransID
			,tmpmain.grouptransid 	= main.transid
			
		FROM #BetDelete tmpmain
			INNER JOIN dbo.bettrans main WITH(NOLOCK) 
				ON	main.custid = tmpmain.custid
					AND main.refno = tmpmain.refno 
					AND main.matchid = tmpmain.matchid
					
		WHERE tmpmain.Bettype BETWEEN 801 AND 806
		
	END	

	-- STEP 1 : BackUp bettrans
	-- 1.1  backup for normal ticket, main bettrade, main cash-out, cash-out member bet tickets
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
		,CASE
			WHEN (tmpmain.betdaqid = 0 AND charindex ('p25',tmpmain.extrainfo)> 0) -- main ticket is Cash-out
				 OR tmpmain.IsCashOutMemberTicket = 1
					THEN @session
			ELSE main.betcheck
		 END AS betcheck
		,main.checktime
		,main.matchid
		,main.bettype
	FROM dbo.bettrans AS main WITH (NOLOCK)
		INNER JOIN #tblMatch tm 
		ON main.matchid = tm.matchid
		INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK) 
		ON	main.transid = tmpmain.transid 
		AND main.matchid = tmpmain.matchid		
	WHERE main.bettype NOT IN (901, 902, 903)
	  AND main.bettype NOT IN (911, 912, 913)
	
	--1.2. Backup BT's sub-tickets (901,902,903) 
	IF(@isExistBT = 1)
	BEGIN
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
			)
		SELECT sub.transid
			,sub.custid
			,CURRENT_TIMESTAMP
			,sub.oddsid
			,sub.hdp1
			,sub.hdp2
			,sub.odds
			,sub.stake
			,sub.STATUS
			,sub.winlost
			,sub.livehomescore
			,sub.liveawayscore
			,sub.liveindicator
			,sub.betteam
			,sub.creator
			,sub.refno
			,sub.winlostdate
			,sub.betfrom
			,sub.betcheck
			,sub.checktime
			,sub.matchid
			,sub.bettype
		FROM dbo.bettrans AS sub WITH (NOLOCK)
			INNER JOIN #BTTransActive bt
			ON sub.matchid 		= bt.matchid			
				AND sub.bettype	= bt.bettype			
				AND sub.transId = bt.transId
			
			INNER JOIN #BetDelete tmpmain 
				ON	bt.refno 	= tmpmain.transid
				AND bt.matchid 	= tmpmain.matchid
		WHERE bt.bettype NOT IN (904)
	END
	
	--1.3. Backup Cash-out's sub-tickets (911,912,913)
	IF (@isExistCashOut = 1)
	BEGIN
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
			)
		SELECT sub.transid
			,sub.custid
			,CURRENT_TIMESTAMP
			,sub.oddsid
			,sub.hdp1
			,sub.hdp2
			,sub.odds
			,sub.stake
			,sub.STATUS
			,sub.winlost
			,sub.livehomescore
			,sub.liveawayscore
			,sub.liveindicator
			,sub.betteam
			,sub.creator
			,sub.refno
			,sub.winlostdate
			,sub.betfrom
			,@session AS betcheck
			,sub.checktime
			,sub.matchid
			,sub.bettype
		FROM dbo.bettrans AS sub WITH (NOLOCK)
			INNER JOIN #CashOutTransActive bt
			ON sub.matchid 		= bt.matchid			
				AND sub.bettype	= bt.bettype			
				AND sub.transId = bt.transId		
	END
	
	--Get data before update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		INSERT INTO #balanceGameBefore(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END AS groupId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #BetDelete tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 1201 AND 1299
			OR b.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
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
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) AS balance
	FROM
	(
		-- normal, main bettrade, main cash-out, cash-out member bet ticket
		SELECT tmpmain.custid
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	main.transid = tmpmain.transid
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = tmpmain.matchid
		WHERE	
			1 = CASE 
				WHEN tmpmain.bettype BETWEEN 801 AND 806 AND tmpmain.statusID = 0 THEN 0 
				ELSE 1 
			END
					
		UNION ALL
		
		SELECT  tmpmain.custid
			  , 0 AS BonusID -- running metric gaming tickets always bet from cash wallet
			  , 2 AS WalletType -- running metric gaming tickets always bet from cash wallet
			  , 0 AS winlost, tl.actual_stake, 0 AS playercomm, tmpmain.Bettype, tmpmain.matchid,tmpmain.sporttype
		FROM	dbo.translog tl WITH(NOLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	tl.translogid = tmpmain.refno					
		WHERE	tl.statusID = 0
				AND tmpmain.bettype BETWEEN 801 AND 806	
							
		UNION ALL
		
		-- sub bettrade (901,902,903)
		SELECT sub.custid
			 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype, sub.matchid,tmpmain.sporttype
		FROM dbo.bettrans sub WITH (NOLOCK)
			INNER JOIN #BTTransActive bt 
				ON sub.matchid = bt.matchid
					AND sub.bettype = bt.bettype
					AND sub.transId = bt.transId
			INNER JOIN #BetDelete AS tmpmain 
				ON	bt.refno 	= tmpmain.transid
				AND bt.matchid 	= tmpmain.matchid
				AND tmpmain.betdaqid = 0
				AND tmpmain.extrainfo is null					
		WHERE @isExistBT = 1
		
		UNION ALL
		
		-- sub cash-out (911,912,913)
		SELECT sub.custid
			 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype, sub.matchid, bt.sporttype
		FROM dbo.bettrans sub WITH (NOLOCK)
			INNER JOIN #CashOutTransActive bt 
				ON sub.matchid = bt.matchid
					AND sub.bettype = bt.bettype
					AND sub.transId = bt.transId															
		WHERE @isExistCashOut = 1
					
		UNION ALL
		
		-- Cricket charge comm
		SELECT b.custid
			 , 0 AS BonusID -- cricket tickets always bet from cash wallet
			 , 2 AS WalletType -- cricket tickets always bet from cash wallet
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype, b.matchid, 50 AS sporttype
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblMatch tm 
				ON b.matchid = tm.matchid
		WHERE b.bettype = 500
			AND EXISTS (
				SELECT TOP 1 1 
				FROM #BetDelete d 
				WHERE b.custid = d.custid
			)
					
		UNION ALL
		
		-- BT-WLSharing (904)
		SELECT	sub904.custid
			  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			  , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype, sub904.matchid, 1 AS sporttype
		FROM	bettrans sub904 WITH (NOLOCK)
			INNER JOIN @tblCustBT902 temp
			ON sub904.custid = temp.custid
				AND sub904.matchid = temp.matchid									
		WHERE sub904.bettype = 904
		
		UNION ALL
		
		-- cash-out summary 914
		SELECT	sub914.custid
			  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype, sub914.matchid, 1 AS sporttype
		FROM	bettrans sub914 WITH (NOLOCK)
			INNER JOIN @tblCustCashOut912 temp
			ON sub914.custid = temp.custid
				AND sub914.matchid = temp.matchid									
		WHERE sub914.bettype = 914
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		     END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets


	/**********************************************   *************************************************************/
	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, TranslogId BIGINT, BetId BIGINT, IsMG BIT, Actual_stake MONEY, IsCashOutMember BIT  )
	DECLARE @TransIds_tmp VARCHAR(MAX) = ''
		, @IssueTypeId INT = 0

	SET @IssueTypeId = CASE WHEN @IsAbnormalBet = 1 THEN 11 ELSE 0 END

	-- STEP 2 : Update bettrans/translog
	-- 2.1. Update bettrans	for normal, main bettrade, main cash-out, cash-out member bet ticket
	WHILE (1=1)
	BEGIN
		DELETE @tmpTransIDBatch

		UPDATE TOP(2000) t
			SET IsFinish = 1
		OUTPUT  DELETED.transid
			   ,CASE WHEN DELETED.IsMetricGaming = 1 THEN  DELETED.refno ELSE NULL END
			   ,DELETED.BetID
			   ,DELETED.IsMetricGaming
			   ,DELETED.actual_stake
			   ,DELETED.IsCashOutMemberTicket
		INTO @tmpTransIDBatch (TransId, TranslogId, BetId, IsMG, Actual_stake, IsCashOutMember)
		FROM #BetDelete t
			INNER JOIN #tblMatch tm ON t.matchid = tm.matchid
		WHERE IsFinish IS NULL
			AND t.Bettype NOT BETWEEN 901 AND 903
			AND t.Bettype NOT BETWEEN 911 AND 913

		IF @@ROWCOUNT = 0 BREAK
		SELECT @TransIds_tmp = CAST((SELECT     m.TransId AS '@transid'
											   ,m.TranslogId AS '@translogid'
											   ,m.BetId AS '@betid'
											   ,m.IsMG AS '@isMG'
											   ,CASE WHEN m.IsMG = 1 THEN ISNULL(m.Actual_stake,0) ELSE 0 END AS '@actual_stake'
											   ,m.IsCashOutMember AS '@IsCashOutMember'
									FROM @tmpTransIDBatch m
									FOR XML PATH('r')
										,ROOT('root')
								) AS VARCHAR(MAX));

		EXEC dbo.TicketVoiding_Admin_VoidingTransId
			@TransIds = @TransIds_tmp,
			@UserId = @UserId,
			@IssueTypeId = @IssueTypeId

		SET @TransIds_tmp = ''

	END
	-- 2.2 - void MetricGaming
	IF (@isExistMG = 1)
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch

			UPDATE TOP(2000) t
				SET IsFinish = 1
			OUTPUT  DELETED.transid
				   ,CASE WHEN DELETED.IsMetricGaming = 1 THEN  DELETED.refno ELSE NULL END
				   ,ISNULL(DELETED.BetID, rs.ResultID)
				   ,DELETED.IsMetricGaming
				   ,DELETED.actual_stake
				   ,DELETED.IsCashOutMemberTicket
			INTO @tmpTransIDBatch (TransId, TranslogId, BetId, IsMG, Actual_stake, IsCashOutMember)
			FROM #BetDelete t
				INNER JOIN #tblMatch tm ON t.matchid = tm.matchid
				INNER JOIN dbo.translog tl WITH(NOLOCK) ON t.refno = tl.translogid
				OUTER APPLY (
						SELECT rs.ResultID 
						FROM DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK) 
						WHERE (
								(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, t.transdesc,0) <> 0)
								OR
								t.bettype = 806
							)
							AND rs.GameID = t.bettype	
							AND rs.VendorID = 5		
							AND rs.MatchID = t.matchid	
					) AS rs
			WHERE IsFinish IS NULL
				AND t.Bettype BETWEEN 801 AND 806

			IF @@ROWCOUNT = 0 BREAK
			SELECT @TransIds_tmp = CAST((SELECT     m.TransId AS '@transid'
												   ,m.TranslogId AS '@translogid'
												   ,m.BetId AS '@betid'
												   ,m.IsMG AS '@isMG'
												   ,CASE WHEN m.IsMG = 1 THEN ISNULL(m.Actual_stake,0) ELSE 0 END AS '@actual_stake'
												   ,m.IsCashOutMember AS '@IsCashOutMember'
										FROM @tmpTransIDBatch m
										FOR XML PATH('r')
											,ROOT('root')
									) AS VARCHAR(MAX));

			EXEC dbo.TicketVoiding_Admin_VoidingTransId
				@TransIds = @TransIds_tmp,
				@UserId = @UserId,
				@IssueTypeId = @IssueTypeId

			SET @TransIds_tmp = ''

		END
	END		

	-- 2.3 update status for sub cash-out ticket (911,912,913)
	IF (@isExistCashOut = 1)
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch

			UPDATE TOP(2000) t
				SET IsFinish = 1
			OUTPUT  DELETED.transid
					,NULL 
					,DELETED.BetID
					,0
					,0
					,0
			INTO @tmpTransIDBatch (TransId, TranslogId, BetId, IsMG, Actual_stake, IsCashOutMember)
			FROM  #CashOutTransActive t
			WHERE IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK
			SELECT @TransIds_tmp = CAST((SELECT     m.TransId AS '@transid'
													,m.TranslogId AS '@translogid'
													,m.BetId AS '@betid'
													,m.IsMG AS '@isMG'
													,m.Actual_stake '@actual_stake'
													,m.IsCashOutMember AS '@IsCashOutMember'
										FROM @tmpTransIDBatch m
										FOR XML PATH('r')
											,ROOT('root')
									) AS VARCHAR(MAX));

			EXEC dbo.TicketVoiding_Admin_VoidingTransId
				@TransIds = @TransIds_tmp,
				@UserId = @UserId,
				@IssueTypeId = @IssueTypeId

			SET @TransIds_tmp = ''

		END

		--Pre-CAL 904
		IF (@isExistBT = 1)
		BEGIN
			BEGIN TRY
				DECLARE @TempDataBT TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
				INSERT INTO @TempDataBT(MatchId, CustIds)
				SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
										FROM #BetDelete tt 
										where tt.MatchId = t.MatchId 
										  AND tt.betdaqid = 0
										  AND tt.extrainfo is null
										FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
				FROM #BetDelete t
				WHERE t.betdaqid = 0
				  AND t.extrainfo is null
				GROUP BY MatchId
				
				DECLARE @RowIdBT INT, @MatchIdTmpBT INT, @CustIdsBT VARCHAR(MAX)
				SELECT @RowIdBT = 1
				WHILE EXISTS (SELECT TOP 1 1 FROM @TempDataBT WHERE RowId = @RowIdBT)
				BEGIN
					SELECT @MatchIdTmpBT = MatchId
						, @CustIdsBT = CustIds
					FROM @TempDataBT t 
					WHERE RowId = @RowIdBT
					
					EXEC dbo.NAP_Admin_Calculate_904 
						@MatchId 	= @MatchIdTmpBT
						, @Action 	= 'VOID'
						, @CustIds 	= @CustIdsBT
						
					SET @RowIdBT = @RowIdBT + 1
				END
				
			END TRY 
			BEGIN CATCH
				SELECT	@ErrCode = 904
					,@ErrMsg = 'Called NAP_Admin_Calculate_904 with error.'
			END CATCH
		END
			
		--Pre-CAL 914
		IF (@isExistCashOut = 1)
		BEGIN
			BEGIN TRY
				DECLARE @TempDataBT1 TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
				INSERT INTO @TempDataBT1(MatchId, CustIds)
				SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
										FROM @tblCustCashOut912 tt 
										where tt.MatchId = t.MatchId
										FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
				FROM @tblCustCashOut912 t
				GROUP BY MatchId
				
				DECLARE @RowIdBT1 INT, @MatchIdTmpBT1 INT, @CustIdsBT1 VARCHAR(MAX)
				SELECT @RowIdBT1 = 1
				WHILE EXISTS (SELECT TOP 1 1 FROM @TempDataBT1 WHERE RowId = @RowIdBT1)
				BEGIN
					SELECT @MatchIdTmpBT1 = MatchId
						, @CustIdsBT1 = CustIds
					FROM @TempDataBT1 t 
					WHERE RowId = @RowIdBT1
					
					EXEC dbo.NAP_Admin_Calculate_914 
						@MatchId 	= @MatchIdTmpBT1
						, @Action 	= 'VOID'
						, @CustIds 	= @CustIdsBT1
						
					SET @RowIdBT1 = @RowIdBT1 + 1
				END
				
			END TRY 
			BEGIN CATCH
				SELECT	@ErrCode = 904
					,@ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
			END CATCH
		END
		
		-- STEP 3 : Update BetTrade selling information
		CREATE TABLE #CustIdList
		(
			custid INT PRIMARY KEY
		)
			
		CREATE TABLE #CustList
		(
			custid INT PRIMARY KEY,
			Balance MONEY
		)
		
		INSERT INTO #CustIdList(custid)
		SELECT DISTINCT custid FROM #BetDelete
		
		INSERT INTO #CustList(custid, Balance)
		SELECT T.custid, SUM(T.Balance)
		FROM
		(
			SELECT	b.custid, b.winlost - b.actual_stake + b.playercomm AS Balance				
			FROM	dbo.bettrans b WITH(NOLOCK)
				LEFT JOIN dbo.translog tl WITH(NOLOCK)
					ON	b.refno = tl.translogid
						AND b.matchid = tl.eventID				
			WHERE	b.custid IN (SELECT custid FROM #CustIdList)
					AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))									
			UNION ALL 
			SELECT	tl.custid, 0 - tl.actual_stake + 0 AS Balance 
			FROM	dbo.translog tl WITH(NOLOCK)
			WHERE	tl.custid IN (SELECT custid FROM #CustIdList)
					AND tl.statusID IN (0, 1)				
			UNION ALL
			SELECT	custid, winlost - actual_stake + playercomm AS Balance
			FROM	dbo.bettransRnG WITH(NOLOCK)
			WHERE	custid IN (SELECT custid FROM #CustIdList)
					AND IsSum=0				
			UNION ALL
			SELECT	custid, winlost - actual_stake + playercomm AS Balance
			FROM	dbo.bettransLC WITH(NOLOCK)
			WHERE	custid IN (SELECT custid FROM #CustIdList) 
					AND IsSum=0	
			UNION ALL
			SELECT bal.CustId, (Credit - Debit) AS Balance
			FROM dbo.BalNetPosition bal WITH(NOLOCK)
				INNER JOIN #BetDelete d 
						 ON bal.CustId = d.CustId 
							AND bal.MatchId = d.matchid 
							AND bal.Bettype = d.bettype	
			UNION ALL
			SELECT DISTINCT c.CustId, c.Credit AS Balance
			FROM DBCUST.custDB.dbo.custInfo c WITH(NOLOCK)						
				 INNER JOIN #CustIdList d 
						 ON c.CustId = d.CustId
		) T
		GROUP BY T.custid
		
		;WITH CTE_Source AS
		(
			SELECT	bts.TradeID AS TradeID
					,bts.TicketID AS [TicketID]					
					,'SB void ticket due to ' + @Reason AS [Remark]
					,tmpsub.awinlost AS [BTBuyBack]
					,0 AS [BTComission]
					,tcust.Balance AS [AfterBalance]
					,'SB' AS [Owner]
					,1 AS [Cancelled]
					,GETDATE() AS [ChangeDate]
					,GETDATE() AS [CreateDate]
			FROM #BetDelete tmpsub						 											 
				 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
						 ON bts.TicketID = tmpsub.refno -- bettrade + cash-out
							AND CASE																				 
									WHEN tmpsub.bettype = 911 -- cash-out													 
											THEN CASE
													WHEN bts.SoldTicketID = tmpsub.transid THEN 1
													ELSE 0
												 END																							
									ELSE 1
								END = 1	
				 INNER JOIN #CustList tcust
						 ON tmpsub.custid = tcust.custid						 							
			WHERE tmpsub.BetType IN (901,911)			  
		)
		MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
		USING (SELECT * FROM CTE_Source) AS [Source]
		ON [Target].TradeID = [Source].TradeID
		WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
									,[BTBuyBack] = [Source].[BTBuyBack]
									,[BTComission] = [Source].[BTComission]
									,[AfterBalance] = [Source].[AfterBalance]
									,[Owner] = [Source].[Owner]
									,[Cancelled] = [Source].[Cancelled]
									,[ChangeDate] = [Source].[ChangeDate]										
		WHEN NOT MATCHED THEN INSERT(TradeID
									,[TicketID]										
									,[Remark]
									,[BTBuyBack]
									,[BTComission]
									,[AfterBalance]
									,[Owner]
									,[Cancelled]
									,[ChangeDate]
									,[CreateDate])
							  VALUES([Source].TradeID
									,[Source].[TicketID]										
									,[Source].[Remark]
									,[Source].[BTBuyBack]
									,[Source].[BTComission]
									,[Source].[AfterBalance]
									,[Source].[Owner]
									,[Source].[Cancelled]
									,[Source].[ChangeDate]
									,[Source].[CreateDate]); 
			
		-- Insert bettrade tickets to send API	
		IF (@isExistBT = 1)	
			WITH cteMainTicket
			AS(
				SELECT	transid
				FROM	#BetDelete 
				WHERE	betdaqid = 0
						AND extrainfo is null
						AND grouptransid = transid -- main ticket
			)
			INSERT INTO dbo.BettradeAPI (
					transid
					,matchid
					,[Session]
					,[action]
					,buybackNo
					,Payout
					,Remark
				)
			SELECT	b.TicketID
					,b.MatchID
					,@session
					,'VOID'
					,b.BuyBackNo
					,b.PayOut
					,'SB void ticket due to ' + @Reason
			FROM	dbo.BetTradeSelling b WITH(NOLOCK)
			WHERE	b.TicketID IN (SELECT transid FROM cteMainTicket)
				AND b.[Status] IN ('Accept', 'Confirm')
	END		
	--re-calculate Cricket - charge comm
	IF(@isExistCricket = 1)
	BEGIN
		DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
		
		BEGIN TRY
			INSERT INTO @TempData(MatchId, CustIds)
			SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
									FROM #BetDelete tt where tt.MatchId = t.MatchId
									FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
			FROM #BetDelete t
			WHERE Bettype = 501
			GROUP BY MatchId

			IF EXISTS (SELECT TOP 1 1 FROM @TempData)
			BEGIN
				DECLARE @RowId INT, @MatchIdTmp INT, @CustIds VARCHAR(MAX)
				SELECT @RowId = 1
				WHILE EXISTS (SELECT TOP 1 1 FROM @TempData WHERE RowId = @RowId)
				BEGIN
					SELECT @MatchIdTmp = MatchId
						, @CustIds = CustIds
					FROM @TempData t WHERE RowId = @RowId
					SET @RowId = @RowId + 1
					
					EXEC dbo.NAP_Admin_Calculate_500 @MatchId	= @MatchIdTmp
						, @Action = 'VOID'
						, @CustIds = @CustIds
				END
			END
		END TRY 
		BEGIN CATCH
			SELECT	@ErrCode = 500
				,@ErrMsg = 'Called NAP_Admin_Calculate_500 with error.'
		END CATCH
	END

	IF (@isExistLucky3 = 1)
	BEGIN
		SELECT @Lucky3TransIDs = STUFF(
										(
											SELECT ',' + CAST(transid AS VARCHAR(MAX))
											FROM #BetDelete
											WHERE Bettype = 1600
											FOR XML PATH('')
										), 1, 1, '')
		
		INSERT INTO #Lucky3Matches(MatchID, Has1stPrize)
		SELECT	r.MatchId,
				MAX(CASE r.Prize WHEN 1 THEN 1 ELSE 0 END)
		FROM dbo.BetLucky3Result r WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #BetDelete b WHERE b.transid = r.TransId AND b.Bettype = 1600)
			AND r.Bettype = 1601
		GROUP BY r.matchid
		
		--Delete data in betLucky3Result
		EXEC dbo.NAP_Admin_PreCalculate_s160 @MatchId = 0, @Mode = 'preCAL', @Action = 'VOID', @strVoidedTransId = @Lucky3TransIDs,
											@FirstBall = NULL, @SecondBall = NULL, @ThirdBall = NULL, @FirstPrizeMaxCount = NULL,
											@PrizeSettingId = NULL, @strCustSetting = NULL
		
		UPDATE l
		SET NumberOf1stPrize = d.NumberOf1stPrize,
			NumberOf2ndPrize = d.NumberOf2ndPrize,
			NumberOf3rdPrize = d.NumberOf3rdPrize
		FROM #Lucky3Matches l
			JOIN (
				SELECT  r.MatchId,
						SUM(CASE r.Prize WHEN 1 THEN Odds * Hits ELSE 0 END) AS NumberOf1stPrize,
						SUM(CASE r.Prize WHEN 2 THEN Odds * Hits ELSE 0 END) AS NumberOf2ndPrize,
						SUM(CASE r.Prize WHEN 3 THEN Odds * Hits ELSE 0 END) AS NumberOf3rdPrize
				FROM dbo.BetLucky3Result r WITH(NOLOCK)
				WHERE EXISTS (SELECT 1 FROM #Lucky3Matches l1 WHERE r.MatchId = l1.MatchID)
					AND r.Bettype = 1601
				GROUP BY r.MatchId
			) d ON l.MatchID = d.MatchId
		
		SELECT @Lucky3Matches = CAST((	SELECT	MatchID AS '@m',
												NumberOf1stPrize AS '@fn',
												NumberOf2ndPrize AS '@sn',
												NumberOf3rdPrize AS '@tn'
										FROM #Lucky3Matches
										FOR XML PATH('r'), ROOT('root'), TYPE) AS VARCHAR(MAX))
		
		--Update match prize count
		EXEC DBPRO.bodb02.dbo.NAP_Admin_Match_Update_s160 @Action = NULL, @IsAuto = 0, @strMatchInfo = @Lucky3Matches
		
		--Return matches which need recalculation
		SELECT @ReCalcMatches = STUFF(
										(
											SELECT ', ' + CAST(MatchID AS VARCHAR(MAX))
											FROM #Lucky3Matches
											WHERE Has1stPrize = 1
											FOR XML PATH('')
										), 1, 2, '')
	END
	
	--Get data after update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		INSERT INTO #balanceGameAfter(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #BetDelete tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR tmp.bettype BETWEEN 81 AND 120 OR tmp.bettype BETWEEN 8101 AND 8120
			OR tmp.Bettype BETWEEN 1201 AND 1299
			OR tmp.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
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
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) balance
	FROM
	(
		-- normal, main bettrade, main cash-out, cash-out member bet ticket
		SELECT tmpmain.custid
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	main.transid = tmpmain.transid
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = tmpmain.matchid
					
		UNION ALL
		
		-- sub bettrade (901,902,903)
		SELECT sub.custid
			 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype, sub.matchid,tmpmain.sporttype
		FROM dbo.bettrans sub WITH (NOLOCK)
			INNER JOIN #BTTransActive bt 
				ON sub.matchid = bt.matchid
					AND sub.bettype = bt.bettype
					AND sub.transId = bt.transId
			INNER JOIN #BetDelete AS tmpmain 
				ON	bt.refno 	= tmpmain.transid
				AND bt.matchid 	= tmpmain.matchid					
		WHERE tmpmain.betdaqid = 0
		  AND tmpmain.extrainfo is null
					
		UNION ALL
		
		-- sub cash-out (911,912,913)		
		SELECT sub.custid
			 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype, sub.matchid,bt.sporttype
		FROM dbo.bettrans sub WITH (NOLOCK)
			INNER JOIN #CashOutTransActive bt 
				ON sub.matchid = bt.matchid
					AND sub.bettype = bt.bettype
					AND sub.transId = bt.transId																
		WHERE @isExistCashOut = 1
		
		UNION ALL
		
		-- Cricket charge comm
		SELECT b.custid
			 , 0 AS BonusID -- cricket tickets always bet from cash wallet
			 , 2 AS WalletType -- cricket tickets always bet from cash wallet
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype, b.matchid, 50 AS sporttype
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblMatch tm 
				ON b.matchid = tm.matchid
		WHERE b.bettype = 500
			AND EXISTS (
				SELECT TOP 1 1 
				FROM #BetDelete d 
				WHERE b.custid = d.custid
			)
					
		UNION ALL
		
		-- BT-WLSharing (904)
		SELECT	sub904.custid
			  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			  , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype, sub904.matchid, 1 AS sporttype  
		FROM	bettrans sub904 WITH (NOLOCK)
			INNER JOIN @tblCustBT902 temp
			ON sub904.custid = temp.custid
				AND sub904.matchid = temp.matchid									
		WHERE sub904.bettype = 904
		
		UNION ALL
		
		-- cash-out summary 914
		SELECT	sub914.custid
			  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype, sub914.matchid, 1 AS sporttype  
		FROM	bettrans sub914 WITH (NOLOCK)
			INNER JOIN @tblCustCashOut912 temp
			ON sub914.custid = temp.custid
				AND sub914.matchid = temp.matchid									
		WHERE sub914.bettype = 914
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
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
	
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
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
	
	----ODDS
	UPDATE odds  
	SET hometotal = hometotal - (CASE WHEN b.betteam = 'h' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
				  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
		   ELSE 0 END )  
	,awaytotal = awaytotal - (CASE WHEN b.betteam = 'a' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
				  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
			ELSE 0 END)  
	FROM dbo.odds o WITH (ROWLOCK,UPDLOCK)  
		INNER JOIN dbo.bettrans b WITH (NOLOCK) 
			ON o.matchid = b.matchid AND o.oddsid = b.oddsid  
		INNER JOIN #tblMatch tm ON b.matchid = tm.matchid
		INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON c.custid = b.custid  
		INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON c.currency = e.exchangeid  
		
	WHERE EXISTS ( 
			SELECT TOP 1 1   
			FROM #BetDelete AS bd
			WHERE bd.TransID  = b.transid
				AND bd.Bettype IN (1,3,7,8)				
	   )  
	
	------ releasing SD process
	--CleanUP:
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistParlay 				= @isExistParlay
		, @isExistOutright 			= @isExistOutright
		, @isExistMG				= @isExistMG
		, @isExistFM				= @isExistFM
		, @isExistMatch				= @isExistMatch
		, @isExistNG				= @isExistNG
		, @isExistVS				= @isExistVS
		, @isExistBB				= @isExistBB
		, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
		, @isExistFM2				= @isExistFM2
		, @IsReleased				= 1
		
	-------> releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess
			@Mode = 'Original'
		  , @Action = 'Void' 
		  , @IsReleased = 1				 

	 IF @FilterUserName IS NOT NULL
	BEGIN
		SELECT @LogData = 'Delete transaction by Username: '+ @FilterUserName
						+ ' Products: '+ @Products
						+ ' Ticket statusid: '+ @StatusIds
						+ ' Winlostdate From: '+ CAST(@FromDate AS VARCHAR(20)) + CASE WHEN @ToDate IS NULL THEN '' ELSE ' To: '+ CAST(@ToDate AS VARCHAR(20)) END
	END
	ELSE 
	BEGIN
		SELECT @LogData = 'Delete transaction transid: ' + CAST(@TransIds AS VARCHAR(8000))
	END 
	SELECT @LogData = @LogData
					+ ' by_login: ' + @username 
					+ ' IP: ' + CAST(@IP AS VARCHAR(15)) 
					+ ' reason: ' + @reason  + ' - -' + @ReasonSC
	EXEC dbo.WriteLog_UserLog @UserID = @UserID, @Doing = @LogData 
	
	-- CHECK IT GROUP or NOT ?   
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
	
	--- BETS: return all additional information for mailing 
	;WITH CTE_CustIdAll AS (
		SELECT DISTINCT t.custid
		FROM #BetDelete b
		CROSS APPLY (
			VALUES (custid)
			,(creator)
			,(recommend)
			,(mrecommend)
			,(srecommend)
		) AS t (custid)
	)
	SELECT ci.custid
		, ci.username
		, ci.username2
		, ci.site
			INTO #CTE_CustInfo
	FROM CustDB.dbo.Customer ci WITH(NOLOCK)
		INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid			
	
	SELECT	
		b.transId
		,b.custid
		,b.homeid
		,b.awayid
		,b.matchcode
		,b.eventdate
		,b.leagueid		
		,b.IsNeutral
		,b.showtime
		,b.OriginalBetType
		,b.odds
		,b.oddsspread
		,b.oddsType
		,b.transdate
		,CASE WHEN b.Bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END transid
		,b.refno
		,b.betteam
		,b.betcheck
		,b.betfrom
		,b.livehomescore
		,b.liveawayscore		
		,b.stake
		,b.status
		,b.winlost
		,b.playercomm AS commission
		,b.currency
		,b.CurrencyName
		,b.betid
		,b.transdesc
		,ISNULL(b.IsHideComm, CAST(0 AS BIT)) AS IsHideComm		
		,b.betdaqid
		,b.ExtraInfo
		,b.MainCashoutId
		,b.SiteId
		,b.IsMetricGaming		
		,b.WalletType
		,b.RefCode
		,b.modds AS MasterOdds
		,b.sporttype AS SportTypeId
		,b.liveindicator AS IsLive
		,b.BetType AS BetTypeId
		,b.Hdp1 AS Handicap1
		,b.Hdp2 AS Handicap2
		,m.SettlementStatus
		,m.GlobalShowTime
		,b.actual_stake AS ActualStake
		--------------------
		,ci.username
		,ci.username2
		,ag.username 	AS AgUsername
		,ag.custid		AS Recommend
		,ma.username 	AS MAgUsername
		,ma.custid 		AS Mrecommend
		,su.username 	AS SAgUsername
		,su.custid 		AS SRecommend
		--------------------
		,su.site 
		,CASE 
			WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
			ELSE su.site 
		END AS EmailGroup
		,@isITAdmin		AS IsITSupport
		,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
		,b.IsBetTrade
		,CASE WHEN b.IsCashOutMemberTicket = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isCashOut
		,b.matchid  -- send letstalk
		,CASE 
			WHEN ISNULL(m.eventstatus, '') <> 'completed' AND b.statusid IN (111, 112, 113)
					THEN CASE
							WHEN ISNULL(mr.IsHTCal, 0) = 0
									AND EXISTS (SELECT TOP 1 1
												FROM dbo.f_Set_Instant_GetBettypes() T
												WHERE T.InstantType IN (1, 3) AND T.bettype = b.bettype)
									THEN CAST(1 AS BIT)
							WHEN ISNULL(mr.IsHTCal, 0) = 1
									AND EXISTS (SELECT TOP 1 1
												FROM dbo.f_Set_Instant_GetBettypes() T
												WHERE T.InstantType IN (2, 3) AND T.bettype = b.bettype)
									THEN CAST(1 AS BIT)
							ELSE CAST(0 AS BIT)
						END
			ELSE CAST(0 AS BIT)
		END AS IsInstantSettlementTicket
	FROM	#BetDelete b
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
		LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = b.matchid
		LEFT JOIN #CTE_CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
		LEFT JOIN #CTE_CustInfo cr WITH(NOLOCK) ON b.creator = cr.custid	
		LEFT JOIN #CTE_CustInfo ag WITH(NOLOCK) ON b.recommend = ag.custid
		LEFT JOIN #CTE_CustInfo ma WITH(NOLOCK) ON b.mrecommend = ma.custid
		LEFT JOIN #CTE_CustInfo su WITH(NOLOCK) ON b.srecommend = su.custid
		LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) ON b.srecommend = s.custid			
	ORDER BY ISNULL(b.MainTransId, b.transid)
		   , CASE 
				WHEN b.BonusID IS NOT NULL
						THEN CASE 
								WHEN b.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE b.transid
			 END	 	
	DROP TABLE #CTE_CustInfo
	--Metric API Calling  
	SELECT	tmp.refno 
			,tmp.Bettype
			,tmp.custid
			,b.statusid
			,b.winlost
			,tmp.odds
			,tmp.oddstype
			,tmp.stake
			,tmp.transdesc
			,tl.SiteId
	FROM	#BetDelete tmp
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON	tmp.transid = b.transid
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON tl.translogid = tmp.refno
	WHERE tmp.Bettype BETWEEN 801 AND 806  
		
	DROP TABLE #tblMatchProcess
	DROP TABLE #BTTransActive
	DROP TABLE #balanceGameBefore
	DROP TABLE #balanceGameAfter
	DROP TABLE #tblTransIds
	DROP TABLE #tblTransIdSolds
	DROP TABLE #BetDelete
	DROP TABLE #tblMatch
	DROP TABLE #CashOutTransActive
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tblCashOutProcess
	DROP TABLE #Lucky3Matches

	
	RETURN
END
GO
