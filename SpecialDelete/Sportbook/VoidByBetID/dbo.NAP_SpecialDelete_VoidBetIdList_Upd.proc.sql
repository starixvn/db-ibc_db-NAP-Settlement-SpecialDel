/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetIdList_Upd]  
	@TransIds			VARCHAR(MAX) =''
	,@UserName			VARCHAR(30) --login username
	,@Password			VARCHAR(50)
	,@UserId			INT = 0 -- custid of Admin
	,@IP				VARCHAR(15)
	,@Reason			NVARCHAR(500) = ''
	,@ReasonSC			NVARCHAR(500) = ''
	,@AbnormalBetType   TINYINT		= NULL --NULL: Uncheck AbnormalBet UI, 0: single, 1: main parlay
	,@FilterUserName	VARCHAR(30) = NULL -- input username
	,@Products			VARCHAR(50)	= NULL
	,@StatusIds			VARCHAR(50) = NULL
	,@FromDate			DATETIME	= NULL	
	,@ToDate			DATETIME	= NULL

AS 
	/* Created by: Jamie  
	 Task:  VOID BY BET ID (Running & Settled tickets)  
	 DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
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
	  - 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
	  - 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
	  - 20220615@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
	  - 20220712@Kathy: Do not using SELECT INTO [Redmine:#175349]
	  - 20220812@Max: MPO - [TVS] wrong data insert into CustLimitBetQueue when transid list include both single and parlay ticket [Redmine: #176578]
	  - 20220818@July: Change of Void By Bet ID regarding to Scale out DBTrans [Redmine: #176811]
	  - 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
	  - 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
	  - 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
	  - 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
	  - 20230522@July: Support sport Cricket for all functions  [Redmine: #188374]
	  - 20230705@July: [SD] Enhance void log to detect more information [Redmine: #190590]
	  - 20230717@July: [SD] Integrate Virtual Sports 3 (Leap Gaming) [Redmine: #189556]
	  - 20230822@July: [TVS] Instant Settlement of Basketball [Redmine: #185492]
	  - 20231211@July: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
	  - 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
	  - 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
	  - 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
	  - 20240826@July: [TVS] Void By Bet ID - Support void abnormal bet for main parlay ticket [Redmine: #209348]
	  - 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]
	  - 20241028@Max: [TVS] Virtual Sports 6 (Betby) - Virtual Betby Basketball [Redmine: #212502]
	  - 20241211@Louisa: Enhance Winlimit - add matchid/transid for BalancePendingCreditGame [Redmine:#215066]
	  - 20250117@July: Enhance gap time between voiding by function and TVS [Redmine: #216667]
	  - 20250401@Neil: [TVS] Upgrade ExchangeID data type [Redmine:#222191]

	 Param's Explanation:   
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
			,@SB_Error			BIT

	SET @StartTime = GETDATE()
	SET @LogActionId = 90513
	SET @SB_Error = 0

	SET @LogData = CASE WHEN @UserId IS NULL THEN '' ELSE '@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
					+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
					+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
					+ CASE WHEN @Password IS NULL THEN '' ELSE ',@Password = ''' + CONVERT(NVARCHAR(50), @Password) + '''' END
					+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
					+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
					+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END
					+ ',@AbnormalBetType = ' + CASE WHEN @AbnormalBetType IS NULL THEN 'NULL' ELSE CONVERT(NVARCHAR(50), @AbnormalBetType) END
					+ CASE WHEN @FilterUserName IS NULL THEN '' ELSE '@FilterUserName = ''' + CONVERT(NVARCHAR(50), @FilterUserName) + '''' END
					+ CASE WHEN @Products IS NULL THEN '' ELSE '@Products = ''' + CONVERT(NVARCHAR(50), @Products) + '''' END
					+ CASE WHEN @StatusIds IS NULL THEN '' ELSE '@StatusIds = ''' + CONVERT(NVARCHAR(50), @StatusIds) + '''' END
					+ CASE WHEN @FromDate IS NULL THEN '' ELSE '@FromDate = ''' + CONVERT(NVARCHAR(50), @FromDate) + ''''  END
					+ CASE WHEN @ToDate IS NULL THEN '' ELSE '@ToDate = ''' + CONVERT(NVARCHAR(50), @ToDate) + ''''  END

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidBetIdList_Upd ' + @LogData

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE	 @isITAdmin					BIT = 0
			,@isExistMatch				BIT = 0
			,@isExistFM					BIT = 0
			,@isExistParlay				BIT = 0
			,@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistOutright			BIT = 0
			,@isExistNG					BIT = 0
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
			,@IsExistVS3 				BIT = 0
			,@IsExistVS4 				BIT = 0
			,@IsExistParlayVS 			BIT = 0
			,@IsExistBB					BIT = 0
			,@isExistFM2				BIT = 0
			,@query						NVARCHAR(MAX) = ''
			,@ExecuteSQL				NVARCHAR(MAX) = ''
			,@Movebetdate				DATETIME
			,@isExistMatch3rd			BIT = 0
			,@strTransCashout			VARCHAR(MAX) = ''
			,@xmlCashoutTicket			XML
			,@TransInfo					VARBINARY(MAX)
			,@SiteDBGroupID				SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL

	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))							
			,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
			,@totalMainParlay		INT = 0

	DECLARE @ErrCode 		INT = 0 
		   ,@ErrMsg		    NVARCHAR(200) = '' 
	
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange
		
	--get balance game for livecs
	CREATE TABLE #balanceGameBefore (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT, TransId BIGINT)
	CREATE TABLE #balanceGameAfter (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT, TransId BIGINT)
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	
	
	CREATE TABLE #SpecialDeleteBets (
		GroupTransId	BIGINT
		,transid		BIGINT PRIMARY KEY --bettrans.transid
		,matchid		INT
		,Bettype		SMALLINT
		,betid			BIGINT
		,stake			MONEY
		,odds			SMALLMONEY
		,oddsspread 	MONEY
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
		,currency		SMALLINT
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
		,LeagueGroupID  SMALLINT
		,zzzWinlost		MONEY
		,VendorMatchId	VARCHAR(50)
	)

	CREATE TABLE #CTE_CustInfo(custid INT, username VARCHAR(30), username2 VARCHAR(50), site VARCHAR(10))

	CREATE TABLE #tblMatch (matchid INT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT, betid BIGINT)	

	DECLARE @tmpMatch_Eventdate TABLE (MatchId INT, Eventdate DATETIME)
	DECLARE @CashoutTickets_tmp AS TABLE (TransID BIGINT,custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, bonusId INT, WalletType TINYINT, status VARCHAR(20))
	DECLARE @tmpTrans_beforeUpd AS TABLE (transid BIGINT,custid INT, Balance MONEY, Bonusid INT, WalletType TINYINT, betdaqid BIGINT)

	IF NOT EXISTS (SELECT 1 FROM CustDB.dbo.Customer WITH(NOLOCK) WHERE userpwd = @password AND custid = @userId AND roleid >=5)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!'  
		
		SELECT @ErrCode AS ErrorCode
		      ,@ErrMsg AS ErrorMsg
		      ,@SiteDBGroupID AS SiteDBGroupID

		RETURN
	END

	INSERT INTO #tblTransIds (transid)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds,',')
	WHERE value <> ''

	/* Products & bettype
	-- SB/NG/LC/BT
	-- Parlay vs Outright ticket 
	-- 
	*/
	INSERT INTO #SpecialDeleteBets(
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
		,modds
		,WalletType
		,RefCode
		,BonusID
		,actual_stake
		,ruben
		,zzzWinlost
	)
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
		,CASE WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1 ELSE 0 END AS IsHideComm
		,b.winlostdate
		,b.oddsid
		,b.ExtraInfo
		,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
		,b.awinlost
		,NULL AS SiteId
		,b.CurrencyName
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,b.actual_stake
		,b.ruben
		,b.winlost
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransIds t ON b.transid = t.transid
	WHERE b.bettype < 19001
		AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND b.bettype NOT BETWEEN 1501 AND 1599	-- NOT IN Keno
		AND b.statusID NOT IN (101, 102)	
		AND b.SiteDBGroupID = @SiteDBGroupID

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #SpecialDeleteBets WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
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
			,ParentID	= CASE WHEN m.sporttype IN (50,8) THEN ISNULL(m.ParentID,0) ELSE 0 END
			,ChildMatchType = CASE WHEN m.sporttype IN (50,8) THEN ISNULL(m.ChildMatchType, 0) ELSE 0 END
			,LeagueGroupID = l.LeagueGroupID
		FROM	#SpecialDeleteBets b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
		WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #SpecialDeleteBets WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (2))))
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
			,LeagueGroupID = l.LeagueGroupID
		FROM	#SpecialDeleteBets b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
		WHERE bettype IN (10)
	END
	
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #SpecialDeleteBets WHERE bettype IN (1231,1232,1233,1237,1238,2770,2771)))
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
			,VendorMatchId = CASE WHEN b.bettype IN (2770,2771) THEN r.VendorMatchId ELSE NULL END
		FROM	#SpecialDeleteBets b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238,2770,2771)
	END
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE d
		SET sporttype = sb.SportType
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END
	-- UPDATE Sportype, Endtime for Bitcoin 
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets 
					WHERE bettype BETWEEN 7901 AND 7999 
							OR bettype BETWEEN 11050 AND 11099
							OR bettype BETWEEN 13000 AND 13011))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
			,eventdate  = m.EventDate
			,EndTime    = m.EndTime
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
	END
	
	-- remove un-supported sports & bettype
	DELETE bd
	FROM #SpecialDeleteBets bd
	WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	IF EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE Bettype BETWEEN 1101 AND 1199 AND StatusID BETWEEN 0 AND 1)  
	BEGIN  
		DELETE 
		FROM	#SpecialDeleteBets 
		WHERE	Bettype BETWEEN 1101 AND 1199 AND StatusID BETWEEN 0 AND 1 -- Not allowed to settle the running Live CS bet   
	END  
	
	/*Modify the way to get move bet date*/
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE #SpecialDeleteBets
		SET eventdate = winlostdate
		WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))	
	END

	INSERT INTO @tmpMatch_Eventdate (MatchId, Eventdate)
	SELECT DISTINCT MatchId, eventdate
	FROM #SpecialDeleteBets

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatch_Eventdate WHERE eventdate <= @Movebetdate)
	BEGIN
		IF @FilterUserName IS NULL -- By Bet ID
		BEGIN
			SELECT @ErrCode= 102, @ErrMsg = 'Could not void some tickets due to Movebet process. Please try Search again.'
		END
		ELSE -- By Username
		BEGIN
			SELECT @ErrCode = 102, @ErrMsg = 'Could not void some tickets due to Movebet process. Please try a new Date range and Search again.'
		END

		SELECT @ErrCode AS ErrorCode
		      ,@ErrMsg AS ErrorMsg
		      ,@SiteDBGroupID AS SiteDBGroupID

		RETURN	
	END

	-- gather match Ids
	INSERT INTO #tblMatch (matchid)
	SELECT	matchid
	FROM	#SpecialDeleteBets
	GROUP BY matchid
	
	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets)
	BEGIN
 		SELECT	@ErrCode = 99, @ErrMsg = 'No ticket found.' 
		
		SELECT @ErrCode AS ErrorCode
		      ,@ErrMsg AS ErrorMsg
		      ,@SiteDBGroupID AS SiteDBGroupID

		RETURN
	END
	
	SELECT   @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 OR sporttype IN (177) THEN 1 ELSE 0 END)
			,@IsExistVS3				= MAX (CASE WHEN bettype BETWEEN 5302 AND 5399 THEN 1 ELSE 0 END)
			,@IsExistVS4				= MAX (CASE WHEN sporttype = 188 THEN 1 ELSE 0 END)
			,@IsExistParlayVS			= MAX (CASE WHEN fs.SpecialBettypes IS NOT NULL THEN 1 ELSE 0 END)
			,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
			,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
			,@isExistMatch3rd			= MAX (CASE WHEN Bettype BETWEEN 7901 AND 7999 OR b.sporttype IN (147,134) THEN 1 ELSE 0 END)
	FROM	#SpecialDeleteBets b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
		OUTER APPLY (
				SELECT bettype AS SpecialBettypes
				FROM f_TVS_SpeciallyBettypes() f
				WHERE f.TypeId = 1 
					AND f.Bettype <> 2799
					AND f.Bettype = b.Bettype
		)fs
	
	--- CHECKING SETTLEMENT PROCESS IN PROGRESS OR NOT ?????  
	DECLARE @avaiableProcess BIT
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		, CASE 
			WHEN Bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes()) 
					AND f.GroupId IS NULL
					AND Bettype NOT IN (1231,1232,1233,2770,2771)
					AND Bettype NOT BETWEEN 7901 AND 7999
					AND sporttype NOT IN (147,134)
				THEN 1 --SB,NG,LC
			WHEN Bettype = 10 THEN 2	-- Outright
			WHEN f.GroupId = 1 THEN 6 -- FM
			WHEN Bettype IN (1231,1232,1233,2770,2771) THEN 4 -- VS Racing
			WHEN Bettype = 38 THEN 5 -- Bet Builder
			WHEN f.GroupId = 2 THEN 7 -- FM 228
			WHEN (Bettype BETWEEN 7901 AND 7999 OR b.sporttype IN (147,134)) THEN 8 --Bitcoin, VS5
			ELSE 0
		END AS KeyID
	FROM #SpecialDeleteBets b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f

	-- Apply new way to lock parlay tickets
	INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
	SELECT matchid, refno
	FROM #SpecialDeleteBets
	WHERE Bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1) AND bettype <> 2799) --NOT 2799: Virtual Sport

	SET @totalMainParlay = @@ROWCOUNT

	EXEC dbo.NAP_Set_GlobalSettingSel 
		 @LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT
	
	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
	BEGIN	
		IF @isExistOutright = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
			OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1 OR @isExistMatch3rd = 1
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright 			= @isExistOutright
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
				SELECT @ErrCode AS ErrorCode
		              ,@ErrMsg AS ErrorMsg
		              ,@SiteDBGroupID AS SiteDBGroupID

				RETURN
			END
		END
		
		IF @totalMainParlay > 0 
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno		= @isExistParlay
				,@IsLockingByRefnoVS	= @IsExistParlayVS
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
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @isExistMatch3rd			= @isExistMatch3rd
					, @IsLockingByRefnoVS		= @IsExistParlayVS
					, @IsReleased				= 1
					
				SELECT @ErrCode AS ErrorCode
		              ,@ErrMsg AS ErrorMsg
		              ,@SiteDBGroupID AS SiteDBGroupID
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
			, @isExistFM				= @isExistFM
			, @isExistMatch				= @isExistMatch
			, @isExistNG				= @isExistNG
			, @isExistVS				= @isExistVS
			, @isExistBB				= @isExistBB
			, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
			, @isExistFM2				= @isExistFM2
		    , @isExistMatch3rd			= @isExistMatch3rd
			, @IsLockingByRefnoVS		= @IsExistParlayVS
			, @spName					= @spName
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN
			SELECT @ErrCode AS ErrorCode
				  ,@ErrMsg AS ErrorMsg
				  ,@SiteDBGroupID AS SiteDBGroupID

			RETURN
		END
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
		,RepUpdateTime
		,SiteDBGroupID
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
		,SYSDATETIME()
		,main.SiteDBGroupID
	FROM dbo.bettrans AS main WITH (NOLOCK)
		INNER JOIN #tblMatch tm 
		ON main.matchid = tm.matchid
		INNER JOIN #SpecialDeleteBets AS tmpmain 
		ON	main.transid = tmpmain.transid 
		AND main.matchid = tmpmain.matchid		
	WHERE main.SiteDBGroupID = @SiteDBGroupID
		AND main.statusID NOT IN (101,102,103)

	--Get data before update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistMatch3rd = 1 OR @IsExistVS3 = 1 
			OR @IsExistVS4 = 1 OR @IsExistParlayVS = 1)
	BEGIN
		INSERT INTO #balanceGameBefore(custid, winlostdate, balance, winlost, gametypeid, groupid, TransId)
		SELECT b.custid, b.winlostdate
			, (b.winlost - b.actual_stake)
			, (CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 7901 AND 7999 THEN 7901
				ELSE 1201
			END AS groupId
			, b.TransId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE (tmp.Bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 7901 AND 7999
			OR b.bettype BETWEEN 1201 AND 1299 --VS
			OR b.bettype BETWEEN 2700 AND 2899 --VS2 (Betradar)
			OR b.bettype BETWEEN 5302 AND 5399 --VS3 (Leap Gaming)
			OR b.bettype BETWEEN 10400 AND 10449 --VS4 (Edge Gaming)
			OR b.bettype BETWEEN 11050 AND 11099 --VS5
			OR b.bettype BETWEEN 13000 AND 13011 --VS6
			) AND b.SiteDBGroupID = @SiteDBGroupID
			AND b.statusID NOT IN (101,102,103)
	END

	--Insert tmp table for correct balance CO
	INSERT INTO @tmpTrans_beforeUpd (transid, custid, Balance, Bonusid, WalletType, betdaqid)
	SELECT transid,custid, winlost - actual_stake + playercomm as balance
		,BonusID = CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		,WalletType = ISNULL(WalletType, 2) -- Cash Wallet as default
		,main.betdaqid
	FROM dbo.bettrans main WITH (NOLOCK)
	WHERE main.SiteDBGroupID = @SiteDBGroupID 
		AND transid IN (SELECT transid FROM #SpecialDeleteBets)
		AND main.statusID NOT IN (101,102,103)

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
				WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154)  OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
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
			 , main.Balance AS winlost, 0 AS actual_stake , 0 AS playercomm --because balance aleady sum into @tmpTrans_beforeUpd
			 , tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM @tmpTrans_beforeUpd main 
			INNER JOIN #SpecialDeleteBets tmpmain
				ON	main.transid = tmpmain.transid
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
	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, BetId BIGINT, Actual_stake MONEY, betdaqid BIGINT, Sporttype SMALLINT)
	DECLARE @TransIds_tmp VARCHAR(MAX) = ''
		, @IssueTypeId INT = 0
		,@IsAbnormalMixParlay BIT = 0

	SET @IssueTypeId = CASE WHEN @AbnormalBetType IN (0,1) THEN 11 ELSE 0 END
	SET @IsAbnormalMixParlay = CASE WHEN @AbnormalBetType = 1 THEN 1 ELSE 0 END

	-- STEP 2 : Update bettrans
	-- 2.1. Update bettrans	for normal ticket
	WHILE (1=1)
	BEGIN
		DELETE @tmpTransIDBatch

		SET @TransIds_tmp = ''
		SET @strTransCashout = ''
		SET @xmlCashoutTicket = ''
		DELETE @CashoutTickets_tmp

		UPDATE TOP(2000) t
			SET IsFinish = 1
		OUTPUT  DELETED.transid
			   ,DELETED.BetID
			   ,DELETED.actual_stake
			   ,tmp.betdaqid
			   ,DELETED.sporttype
		INTO @tmpTransIDBatch (TransId, BetId, Actual_stake, betdaqid, Sporttype)
		FROM #SpecialDeleteBets t
			INNER JOIN #tblMatch tm ON t.matchid = tm.matchid
			INNER JOIN @tmpTrans_beforeUpd tmp ON tmp.transid = t.transid
		WHERE t.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK
		SELECT @TransIds_tmp = CAST((SELECT     m.TransId AS '@transid'
											   ,m.BetId AS '@betid'
											   ,m.betdaqid AS '@betdaqid'
											   ,m.Sporttype AS '@sport'
									FROM @tmpTransIDBatch m
									FOR XML PATH('r')
										,ROOT('root')
								) AS VARCHAR(MAX));

		EXEC dbo.TicketVoiding_Admin_VoidingTransId
			@TransIds = @TransIds_tmp,
			@UserId = @UserId,
			@IssueTypeId = @IssueTypeId,
			@IsAbnormalMixParlay = @IsAbnormalMixParlay,
			@strTransCashout = @strTransCashout OUTPUT

		-- Adjust BL before for affected cashout tickets
		IF @strTransCashout <> ''
		BEGIN
			SET @xmlCashoutTicket = CONVERT(XML, @strTransCashout)
					
			INSERT INTO @CashoutTickets_tmp(transid, custid, winlost, actual_stake, playercomm, bonusId, WalletType, status)
			SELECT T.C.value('./@t', 'BIGINT') 		AS transid
					,T.C.value('./@c', 'INT') 		AS custid
					,T.C.value('./@wl', 'MONEY') 	AS winlost
					,T.C.value('./@al', 'MONEY') 	AS actual_stake
					,T.C.value('./@pl', 'MONEY') 	AS playercomm
					,T.C.value('./@bn', 'INT') 		AS bonusid
					,T.C.value('./@w', 'TINYINT') 	AS WalletType
					,T.C.value('./@st', 'VARCHAR(20)') 	AS status
			FROM @xmlCashoutTicket.nodes('/b') AS T(C)
			OPTION (OPTIMIZE FOR (@xmlCashoutTicket = NULL ))
					
			UPDATE bf
				SET balance = bf.balance - bl.balance_old + bl.balance_new
			FROM @BeforeUpd bf
				INNER JOIN  (
							SELECT	c.custid,c.BonusID,c.WalletType, SUM(c.balance) AS balance_old, SUM(tmp.winlost- tmp.actual_stake + tmp.playercomm) AS balance_new
							FROM  @CashoutTickets_tmp tmp 
									INNER JOIN @tmpTrans_beforeUpd C ON c.TransID = tmp.transid AND tmp.custid = c.custid
							GROUP BY c.custid,c.BonusID,c.WalletType							
						) AS bl ON bl.custid = bf.custid AND bf.bonusId =  bl.BonusID AND bf.walletType = bl.WalletType

			--Correct data captured before because CO happen when voiding ticket
			UPDATE b
			SET b.status = t.status
				, b.WinLost = t.winlost - t.actual_stake
				, b.actual_stake = t.actual_stake
				, b.betdaqid = -2
				, b.IsCashOut = 1
			FROM #SpecialDeleteBets b 
				INNER JOIN @CashoutTickets_tmp t ON t.transid = b.transid
			WHERE b.IsCashOut = 0 

			DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY)
			DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
			DECLARE @matchid INT
			
			UPDATE z
			SET z.status = t.status
				, z.winlost = t.winlost
			OUTPUT deleted.matchid, deleted.transid, t.status, t.winlost
			INTO @tmpTransInfo (matchid, transid, STATUS, winlost)
			FROM zzzbettrans z WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @CashoutTickets_tmp t ON t.transid = z.transid
			WHERE z.status <> t.status

			IF @SiteDBGroupID <> 0 AND EXISTS ( SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				INSERT INTO @tmpMatchidInfo (MatchId)
				SELECT DISTINCT MatchId FROM @tmpTransInfo

				WHILE (1=1)
				BEGIN
					UPDATE TOP(1)m
					SET IsFinish = 1, @matchid = MatchId 
					FROM @tmpMatchidInfo m
					WHERE IsFinish IS NULL

					IF @@ROWCOUNT = 0 BREAK;
					SET @transInfo = COMPRESS((
					SELECT	transId AS 't'
							, matchid AS 'mid'
							, STATUS AS 's'
							, winlost AS 'w'
					FROM	@tmpTransInfo WHERE matchid = @MatchId 
					FOR JSON PATH))

					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
					SELECT 'TVS', 'Void', 'zzzbettrans', 'U', @matchid, @transInfo, 's'
				END
			END
		END

	END	

	-- Update CashOutSelling [#165097]
	UPDATE c
	SET CashOutStatus = 6 --Void
	   ,ChangeDate = GETDATE()
	FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #SpecialDeleteBets b ON c.TransID = b.transid AND c.MatchID = b.matchid
	WHERE b.betdaqid = -2 

	--Get data after update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistMatch3rd = 1 OR @IsExistVS3 = 1 
			OR @IsExistVS4 = 1 OR @IsExistParlayVS = 1)
	BEGIN
		INSERT INTO #balanceGameAfter(custid, winlostdate, balance, winlost, gametypeid, groupid, TransId)
		SELECT b.custid, b.winlostdate
			, (b.winlost - b.actual_stake)
			, (CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 7901 AND 7999 THEN 7901
				ELSE 1201
			END
			, b.TransId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE (tmp.Bettype BETWEEN 1101 AND 1199
			OR tmp.bettype BETWEEN 81 AND 120 OR tmp.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 7901 AND 7999
			OR b.Bettype BETWEEN 1201 AND 1299 --VS
			OR b.bettype BETWEEN 2700 AND 2899 --VS2 (Betradar)
			OR b.bettype BETWEEN 5302 AND 5399 --VS3 (Leap Gaming)
			OR b.bettype BETWEEN 10400 AND 10449 --VS4 (Edge Gaming)
			OR b.bettype BETWEEN 11050 AND 11099 --VS5
			OR b.bettype BETWEEN 13000 AND 13011 --VS6
			) AND b.SiteDBGroupID = @SiteDBGroupID
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
			INNER JOIN #SpecialDeleteBets tmpmain
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
	
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistMatch3rd = 1 OR @IsExistVS3 = 1 
			OR @IsExistVS4 = 1 OR @IsExistParlayVS = 1)
	BEGIN
		
		CREATE TABLE #balanceGameChange (
			custid 			INT
			,winlostdate 	SMALLDATETIME
			,balance 		MONEY
			,bettype		SMALLINT
			,gametypeid		SMALLINT			
			,Increased 		BIT
			,TransId		BIGINT
		)

		INSERT INTO #balanceGameChange (custid, winlostdate, balance, bettype, gametypeid, Increased, TransId)
		SELECT	b.custid
				,b.winlostdate
				,a.winlost - b.winlost
				,a.groupid
				,a.gametypeid
				,CASE WHEN a.winlost > b.winlost THEN 1 ELSE 0 END
				,a.TransId
		FROM	#balanceGameBefore b
			INNER JOIN #balanceGameAfter a 
				ON b.TransId = a.TransId
		WHERE	b.winlost <> a.winlost
		
		INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
				,RefID
		)
		SELECT	custid
				,winlostdate
				,ABS(balance)
				,bettype
				,gametypeid
				, TransId
		FROM	#balanceGameChange
		WHERE	Increased = 0

		INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
				,RefID
		)
		SELECT	custid
				,winlostdate
				,balance
				,bettype
				,gametypeid
				,TransId
		FROM	#balanceGameChange
		WHERE	Increased = 1
		
		DROP TABLE #balanceGameChange
	END  
	
	------ releasing SD process
	--CleanUP:
	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
	BEGIN
		IF @isExistOutright = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
			OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1 OR @isExistMatch3rd = 1
		BEGIN
			------ releasing single process
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright 			= @isExistOutright
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
				@IsLockingByRefno = @isExistParlay
				,@IsLockingByRefnoVS		= @IsExistParlayVS
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
			, @isExistFM				= @isExistFM
			, @isExistMatch				= @isExistMatch
			, @isExistNG				= @isExistNG
			, @isExistVS				= @isExistVS
			, @isExistBB				= @isExistBB
			, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
			, @isExistFM2				= @isExistFM2
		    , @isExistMatch3rd			= @isExistMatch3rd
			, @IsLockingByRefnoVS		= @IsExistParlayVS
			, @IsReleased				= 1
	END
		
	----------------Insert Max Payout Queue----------------
	DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL, @sporttype SMALLINT = NULL, @ParentID INT= NULL, @ChildMatchType TINYINT = NULL
	DECLARE @Match_tmp AS TABLE (matchId INT, sporttype SMALLINT, ParentID INT, ChildMatchType TINYINT, IsFinish BIT)

	INSERT INTO @Match_tmp (MatchId, sporttype, ParentID, ChildMatchType)
	SELECT DISTINCT t.matchid, t.sporttype, t.ParentID, t.ChildMatchType
	FROM #SpecialDeleteBets t
	WHERE t.Bettype <> 29

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
						WHEN s.SiteLabel = '789y' THEN 2 --789y
						ELSE 1 END AS '@sitetype'
					,b.TransId AS '@transid'
					,b.bettype AS '@bettype'
				FROM #SpecialDeleteBets b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
				WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype 
					AND b.Bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
				FOR XML PATH('r'), ROOT('root')
			)

		SET @MatchId_MaxPO = CASE WHEN @sporttype IN (50,8) AND @ParentID <> 0 AND @ChildMatchType = 200 THEN @ParentID ELSE @MatchId_MaxPO END

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO
	END

	IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype = 29)
	BEGIN
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
									,t.ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #SpecialDeleteBets t
								WHERE t.Bettype = 29
								GROUP BY custid, ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
	END

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
		FROM #SpecialDeleteBets b
		CROSS APPLY (
			VALUES (custid)
			,(creator)
			,(recommend)
			,(mrecommend)
			,(srecommend)
		) AS t (custid)
	)
	INSERT INTO #CTE_CustInfo(custid, username, username2, site)
	SELECT ci.custid
		, ci.username
		, ci.username2
		, ci.site
	FROM CustDB.dbo.Customer ci WITH(NOLOCK)
		INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid			
	
	BEGIN -- Instant Settlement declaration
			
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT)
		CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

		INSERT INTO #CTE_match (matchid, sporttype)
		SELECT DISTINCT t.matchid, m.sporttype
		FROM #SpecialDeleteBets t
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
			
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 1) --Soccer	 
		BEGIN 
			INSERT INTO #CTE_isCal (matchid, IsHTCal)
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM #CTE_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
			WHERE m.sporttype = 1

			--> Build bettype list supported for instant settlement based on settlement status of match
			INSERT INTO #InstantSettlementBettypes (matchid, bettype)
			SELECT c.matchid,  f.bettype
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype
						FROM dbo.f_TVS_GetInstantBettypes() 
						WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
									   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
									ELSE 0 END
				)f	 	
		END
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 2) --Basketball
		BEGIN
			INSERT INTO #CTE_isCal (matchid, ResourceId)
			SELECT m.matchid, rd.ResourceId
			FROM #CTE_match m
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
					ON rd.matchid = m.matchid 
					AND ResultStatusID IN (2,5) AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 
			WHERE m.sporttype = 2

			INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
			SELECT DISTINCT c.matchid, f.bettype, f.betid
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype, betid
						FROM dbo.f_TVS_GetInstantBettypes()
						WHERE InstantType IS NULL
						AND 1 = CASE WHEN c.ResourceId IS NULL THEN 1 --NOT executed on this match.
									 WHEN c.ResourceId IS NOT NULL AND ResourceId NOT IN (SELECT ResourceId FROM #CTE_isCal) THEN 1
									 ELSE 0 END
				)f	 	
		END
			
		DROP TABLE #CTE_match
		DROP TABLE #CTE_isCal
	END	

	------------------------------------------------------------------------------
	--1. Table return error code/ msg
	SELECT @ErrCode AS ErrorCode
		  ,@ErrMsg AS ErrorMsg
		  ,@SiteDBGroupID AS SiteDBGroupID

	--2. Table get tickets
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
		,ci.site 
		,CASE 
			WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
			ELSE ci.site 
		END AS EmailGroup
		,@isITAdmin		AS IsITSupport
		,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
		,b.matchid 
		,b.oddsid AS OddsId
		,CASE 
			WHEN ISNULL(m.eventstatus, '') <> @eventstatus_completed AND b.statusid IN (111, 112, 113) AND ISNULL(b.betdaqid,0) <> -2
					THEN CASE WHEN m.sporttype = 1
									AND EXISTS (SELECT TOP 1 1
												FROM #InstantSettlementBettypes
												WHERE bettype = b.bettype)
									THEN 1
							  WHEN m.sporttype = 2
									AND EXISTS (SELECT TOP 1 1
												FROM #InstantSettlementBettypes
												WHERE bettype = b.bettype AND (betid = b.betid OR b.betid IS NULL))
									THEN 1
							ELSE 0 END
			ELSE 0
		END AS IsInstantSettlementTicket
		,CASE WHEN vip.CustID IS NOT NULL THEN 1 ELSE 0 END AS IsVipMember
		,b.EndTime --Support bitcoin
		,CASE WHEN b.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN m.ParentID ELSE b.matchid END AS ParentMatchId -- send letstalk
		,b.LeagueGroupID
		,ISNULL(si.IsChinaView,0) AS IsChinaView
		,ISNULL(si.SpecialPlatfrom,0) AS SpecialPlatform --2: JollyView
		,b.winlostdate
		,@SiteDBGroupID AS SiteDBGroupID
		,b.zzzWinlost
		,VendorMatchId
	FROM	#SpecialDeleteBets b
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
		LEFT JOIN #CTE_CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
		LEFT JOIN #CTE_CustInfo cr WITH(NOLOCK) ON b.creator = cr.custid	
		LEFT JOIN #CTE_CustInfo ag WITH(NOLOCK) ON b.recommend = ag.custid
		LEFT JOIN #CTE_CustInfo ma WITH(NOLOCK) ON b.mrecommend = ma.custid
		LEFT JOIN #CTE_CustInfo su WITH(NOLOCK) ON b.srecommend = su.custid
		LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) ON b.srecommend = s.custid
		LEFT JOIN @VIPAccount_tmp vip ON b.custid = vip.CustID			
		LEFT JOIN CustDB.dbo.Site si WITH(NOLOCK) ON su.site = si.site
	ORDER BY ISNULL(b.MainTransId, b.transid)
		   , CASE 
				WHEN b.BonusID IS NOT NULL
						THEN CASE 
								WHEN b.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE b.transid
			 END	 	
		
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

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.'
								+ @LogData
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tblMatchProcess
	DROP TABLE #balanceGameBefore
	DROP TABLE #balanceGameAfter
	DROP TABLE #tblTransIds
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblMatch
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #CTE_CustInfo

	RETURN
END
GO
