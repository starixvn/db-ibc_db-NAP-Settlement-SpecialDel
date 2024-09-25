/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidSingleBet_Update]
(
	@MatchId				INT,	
	@Bet					VARCHAR(10)		= NULL,
	@TimeType	 			SMALLINT 		= 0,
	@FromTransdate			DATETIME 		= NULL,
	@ToTransdate			DATETIME 		= NULL,
	@LiveIndicator 			SMALLINT 		= 0,
    @LiveHomeScore 			SMALLINT 		= NULL,
    @LiveAwayScore 			SMALLINT 		= NULL,		
    @BetTypes				XML				= NULL,
	@OddsFilter				XML				= NULL,
    @UserName 				NVARCHAR(50),
    @UserPassword			NVARCHAR(50),
    @UserID					INT,
    @IP						VARCHAR(15)		= '',
    @Reason					NVARCHAR(500)	= '',
	@ReasonSC				NVARCHAR(500)	= '',
	@SecondAcceptFlag		TINYINT			= 0 ,
	@TransIds				VARCHAR(MAX)	= '',
	@IsCheckTime			BIT				= 1,
	@SelectionSubParlays	VARCHAR(200)    = ''
)
AS
	/*
	Created by: Kathy
	Task : Special Delete
	DB: DBTXN/bodb02
	Original:

	Revisions:
		- 20140102@Kathy: Add username2 column [Redmine:#10270]
		- 20140121@Elodie: Apply LAS system for special delete function [Redmine:#10701]
		- 20140411@Kathy: - Separate tickets of Bet Fair, OneExchange 3rd parties [Redmine:#10128]
						  - Add 2 new bettypes 1H Total Goal and 1H First Goal/ Last Goal (126, 127) [Redmine:#14749]
		- 20140701@Kathy: Apply BetRadar - change @BetTypes to varchar(1000) [Redmine:#18219]
		- 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]		
		- 20140806@Kathy: Support new 11 bettypes [Redmine:#19955]
		- 20140929@Kathy: - Offer new bettypes from Sportting Solutions and new IBC bettypes [Redmine:#23129]
						  - Add moneyline in filter
		- 20141125@Kathy: Add betid column [Redmine:##26489]
		- 20141204@Kathy: Remove codes which are used in checking permission on DBPolicy [Redmine:#27058]	
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20150615@Dominic: BetTrade Integration 	[Redmine:#36964]			
		- 20150806@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20150917@Patrick: #43565: Show error-message in case user clicks void button but no tickets are found
		- 20151008@Kathy: insert bettrade tickets to send API [Redmine:#43233]
		- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]
		- 20151103@Kathy: Enhance performance [Redmine:#43233]
		- 20150712@Kathy: - Apply 28 Live Bettypes(PH) [Redmine: #48110]
						  - Database - Change datatype [Redmine: #48660]
		- 20150119@Kathy: Changes for phase 1.2 of PH All in One: bettype 4,30,413,414,405 [Redmine:#50932]	  
		- 20160112@Patrick: Support Cricket [Redmine: #50688]
		- 20160401@Bobby: #55354 - Update changes for new message structure
		- 20160426@Bobby: #56641 - Integrate Fast Market bettypes
		- 20160405@Kathy: Allow to void settled ticket [Redmine:#54344]
		- 20160706@Kathy: Get Refno for Lucky Single Ticket [Redmine:#55272]
		- 20160722@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
		- 20160810@Bobby: #62223 - Apply new business terms for VOID bet function
		- 20160909@Kent: Add logic for bettype 425, 426, 429 - PH AIO [Redmine:#62880]
		- 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
		- 20161101@Elodie: #56641 - Integrate Fast Market new bettypes
		- 20161221@Kathy: Release lock after voiding tickets [Redmine:#68960]
		- 20170220@Kent: Add logic of new bettypes in BAIO [Redmine:#71536]
		- 20170301@Kent: Return dummy tables for exceptional return cases [Redmine:#71536]
		- 20170309@Kent: Integrate Cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread and Remove DateTime column - Fast Markets Phase 2 [Redmine:#90667]
		- 201800516Alan: Allow void single and parlay tickets [Redmine:#93167]
		- 20180808@Alan: Allow to void Sub Parlay ticket while the status of main is 'Reject' [Redmine:#99528]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181002@Alan: Exclude BetTrade and Cash Out tickets when check negative balance [102212] 
		- 20181017@Alan: Write log new reason chinese simplified [102918]
		- 20181003@Alan: Add new column SettlementStatus [102423]
		- 20180821@Alan: Incorporate ESports 2.0 [99448]
		- 20181228@Alan: E-Sports Phase 2b - Support In-play status [106456]
		- 20190419@Kathy: Mark Ticket for Settlement Exclusion [Redmine:#108826]
		- 20190531@Raymond.Le: PH AIO 4 - change filter advanced mode for bettype 479, 481 [112884]
		- 20190718@Charles: Drop table #CTE_CustInfo [115870]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20190920@Helen: SP Tunning [120058]
		- 20190909@Kathy: Do not update statuswinlost when voiding ticket [Redmine:#115376]
		- 20191018@Charles: Support filter ticket by Checktime in Void Single Bet [121868]
		- 20191101@Charles: Remove column IsMarked [122187]
		- 20200508@Charles: PHAIO 5.1 for Penalty [132985]
		- 20200609@Charles: Remove notify when void tickets [131865]
		- 20200727@Zane: Basketball AIO Phase 2 - Change filter advanced mode [137189]
		- 20200911@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20200925@Charles: HotFix - advance mode can not search all for 226-227 (fast market)[142312]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20201211@Charles: TVS - Enhance letstalk notification for settled tickets [Redmine: #145103]
		- 20210303@July: Enhance data type advance mode [Redmine: #150075]
		- 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20210426@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20210514@July: SD - Remove unused code/products [Redmine: #121752]
		- 20210523@Max: NAP Special Delele - The match locked Temp Variable Number while CSD doing void [Redmine: #155648]
		- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
		- 20210622@Helen: [TVS] SP Tuning [Redmine: #157354]
		- 20210714@July: Saba Time Machine - Support multiple HDP/OU value search [Redmine: #157642]
		- 20210722@Max: [TVS HF] Exclude Cash-Out tickets from Void Time Calculation [Redmine: #158294]
		- 20210727@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210801@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
		- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220216@July: Fix check ISNULL betdaqid [Redmine: #167055]
		- 20220301@Max: [TVS] Integrate new bet types of Cricket [Redmine: #168080]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
		- 20220531@July: [TVS] Send data to Jacktime for Cashout Basketball [Redmine: #173389]
		- 20220615@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220705@Max: [TVS] Support multiple selection on Player filter of Cricket AIO [Redmine: #174652] 
		- 20220712@Kathy: Do not using SELECT INTO [Redmine:#175349]
		- 20220804@Max: TVS HotFix Filter Player Cricket [Redmine: #176290]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221005@Max: Special Delete - Void parlay ticket cause replication latency on DB052,DB053,DB061 [Redmine: #178736]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230526@Max: [TVS] Check invalid when inputting cricket's child matchID for all functions of Special Delete [Redmine: #188374]
		- 20230705@July: [SD] Enhance void log to detect more information [Redmine: #190590]
		- 20230810@July: [SD] Void Single Bet - Support searching ticket without using time range & Add Selection control for Sub Parlay [Redmine: #191448]
	    - 20230822@July: [TVS] Instant Settlement of Basketball [Redmine: #185492]
		- 20231006@Max: [TVS] Integrate Parlay Boost Bonus [Redmine: #192778]
		- 20231211@July: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20240129@July: Update the Advance Mode for bet types of Basketball [Redmine: #199605]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240312@July: Update the Advance Mode for bet types of Cricket [Redmine: #199238]
		- 20240321@Max: [TVS] Remove parameters when calling SP for settling parlay tickets [Redmine: #202022]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]

	Param's Explanation: Special bet delete option
		- @SecondAcceptFlag: 
		  + 0: All tickets
		  + 1: Normal tickets only
		  + 2: SA tickets only
     
		-@LiveIndicator:
		 + 0: Dead
		 + 1: Live
		 + 2: All

		 - @TimeType:
		 + 0: TransTime.
		 + 1: CheckTime.
		
		- @BetTypes : 
		'<BetTypes>
			<BetType Id="1" 
					 BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
					 Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
					 Game="01"				-- Default : "All" ; Format : 0X 
					 BetOption="4-4,5-5"	-- Default : "All" ; Format : hdp2-betteam,...					 
					 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ;
					 ValueHdp1				-- Default : "All" ; Format : 1,2,3,4,... ;	
					 ValueHdp2				-- Default : "All" ; Format : Single Number
					 Goal="2"				-- Default : "All" ; Format : Single Number
					 OddsSpread="1.5"		-- Default : "All" ; Format : 1.5,0.5,1.0,...
					 OddsId="8518"			-- Default : "All" ; Format : 8518,8519,...
					 Transdesc = '100001'	-- Default : "All" ; Format : 100001,100002,... (PlayerId - [Team].[TeamID])
					 VirtualHead ="1"		-- Default : "All" ; Format : Single Number
			/>
		 <BetTypes/>'
		 - @SelectionSubParlays: 
			+ IF @Bet: 'All' OR 'Single' => default : ''
			+ IF @Bet: 'SubParlay' => value : '2,3,4,5,6,7,8,9,10 UP'
	*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
			,@SB_Error			BIT

	SET @StartTime = GETDATE()
	SET @LogActionId = 90512
	SET @SB_Error = 0

	SET @LogData = CASE WHEN @MatchId IS NULL THEN '' ELSE '@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
					+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
					+ CASE WHEN @Bet IS NULL THEN '' ELSE ',@Bet = ''' + @Bet + '''' END
					+ CASE WHEN @TimeType IS NULL THEN '' ELSE ',@TimeType = ' + CONVERT(NVARCHAR(50), @TimeType) END
					+ CASE WHEN @FromTransdate IS NULL THEN '' ELSE ',@FromTransdate = ''' + CONVERT(NVARCHAR(50), @FromTransdate, 21) + '''' END
					+ CASE WHEN @ToTransdate IS NULL THEN '' ELSE ',@ToTransdate = ''' + CONVERT(NVARCHAR(50), @ToTransdate, 21) + '''' END
					+ CASE WHEN @LiveIndicator IS NULL THEN '' ELSE ',@LiveIndicator = ' + CONVERT(NVARCHAR(50), @LiveIndicator) END
					+ CASE WHEN @LiveHomeScore IS NULL THEN '' ELSE ',@LiveHomeScore = ' + CONVERT(NVARCHAR(50), @LiveHomeScore) END
					+ CASE WHEN @LiveAwayScore IS NULL THEN '' ELSE ',@LiveAwayScore = ' + CONVERT(NVARCHAR(50), @LiveAwayScore) END
					+ CASE WHEN @BetTypes IS NULL THEN '' ELSE ',@BetTypes = ''' + CONVERT(NVARCHAR(MAX), @BetTypes) + '''' END
					+ CASE WHEN @OddsFilter IS NULL THEN '' ELSE ',@OddsFilter = ''' + CONVERT(NVARCHAR(MAX), @OddsFilter) + '''' END
					+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
					+ CASE WHEN @UserPassword IS NULL THEN ''ELSE ',@UserPassword = ''' + CONVERT(NVARCHAR(50), @UserPassword) + '''' END
					+ CASE WHEN @UserID IS NULL THEN '' ELSE ',@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
					+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
					+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
					+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END
					+ CASE WHEN @SecondAcceptFlag IS NULL THEN '' ELSE ',@SecondAcceptFlag = ' + CONVERT(NVARCHAR(50), @SecondAcceptFlag) END
					+ CASE WHEN @IsCheckTime IS NULL THEN '' ELSE ',@IsCheckTime = ' + CONVERT(NVARCHAR(50), @IsCheckTime) END
					+ CASE WHEN @SelectionSubParlays IS NULL THEN '' ELSE ',@SelectionSubParlays = ''' + CONVERT(NVARCHAR(50), @SelectionSubParlays) + '''' END

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidSingleBet_Update ' + @LogData

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @isITAdmin			BIT = 0
			,@isExistParlay		BIT = 0
			,@isExistSingle		BIT = 0
			,@isExistFM			BIT = 0
			,@isExistFM2		BIT = 0
			,@avaiableProcess	BIT = 0
			,@ValueDefault		SMALLMONEY = 9999.00
			,@Movebetdate		DATETIME
			,@Eventdate			DATETIME
			,@FCUpdateTime		DATETIME2
			,@NegativeBalanceUsers	VARCHAR(MAX)	= ''	
			,@ErrMsg					NVARCHAR(200)	= ''
			,@ErrCode				INT				= 0	  
			,@SiteDBGroupID		SMALLINT
			,@transInfo			VARBINARY(MAX) 
			,@strSetting		VARCHAR(MAX)
			,@sqlOpenqueryCommand NVARCHAR(MAX) = ''


	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MainParlay_MaxPO	VARCHAR(MAX) = NULL
		,@MatchId_MaxPO INT
	
	DECLARE @session			NVARCHAR(50)
		   ,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalSubParlay		INT = 0

	DECLARE @CustIds			VARCHAR(MAX) = ''

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(500),
		Game			VARCHAR(500),
		BetOption		NVARCHAR(250),
		[Value]			VARCHAR(500),
		ValueHdp1		VARCHAR(500),
		ValueHdp2		VARCHAR(500),
		Goal			VARCHAR(10),
		OddsSpread		VARCHAR(500),
		OddsId			VARCHAR(1000),
		Transdesc		NVARCHAR(2000),
		VirtualHead		VARCHAR(500)
	)

	CREATE TABLE #tblBetType_Detail
	(
		Id				SMALLINT,
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(50),
		[Value]			SMALLMONEY,
		ValueHdp1		SMALLMONEY,
		ValueHdp2		SMALLMONEY,
		Goal			BIGINT,
		OddsSpread		MONEY,
		OddsId			INT,
		Transdesc		NVARCHAR(2000),
		VirtualHead		SMALLMONEY,
		Hdp1_tmp		SMALLMONEY
	)	
	
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #BeforeUpd (custid INT,balance MONEY)
	CREATE TABLE #AfterUpd(custid INT, balance MONEY)  
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT, betid BIGINT)	

	CREATE TABLE #SpecialDeleteBets (
		grouptransid		BIGINT,
		transid				BIGINT PRIMARY KEY, 
		custid				INT, 
		recommend			INT, 
		mrecommend			INT, 
		srecommend			INT, 
		betfrom				NVARCHAR(4),
		statusID			INT, 
		status				NVARCHAR(10), 
		username			VARCHAR(30),
		username2			VARCHAR(50),
		SecAcceptFlag		BIT, 
		creator				INT,
		hdp1 				SMALLMONEY,  
		hdp2 				SMALLMONEY,
		bettype 			SMALLINT,
		betteam 			NVARCHAR(10),
		betcheck			NVARCHAR(50),
		odds				SMALLMONEY, 
		oddsspread 			MONEY,
		OddsType			INT,
		transdate			DATETIME,
		checktime	        DATETIME,
		IsLiveIndicator		BIT,
		livehomescore 		SMALLINT, 
		liveawayscore 		SMALLINT,
		Stake				MONEY,
		CurrencyName		VARCHAR(10),
		betid				BIGINT,
		betdaqid			BIGINT,
		TransDesc			NVARCHAR(1000),
		refno				BIGINT,
		ExtraInfo			VARCHAR(1000),
		IsCashOut			BIT DEFAULT(0),
		awinlost			MONEY,
		matchid				INT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		BonusID				INT,		
		MainTransId			BIGINT,
		WinLost				MONEY,
		IsMixParlay			BIT DEFAULT (0),
		SubTransDesc		NVARCHAR(1000),
		SubTransId			BIGINT,
		SubStatus			NVARCHAR(10),
		SubBetCheck			NVARCHAR(50),
		SubBetTeam			NVARCHAR(10),
		SubBetType			SMALLINT DEFAULT (0),
		SubHdp1				SMALLMONEY,
		SubHdp2				SMALLMONEY,
		SubOdds				SMALLMONEY,
		FilterBettype		SMALLINT,
		FilterBetTeam		NVARCHAR(10), 
		FilterSet			VARCHAR(50),
		FilterGame			VARCHAR(50),
		FilterValue			SMALLMONEY,	
		FilterGoal			BIGINT,
		FilterBetOption		NVARCHAR(50),
		FilterHdp1		 	SMALLMONEY,
        FilterHdp2		 	SMALLMONEY,
		FilterOddsSpread	MONEY,
		FilterOddsId		INT,
		FilterTransdesc	    NVARCHAR(2000),
		FilterOdds			MONEY,
		ActualStake			MONEY,
		main_ruben			TINYINT,
		main_custId			INT,
		OddsId				INT,
		SiteDBGroupId		SMALLINT,
		SettlementStatus	TINYINT,
		eventstatus			NVARCHAR(50),
		SiteID				INT,
		modds				SMALLMONEY,
		mainoddsspread 		MONEY
	)

	CREATE TABLE #SpecialDeleteBetsm (
		CustId				INT,
		OddsSpread 			MONEY,
		TransDate			DATETIME,
		checktime			DATETIME,
		LiveIndicator		BIT,
		LiveHomeScore 		SMALLINT, 
		LiveAwayScore 		SMALLINT,
		Creator				INT,		
		Refno				BIGINT,
		SubTransDesc		NVARCHAR(1000),
		SubTransId			BIGINT,
		SubStatus			NVARCHAR(10),
		SubBetCheck			NVARCHAR(50),
		SubBetTeam			NVARCHAR(10),
		SubBetType			SMALLINT DEFAULT (0),
		SubHdp1				SMALLMONEY,
		SubHdp2				SMALLMONEY,
		SubOdds				MONEY,
		SubOddsSpread		MONEY,
		SubOddsId			INT,
		SiteDBGroupId		SMALLINT,
		matchid				INT,
		IsFinish			BIT
	)

	CREATE TABLE #CTE_CustInfo(custid INT, username VARCHAR(30), username2 VARCHAR(50), site VARCHAR(10), currency TINYINT)
	
	DECLARE @CountTransId	INT

	DECLARE @tmpTrans_beforeUpd AS TABLE (matchid INT, transid BIGINT, custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, status VARCHAR(20), Bonusid INT, WalletType TINYINT, betdaqid BIGINT)
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY)
	DECLARE @tmpSelectionSubParlay TABLE (Id VARCHAR(10))
	DECLARE @tmpBoostSite TABLE(SiteId INT, srecommend INT, IsDeposit BIT DEFAULT(0))
	DECLARE @tmpBoostSetting TABLE (SiteId INT, OverOdds DECIMAL(9,4), Boost TINYINT)

	
	DECLARE @Odds_str NVARCHAR(100)
		, @OddsType_Input VARCHAR(29)
	DECLARE @tmp_Odds AS TABLE (Odds SMALLMONEY, OddsType TINYINT)

	SELECT @Odds_str = REPLACE(t.c.value('@o','NVARCHAR(MAX)'), '&', ',')
			, @OddsType_Input = t.c.value('@ost','VARCHAR(20)')
	FROM @OddsFilter.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@OddsFilter = NULL))

	INSERT INTO @tmp_Odds (Odds, OddsType)
	SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, @OddsType_Input) f
	
	SET @session = CAST (NEWID() AS NVARCHAR(50))

	DECLARE @sporttype SMALLINT = NULL, @LeagueGroupID SMALLINT = NULL
	DECLARE @tmpMatchId TABLE (MatchId INT, matchdate DATETIME, IsFinish BIT)

	SELECT @Eventdate = m.eventdate 
		   ,@sporttype = m.sporttype
		   ,@MatchId_MaxPO = @MatchId
		   ,@LeagueGroupID = l.LeagueGroupID
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.league l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE m.matchid = @MatchId

	INSERT INTO @tmpMatchId (MatchId, matchdate)
	SELECT MatchId, eventdate
	FROM dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN sporttype NOT IN (50,8) AND matchid = @MatchId THEN 1
					WHEN sporttype IN (50,8) AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END

	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
	IF @Eventdate <= @Movebetdate
	BEGIN
		SELECT 99 AS ErrorCode
		     , 'Match is under Movebet process, could not void ticket.' AS ErrorMsg
			 , @NegativeBalanceUsers AS NegativeBalanceUsers
			 ,@SiteDBGroupID AS SiteDBGroupID

		RETURN	
	END	
			
	-- Check password	
	IF NOT EXISTS (SELECT 1
					FROM custDB.dbo.customer WITH(NOLOCK)
					WHERE userpwd = @UserPassword
						AND custid = @UserID
						AND roleid>=5)
	BEGIN
		SELECT 113 AS ErrorCode
			, 'Sorry. You can not process void bet due to either wrong password or insufficient permission!' AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers
		
		RETURN
	END	
			
	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@TransIds,',')	
		
		SET @CountTransId = @@ROWCOUNT	
		
	END TRY
	BEGIN CATCH
		SELECT	114 AS ErrorCode
				, 'Invalid TransIds.' AS ErrorMsg	
				, @NegativeBalanceUsers AS NegativeBalanceUsers
				,@SiteDBGroupID AS SiteDBGroupID
		
		RETURN
	END CATCH	

	-- Parse xml @BetTypes
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc, VirtualHead)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(500)') AS [Set]				-- check columns : betid		 ; single-choice + multi-choice
			, t.c.value('@Game','VARCHAR(500)') AS Game				-- check columns : betid		 ; single-choice + multi-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]			-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1			 ; single-choice + multi-choice
			, t.c.value('@ValueHdp2','VARCHAR(500)') AS ValueHdp2	-- check columns : hdp2			 ; single-choice + multi-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice + multi-choice
			, t.c.value('@OddsSpread','VARCHAR(500)') AS OddsSpread	-- Check columns : OddsSpread	 ; single-choice + multi-choice
			, t.c.value('@OddsId','VARCHAR(1000)') AS OddsId		-- check columns : OddsId		 ; single-choice + multi-choice
			, t.c.value('@Transdesc','NVARCHAR(2000)') AS Transdesc	-- check columns : Transdesc	 ; single-choice + multi-choice
			, t.c.value('@VirtualHead','NVARCHAR(500)') AS VirtualHead	-- check columns : hdp1 OR hdp2	 ; single-choice
	FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))
	
	INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc, VirtualHead)
	SELECT cte.Id
		 , CASE
				WHEN cte.Id = 30 AND cte.BetTeam = '4:0up' THEN '4:0' -- replace row [bettype 30 - betteam '4:0up'] by [bettype 30 - betteam '4:0'] 
				WHEN cte.Id = 30 AND cte.BetTeam = '0:4up' THEN '0:4' -- replace row [bettype 30 - betteam '0:4up'] by [bettype 30 - betteam '0:4']
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4&Over' THEN 'G4' -- replace row [bettype 179 - betteam 'G4&Over'] by [bettype 179 - betteam 'G4'] 
				ELSE cte.BetTeam
		   END AS BetTeam
		 , cte.[Set]
		 , cte.Game
		 , cte.BetOption
		 , cte.[Value]
		 , cte.ValueHdp1
		 , cte.ValueHdp2
		 , cte.Goal
		 , cte.OddsSpread
		 , cte.OddsId
		 , cte.Transdesc
		 , cte.VirtualHead
	FROM (
		SELECT cte.Id
			 , bt.value AS BetTeam 
			 , se.value AS [Set]
			 , ga.value AS Game
			 , bop.value AS BetOption
			 , CAST(CASE WHEN v.value = 'ALL' THEN @ValueDefault 
						ELSE v.value END AS SMALLMONEY) AS [Value]
			 , CAST(CASE WHEN vhdp1.value = 'ALL' THEN @ValueDefault
						ELSE vhdp1.value END AS SMALLMONEY) AS ValueHdp1
			 , CAST(CASE WHEN cte.ValueHdp2 = 'ALL' THEN @ValueDefault 
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2					 
			 , CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal END AS BIGINT) AS Goal
			 , CAST(CASE WHEN os.value = 'ALL' THEN @ValueDefault
						ELSE os.value END AS MONEY) AS OddsSpread
			 , CAST(CASE WHEN osid.value = 'ALL' THEN NULL
						ELSE osid.value END AS INT) AS OddsId
			 , CAST(CASE WHEN td.value = 'ALL' THEN NULL
						ELSE td.value END AS NVARCHAR(2000)) AS Transdesc
			 , CAST(CASE WHEN cte.VirtualHead = 'ALL' THEN @ValueDefault 
						ELSE cte.VirtualHead END AS SMALLMONEY) AS VirtualHead		
		FROM #tblBetType cte
			 CROSS APPLY STRING_SPLIT(cte.betteam, ',') bt
			 CROSS APPLY STRING_SPLIT(cte.[Set], ',') se
			 CROSS APPLY STRING_SPLIT(cte.Game, ',') ga
			 CROSS APPLY STRING_SPLIT(cte.BetOption, ',') bop
			 CROSS APPLY STRING_SPLIT(cte.[Value], ',') v
			 CROSS APPLY STRING_SPLIT(cte.ValueHdp1, ',') vhdp1
			 CROSS APPLY STRING_SPLIT(cte.OddsSpread, ',') os
			 CROSS APPLY STRING_SPLIT(cte.OddsId, ',') osid
			 CROSS APPLY STRING_SPLIT(cte.Transdesc, ',') td
	) cte	
	WHERE CASE WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
			WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
			ELSE 1 END = 1

	-- check and not allow attempt to void tickets of this match while it's being calculated
	---------------------------------------------------------------------------	
	BEGIN 
		SELECT @isExistSingle = MAX(CASE WHEN f.GroupId IN (1,2) THEN 0 ELSE 1 END)
				,@isExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
				,@isExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)  
			INNER JOIN @tmpMatchId m ON m.MatchId = b.matchid
			INNER JOIN #tblTransIds t ON t.transid = b.transid  
			INNER JOIN #tblBetType_Detail tp ON tp.Id = b.bettype 
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
				)f
	 
		-- Tuning EC2021
		INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
		SELECT bm.matchid, bm.refno
		FROM #tblTransIds t 
			INNER LOOP JOIN dbo.bettransm bm WITH (NOLOCK) ON t.transid = bm.transid 
		WHERE bm.matchid  IN (SELECT matchid FROM @tmpMatchId) 
			AND bm.statusID NOT IN (101, 102, 103)

		SET @totalSubParlay = @@ROWCOUNT
		IF @totalSubParlay > 0 
			SET @isExistParlay = 1
	END 

	EXEC dbo.NAP_Set_GlobalSettingSel 
			 @LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT DISTINCT b.matchid
			, CASE 
				WHEN Bettype NOT IN (9, 29, 2799, 10449, 10, 38) 
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
		FROM dbo.bettrans b WITH (NOLOCK)  
			INNER JOIN @tmpMatchId m ON m.MatchId = b.matchid
			INNER JOIN #tblTransIds t ON t.transid = b.transid  
			INNER JOIN #tblBetType_Detail tp ON tp.Id = b.bettype 
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
				)f

	-- Apply new way to lock parlay tickets	
	IF @totalSubParlay = 0 OR @totalSubParlay <= @ThreadHold
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess 
				 @isExistMatch		= @isExistSingle
				,@isExistFM			= @isExistFM
				,@isExistFM2		= @isExistFM2
				,@spName			= @spName
				,@avaiableProcess 	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN
				SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					, @NegativeBalanceUsers AS NegativeBalanceUsers
					,@SiteDBGroupID AS SiteDBGroupID

				RETURN		
			END	
		END
		
		IF @totalSubParlay > 0
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				 @IsLockingByRefno	= 1
				,@spName			= @spName
				,@Session			= @Session
				,@avaiableProcess 	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN	
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					 @isExistMatch		= @isExistSingle
					,@isExistFM			= @isExistFM
					,@isExistFM2		= @isExistFM2
					,@IsReleased		= 1
				
				SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					, @NegativeBalanceUsers AS NegativeBalanceUsers
					,@SiteDBGroupID AS SiteDBGroupID

				RETURN;	
			END	
		END
	END
	ELSE IF @totalSubParlay > @ThreadHold
	BEGIN
		-- checking SD proccess
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay		= @isExistParlay  
			,@isExistMatch		= @isExistSingle
			,@isExistFM			= @isExistFM
			,@isExistFM2		= @isExistFM2
			,@spName			= @spName
			,@avaiableProcess 	= @avaiableProcess OUTPUT
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN	
			SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					, @NegativeBalanceUsers AS NegativeBalanceUsers
					,@SiteDBGroupID AS SiteDBGroupID

			RETURN		
		END	
	END

	------------------***** Insert all data into #SpecialDeleteBets *****------------------
	IF @Bet = 'All' OR @Bet = 'Single'
	BEGIN
		IF @IsCheckTime = 1 --checkbox for the time range
		BEGIN
			INSERT INTO #SpecialDeleteBets (
				grouptransid
				,transid
				,custid
				,recommend
				,mrecommend
				,srecommend
				,betfrom
				,statusID
				,status
				,SecAcceptFlag
				,creator
				,hdp1
				,hdp2
				,bettype
				,betteam
				,betcheck
				,odds
				,oddsspread
				,OddsType
				,transdate
				,checktime
				,IsLiveIndicator
				,livehomescore
				,liveawayscore
				,Stake
				,CurrencyName
				,betid
				,betdaqid
				,refno
				,TransDesc
				,ExtraInfo
				,awinlost
				,IsCashOut
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,FilterBettype
				,FilterBetTeam
				,FilterSet
				,FilterGame	
				,FilterValue
				,FilterGoal
				,FilterBetOption
				,FilterHdp1
				,FilterHdp2
				,FilterOddsSpread
				,FilterOddsId
				,FilterTransdesc
				,ActualStake
				,OddsId
				,SiteDBGroupId
				,FilterOdds
				,matchid
				,modds
			)
			SELECT	
				b.transid
				,b.transid
				,b.custid
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.betfrom
				,b.statusID
				,b.STATUS
				,b.SecAcceptFlag
				,b.creator
				,b.hdp1
				,b.hdp2
				,b.bettype
				,b.betteam
				,b.betcheck
				,b.odds
				,b.oddsspread
				,b.oddstype
				,b.transdate
				,b.checktime
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,b.stake
				,b.CurrencyName
				,b.betid
				,b.betdaqid
				,b.refno
				,b.TransDesc
				,b.ExtraInfo
				,b.awinlost
				,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,b.bettype AS FilterBetType
				,b.betteam AS FilterBetTeam
				,b.betid AS FilterSet
				,RIGHT(b.betid, 2) AS FilterGame
				,b.hdp1 + b.hdp2 AS FilterValue
				,ISNULL(b.betid, 0) AS FilterGoal
				,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
				,b.hdp1 AS FilterHdp1
				,CASE WHEN b.bettype = 646 THEN ABS(b.hdp2) ELSE b.hdp2 END AS FilterHdp2 --646: Match Handicap & Total
				,CASE WHEN b.bettype = 229 THEN ABS(b.oddsspread) ELSE b.oddsspread END AS FilterOddsSpread -- 229:SABA HDP Time Machine
				,b.oddsid AS FilterOddsId
				,b.transdesc AS FilterTransdesc
				,b.actual_stake AS ActualStake
				,b.oddsid
				,b.SiteDBGroupID
				,b.odds AS FilterOdds
				,b.matchid
				,b.modds
			FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON	t.transid = b.transid
			WHERE	b.matchid IN (SELECT matchid FROM @tmpMatchId)
				AND CASE
						WHEN @TimeType = 0 THEN b.transdate
						WHEN @TimeType = 1 AND b.checktime IS NOT NULL THEN b.checktime
						WHEN @TimeType = 1 AND b.checktime IS NULL THEN b.transdate
					END BETWEEN @FromTransdate AND @ToTransdate
				AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveindicator END = @LiveIndicator
				AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END 
				AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END 			
				AND ISNULL(b.SecAcceptFlag, 0)  = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag, 0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND b.statusID NOT IN (101, 102, 103)
				AND b.betfrom <> 'p'
				AND b.SiteDBGroupID = @SiteDBGroupID
			OPTION (OPTIMIZE FOR (@CountTransId = 1))
		END
		ELSE --Disable time range
		BEGIN
			INSERT INTO #SpecialDeleteBets (
				grouptransid
				,transid
				,custid
				,recommend
				,mrecommend
				,srecommend
				,betfrom
				,statusID
				,status
				,SecAcceptFlag
				,creator
				,hdp1
				,hdp2
				,bettype
				,betteam
				,betcheck
				,odds
				,oddsspread
				,OddsType
				,transdate
				,checktime
				,IsLiveIndicator
				,livehomescore
				,liveawayscore
				,Stake
				,CurrencyName
				,betid
				,betdaqid
				,refno
				,TransDesc
				,ExtraInfo
				,awinlost
				,IsCashOut
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,FilterBettype
				,FilterBetTeam
				,FilterSet
				,FilterGame	
				,FilterValue
				,FilterGoal
				,FilterBetOption
				,FilterHdp1
				,FilterHdp2
				,FilterOddsSpread
				,FilterOddsId
				,FilterTransdesc
				,ActualStake
				,OddsId
				,SiteDBGroupId
				,FilterOdds
				,matchid
				,modds
			)
			SELECT	
				b.transid
				,b.transid
				,b.custid
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.betfrom
				,b.statusID
				,b.STATUS
				,b.SecAcceptFlag
				,b.creator
				,b.hdp1
				,b.hdp2
				,b.bettype
				,b.betteam
				,b.betcheck
				,b.odds
				,b.oddsspread
				,b.oddstype
				,b.transdate
				,b.checktime
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,b.stake
				,b.CurrencyName
				,b.betid
				,b.betdaqid
				,b.refno
				,b.TransDesc
				,b.ExtraInfo
				,b.awinlost
				,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,b.bettype AS FilterBetType
				,b.betteam AS FilterBetTeam
				,b.betid AS FilterSet
				,RIGHT(b.betid, 2) AS FilterGame
				,b.hdp1 + b.hdp2 AS FilterValue
				,ISNULL(b.betid, 0) AS FilterGoal
				,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
				,b.hdp1 AS FilterHdp1
				,CASE WHEN b.bettype = 646 THEN ABS(b.hdp2) ELSE b.hdp2 END AS FilterHdp2 --646: Match Handicap & Total
				,CASE WHEN b.bettype = 229 THEN ABS(b.oddsspread) ELSE b.oddsspread END AS FilterOddsSpread -- 229:SABA HDP Time Machine
				,b.oddsid AS FilterOddsId
				,b.transdesc AS FilterTransdesc
				,b.actual_stake AS ActualStake
				,b.oddsid
				,b.SiteDBGroupID
				,b.odds AS FilterOdds
				,b.matchid
				,b.modds
			FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON	t.transid = b.transid
			WHERE	b.matchid IN (SELECT matchid FROM @tmpMatchId)
				AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveindicator END = @LiveIndicator
				AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END 
				AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END 			
				AND ISNULL(b.SecAcceptFlag, 0)  = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag, 0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND b.statusID NOT IN (101, 102, 103)
				AND b.betfrom <> 'p'
				AND b.SiteDBGroupID = @SiteDBGroupID
			OPTION (OPTIMIZE FOR (@CountTransId = 1))
		END
	END

	-- Search Parlay Tickets
	IF @Bet = 'All' OR @Bet = 'Sub Parlay'	
	BEGIN
		IF @IsCheckTime = 1 --checkbox for the time range
		BEGIN
			INSERT INTO #SpecialDeleteBetsm (
				CustId
				,OddsSpread
				,TransDate
				,checktime
				,LiveIndicator
				,LiveHomeScore 
				,LiveAwayScore 
				,Creator
				,Refno
				,SubTransDesc
				,SubTransId
				,SubStatus
				,SubBetCheck
				,SubBetTeam
				,SubBetType
				,SubHdp1
				,SubHdp2
				,SubOdds
				,SubOddsSpread
				,SubOddsId
				,SiteDBGroupId
				,matchid
			)
			SELECT
				 bm.custid 
				,bm.oddsspread
				,bm.transdate
				,bm.checktime
				,bm.liveindicator
				,bm.livehomescore
				,bm.liveawayscore
				,bm.creator
				,bm.refno
				,bm.transdesc AS SubTransDesc
				,bm.transid AS SubTransId
				,bm.status AS SubStatus
				,bm.betcheck AS SubBetCheck
				,bm.betteam AS SubBetTeam
				,bm.bettype AS SubBetType
				,bm.hdp1 AS SubHdp1
				,CASE WHEN bm.bettype = 646 THEN ABS(bm.hdp2) ELSE bm.hdp2 END AS SubHdp2 --646: Match Handicap & Total
				,bm.odds As SubOdds
				,CASE WHEN bm.bettype = 229 THEN ABS(bm.oddsspread) ELSE bm.oddsspread END AS SubOddsSpread -- 229:SABA HDP Time Machine
				,bm.oddsid
				,bm.SiteDBGroupID
				,bm.matchid
			FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
				INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON t.transid = bm.transid
			WHERE bm.matchid IN (SELECT matchid FROM @tmpMatchId)
				AND	CASE
						WHEN @TimeType = 0 THEN bm.transdate
						WHEN @TimeType = 1 AND bm.checktime IS NOT NULL THEN bm.checktime
						WHEN @TimeType = 1 AND bm.checktime IS NULL THEN bm.transdate
					END BETWEEN @FromTransdate AND @ToTransdate
				AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE bm.liveIndicator END = @LiveIndicator
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.statusID NOT IN (101, 102, 103)
				AND bm.betfrom <> 'p'
				AND bm.SiteDBGroupID = @SiteDBGroupID
		END
		ELSE --Disable time range
		BEGIN
			INSERT INTO #SpecialDeleteBetsm (
				CustId
				,OddsSpread
				,TransDate
				,checktime
				,LiveIndicator
				,LiveHomeScore 
				,LiveAwayScore 
				,Creator
				,Refno
				,SubTransDesc
				,SubTransId
				,SubStatus
				,SubBetCheck
				,SubBetTeam
				,SubBetType
				,SubHdp1
				,SubHdp2
				,SubOdds
				,SubOddsSpread
				,SubOddsId
				,SiteDBGroupId
				,matchid
			)
			SELECT
				 bm.custid 
				,bm.oddsspread
				,bm.transdate
				,bm.checktime
				,bm.liveindicator
				,bm.livehomescore
				,bm.liveawayscore
				,bm.creator
				,bm.refno
				,bm.transdesc AS SubTransDesc
				,bm.transid AS SubTransId
				,bm.status AS SubStatus
				,bm.betcheck AS SubBetCheck
				,bm.betteam AS SubBetTeam
				,bm.bettype AS SubBetType
				,bm.hdp1 AS SubHdp1
				,CASE WHEN bm.bettype = 646 THEN ABS(bm.hdp2) ELSE bm.hdp2 END AS SubHdp2 --646: Match Handicap & Total
				,bm.odds As SubOdds
				,CASE WHEN bm.bettype = 229 THEN ABS(bm.oddsspread) ELSE bm.oddsspread END AS SubOddsSpread -- 229:SABA HDP Time Machine
				,bm.oddsid
				,bm.SiteDBGroupID
				,bm.matchid
			FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
				INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON t.transid = bm.transid
			WHERE bm.matchid IN (SELECT matchid FROM @tmpMatchId)
				AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE bm.liveIndicator END = @LiveIndicator
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.statusID NOT IN (101, 102, 103)
				AND bm.betfrom <> 'p'
				AND bm.SiteDBGroupID = @SiteDBGroupID
		END
		
		BEGIN
			INSERT INTO #SpecialDeleteBets (			
				transid			
				,custid			
				,odds
				,oddsspread		
				,OddsType		
				,transdate
				,checktime		
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
				,srecommend
				,mrecommend		
				,recommend
				,betid			
				,betdaqid		
				,TransDesc	
				,refno
				,WinLost
				,IsMixParlay
				,SubTransDesc
				,SubTransId
				,SubStatus
				,SubBetCheck
				,SubBetTeam
				,SubBetType
				,SubHdp1
				,SubHdp2
				,SubOdds
				,FilterBettype
				,FilterBetTeam
				,FilterSet
				,FilterGame	
				,FilterValue
				,FilterHdp1
				,FilterHdp2
				,FilterGoal
				,FilterOddsSpread
				,FilterOddsId
				,FilterTransdesc
				,ExtraInfo
				,ActualStake
				,main_ruben
				,main_custId
				,OddsId
				,SiteDBGroupId
				,FilterOdds
				,statusID
				,matchid
				,SiteID
				,mainoddsspread
				,modds
			)
			SELECT
				b.transid,
				bm.custid,
				b.odds,
				bm.oddsspread,
				b.OddsType,
				bm.transdate,
				bm.checktime,
				b.bettype,
				b.betteam,
				b.betcheck,
				b.hdp1,
				b.hdp2,
				bm.liveindicator,
				bm.livehomescore,
				bm.liveawayscore,
				bm.creator,
				b.stake,
				b.CurrencyName, 
				b.status,
				b.srecommend,
				b.mrecommend,
				b.recommend,
				b.betid,
				b.betdaqid,
				b.transdesc,
				bm.refno,
				b.WinLost - b.actual_stake AS WinLost,
				1 AS IsMixParlay,
				bm.SubTransDesc,
				bm.SubTransId,
				bm.SubStatus,
				bm.SubBetCheck,
				bm.SubBetTeam,
				bm.SubBetType,
				bm.SubHdp1,
				bm.SubHdp2,
				bm.SubOdds,
				bm.SubBetType AS FilterBetType,
				bm.SubBetTeam AS FilterBetTeam,
				bm.SubBetCheck AS FilterSet,
				RIGHT(bm.SubBetCheck, 2) AS FilterGame,
				bm.SubHdp1 + bm.SubHdp2 AS FilterValue,
				bm.SubHdp1 AS FilterHdp1,
				CASE WHEN b.bettype = 646 THEN ABS(bm.SubHdp2) ELSE bm.SubHdp2 END AS FilterHdp2, --646: Match Handicap & Total
				ISNULL(bm.SubBetCheck, 0) AS FilterGoal,
				CASE WHEN b.bettype = 229 THEN ABS(bm.SubOddsSpread) ELSE bm.SubOddsSpread END AS FilterOddsSpread, -- 229:SABA HDP Time Machine
				bm.SubOddsId AS FilterOddsId,
				bm.SubTransDesc AS FilterTransdesc,
				b.ExtraInfo,
				b.actual_stake AS ActualStake,
				b.ruben,
				b.custid,
				bm.SubOddsId
				,bm.SiteDBGroupId
				,bm.SubOdds AS FilterOdds
				,b.statusID
				,bm.matchid
				,b.BetSiteID
				,b.oddsspread
			    ,b.modds
			FROM #SpecialDeleteBetsm bm WITH (NOLOCK)
				INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) 
					ON b.matchid = 29 AND bm.refno = b.refno AND bm.SiteDBGroupId = b.SiteDBGroupID
		
			IF @SelectionSubParlays <> ''
			BEGIN
				INSERT INTO @tmpSelectionSubParlay (Id)
				SELECT value AS  Id
				FROM STRING_SPLIT(@SelectionSubParlays, ',')
		
				DELETE b
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM @tmpSelectionSubParlay sp 
						WHERE 1 = CASE WHEN sp.Id = '10 UP' AND b.hdp2 >= 10 THEN 1
									   WHEN sp.Id <> '10 UP' AND b.hdp2 = CAST (sp.Id AS SMALLMONEY) THEN 1
									   ELSE 0 END)
			END
		END
	END
	
	/*
		filter for [Set] (+ [Quarter])
		[Set] : 8xx; 1324 : 8xxyy
		[Quarter] : 80X; 613 : 80XYY		
		filter for Game : Only handle for bettype 1324		 
		filter for BetOption : Only handle for bettypes 221 -> 227		 
		filter for [Value]		
		filter for ValuaHdp1
		filter for ValuaHdp2		 
		filter for Goal
	*/
	BEGIN
		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND 
				CASE
					WHEN tp.Id <> 376 THEN CASE WHEN tp.BetTeam = 'All' OR b.FilterBetTeam = tp.BetTeam THEN 1 ELSE 0 END
					ELSE 
						CASE tp.BetTeam
							 WHEN 'All-All' THEN 1
							 WHEN 'All-S' THEN CASE WHEN b.FilterBetTeam LIKE '%S%' THEN 1 ELSE 0 END
							 WHEN 'All-M' THEN CASE WHEN b.FilterBetTeam LIKE '%M%' THEN 1 ELSE 0 END
							 WHEN 'H-All' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) <> '-----' THEN 1 ELSE 0 END
							 WHEN 'A-All' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) <> '-----' THEN 1 ELSE 0 END
							 WHEN 'H-S' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) LIKE '%S%' THEN 1 ELSE 0 END
							 WHEN 'H-M' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) LIKE '%M%' THEN 1 ELSE 0 END
							 WHEN 'A-S' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) LIKE '%S%' THEN 1 ELSE 0 END
							 WHEN 'A-M' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) LIKE '%M%' THEN 1 ELSE 0 END
							 ELSE 0
						END
				END = 1
		)

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%' ))

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

		IF @SportType NOT IN (50) --NOT Cricket
		BEGIN
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.FilterHdp2 = tp.ValueHdp2 ))

		END
		ELSE --Cricket
		BEGIN
			--Note: Value of Cricket => hdp1 value
			UPDATE #tblBetType_Detail 
			SET Hdp1_tmp = CASE WHEN [Value] <> @ValueDefault THEN [Value] 
								WHEN ValueHdp1 <> @ValueDefault THEN ValueHdp1 
								ELSE @ValueDefault END
			
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE b.FilterBetTeam NOT IN ('y')
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
								WHERE tp.Id = b.FilterBettype 
								AND 1 = CASE WHEN tp.Hdp1_tmp = @ValueDefault AND tp.VirtualHead = @ValueDefault THEN 1
											 WHEN tp.Hdp1_tmp <> @ValueDefault AND tp.VirtualHead = @ValueDefault AND b.FilterHdp1 = tp.Hdp1_tmp THEN 1
											 WHEN tp.Hdp1_tmp <> @ValueDefault AND tp.VirtualHead <> @ValueDefault AND (b.FilterHdp1 = tp.Hdp1_tmp OR b.FilterHdp1 >= tp.VirtualHead) THEN 1
											 WHEN tp.Hdp1_tmp = @ValueDefault AND tp.VirtualHead <> @ValueDefault AND b.FilterHdp1 >= tp.VirtualHead THEN 1
											 ELSE 0 END)
			
			--Group bettypes: xxx Fancy (Yes/No value case 'y')
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE b.FilterBetTeam IN ('y')
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
								WHERE tp.Id = b.FilterBettype
								AND 1 = CASE WHEN tp.ValueHdp2 = @ValueDefault AND tp.VirtualHead = @ValueDefault THEN 1
											 WHEN tp.ValueHdp2 <> @ValueDefault AND tp.VirtualHead = @ValueDefault AND b.FilterHdp2 = tp.ValueHdp2 THEN 1
											 WHEN tp.ValueHdp2 <> @ValueDefault AND tp.VirtualHead <> @ValueDefault AND (b.FilterHdp2 = tp.ValueHdp2 OR b.FilterHdp2 >= tp.VirtualHead) THEN 1
											 WHEN tp.ValueHdp2 = @ValueDefault AND tp.VirtualHead <> @ValueDefault AND b.FilterHdp2 >= tp.VirtualHead THEN 1
											 ELSE 0 END)
		END

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ) OR b.bettype = 29)

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread ))

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.OddsId IS NULL OR b.FilterOddsId = tp.OddsId))

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND  (tp.Transdesc IS NULL OR b.FilterTransdesc = tp.Transdesc))

		IF @OddsFilter IS NOT NULL
		BEGIN
			DELETE b
			FROM #SpecialDeleteBets b
				LEFT JOIN f_Set_OddsTypeBettypes() f ON f.BetType = b.FilterBettype
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM @tmp_Odds tp
				WHERE tp.OddsType = b.OddsType 
					AND 1 = CASE WHEN b.IsMixParlay = 1 AND b.FilterOdds = tp.Odds THEN 1
								WHEN b.IsMixParlay = 0 AND f.BetType IS NOT NULL AND b.FilterOdds = tp.Odds THEN 1
								WHEN b.IsMixParlay = 0 AND f.BetType IS NULL AND b.OddsType = 1 AND b.FilterOdds = tp.Odds - 1 THEN 1
								WHEN b.IsMixParlay = 0 AND f.BetType IS NULL AND b.OddsType <> 1 AND b.FilterOdds = tp.Odds THEN 1
							ELSE 0 END
				)
		END
	END	

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype NOT IN (9, 29, 2799, 10449)))
	BEGIN
		UPDATE d
		SET eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29, 2799, 10449)
	END
	
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (10)))
	BEGIN
		UPDATE d
		SET eventstatus = ISNULL(odds.oddsstatus,'')
			,SettlementStatus = 0
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	d.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE d.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE d
			SET eventstatus = ISNULL(o.eventstatus,'')
				,SettlementStatus = 0
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE d.bettype IN (1231,1232,1233,1237,1238)
	END

	------------------***** End of insert all data into #SpecialDeleteBets *****------------------
	--------------------------------------------------------------------------------------			
	 --check no data
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets) AND NOT EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBetsm))
	BEGIN
		SELECT 99 AS ErrorCode
			, 'No ticket found.' AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers
		
		IF @totalSubParlay = 0 OR @totalSubParlay <= @ThreadHold
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					 @isExistMatch		= @isExistSingle
					,@isExistFM			= @isExistFM
					,@isExistFM2		= @isExistFM2
					,@IsReleased		= 1
			END
			
			IF @totalSubParlay > 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1
			END						
		END
		ELSE IF @totalSubParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay		= @isExistParlay  
				,@isExistMatch		= @isExistSingle
				,@isExistFM			= @isExistFM
				,@isExistFM2		= @isExistFM2
				,@IsReleased		= 1

		END
			
	END
	ELSE
	BEGIN		
		------------------***** Begin Special Delete *****------------------		                                                                                                                                               
		DECLARE @BeforeUpd 	TVP_BalanceWalletChange
		DECLARE @AfterUpd 	TVP_BalanceWalletChange
		
		-- Step 1: Backup into zzzbettrans
		-- 1.1. Backup normal tickets
		INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
					winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
					winlostdate,betfrom,betcheck,checktime,matchid, bettype, RepUpdateTime, SiteDBGroupID)
		SELECT  main.transid, main.custid, CURRENT_TIMESTAMP, main.oddsid, main.hdp1, main.hdp2, main.odds, main.stake, main.status, 
				main.winlost, main.livehomescore, main.liveawayscore, main.liveindicator, main.betteam, main.creator , main.refno, 
				main.winlostdate, main.betfrom, main.betcheck, 
				main.checktime, main.matchid, main.bettype, SYSDATETIME(), main.SiteDBGroupID
		FROM	dbo.bettrans main WITH (nolock)
			INNER JOIN #SpecialDeleteBets tmpmain ON main.transid = tmpmain.transid AND main.transid = tmpmain.grouptransid AND main.matchid = tmpmain.matchid

		-- 1.4.  BackUp bettransm tickets into zzzbettrans
		INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
				winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID
		)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype , SYSDATETIME(), b.SiteDBGroupID
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #SpecialDeleteBets AS r ON r.SubTransId=b.transid

		-- 1.5.  BackUp bettransm tickets into zzzbettransm
		INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				 winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
				 winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype , SYSDATETIME(), b.SiteDBGroupID
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #SpecialDeleteBets AS r ON r.SubTransId=b.transid   
		
		-- Step 2: Update bettrans
		-- 2.1. Update normal tickets
		WHILE (1=1)
		BEGIN
			UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
			FROM @tmpMatchId p
			WHERE p.IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK

			SET @FCUpdateTime = SYSDATETIME()
			UPDATE	main
				SET winlost		= main.actual_stake
					,ruben			= 1
					--,statuswinlost	= 6
					,creator		= @UserID
					,awinlost		= 0
					,mwinlost		= 0
					,swinlost		= 0
					,playercomm		= 0
					,comm			= 0
					,acomm			= 0
					,scomm			= 0
					,statusID		= 102       
					,status			= 'VOID'
					,FcUpdateTime  = @FCUpdateTime
						OUTPUT deleted.Transid,
							deleted.custid,  
							deleted.winlost,
							deleted.actual_stake,
							deleted.playercomm,
							deleted.BonusID,
							deleted.WalletType,
							deleted.betdaqid,
							deleted.status,
							@MatchId
					INTO @tmpTrans_beforeUpd (transid, custid, winlost, actual_stake, playercomm, Bonusid, WalletType, betdaqid, status, matchid)
			FROM	dbo.bettrans main WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #SpecialDeleteBets tmpmain 
					ON	main.transid = tmpmain.transid 
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = @matchid
		

			SET @transInfo = COMPRESS((
				SELECT	t.transId AS 't'
						, b.winlost AS 'w'
						, b.ruben AS 'r'
						, b.creator AS 'cr'
						, b.awinlost AS 'aw'
						, b.mwinlost AS 'mw'
						, b.swinlost AS 'sw'
						, b.playercomm AS 'pc'
						, b.comm AS 'c'
						, b.acomm AS 'ac'
						, b.scomm AS 'sc'
						, b.statusID AS 'sid'
						, b.status AS 's'
						, b.FcUpdateTime AS 'rut'
				FROM	#SpecialDeleteBets t 
					INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
					INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
				WHERE t.matchid = @MatchId
				FOR JSON PATH))
		
			IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'VoidSingleBet', 'bettrans', 'U', @matchid, @transInfo, 's'
			END
		END

		-- Capture balance before updating Bettrans - New code for CO new Model
		INSERT INTO @BeforeUpd (matchid, custid, balanceType, BonusID, WalletType, balance)
		SELECT	tmp.matchid AS matchid
			  , tmp.custid
			  , 1 AS balanceType
			  , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			  , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			  , SUM (tmp.winlost - tmp.actual_stake + tmp.playercomm) AS balance
		FROM @tmpTrans_beforeUpd tmp
		GROUP BY matchid
			   , custid
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets
		
		--> capture Before Balance Update		
		INSERT INTO #BeforeUpd(custid, balance)
		SELECT	b.custid , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM @tmpTrans_beforeUpd b
		GROUP BY b.CustID

		--Correct data captured before because CO happen when voiding ticket
		IF EXISTS (SELECT TOP(1) 1 FROM #SpecialDeleteBets	b
						INNER JOIN @tmpTrans_beforeUpd t ON t.transid = b.transid
					WHERE b.IsCashOut = 0 AND t.betdaqid = -2 )
		BEGIN
			UPDATE b
			SET b.status = t.status
				, b.WinLost = t.winlost - t.actual_stake
				, b.ActualStake = t.actual_stake
				, b.betdaqid = -2
				, b.IsCashOut = 1
			FROM #SpecialDeleteBets b 
				INNER JOIN @tmpTrans_beforeUpd t ON t.transid = b.transid
			WHERE b.IsCashOut = 0 
				AND t.betdaqid = -2

			UPDATE z
			SET z.status = t.status
				, z.winlost = t.winlost
			OUTPUT deleted.matchid, deleted.transid, t.status, t.winlost
			INTO @tmpTransInfo (matchid, transid, STATUS, winlost)
			FROM zzzbettrans z WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tmpTrans_beforeUpd t ON t.transid = z.transid
			WHERE z.status <> t.status
				AND t.betdaqid = -2

			DELETE @tmpMatchId 
			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT matchid
			FROM @tmpTransInfo
			
			WHILE (1=1)
			BEGIN
				SET @transInfo = NULL

				UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
				FROM @tmpMatchId p
				WHERE p.IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK

				SET @transInfo = COMPRESS((
						SELECT	transId AS 't'
								, matchid AS 'mid'
								, STATUS AS 's'
								, winlost AS 'w'
						FROM	@tmpTransInfo WHERE matchid = @MatchId 
						FOR JSON PATH))

				IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
					SELECT 'TVS', 'VoidSingleBet', 'zzzbettrans', 'U', @matchid, @transInfo, 's' 
				END
			END
		END
		
		-- Capture balance after updating Bettrans
		INSERT INTO @AfterUpd(matchid, custid, balanceType, BonusID, WalletType, balance)
		SELECT	matchid AS matchid
			  , custid
			  , 1 AS balanceType
			  , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			  , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			  , SUM (winlost - actual_stake + playercomm) balance
		FROM (
			SELECT	main.custid
				  , main.BonusID
				  , main.WalletType
				  , main.winlost, main.actual_stake, main.playercomm,  main.matchid
			FROM	dbo.bettrans main WITH (NOLOCK)
				INNER JOIN #SpecialDeleteBets tmpmain
					ON	main.transid = tmpmain.transid 
						AND main.transid = tmpmain.grouptransid
						AND main.matchid = tmpmain.matchid
			
		) tmp
		GROUP BY matchid
				, custid
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets

		---INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			  @BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd	
			, @ActionId				= 0			
		
		-- Update Parlay Tickets
		IF EXISTS (SELECT 1 FROM #SpecialDeleteBetsm)
		BEGIN
			DECLARE @matchdate		DATETIME
					,@transid_tmp	VARCHAR(2000)  
					,@transids_29 VARCHAR(MAX) = '' 
					,@refnos_29  VARCHAR(MAX) = '' 

			DECLARE @tmpTransIDBatch TABLE (transid BIGINT)

			DELETE @tmpMatchId
			INSERT INTO @tmpMatchId(MatchId)
			SELECT DISTINCT MatchId
			FROM #SpecialDeleteBetsm	

			WHILE (1=1)
			BEGIN
				UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
				FROM @tmpMatchId p
				WHERE p.IsFinish IS NULL
		
				IF @@ROWCOUNT = 0 BREAK

				SELECT	@matchdate = eventdate
				FROM	dbo.match WITH(NOLOCK)
				WHERE	matchid = @MatchId

				WHILE (1=1)
				BEGIN
					DELETE @tmpTransIDBatch
					SET @transid_tmp = ''
		
					UPDATE TOP(100) t
					SET isFinish = 1
						OUTPUT deleted.SubTransId
						INTO @tmpTransIDBatch(transid)
					FROM #SpecialDeleteBetsm t
					WHERE isFinish IS NULL AND t.MatchId = @MatchId

					IF @@ROWCOUNT = 0 BREAK

					SELECT	@transid_tmp = @transid_tmp + CONVERT(VARCHAR(50), TransId) + ','
					FROM	@tmpTransIDBatch

					EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchId   
						,@matchdate = @matchdate  
						,@mode = 'VOID'  
						,@VoidTransID = @transid_tmp  
						,@UserId = @UserId
				END

				BEGIN TRY 
					SELECT	@transids_29 = @transids_29 + CONVERT(VARCHAR(20), transid) + ','  
					FROM	#SpecialDeleteBets  
					WHERE	bettype = 29  AND matchid = @MatchId
					GROUP BY transid

					DELETE @tmpBoostSite
					INSERT INTO @tmpBoostSite(SiteId, srecommend )
					SELECT DISTINCT SiteID, srecommend
					FROM	#SpecialDeleteBets t
					WHERE	bettype = 29  AND matchid = @MatchId
						AND t.betteam = '1' -- mix parlay
						AND t.mainoddsspread = 2 -- offer parlay bonus
						AND NOT EXISTS (SELECT 	TOP 1 1 
									FROM 	dbo.bettransm bm WITH(NOLOCK) 
									WHERE 	t.refno = bm.refno 
											AND ((ISNULL(bm.statuswinlost,0) = 4 AND bm.statusID = 113)
												OR bm.statusId = 0
											)
							) -- lose/running

					UPDATE si 
					SET IsDeposit = 1
					FROM	@tmpBoostSite si
						INNER JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK)
							ON si.srecommend = d.custid

					SET @sqlOpenqueryCommand = ''
					SET @sqlOpenqueryCommand = 'SELECT SiteId, OverOdds, Boost FROM OPENQUERY(DBPRO,''SELECT SiteId, OverOdds, Boost FROM bodb02.dbo.ParlayOddsBoostSetting p WITH(NOLOCK) WHERE p.SiteId IN ('
											+ (SELECT  STRING_AGG(CAST(s.SiteID AS VARCHAR(MAX)),',') 
												FROM (
													SELECT SiteId
													FROM (
														SELECT SiteId
														FROM @tmpBoostSite t
														UNION
														SELECT -1
														UNION 
														SELECT -2
													) t
													GROUP BY t.SiteID
												) s 
											)
									+ ')'')'

					DELETE @tmpBoostSetting
					INSERT INTO @tmpBoostSetting(SiteId, OverOdds, Boost)							
					EXEC (@sqlOpenqueryCommand)

					SET @strSetting = ''
					SELECT @strSetting = CAST((
						SELECT	si.SiteId AS 's'
								,(SELECT t.OverOdds AS 'o', t.Boost AS 'b' -- get its own settings
									FROM (SELECT se.SiteId, se.OverOdds, se.Boost
										FROM	@tmpBoostSetting se
										WHERE	EXISTS (SELECT TOP 1 1 FROM	@tmpBoostSite si WHERE se.SiteId = si.SiteId)
										UNION
										SELECT	si.SiteId, se.OverOdds, se.Boost -- If the site ID does not have its own settings, the default value will be taken on default SiteId (-1 if it's credit, -2 if it's licensee)
										FROM	@tmpBoostSite si
											CROSS APPLY (
												SELECT	se.OverOdds, se.Boost
												FROM	@tmpBoostSetting se
												WHERE	se.SiteId = CASE WHEN si.IsDeposit = 1 THEN -2 ELSE -1 END
											) se
										WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpBoostSetting se WHERE si.SiteId = se.SiteId)
									) t
								WHERE si.SiteId = t.SiteId
								FOR JSON AUTO
								) AS v
						FROM	@tmpBoostSite si
						FOR JSON AUTO
					) AS VARCHAR(MAX))

					EXEC dbo.NAP_Admin_Calculate_MP_broker   
						@matchid = @matchid  
						,@matchdate = @matchdate  
						,@strXML = @transids_29  
						,@mode  = 'PRECAL-29'
						,@strSetting = @strSetting
				END TRY  
				BEGIN CATCH   
					SELECT 100 AS ErrorCode
						, ERROR_MESSAGE()  AS ErrorMsg
						, @NegativeBalanceUsers AS NegativeBalanceUsers
						,@SiteDBGroupID AS SiteDBGroupID

				END CATCH  

				SET @transids_29 = ''
			END
		 

			IF EXISTS ( SELECT TOP 1 1  
						FROM #SpecialDeleteBets r
							INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON	b.refno = r.refno  
						WHERE b.matchid = 29 AND b.bettype = 29  
			)   
			BEGIN 
			---********* Calculate balance for system parlay********---  
				DECLARE @BeforeUpdSP	TVP_BalanceWalletChange
				DECLARE @AfterUpdSP		TVP_BalanceWalletChange

				--Get data before update  
				INSERT INTO @BeforeUpdSP (matchid, custid, balanceType, BonusID, WalletType, balance)  
				SELECT r.matchid AS matchid, b.custid, 1 AS balanceType, 0 AS BonusID, 2 AS WalletType, SUM(b.winlost - b.actual_stake + b.playercomm) balance
				FROM #SpecialDeleteBetsm r 
				 INNER HASH JOIN dbo.bettrans b WITH (NOLOCK)ON b.refno = r.refno  
				WHERE b.matchid = 29 AND b.bettype = 29  
				GROUP BY b.CustID, r.matchid

				--Prepare for Max Payout
				SELECT @MainParlay_MaxPO = (SELECT t.main_custId AS '@custid'
									,t.main_ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #SpecialDeleteBets t
								WHERE bettype = 29
								GROUP BY main_custId, main_ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)

				--Settlement System parlay (changed balance)  
				BEGIN TRY  
					SELECT  @refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
					FROM #SpecialDeleteBets  
					WHERE Bettype = 29 
						AND (statusID IS NULL OR statusID <> 102) 
					GROUP BY refno, transid
					SET @refnos_29 = STUFF(@refnos_29,1,1,'')

					EXEC dbo.NAP_Admin_Calculate_MP_broker  
					@matchdate = @matchdate  
					,@strXML = @refnos_29  
					,@mode  = '29'  
				END TRY  
				BEGIN CATCH   
					SELECT 100 AS ErrorCode
						, ERROR_MESSAGE()  AS ErrorMsg
						, @NegativeBalanceUsers AS NegativeBalanceUsers

				END CATCH  
		  
				--Get data after update  
				INSERT INTO @AfterUpdSP (matchid, custid, balanceType, BonusID, WalletType, balance)  
				SELECT r.matchid AS matchid
					 , b.custid  
					 , 1 AS balanceType
					 , 0 AS BonusID
					 , 2 AS WalletType
					 , SUM(b.winlost - b.actual_stake + b.playercomm) balance
				FROM  #SpecialDeleteBetsm r 
					INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = r.refno  
				WHERE b.matchid = 29 AND b.bettype = 29  
				GROUP BY b.CustID, r.matchid  

				---insert data into pending balance table   
				EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					  @BalanceWalletBefore	 = @BeforeUpdSP
					, @BalanceWalletAfter	 = @AfterUpdSP
				
			 ---********* End of calculate balance for system parlay********---  
			END  
		END  
				
		--> Capture balance after update	
		INSERT INTO #AfterUpd(custid, balance)
		SELECT	b.custid , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE transid IN (SELECT transid FROM #SpecialDeleteBets)
		GROUP BY b.CustID

		SET @NegativeBalanceUsers = ''
		SELECT @CustIds = @CustIds + CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20), b.custid)
		FROM #BeforeUpd b
			 INNER JOIN	#AfterUpd a ON a.custid = b.custid
		WHERE b.balance > a.balance
		
		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

		-- Update CashOutSelling [#165097]
		UPDATE c
		SET CashOutStatus = 6 --Void
		   ,ChangeDate = GETDATE()
		FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #SpecialDeleteBets b ON c.TransID = b.transid AND c.MatchID = b.matchid
		WHERE b.betdaqid = -2 

		IF @totalSubParlay = 0 OR @totalSubParlay <= @ThreadHold
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					 @isExistMatch		= @isExistSingle
					,@isExistFM			= @isExistFM
					,@isExistFM2		= @isExistFM2
					,@IsReleased		= 1
			END
			
			IF @totalSubParlay > 0
			BEGIN
				------ releasing refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1
			END						
		END
		ELSE IF @totalSubParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay		= @isExistParlay  
				,@isExistMatch		= @isExistSingle
				,@isExistFM			= @isExistFM
				,@isExistFM2		= @isExistFM2
				,@IsReleased		= 1

		END
		------------------***** End of Special Delete *****------------------
		
		----------------Insert Max Payout Queue----------------
		DECLARE @TransIds_MaxPO VARCHAR(MAX) = ''

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
					WHERE bettype NOT IN (29,2799, 10449)
					FOR XML PATH('r'), ROOT('root')
				)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO

		IF @MainParlay_MaxPO IS NOT NULL
		BEGIN
			--Insert Max Payout Queue
			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
				@MatchId= 29
				,@TransidList = @MainParlay_MaxPO
		END
		
		-- CHECK IT GROUP or NOT ?   
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

		--1. Table return error code/ msg
		SELECT @ErrCode AS ErrorCode
			,@ErrMsg AS ErrorMsg
			,@NegativeBalanceUsers AS NegativeBalanceUsers
			,@SiteDBGroupID AS SiteDBGroupID
		
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
		INSERT INTO #CTE_CustInfo(custid, username, username2, site, currency)
		SELECT ci.custid
			, ci.username
			, ci.username2
			, ci.site
			, ci.currency
		FROM CustDB.dbo.Customer ci WITH(NOLOCK)
			INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid		
		
		BEGIN -- Instant Settlement declaration
			
			DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
			CREATE TABLE #CTE_match (matchid INT)
			CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

			INSERT INTO #CTE_match (matchid)
			SELECT DISTINCT t.matchid
			FROM #SpecialDeleteBets t
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
			
			IF @sportType = 1 --Soccer					 
			BEGIN 
				INSERT INTO #CTE_isCal (matchid, IsHTCal)
				SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
				FROM #CTE_match m
					LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid

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
			IF @sportType = 2 --Basketball
			BEGIN
				INSERT INTO #CTE_isCal (matchid, ResourceId)
				SELECT m.matchid, rd.ResourceId
				FROM #CTE_match m
					LEFT JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
						ON rd.matchid = m.matchid 
						AND ResultStatusID IN (2,5) AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 

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

		SELECT	al.odds
			,al.oddsspread
			,al.OddsType
			,al.transdate
			,al.checktime			
			,al.betfrom
			,al.refno
			,al.betteam
			,al.betcheck
			,al.livehomescore
			,al.liveawayscore
			,cr.username AS creator
			,al.Stake
			,ci.currency
			,al.CurrencyName
			,al.status
			,al.SecAcceptFlag
			,al.betid
			,al.grouptransid
			,al.transid
			,al.TransDesc
			,al.betdaqid
			,al.ExtraInfo
			,al.IsCashOut
			,al.WinLost
			,al.bettype AS BetTypeId
			,al.hdp1 AS Handicap1
			,al.hdp2 AS Handicap2
			,al.IsLiveIndicator AS IsLive
			,al.IsMixParlay
			,al.SubTransDesc
			,al.SubTransid
			,al.SubStatus
			,al.SubBetcheck
			,al.SubBetteam
			,al.SubBettype
			,al.SubHdp1
			,al.SubHdp2
			,al.SubOdds
			,al.MainTransId
			,al.custid
			,al.recommend
			,al.mrecommend
			,al.srecommend		
			,ci.username
			,ci.username2			
			,ag.UserName AS AgUserName
			,ma.UserName AS MagUserName
			,su.Username AS SagUserName
			,CASE 
				WHEN al.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
				ELSE su.site 
			END AS EmailGroup
			,su.site 
			,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
			,@isITAdmin	AS IsITSupport
			,CURRENT_TIMESTAMP AS [DateTime]		
			,al.WalletType
			,al.RefCode
			,al.SettlementStatus AS SettlementStatus
			,al.ActualStake
			,CASE 
				WHEN al.eventstatus <> @eventstatus_completed AND al.statusID IN (111, 112, 113) AND ISNULL(al.betdaqid,0) <> -2
						THEN CASE
								WHEN @sporttype = 1
										AND EXISTS (SELECT TOP 1 1
													FROM #InstantSettlementBettypes
													WHERE bettype = al.bettype)
										THEN 1
								WHEN @sporttype = 2 
									AND EXISTS (SELECT TOP 1 1
												FROM #InstantSettlementBettypes
												WHERE bettype = al.bettype AND (betid = al.betid OR al.betid IS NULL))
									THEN 1
								ELSE 0
							END
				ELSE 0
			END AS IsInstantSettlementTicket
			,@sporttype AS SportTypeId
			,al.SiteDBGroupId
			,al.matchid AS MatchId
			,@LeagueGroupID AS LeagueGroupID
			,ISNULL(si.IsChinaView,0) AS IsChinaView
			,ISNULL(si.SpecialPlatfrom,0) AS SpecialPlatform --2: JollyView
			,al.modds AS MasterOdds
		FROM #SpecialDeleteBets al
			INNER JOIN #CTE_CustInfo ci WITH(NOLOCK) ON al.custid = ci.custid
			INNER JOIN #CTE_CustInfo cr WITH(NOLOCK) ON	al.creator = cr.custid	
			INNER JOIN #CTE_CustInfo ag WITH(NOLOCK) ON al.recommend = ag.custid
			INNER JOIN #CTE_CustInfo ma WITH(NOLOCK) ON al.mrecommend = ma.custid
			INNER JOIN #CTE_CustInfo su WITH(NOLOCK) ON al.srecommend = su.custid
			LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) ON al.srecommend = s.custid
			LEFT JOIN CustDB.dbo.Site si WITH(NOLOCK) ON su.site = si.site
		ORDER BY ISNULL(al.MainTransId, al.transid)
			   , CASE WHEN al.BonusID IS NOT NULL
					THEN CASE WHEN al.MainTransId IS NULL THEN 1
						ELSE 2 END
					ELSE al.transid
				 END
		DROP TABLE #CTE_CustInfo
	END	
	
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	       
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, @MatchId, GETDATE(),@SubmittedDate)
        END        
	END TRY
	BEGIN CATCH
	END CATCH

	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'
							,@MatchId AS '@MatchId'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.'
								+ @LogData
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT


	DROP TABLE #tblBettype
	DROP TABLE #tblBetType_Detail
	DROP TABLE #tblTransIds
	DROP TABLE #tblMatchProcess
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #SpecialDeleteBetsm
	DROP TABLE #BeforeUpd  
	DROP TABLE #AfterUpd 
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tblMatchParlayProcess

END