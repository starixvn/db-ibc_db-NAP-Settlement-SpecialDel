/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetIdList_Upd]  
	@TransIds			VARCHAR(MAX)
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
	  - 20210107@Charles: Return extra oddsid column in results [Redmine: #143666]
	  - 20210505@July: Show VIP status on void email [Redmine: #153157]
	  - 20210514@July: SD - Remove unused code/products [Redmine: #121752]
	  - 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
	  - 20210622@Helen: [TVS] SP Tuning [Redmine: #157354]
	  - 20210720@July: TVS - Modify the way to get move bet date [Redmine: #154974]
	  - 20210801@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
	  - 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	  - 20210820@July: Integrate Bitcoin [Redmine: #159948]
	  - 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
	  - 20210930@July: Change the source balance (balancetype = 4) of Bitcoin product [Redmine: #162474]
	  - 20211207@July: Implement New Cash Out Model [Redmine: #165097]

	 Param's Explanation:   
	*/
BEGIN
	SET NOCOUNT ON	

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidBetIdList_Upd '
				+ CASE WHEN @UserId IS NULL THEN '' ELSE '@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
				+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
				+ CASE WHEN @Password IS NULL THEN '' ELSE ',@Password = ''' + CONVERT(NVARCHAR(50), @Password) + '''' END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
				+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
				+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END
				+ CASE WHEN @IsAbnormalBet IS NULL THEN '' ELSE ',@IsAbnormalBet = ' + CONVERT(NVARCHAR(50), @IsAbnormalBet) END
				+ CASE WHEN @FilterUserName IS NULL THEN '' ELSE '@FilterUserName = ''' + CONVERT(NVARCHAR(50), @FilterUserName) + '''' END
				+ CASE WHEN @Products IS NULL THEN '' ELSE '@Products = ''' + CONVERT(NVARCHAR(50), @Products) + '''' END
				+ CASE WHEN @StatusIds IS NULL THEN '' ELSE '@StatusIds = ''' + CONVERT(NVARCHAR(50), @StatusIds) + '''' END
				+ CASE WHEN @FromDate IS NULL THEN '' ELSE '@FromDate = ''' + CONVERT(NVARCHAR(50), @FromDate) + ''''  END
				+ CASE WHEN @ToDate IS NULL THEN '' ELSE '@ToDate = ''' + CONVERT(NVARCHAR(50), @ToDate) + ''''  END
				
			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

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
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
			,@IsExistBB					BIT = 0
			,@isExistLucky3				BIT = 0
			,@Lucky3TransIDs			VARCHAR(MAX)
			,@Lucky3Matches				VARCHAR(MAX) = ''
			,@isExistFM2				BIT = 0
			,@query						NVARCHAR(MAX) = ''
			,@ExecuteSQL				NVARCHAR(MAX) = ''
			,@Movebetdate				DATETIME
			,@isExistMatch3rd			BIT = 0

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL

	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))							
			,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
			,@totalMainParlay		INT = 0

	SELECT @ErrCode	= 0
		  ,@ErrMsg	= ''
	
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange
		
	--get balance game for livecs
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
		,IsCashOut		BIT DEFAULT(0)
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
		,ParentID		INT
		,ChildMatchType TINYINT
		,EndTime		DATETIME
		,ruben			TINYINT
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
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	CREATE TABLE #Lucky3Matches
	(
		MatchID				INT PRIMARY KEY,
		Has1stPrize			BIT,
		NumberOf1stPrize	INT DEFAULT(0),
		NumberOf2ndPrize	INT DEFAULT(0),
		NumberOf3rdPrize	INT DEFAULT(0)
	)
	
	DECLARE @tmpMatch_Eventdate TABLE (MatchId INT, Eventdate DATETIME)

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
		,IsCashOut
		,awinlost
		,SiteId
		,CurrencyName
		,IsMetricGaming
		,modds
		,WalletType
		,RefCode
		,BonusID
		,actual_stake
		,ruben
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
		,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
		,b.awinlost
		,tl.SiteId
		,b.CurrencyName
		,1 AS IsMetricGaming
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,tl.actual_stake
		,b.ruben
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
		,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
		,b.awinlost
		,NULL AS SiteId
		,b.CurrencyName
		,0 AS IsMetricGaming
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,b.actual_stake
		,b.ruben
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransIds t
			ON b.transid = t.transid
	WHERE b.bettype < 19001
		AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND b.bettype NOT BETWEEN 801 AND 806-- MG
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
			,IsCashOut
			,awinlost
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
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.awinlost
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
			,ParentID	= CASE WHEN m.sporttype = 50 THEN ISNULL(m.ParentID,0) ELSE 0 END
			,ChildMatchType = CASE WHEN m.sporttype = 50 THEN ISNULL(m.ChildMatchType, 0) ELSE 0 END
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
		UPDATE d
		SET sporttype = sb.SportType
		FROM #BetDelete d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END
	-- UPDATE Sportype, Endtime for Bitcoin 
	IF(EXISTS(SELECT TOP 1 1 FROM #BetDelete WHERE bettype BETWEEN 7901 AND 7999))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
			,eventdate  = m.EventDate
			,EndTime    = m.EndTime
		FROM #BetDelete d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
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
	
	/*Modify the way to get move bet date*/
	IF(EXISTS(SELECT TOP 1 1 FROM #BetDelete WHERE bettype IN (9,29,2799)))
	BEGIN
		UPDATE #BetDelete
		SET eventdate = winlostdate
		WHERE bettype IN (9, 29, 2799)	
	END

	INSERT INTO @tmpMatch_Eventdate (MatchId, Eventdate)
	SELECT DISTINCT MatchId, eventdate
	FROM #BetDelete

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatch_Eventdate WHERE eventdate <= @Movebetdate)
	BEGIN
		IF @FilterUserName IS NULL -- By Bet ID
		BEGIN
			SELECT @ErrCode = 102
				 , @ErrMsg = 'Could not void some tickets due to Movebet process. Please try Search again.'
		END
		ELSE -- By Username
		BEGIN
			SELECT @ErrCode = 102
				 , @ErrMsg = 'Could not void some tickets due to Movebet process. Please try a new Date range and Search again.'
		END

		RETURN	
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
	
	SELECT @winlostdate 				= MIN (winlostdate)
			,@isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
			,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
			,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistLucky3				= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
			,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
			,@isExistMatch3rd			= MAX (CASE WHEN Bettype BETWEEN 7901 AND 7999 THEN 1 ELSE 0 END)
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
					AND Bettype NOT BETWEEN 7901 AND 7999
				THEN 1 --SB,NG,LC
			WHEN Bettype = 10 THEN 2	-- Outright
			WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
			WHEN f.GroupId = 1 THEN 6 -- FM
			WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
			WHEN Bettype = 38 THEN 5 -- Bet Builder
			WHEN f.GroupId = 2 THEN 7 -- FM 228
			WHEN Bettype BETWEEN 7901 AND 7999 THEN 8 --Bitcoin
			ELSE 0
		END AS KeyID
	FROM #BetDelete b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f

	-- Apply new way to lock parlay tickets
	INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
	SELECT matchid, refno
	FROM #BetDelete
	WHERE Bettype IN (9,29) --NOT 2799: Virtual Sport

	SET @totalMainParlay = @@ROWCOUNT

	EXEC dbo.NAP_Set_GlobalSettingSel 
		 @LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT
	
	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
	BEGIN	
		IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
			OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1 OR @isExistMatch3rd = 1
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright 			= @isExistOutright
				, @isExistMG				= @isExistMG
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @isExistMatch
				, @isExistNG				= @isExistNG
				, @isExistVS				= @isExistVS
				, @isExistBB				= @isExistBB
				, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				, @isExistFM2				= @isExistFM2
				, @isExistMatch3rd			= @isExistMatch3rd
				, @spName					= @spName
				, @avaiableProcess 			= @avaiableProcess OUTPUT
				, @ErrCode					= @ErrCode OUTPUT
				, @ErrMsg					= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN	
				RETURN
			END
		END
		
		IF @totalMainParlay > 0 
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno		= 1
				,@SPName				= @SPName
				,@Session				= @Session
				,@avaiableProcess 		= @avaiableProcess OUTPUT
				,@ErrCode				= @ErrCode OUTPUT
				,@ErrMsg				= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN	
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistOutright 			= @isExistOutright
					, @isExistMG				= @isExistMG
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @isExistMatch3rd			= @isExistMatch3rd
					, @IsReleased				= 1
						
				RETURN
			END
		END		
	END
	ELSE IF @totalMainParlay > @ThreadHold
	BEGIN
		-- checking SD proccess
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
		    , @isExistMatch3rd			= @isExistMatch3rd
			, @spName					= @spName
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN		
			RETURN
		END
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
	-- 1.1  backup for normal ticket
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
		,main.betcheck
		,main.checktime
		,main.matchid
		,main.bettype
	FROM dbo.bettrans AS main WITH (NOLOCK)
		INNER JOIN #tblMatch tm 
		ON main.matchid = tm.matchid
		INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK) 
		ON	main.transid = tmpmain.transid 
		AND main.matchid = tmpmain.matchid		
	
	--Get data before update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1 OR @isExistMatch3rd = 1)
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
				WHEN b.bettype BETWEEN 7901 AND 7999 THEN 7901
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
			OR b.bettype BETWEEN 7901 AND 7999
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				WHEN b.bettype BETWEEN 7901 AND 7999 THEN 7901
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
	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, TranslogId BIGINT, BetId BIGINT, IsMG BIT, Actual_stake MONEY)
	DECLARE @TransIds_tmp VARCHAR(MAX) = ''
		, @IssueTypeId INT = 0

	SET @IssueTypeId = CASE WHEN @IsAbnormalBet = 1 THEN 11 ELSE 0 END

	-- STEP 2 : Update bettrans/translog
	-- 2.1. Update bettrans	for normal ticket
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
		INTO @tmpTransIDBatch (TransId, TranslogId, BetId, IsMG, Actual_stake)
		FROM #BetDelete t
			INNER JOIN #tblMatch tm ON t.matchid = tm.matchid
		WHERE IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK
		SELECT @TransIds_tmp = CAST((SELECT     m.TransId AS '@transid'
											   ,m.TranslogId AS '@translogid'
											   ,m.BetId AS '@betid'
											   ,m.IsMG AS '@isMG'
											   ,CASE WHEN m.IsMG = 1 THEN ISNULL(m.Actual_stake,0) ELSE 0 END AS '@actual_stake'
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
			INTO @tmpTransIDBatch (TransId, TranslogId, BetId, IsMG, Actual_stake)
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
	
	-- Update CashOutSelling [#165097]
	UPDATE c
	SET CashOutStatus = 6 --Void
	FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #BetDelete b ON c.TransID = b.transid AND c.MatchID = b.matchid
	WHERE b.betdaqid = -2 

	--Get data after update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1 OR @isExistMatch3rd = 1)
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
				WHEN b.bettype BETWEEN 7901 AND 7999 THEN 7901
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
			OR b.bettype BETWEEN 7901 AND 7999
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				WHEN b.bettype BETWEEN 7901 AND 7999 THEN 7901
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
	
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1 OR @isExistMatch3rd = 1)
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
	
	------ releasing SD process
	--CleanUP:
	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
	BEGIN
		IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
			OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1 OR @isExistMatch3rd = 1
		BEGIN
			------ releasing single process
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright 			= @isExistOutright
				, @isExistMG				= @isExistMG
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @isExistMatch
				, @isExistNG				= @isExistNG
				, @isExistVS				= @isExistVS
				, @isExistBB				= @isExistBB
				, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				, @isExistFM2				= @isExistFM2
				, @isExistMatch3rd			= @isExistMatch3rd
				, @IsReleased				= 1
		END

		IF @totalMainParlay > 0 
		BEGIN
			------ releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
				,@Session	= @Session
				,@IsReleased = 1
	    END			
	END
	ELSE IF @totalMainParlay > @ThreadHold
	BEGIN
		------ releasing SD process
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
		    , @isExistMatch3rd			= @isExistMatch3rd
			, @IsReleased				= 1
	END
		
	----------------Insert Max Payout Queue----------------
	DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL, @sporttype SMALLINT = NULL, @ParentID INT= NULL, @ChildMatchType TINYINT = NULL
	DECLARE @Match_tmp AS TABLE (matchId INT, sporttype SMALLINT, ParentID INT, ChildMatchType TINYINT, IsFinish BIT)

	INSERT INTO @Match_tmp (MatchId, sporttype, ParentID, ChildMatchType)
	SELECT DISTINCT t.matchid, t.sporttype, t.ParentID, t.ChildMatchType
	FROM #BetDelete t

	WHILE (1=1)
	BEGIN
		SELECT @TransIds_MaxPO = '', @MatchId_MaxPO = NULL, @sporttype = NULL, @ParentID = NULL, @ChildMatchType = NULL
		
		UPDATE TOP(1) mt SET mt.IsFinish = 1, @MatchId_MaxPO = mt.matchid, @sporttype = mt.sporttype, @ParentID = mt.ParentID, @ChildMatchType = mt.ChildMatchType
		FROM @Match_tmp mt
		WHERE mt.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
					,CASE 
						WHEN dp.custid IS NOT NULL THEN 3 --deposit 
						WHEN c.site = '789y' THEN 2 --789y
						ELSE 1 END AS '@sitetype'
					,b.TransId AS '@transid'
					,b.bettype AS '@bettype'
				FROM #BetDelete b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
				WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype AND b.Bettype NOT IN (29,2799)
				FOR XML PATH('r'), ROOT('root')
			)

		SET @MatchId_MaxPO = CASE WHEN @sporttype = 50 AND @ParentID <> 0 AND @ChildMatchType = 200 THEN @ParentID ELSE @MatchId_MaxPO END

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO

		IF EXISTS (SELECT TOP 1 1 FROM #BetDelete WHERE bettype = 29)
		BEGIN
			--Prepare for Max Payout
			SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
										,t.ruben AS '@ruben'
										,t.transid AS '@transid'
									FROM #BetDelete t
									GROUP BY custid, ruben, transid
									FOR XML PATH('r'), ROOT('root')
								)

			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
				@MatchId= 29
				,@TransidList = @MainParlay_MaxPO
		END
	END
	-------------------------------------------------------
	 
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

	--get list VIP Account
	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
							FROM dbo.Dep_CustVIP WITH (NOLOCK)	
							'
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
	INSERT INTO @VIPAccount_tmp(CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

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
		,b.IsCashOut
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
		,b.MainTransId
		,ci.username
		,ci.username2
		,ag.username 	AS AgUsername
		,ag.custid		AS Recommend
		,ma.username 	AS MAgUsername
		,ma.custid 		AS Mrecommend
		,su.username 	AS SAgUsername
		,su.custid 		AS SRecommend
		,su.site 
		,CASE 
			WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
			ELSE su.site 
		END AS EmailGroup
		,@isITAdmin		AS IsITSupport
		,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
		,b.matchid  -- send letstalk
		,b.oddsid AS OddsId
		,CASE 
			WHEN ISNULL(m.eventstatus, '') <> 'completed' AND b.statusid IN (111, 112, 113) AND b.betdaqid <> -2
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
		,CASE WHEN vip.CustID IS NOT NULL THEN 1 ELSE 0 END AS IsVipMember
		,b.EndTime --Support bitcoin
	FROM	#BetDelete b
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
		LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = b.matchid
		LEFT JOIN #CTE_CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
		LEFT JOIN #CTE_CustInfo cr WITH(NOLOCK) ON b.creator = cr.custid	
		LEFT JOIN #CTE_CustInfo ag WITH(NOLOCK) ON b.recommend = ag.custid
		LEFT JOIN #CTE_CustInfo ma WITH(NOLOCK) ON b.mrecommend = ma.custid
		LEFT JOIN #CTE_CustInfo su WITH(NOLOCK) ON b.srecommend = su.custid
		LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) ON b.srecommend = s.custid
		LEFT JOIN @VIPAccount_tmp vip ON b.custid = vip.CustID			
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
		
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN       
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, NULL, GETDATE(),@SubmittedDate)
        END        
	END TRY
	BEGIN CATCH
	END CATCH

	DROP TABLE #tblMatchProcess
	DROP TABLE #balanceGameBefore
	DROP TABLE #balanceGameAfter
	DROP TABLE #tblTransIds
	DROP TABLE #BetDelete
	DROP TABLE #tblMatch
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #Lucky3Matches
	DROP TABLE #tblMatchParlayProcess

	RETURN
END
GO
