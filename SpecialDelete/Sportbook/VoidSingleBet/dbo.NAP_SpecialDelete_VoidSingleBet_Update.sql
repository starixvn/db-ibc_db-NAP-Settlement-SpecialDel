/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidSingleBet_Update]
	@MatchId				INT,
	
	@FromTransId			BIGINT = 0, 
	@ToTransId				BIGINT = 0,			
	
	@Bet					VARCHAR(10)		= NULL,
	@TimeType	 			SMALLINT 		= 0,
	@FromTransdate			DATETIME 		= NULL,
	@ToTransdate			DATETIME 		= NULL,

	@LiveIndicator 			SMALLINT 		= 0,
    @LiveHomeScore 			SMALLINT 		= NULL,
    @LiveAwayScore 			SMALLINT 		= NULL,		
    @BetTypes				XML				= NULL,
	
    @UserName 				NVARCHAR(50),
    @UserPassword			NVARCHAR(50),
    @UserID					INT,
    @IP						VARCHAR(15)		= '',
    @Reason					NVARCHAR(500)	= '',
	@ReasonSC				NVARCHAR(500)	= '',
	@SecondAcceptFlag		TINYINT			= 0 ,
    
	@TransIds				VARCHAR(MAX)	= '',
	@TransIdSolds			VARCHAR(MAX)	= '', -- just for BetTrade's subticket (transid of bettype 901)	
		
	@NegativeBalanceUsers	VARCHAR(MAX)	= ''	OUTPUT,
	@InvalidTransIds		VARCHAR(MAX)	= ''	OUTPUT, -- invalid trans of BTrade
	@ErrMsg					NVARCHAR(200)	= ''	OUTPUT,
    @ErrCode				INT				= 0		OUTPUT    

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
			/>
		 <BetTypes/>'
	*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @isITAdmin			BIT = 0
			,@isExistParlay		BIT = 0
			,@isExistBT			BIT = 0
			,@isExistCashOut	BIT = 0
			,@isExistSingle		BIT = 0
			,@isExistFM			BIT = 0
			,@isExistFM2		BIT = 0
			,@avaiableProcess	BIT = 0
	DECLARE @session			NVARCHAR(50)
	DECLARE @CustIds			VARCHAR(MAX) = ''
	SET @NegativeBalanceUsers = ''
	
	CREATE TABLE #tblBetType
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
		OddsSpread		MONEY
	)					
	
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblTransIdSolds (grouptransid BIGINT, transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	CREATE TABLE #NegativeBalance (transid BIGINT)
	CREATE TABLE #BeforeUpd (custid INT,balance MONEY)
	CREATE TABLE #AfterUpd(custid INT, balance MONEY)  

	CREATE TABLE #BetDelete (
		grouptransid		BIGINT,
		transid				BIGINT PRIMARY KEY, 
		custid				INT, 
		recommend			INT, 
		mrecommend			INT, 
		srecommend			INT, 
		betfrom				NVARCHAR(1),
		statusID			INT, 
		status				NVARCHAR(10), 
		username			VARCHAR(30),
		username2			VARCHAR(50),
		SecAcceptFlag		BIT, 
		creator				INT,
		hdp1 				SMALLMONEY,  
		hdp2 				SMALLMONEY,
		bettype 			SMALLINT,
		OriginalBetType		SMALLINT,
		betteam 			NVARCHAR(10),
		betcheck			NVARCHAR(50),
		odds				MONEY, 
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
		IsCashOutMemberTicket BIT DEFAULT 0,
		MainCashoutId		BIGINT,
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
		SubOdds				MONEY,
		FilterBettype		SMALLINT,
		FilterBetTeam		NVARCHAR(10), 
		FilterSet			VARCHAR(50),
		FilterGame			VARCHAR(50),
		FilterValue			SMALLMONEY,	
		FilterGoal			BIGINT,
		FilterBetOption		NVARCHAR(50),
		FilterHdp1		 	SMALLMONEY,
        FilterHdp2		 	SMALLMONEY,
		FilterOddsSpread	 MONEY
	)

	CREATE TABLE #BetDeletem (
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
		SubOddsSpread		MONEY
	)
	
	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)
	
	CREATE INDEX IX_BetDelete_RefCode ON #BetDelete(RefCode)	
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	DECLARE @tblInvalidTrans TABLE (transid BIGINT) -- store invalid BT transid
	DECLARE @tblCustBT902 TABLE (custid INT) --store BT's custid 
	DECLARE @tblCustCashOut912 TABLE (custid INT) --store Cash-Out's custid 
	
	CREATE TABLE #CashOutSubTicket
	(
		transid				BIGINT PRIMARY KEY,
		bettype				SMALLINT,
		OriginalBetType		SMALLINT,
		MainCashoutId		BIGINT,
		matchid				INT,
		MainTransId			BIGINT
	) -- store 911,912,913		
	
	DECLARE @LogData NVARCHAR(500)
			,@CountTransId	INT
	
	SELECT @ErrCode = 0
		 , @ErrMsg = ''
		 , @InvalidTransIds = ''
	
	SET @session = CAST (NEWID() AS NVARCHAR(50))
			
	-- Check password	
	IF NOT EXISTS (SELECT 1
					FROM custDB.dbo.customer WITH(NOLOCK)
					WHERE userpwd = @UserPassword
						AND custid = @UserID
						AND roleid>=5)
	BEGIN
		SELECT @LogData ='fail to void bet for matchid ' + CONVERT(VARCHAR(20), @MatchId)
		 + ' from ' + CONVERT(VARCHAR(20), @FromTransId) + ' to ' + CONVERT(VARCHAR(20), @ToTransId) + ' reason: ' + @Reason
			
		EXEC WriteLog_UserLog 
			@UserID = @UserID, 
			@Doing	= @LogData
			
		SELECT @ErrMsg = 'Sorry. You can not process void bet due to either wrong password or insufficient permission!'
			,@ErrCode  = 101								  
		
		RETURN
	END	
			
	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds,',')	
		OPTION (maxrecursion 0)
		
		SET @CountTransId = @@ROWCOUNT	
		
		IF ISNULL(@TransIdSolds,'') <> ''
			INSERT INTO #tblTransIdSolds(grouptransid, transid)
			SELECT  refno, transid
			FROM	dbo.bettrans sub WITH(NOLOCK)
			WHERE	transid IN (SELECT val FROM dbo.strSplit(@TransIdSolds,','))
					AND bettype = 901
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = 'Invalid TransIds.'										
		
		RETURN
	END CATCH	
	
	-- Parse xml @BetTypes	
	;WITH CTE_ParsedBettypes_1 AS
	(	
		SELECT t.c.value('@Id','SMALLINT') AS Id
			 , t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			 , t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
			 , t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
			 , t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			 , t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			 , t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1	 	 	 ; single-choice + multi-choice
			 , t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2	-- check columns : hdp2	 	 	 ; single-choice
			 , t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
			 , t.c.value('@OddsSpread', 'VARCHAR(20)') AS OddsSpread	-- Check columns : OddsSpread ; single value
		FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	),
	CTE_ParsedBettypes AS
	(
		SELECT cte.Id
			 , bt.val AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , bop.val AS BetOption
			 , CAST(CASE WHEN v.val = 'ALL' THEN 9999.00 
						ELSE v.val END AS SMALLMONEY) AS [Value]
			 , CAST(CASE WHEN vhdp1.val = 'ALL' THEN 9999.00 
						ELSE vhdp1.val END AS SMALLMONEY) AS ValueHdp1
			 , CAST(CASE WHEN cte.ValueHdp2 = 'ALL' THEN 9999.00 
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2				 
			 , CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal END AS BIGINT) AS Goal
			, CAST(CASE WHEN cte.OddsSpread = 'ALL' THEN 9999.00 
						ELSE cte.OddsSpread END AS MONEY) AS OddsSpread
		FROM CTE_ParsedBettypes_1 cte
			 CROSS APPLY dbo.strSplit(cte.betteam, ',') bt
			 CROSS APPLY dbo.strSplit(cte.BetOption, ',') bop
			 CROSS APPLY dbo.strSplit(cte.[Value], ',') v
			 CROSS APPLY dbo.strSplit(cte.ValueHdp1, ',') vhdp1
	)	 
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread)
	SELECT cte.Id
		 , cte.BetTeam
		 , cte.[Set]
		 , cte.Game
		 , cte.BetOption
		 , cte.[Value]
		 , cte.ValueHdp1
		 , cte.ValueHdp2
		 , cte.Goal
		 , cte.OddsSpread
	FROM CTE_ParsedBettypes cte		 		
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))	
	
	DECLARE @SettlementStatus TINYINT = NULL
	SELECT @SettlementStatus = m.SettlementStatus FROM dbo.match m WHERE m.matchid = @MatchId		
	
	-- check and not allow attempt to void tickets of this match while it's being calculated
	---------------------------------------------------------------------------	
	BEGIN 
		SELECT @isExistSingle = MAX(CASE WHEN f.GroupId IN (1,2) THEN 0 ELSE 1 END)
				,@isExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
				,@isExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)  
			INNER JOIN #tblTransIds t ON t.transid = b.transid  
			INNER JOIN #tblBettype tp ON tp.Id = b.bettype 
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
				)f
		WHERE b.matchid = @matchid 
	 
		SELECT TOP 1 @isExistParlay = 1  
		FROM #tblTransIds t 
			INNER LOOP JOIN dbo.bettransm bm WITH (NOLOCK) ON t.transid = bm.transid 
			INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON bm.refno = b.refno  
		WHERE b.matchid = 29  
			AND b.bettype = 29   
			AND bm.matchid  = @matchid  
	END 

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @matchid AS matchid, 1 AS KeyID WHERE @isExistSingle = 1 
	UNION ALL
	SELECT @MatchId AS matchid, 6 AS KeyId WHERE @isExistFM = 1
	UNION ALL
	SELECT @MatchId AS matchid, 7 AS KeyId WHERE @isExistFM2 = 1

	-- checking SD proccess
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistParlay		= @isExistParlay  
		,@isExistMatch		= @isExistSingle
		,@isExistFM			= @isExistFM
		,@isExistFM2		= @isExistFM2
		,@avaiableProcess 	= @avaiableProcess OUTPUT
		,@ErrCode			= @ErrCode OUTPUT
		,@ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN	
		RETURN		
	END		

	------------------***** Insert all data into #BetDelete *****------------------
	IF @FromTransId > 0
	BEGIN
		INSERT INTO #BetDelete (
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
			,MainCashoutId
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
			,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
				ELSE NULL END AS MainCashoutId
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
			,b.hdp2 AS FilterHdp2
			,b.oddsspread AS FilterOddsSpread
		FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
			 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON	t.transid = b.transid
		WHERE	b.matchid=@matchid 
			AND b.transid BETWEEN @FromTransId AND @ToTransId
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveindicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END 
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END 			
			AND ISNULL(b.SecAcceptFlag, 0)  = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag, 0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
			AND b.statusID NOT IN (101, 102)
			AND b.betfrom <> 'p'
		
		OPTION (OPTIMIZE FOR (@CountTransId = 1))
	END
	
	IF @Bet = 'All' OR @Bet = 'Single'
	BEGIN
		INSERT INTO #BetDelete (
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
			,MainCashoutId
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
			,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
				ELSE NULL END AS MainCashoutId
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
			,b.hdp2 AS FilterHdp2
			,b.oddsspread AS FilterOddsSpread
		FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
			 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON	t.transid = b.transid
		WHERE	b.matchid=@matchid 
			AND CASE
					WHEN @TimeType = 0 THEN b.transdate
					WHEN @TimeType = 1 AND b.checktime IS NOT NULL THEN b.checktime
					WHEN @TimeType = 1 AND b.checktime IS NULL THEN b.transdate
				END BETWEEN @FromTransdate AND @ToTransdate
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveindicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END 
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END 			
			AND ISNULL(b.SecAcceptFlag, 0)  = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag, 0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
			AND b.statusID NOT IN (101, 102)
			AND b.betfrom <> 'p'
		
		OPTION (OPTIMIZE FOR (@CountTransId = 1))
	END

	-- Search Parlay Tickets
	IF @Bet = 'All' OR @Bet = 'Sub Parlay'	
	BEGIN
		BEGIN
			INSERT INTO #BetDeletem (
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
			)
			SELECT
				bm.custid, 
				bm.oddsspread,
				bm.transdate,
				bm.checktime,
				bm.liveindicator,
				bm.livehomescore,
				bm.liveawayscore,
				bm.creator,
				bm.refno,
				bm.transdesc AS SubTransDesc,
				bm.transid AS SubTransId,
				bm.status AS SubStatus,
				bm.betcheck AS SubBetCheck,
				bm.betteam AS SubBetTeam,
				bm.bettype AS SubBetType,
				bm.hdp1 AS SubHdp1,
				bm.hdp2 AS SubHdp2,
				bm.odds As SubOdds,
				bm.oddsspread AS SubOddsSpread
			FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
				INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON t.transid = bm.transid
			WHERE
				bm.matchid=@MatchId 
				AND	CASE
						WHEN @TimeType = 0 THEN bm.transdate
						WHEN @TimeType = 1 AND bm.checktime IS NOT NULL THEN bm.checktime
						WHEN @TimeType = 1 AND bm.checktime IS NULL THEN bm.transdate
					END BETWEEN @FromTransdate AND @ToTransdate
				AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE bm.liveIndicator END = @LiveIndicator
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.statusID NOT IN (101, 102)
				AND bm.betfrom <> 'p'
		END
		
		BEGIN
			INSERT INTO #BetDelete (			
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
				bm.SubHdp2 AS FilterHdp2,
				ISNULL(bm.SubBetCheck, 0) AS FilterGoal,
				bm.SubOddsSpread AS FilterOddsSpread
			FROM #BetDeletem bm WITH (NOLOCK)
				INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.matchid = 29 AND bm.refno = b.refno
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
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
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
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%'  ))

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ) OR b.bettype = 29)

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.Filterhdp1 = tp.ValueHdp1 ))
		
		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.Filterhdp2 = tp.ValueHdp2 ))

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread ))
	END	
	------------------***** End of insert all data into #BetDelete *****------------------
	--------------------------------------------------------------------------------------		
	-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets	
	INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, transid)
	SELECT RefCode, custid, bettype, MAX(transid) transid
	FROM #BetDelete
	WHERE RefCode IS NOT NULL		
	GROUP BY RefCode, custid, bettype
	HAVING COUNT(*) = 1	
	
	IF @@ROWCOUNT > 0 
	BEGIN
		INSERT INTO #BetDelete(
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
				,ExtraInfo				
				,awinlost
				,MainCashoutId			
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
		)
		SELECT	b.transid
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
				,b.ExtraInfo				
				,b.awinlost
				,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
					ELSE NULL END AS MainCashoutId
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,r.transid AS MainTransId
				,b.WinLost - b.actual_stake AS WinLost
		FROM #tmpRefCodeSummary r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON b.RefCode = r.RefCode
						AND b.transid <> r.transid
						AND b.matchid = @MatchId
						AND b.custid = r.custid
						AND b.bettype = r.bettype
		WHERE b.statusID NOT IN (101,102 ) -- reject, void	
	END
	
	-- delete main ticket if it's BT but subticket is not exists in SOLD list
	DELETE
	FROM	#BetDelete
	OUTPUT	DELETED.grouptransid
	INTO	@tblInvalidTrans (transid)
	WHERE	grouptransid NOT IN (SELECT grouptransid FROM #tblTransIdSolds)
			AND betdaqid = 0 
			AND extrainfo is null
	
	-- delete main ticket if it's not BT but have subticket in SOLD list
	DELETE
	FROM	#BetDelete
	OUTPUT	DELETED.grouptransid
	INTO	@tblInvalidTrans
	WHERE	transid IN (SELECT grouptransid FROM #tblTransIdSolds)
			AND betdaqid = -1 
			AND extrainfo is null
	
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
				 ON bd.transid = rp.transid					
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
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete) AND NOT EXISTS (SELECT TOP 1 1 FROM #BetDeletem))
	BEGIN
		IF @InvalidTransIds = ''
			SELECT	@ErrCode = 99
					,@ErrMsg = 'No ticket found.'
		
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch	= @isExistSingle
			,@isExistParlay = @isExistParlay 
			,@IsReleased	= 1
			
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original' 
			  , @Action = 'Void'
			  , @IsReleased = 1								
	END
	ELSE
	BEGIN
		DELETE 
		FROM	#tblTransIdSolds 
		WHERE	grouptransid IN (SELECT transid FROM @tblInvalidTrans)				
		
		--- check exists BT + Cash-out or not
		SELECT @isExistBT 	= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
			 , @isExistCashOut = MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
		FROM #BetDelete
		
		------------------***** Begin Special Delete *****------------------		                                                                                                                                               
		DECLARE @BeforeUpd 	TVP_BalanceWalletChange
		DECLARE @AfterUpd 	TVP_BalanceWalletChange
		
		IF (@isExistBT = 1 AND EXISTS (SELECT TOP 1 1 FROM #tblTransIdSolds))
		BEGIN
			INSERT INTO #BetDelete (
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
				,OriginalBetType
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
				,ExtraInfo
				,awinlost
				,refno
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
			)	
			SELECT  
				tmpmain.transid
				,sub.transid
				,sub.custid
				,tmpmain.recommend
				,tmpmain.mrecommend
				,tmpmain.srecommend
				,tmpmain.betfrom
				,sub.statusid
				,'SOLD'
				,tmpmain.SecAcceptFlag
				,sub.creator
				,tmpmain.hdp1
				,tmpmain.hdp2
				,sub.bettype
				,tmpmain.bettype AS OriginalBetType
				,tmpmain.betteam
				,tmpmain.betcheck
				,tmpmain.odds
				,tmpmain.oddsspread
				,tmpmain.OddsType
				,sub.transdate
				,sub.checktime
				,tmpmain.IsLiveIndicator
				,tmpmain.livehomescore
				,tmpmain.liveawayscore
				,tmpmain.Stake
				,tmpmain.CurrencyName
				,tmpmain.bettype AS betid
				,tmpmain.betdaqid
				,tmpmain.ExtraInfo
				,sub.awinlost
				,sub.refno
				,sub.WalletType
				,sub.RefCode
				,sub.BonusID
				,tmpmain.transid AS MainTransId
				,sub.WinLost - sub.actual_stake AS WinLost
			FROM	dbo.bettrans sub WITH(NOLOCK)
				INNER JOIN #BetDelete tmpmain 
					ON	sub.refno = tmpmain.transid						
						AND tmpmain.betdaqid = 0
						AND tmpmain.extrainfo is null			
						AND sub.bettype = 901
						AND sub.matchid = @matchid
			WHERE sub.transid IN (SELECT transid FROM #tblTransIdSolds)
			
			--insert custBT 
			INSERT INTO @tblCustBT902( custid )
			SELECT sub902.custid
			FROM dbo.bettrans sub902 WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain with(NOLOCK) ON	sub902.refno = tmpmain.transid
						
			WHERE sub902.matchid 		= @matchid
				AND sub902.bettype 		= 902
				AND tmpmain.betdaqid 	= 0
				AND tmpmain.extrainfo is null
			GROUP BY sub902.custid
			
		END	
		
		IF (@isExistCashOut = 1)
		BEGIN
			-- insert cash-out sub ticket 911
			INSERT INTO #BetDelete (
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
				,OriginalBetType		
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
				,ExtraInfo
				,MainCashoutId
				,awinlost
				,refno
				,matchid
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
			)
			OUTPUT inserted.transid
				 , inserted.bettype 
				 , inserted.OriginalBetType
				 , inserted.MainCashoutId
				 , inserted.matchid
				 , inserted.MainTransId
					INTO #CashOutSubTicket(transid
										 , bettype
										 , OriginalBetType
										 , MainCashoutId
										 , matchid
										 , MainTransId)	
			SELECT  tmpmain.transid
					,sub.transid
					,sub.custid
					,tmpmain.recommend
					,tmpmain.mrecommend
					,tmpmain.srecommend
					,tmpmain.betfrom
					,sub.statusid
					,'Cash out'
					,tmpmain.SecAcceptFlag		
					,sub.creator						
					,tmpmain.hdp1
					,tmpmain.hdp2
					,sub.bettype
					,tmpmain.bettype AS OriginalBetType
					,tmpmain.betteam
					,tmpmain.betcheck
					,tmpmain.odds
					,tmpmain.oddsspread
					,tmpmain.OddsType
					,sub.transdate
					,sub.checktime
					,tmpmain.IsLiveIndicator
					,tmpmain.livehomescore
					,tmpmain.liveawayscore
					,sub.Stake
					,tmpmain.CurrencyName
					,tmpmain.bettype AS betid
					,sub.betdaqid
					,sub.ExtraInfo
					,tmpmain.transid AS MainCashoutId
					,sub.awinlost
					,sub.refno
					,sub.matchid
					,sub.WalletType
					,sub.RefCode
					,sub.BonusID
					,tmpmain.transid AS MainTransId
					,sub.WinLost - sub.actual_stake AS WinLost
			FROM	dbo.bettrans sub WITH(NOLOCK)
				INNER JOIN #BetDelete tmpmain 
					ON	sub.refno = tmpmain.transid	
						AND sub.custid = tmpmain.custid					
						AND tmpmain.betdaqid = 0
						AND charindex ('p25',tmpmain.extrainfo)> 0			
						AND sub.bettype = 911
						AND sub.matchid = @matchid	
			WHERE sub.statusID NOT IN (102, 101) -- VOID, REJECT						
			
			-- insert cash-out member bet tickets			
			INSERT INTO #BetDelete(
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
					,OriginalBetType		
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
					,ExtraInfo
					,IsCashOutMemberTicket
					,MainCashoutId
					,awinlost
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
					,WinLost
			)
			SELECT	b.transid
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
					,sub911.OriginalBetType
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
					,b.ExtraInfo
					,1 AS IsCashOutMemberTicket
					,sub911.MainCashoutId
					,b.awinlost
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,sub911.MainTransId
					,b.WinLost - b.actual_stake AS WinLost
			FROM #BetDelete sub911
			 CROSS APPLY (
							  SELECT b.transid
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
									,b.ExtraInfo
									,b.awinlost
									,b.WalletType
									,b.RefCode
									,b.BonusID
									,b.WinLost
									,b.actual_stake
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID NOT IN (102, 101) -- VOID, REJECT
						 ) AS b
			WHERE sub911.bettype = 911	
			
			-- insert 912,913
			INSERT INTO #CashOutSubTicket(transid, bettype, OriginalBetType, MainCashoutId, matchid, MainTransId)															
			SELECT sub_912_913.transid, sub_912_913.bettype, sub911.OriginalBetType, sub911.MainCashoutId, sub911.matchid, sub911.MainTransId
			FROM #CashOutSubTicket sub911
				 INNER JOIN dbo.bettrans sub_912_913 (nolock)
						 ON sub911.transid = sub_912_913.refno
							AND sub911.matchid = sub_912_913.matchid						    
							AND sub_912_913.bettype IN (912,913) 
							AND sub_912_913.statusID NOT IN (102, 101) -- VOID, REJECT
			
			-- insert custCashOut912
			INSERT INTO @tblCustCashOut912( custid )
			SELECT DISTINCT custid
			FROM #BetDelete						
			WHERE IsCashOutMemberTicket = 1								
		END

		--> capture Before Balance Update		
		INSERT INTO #NegativeBalance (transid)  
		SELECT	b.transid
		FROM  #BetDelete b WITH (NOLOCK)
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete sub911 (NOLOCK)
					  WHERE sub911.bettype = 911 AND sub911.transid = b.refno) -- exclude Cash out
			AND CASE WHEN b.betdaqid = 0 AND b.extrainfo IS NULL THEN 0 ELSE 1 END = 1 -- exclude BT member

		INSERT INTO #BeforeUpd(custid, balance)
		SELECT	b.custid , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE transid IN (SELECT transid FROM #NegativeBalance)			
		GROUP BY b.CustID

		
		-- Step 1: Backup into zzzbettrans
		-- 1.1. Backup normal, main bettrade, main cash-out, cash-out member bet ticket
		INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
					winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
					winlostdate,betfrom,betcheck,checktime,matchid, bettype)
		SELECT  main.transid, main.custid, CURRENT_TIMESTAMP, main.oddsid, main.hdp1, main.hdp2, main.odds, main.stake, main.status, 
				main.winlost, main.livehomescore, main.liveawayscore, main.liveindicator, main.betteam, main.creator , main.refno, 
				main.winlostdate, main.betfrom, 
				CASE
					WHEN (tmpmain.betdaqid = 0 AND charindex ('p25',tmpmain.extrainfo)> 0) -- main ticket is Cash-out
						 OR tmpmain.IsCashOutMemberTicket = 1 THEN @session
					ELSE main.betcheck
				END AS betcheck,
				main.checktime, main.matchid, main.bettype
		FROM	dbo.bettrans main WITH (nolock)
			INNER JOIN #BetDelete tmpmain ON main.transid = tmpmain.transid AND main.transid = tmpmain.grouptransid AND main.matchid = @matchid
		
		-- 1.2. Back up BetTrade's subtickets (901,902,903)
		IF (@isExistBT = 1)  
			INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
						winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
						winlostdate,betfrom,betcheck,checktime,matchid, bettype)
			SELECT  sub.transid, sub.custid, CURRENT_TIMESTAMP, sub.oddsid, sub.hdp1, sub.hdp2, sub.odds, sub.stake, sub.status, 
					sub.winlost, sub.livehomescore, sub.liveawayscore, sub.liveindicator, sub.betteam, sub.creator , sub.refno, 
					sub.winlostdate, sub.betfrom, sub.betcheck, sub.checktime, sub.matchid, sub.bettype
			FROM	dbo.bettrans sub WITH (nolock)
				INNER JOIN #BetDelete tmpmain ON sub.refno = tmpmain.transid AND sub.matchid = @matchid
			WHERE	sub.bettype IN (901, 902, 903)
					AND tmpmain.betdaqid = 0
					AND tmpmain.extrainfo is null
				
		-- 1.3. Back up Cash-out's subtickets (911,912,913) 
		IF (@isExistCashOut = 1)
			INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
						winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
						winlostdate,betfrom,betcheck,checktime,matchid, bettype)
			SELECT  b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, 
					b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno, 
					b.winlostdate, b.betfrom, 
					@session AS betcheck, 
					b.checktime, b.matchid, b.bettype
			FROM dbo.bettrans b WITH (nolock)
				 INNER JOIN #CashOutSubTicket sub ON b.transid = sub.transid		

		-- 1.4.  BackUp bettransm tickets into zzzbettrans
		INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
				winlostdate, betfrom, betcheck, checktime, matchid, bettype
		)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype  
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r ON r.SubTransId=b.transid

		-- 1.5.  BackUp bettransm tickets into zzzbettransm
		INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				 winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
				 winlostdate, betfrom, betcheck, checktime, matchid, bettype)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype  
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r ON r.SubTransId=b.transid   

		-- Capture balance before updating Bettrans
		INSERT INTO @BeforeUpd (matchid, custid, balanceType, BonusID, WalletType, balance)
		SELECT	@MatchId AS matchid
			  , custid
			  , 1 AS balanceType
			  , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			  , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			  , SUM (winlost - actual_stake + playercomm) balance
		FROM (
			-- normal, main bettrade, main cash-out, cash-out member bet ticket
			SELECT	main.custid
				  , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
				  , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
				  , main.winlost, main.actual_stake, main.playercomm
			FROM	dbo.bettrans main WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain
					ON	main.transid = tmpmain.transid 
						AND main.transid = tmpmain.grouptransid
						AND main.matchid = @matchid
			UNION ALL
			-- bettrade subticket (901,902,903)
			SELECT	sub.custid
				  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				  , sub.winlost, sub.actual_stake, sub.playercomm
			FROM	dbo.bettrans sub WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain with(NOLOCK)
					ON	sub.refno = tmpmain.transid
						AND sub.bettype BETWEEN 901 AND 910
						AND tmpmain.betdaqid = 0
						AND tmpmain.extrainfo is null
						AND sub.matchid = @matchid
			WHERE @isExistBT = 1
			UNION ALL
			-- cash-out subticket (911,912,913)	
			SELECT	b.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , b.winlost, b.actual_stake, b.playercomm
			FROM	dbo.bettrans b WITH (nolock)
				INNER JOIN #CashOutSubTicket sub ON b.transid = sub.transid
			WHERE @isExistCashOut = 1			
			UNION ALL
			-- bettrade summary 904
			SELECT	sub904.custid
				  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				  , sub904.winlost, sub904.actual_stake, sub904.playercomm
			FROM	dbo.bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp ON sub904.custid = temp.custid						
			WHERE sub904.matchid = @matchid AND sub904.bettype = 904
			UNION ALL
			-- cash-out summary 914
			SELECT	sub914.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , sub914.winlost, sub914.actual_stake, sub914.playercomm
			FROM	dbo.bettrans sub914 WITH (NOLOCK)
					INNER JOIN @tblCustCashOut912 temp ON sub914.custid = temp.custid						
			WHERE sub914.matchid = @matchid AND sub914.bettype = 914
		) tmp
		GROUP BY custid
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets
		
		-- Step 2: Update bettrans
		-- 2.1. Update normal, main bettrade, main cash-out, cash-out member bet ticket
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
		FROM	dbo.bettrans main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #BetDelete tmpmain 
				ON	main.transid = tmpmain.transid 
				AND main.transid = tmpmain.grouptransid
				AND main.matchid = @matchid
					
		IF (@isExistBT = 1)
		BEGIN
			-- 2.2.1. Update BetTrade's subtickets (901,902,903) 
			UPDATE	sub
				SET winlost			= sub.actual_stake
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
			FROM	dbo.bettrans sub WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #BetDelete tmpmain 
				ON	tmpmain.transid = sub.refno
					AND sub.bettype IN (901, 902, 903)
					AND tmpmain.betdaqid = 0
					AND tmpmain.extrainfo is null
					AND sub.matchid = @matchid								
			
			--Pre-CAL 904
			BEGIN TRY				
				DECLARE @CustIdsBT VARCHAR(MAX)
				SET @CustIdsBT = STUFF((SELECT ',' + CAST(tt.CustId AS VARCHAR(50))
										FROM #BetDelete tt 
										WHERE tt.betdaqid = 0
										  AND tt.extrainfo is null								    
										FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')											    
				EXEC dbo.NAP_Admin_Calculate_904 
						  @MatchId 	= @MatchID
						, @Action 	= 'VOID'
						, @CustIds 	= @CustIdsBT				
			END TRY 
			BEGIN CATCH
				SELECT @ErrCode = 904
					 , @ErrMsg = 'Called NAP_Admin_Calculate_904 with error.'
			END CATCH
		END
		
		IF (@isExistCashOut = 1)
		BEGIN
			-- 2.2.2. Update Cash-out's subtickets (911,912,913)
			UPDATE	b
				SET winlost			= b.actual_stake
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
			FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #CashOutSubTicket sub ON b.transid = sub.transid														
			
			--Pre-CAL 914
			BEGIN TRY				
				DECLARE @CustIdsCashOut VARCHAR(MAX)
				SET @CustIdsCashOut = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
											 FROM @tblCustCashOut912 tt								    
											 FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')											    
				EXEC dbo.NAP_Admin_Calculate_914 
						  @MatchId 	= @MatchID
						, @Action 	= 'VOID'
						, @CustIds 	= @CustIdsCashOut				
			END TRY 
			BEGIN CATCH
				SELECT @ErrCode = 914
					 , @ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
			END CATCH
		END
		
		-- Capture balance after updating Bettrans
		INSERT INTO @AfterUpd(matchid, custid, balanceType, BonusID, WalletType, balance)
		SELECT	@MatchId AS matchid
			  , custid
			  , 1 AS balanceType
			  , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			  , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			  , SUM (winlost - actual_stake + playercomm) balance
		FROM (
			-- normal, main bettrade, main cash-out, cash-out member bet ticket
			SELECT	main.custid
				  , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
				  , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
				  , main.winlost, main.actual_stake, main.playercomm
			FROM	dbo.bettrans main WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain
					ON	main.transid = tmpmain.transid 
						AND main.transid = tmpmain.grouptransid
						AND main.matchid = @matchid
			UNION ALL
			-- bettrade subticket (901,902,903)
			SELECT	sub.custid
				  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				  , sub.winlost, sub.actual_stake, sub.playercomm
			FROM	dbo.bettrans sub WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain with(NOLOCK)
					ON	sub.refno = tmpmain.transid
						AND sub.bettype BETWEEN 901 AND 910
						AND tmpmain.betdaqid = 0
						AND tmpmain.extrainfo is null
						AND sub.matchid = @matchid
			WHERE @isExistBT = 1
			UNION ALL
			-- cash-out subticket (911,912,913)	
			SELECT	b.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , b.winlost, b.actual_stake, b.playercomm
			FROM	dbo.bettrans b WITH (nolock)
				INNER JOIN #CashOutSubTicket sub ON b.transid = sub.transid
			WHERE @isExistCashOut = 1			
			UNION ALL
			-- bettrade summary 904
			SELECT	sub904.custid
				  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				  , sub904.winlost, sub904.actual_stake, sub904.playercomm
			FROM	dbo.bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp ON sub904.custid = temp.custid						
			WHERE sub904.matchid = @matchid AND sub904.bettype = 904
			UNION ALL
			-- cash-out summary 914
			SELECT	sub914.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , sub914.winlost, sub914.actual_stake, sub914.playercomm
			FROM	dbo.bettrans sub914 WITH (NOLOCK)
					INNER JOIN @tblCustCashOut912 temp ON sub914.custid = temp.custid						
			WHERE sub914.matchid = @matchid AND sub914.bettype = 914
		) tmp
		GROUP BY custid
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets

		---INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			  @BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd	
			, @ActionId				= 0			
		
		IF (@isExistBT = 1 OR @isExistCashOut = 1)
		BEGIN		
			-- STEP 3: Update BetTrade selling information
			CREATE TABLE #CustIdList ( custid INT PRIMARY KEY )
			
			CREATE TABLE #CustList ( custid INT PRIMARY KEY, Balance MONEY )
			
			INSERT INTO #CustIdList(custid)
			SELECT DISTINCT custid FROM #BetDelete
			
			INSERT INTO #CustList(custid, Balance)
			SELECT T.custid, SUM(T.Balance)
			FROM
			(
				SELECT	b.custid, b.winlost - b.actual_stake + b.playercomm AS Balance				
				FROM	dbo.bettrans b WITH(NOLOCK) 
					LEFT JOIN dbo.translog tl WITH(NOLOCK) ON	b.refno = tl.translogid AND b.matchid = tl.eventID					
				WHERE	b.custid IN (SELECT custid FROM #CustIdList)
						AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))						
				UNION ALL 
				SELECT	tl.custid, 0 - tl.actual_stake + 0 AS Balance 
				FROM	dbo.translog tl WITH(NOLOCK)
				WHERE	tl.custid IN (SELECT custid FROM #CustIdList) AND tl.statusID IN (0, 1)
				UNION ALL
				SELECT	custid, winlost - actual_stake + playercomm AS Balance
				FROM	dbo.bettransRnG WITH(NOLOCK)
				WHERE	custid IN (SELECT custid FROM #CustIdList) AND IsSum=0				
				UNION ALL
				SELECT	custid, winlost - actual_stake + playercomm AS Balance
				FROM	dbo.bettransLC WITH(NOLOCK)
				WHERE	custid IN (SELECT custid FROM #CustIdList) AND IsSum=0	
				UNION ALL
				SELECT bal.CustId, (Credit - Debit) AS Balance
				FROM dbo.BalNetPosition bal WITH(NOLOCK)
					INNER JOIN #BetDelete d ON bal.CustId = d.CustId AND bal.MatchId = @MatchId AND bal.Bettype = d.bettype	
				UNION ALL
				SELECT DISTINCT c.CustId, c.Credit AS Balance
				FROM DBCUST.custDB.dbo.custInfo c WITH(NOLOCK)						
					 INNER JOIN #CustIdList d ON c.CustId = d.CustId
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
								AND CASE WHEN tmpsub.bettype = 911 -- cash-out													 
										THEN CASE WHEN bts.SoldTicketID = tmpsub.transid THEN 1
											ELSE 0 END																							
										ELSE 1 END = 1	
					 INNER JOIN #CustList tcust ON tmpsub.custid = tcust.custid						 							
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
			
			--Step 5:  Insert bettrade tickets to send API
			IF (@isExistBT = 1)
				WITH cteMainTicket
				AS(
					SELECT  transid
					FROM	#BetDelete
					WHERE	betdaqid = 0
							AND extrainfo is null
							AND grouptransid = transid
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
		
		--------
		-- update totalbets
		DECLARE @Total TABLE (oddsid INT, HomeTotal MONEY, AwayTotal MONEY)
		INSERT INTO @Total
			SELECT oddsid,
				SUM(CASE WHEN betteam='h' THEN (CASE WHEN ABS(odds) > 1 THEN ABS(odds) 
						 ELSE 1 END * b.stake * e.actualrate * (1-b.tpositiontaking)) ELSE 0 END) homeTotal,
				SUM(CASE WHEN betteam='a' THEN (CASE WHEN ABS(odds) > 1 THEN ABS(odds) 
						 ELSE 1 END * b.stake * e.actualrate * (1-b.tpositiontaking)) ELSE 0 END) awayTotal
			FROM dbo.bettrans b WITH (nolock)
				INNER JOIN custDB.dbo.exchange e WITH (nolock) ON b.currency = e.exchangeid
			WHERE bettype IN (1,3,7,8) AND ruben = 0 AND oddsid <> 0 AND matchid = @MatchId
			GROUP BY oddsid

		UPDATE odds WITH (rowlock, updlock)
		SET hometotal = t.HomeTotal, awaytotal = t.AwayTotal
		FROM @Total t WHERE odds.oddsid = t.oddsid AND odds.matchid = @MatchId

		-- Update Parlay Tickets
		IF EXISTS (SELECT 1 FROM #BetDeletem)
		BEGIN
			DECLARE @matchdate		DATETIME
					,@match_tmp		VARCHAR(20)
					,@rowcount		INT
					,@step			INT
					,@transid_tmp	VARCHAR(2000)  

			SELECT	@matchdate = eventdate,  
					@match_tmp = CONVERT(VARCHAR(20),matchid),  
					@step = 0  
			FROM	match WITH(NOLOCK)   
			WHERE	matchid = @matchid  	

			DECLARE @transtbl TABLE (id INT IDENTITY, transid BIGINT)  
		
			INSERT INTO @transtbl (transid)  
			SELECT	SubTransId  
			FROM	#BetDeletem  
		   
			SELECT @rowcount = @@ROWCOUNT 
		 
			WHILE @step < @rowcount  
			BEGIN  
				SET @transid_tmp = ''  

				SELECT	@transid_tmp  = @transid_tmp + CONVERT(VARCHAR(20),transid)  + ','   
				FROM	@transtbl  
				WHERE	id > @step AND id <= @step + 100  
			 
				SET @step = @step + 100  

				EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchId  
				,@fth = 0  
				,@fta = 0  
				,@hth = 0  
				,@hta = 0  
				,@matchdate = @matchdate  
				,@mode = 'VOID'  
				,@VoidTransID = @transid_tmp  
				,@UserId = @UserId 
			END  

			IF EXISTS ( SELECT TOP 1 1  
						FROM #BetDelete r
							INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON	b.refno = r.refno  
						WHERE b.matchid = 29 AND b.bettype = 29  
			)   
			BEGIN 
				BEGIN TRY  
					DECLARE @transids_29 VARCHAR(MAX) = '' ,@refnos_29  VARCHAR(MAX) = '' 
				   
					SELECT	@transids_29 = @transids_29 + CONVERT(VARCHAR(20), transid) + ','  
					FROM	#BetDelete  
					WHERE	bettype = 29  
					GROUP BY transid
					
					EXEC dbo.NAP_Admin_Calculate_MP_broker   
						@matchid = @matchid  
						,@matchdate = @matchdate  
						,@strXML = @transids_29  
						,@mode  = 'PRECAL-29'
				END TRY  
				BEGIN CATCH   
					SELECT @ErrCode = 100, @ErrMsg = ERROR_MESSAGE()  
				END CATCH  

			---********* Calculate balance for system parlay********---  
				DECLARE @BeforeUpdSP	TVP_BalanceWalletChange
				DECLARE @AfterUpdSP		TVP_BalanceWalletChange

				--Get data before update  
				INSERT INTO @BeforeUpdSP (matchid, custid, balanceType, BonusID, WalletType, balance)  
				SELECT @MatchId AS matchid, b.custid, 1 AS balanceType, 0 AS BonusID, 2 AS WalletType, SUM(b.winlost - b.actual_stake + b.playercomm) balance
				FROM #BetDeletem r 
				 INNER HASH JOIN dbo.bettrans b WITH (NOLOCK)ON b.refno = r.refno  
				WHERE b.matchid = 29 AND b.bettype = 29  
				GROUP BY b.CustID  

				--Settlement System parlay (changed balance)  
				BEGIN TRY  
					SELECT  @refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
					FROM #BetDelete  
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
					SELECT @ErrCode = 100, @ErrMsg = ERROR_MESSAGE()  
				END CATCH  
		  
				--Get data after update  
				INSERT INTO @AfterUpdSP (matchid, custid, balanceType, BonusID, WalletType, balance)  
				SELECT @MatchId AS matchid
					 , b.custid  
					 , 1 AS balanceType
					 , 0 AS BonusID
					 , 2 AS WalletType
					 , SUM(b.winlost - b.actual_stake + b.playercomm) balance
				FROM  #BetDeletem r 
					INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = r.refno  
				WHERE b.matchid = 29 AND b.bettype = 29  
				GROUP BY b.CustID  

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
		WHERE transid IN (SELECT transid FROM #BetDelete)
		GROUP BY b.CustID

		SET @NegativeBalanceUsers = ''
		SELECT @CustIds = @CustIds + CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20), b.custid)
		FROM #BeforeUpd b
			 INNER JOIN	#AfterUpd a ON a.custid = b.custid
		WHERE b.balance > a.balance
		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
		 
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch	= @isExistSingle
			,@isExistFM		= @isExistFM
			,@isExistParlay = @isExistParlay 
			,@isExistFM2	= @isExistFM2
			,@IsReleased	= 1
		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original' 
			,@Action = 'Void'
			,@IsReleased = 1	
			
		------------------***** End of Special Delete *****------------------		 
		IF(@FromTransId > 0)
		BEGIN
			SELECT @LogData ='void bet for matchid ' + CONVERT(VARCHAR(20), @MatchId) 
						+ ' from ' + CONVERT(VARCHAR(20), @FromTransId) + ' to ' + CONVERT(VARCHAR(20), @ToTransId) 
						+ ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) + ' reason: ' + @Reason + ' - ' + @ReasonSC
		END
		ELSE
		BEGIN
			SELECT @LogData ='void bet for matchid ' + CONVERT(VARCHAR(20), @MatchId) 
						+ ' from ' + CONVERT(VARCHAR(25), @FromTransdate) + ' to ' + CONVERT(VARCHAR(25), @ToTransdate) 
						+ ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) + ' reason: ' + @Reason + ' - ' + @ReasonSC
		END				
		EXEC WriteLog_UserLog 
			@UserID = @UserID
			,@Doing = @LogData
		
		-- CHECK IT GROUP or NOT ?   
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
		
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
			, ci.currency
				INTO #CTE_CustInfo
		FROM CustDB.dbo.Customer ci WITH(NOLOCK)
			INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid		
		
		SELECT	al.odds
			,al.oddsspread
			,al.OddsType
			,al.transdate
			,al.checktime			
			,al.OriginalBetType
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
			,al.MainCashoutId
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
			-----------------------------	
			,al.custid
			,al.recommend
			,al.mrecommend
			,al.srecommend		
			,ci.username
			,ci.username2			
			,ag.UserName AS AgUserName
			,ma.UserName AS MagUserName
			,su.Username AS SagUserName
			---------------------------------------
			,CASE 
				WHEN al.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
				ELSE su.site 
			END AS EmailGroup
			,su.site 
			,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
			,CASE WHEN al.betdaqid = 0 AND al.extrainfo is null THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isBetTrade
			,CASE WHEN al.IsCashOutMemberTicket = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isCashOut
			,@isITAdmin	AS IsITSupport
			,CURRENT_TIMESTAMP AS [DateTime]		
			,al.WalletType
			,al.RefCode
			,@SettlementStatus AS SettlementStatus
		FROM	#BetDelete al
			INNER JOIN #CTE_CustInfo ci WITH(NOLOCK) ON al.custid = ci.custid
			INNER JOIN #CTE_CustInfo cr WITH(NOLOCK) ON	al.creator = cr.custid	
			INNER JOIN #CTE_CustInfo ag WITH(NOLOCK) ON al.recommend = ag.custid
			INNER JOIN #CTE_CustInfo ma WITH(NOLOCK) ON al.mrecommend = ma.custid
			INNER JOIN #CTE_CustInfo su WITH(NOLOCK) ON al.srecommend = su.custid
			LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) ON al.srecommend = s.custid
		ORDER BY ISNULL(al.MainTransId, al.transid)
			   , CASE WHEN al.BonusID IS NOT NULL
					THEN CASE WHEN al.MainTransId IS NULL THEN 1
						ELSE 2 END
					ELSE al.transid
				 END
		DROP TABLE #CTE_CustInfo
	END		
	
	DROP TABLE #tblBettype
	DROP TABLE #tblTransIds
	DROP TABLE #tblTransIdSolds
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblCashOutProcess
	DROP TABLE #CashOutSubTicket
	DROP TABLE #BetDelete
	DROP TABLE #BetDeletem
	DROP TABLE #BeforeUpd  
	DROP TABLE #AfterUpd 
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #NegativeBalance
	
END