/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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
	@TransIds				VARCHAR(MAX)	= ''
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
			/>
		 <BetTypes/>'
	*/
BEGIN
	SET NOCOUNT ON;
	
	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidSingleBet_Update '
					+ CASE WHEN @MatchId IS NULL THEN '' ELSE '@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
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
					+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END

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
			,@transInfo XML 

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MainParlay_MaxPO	VARCHAR(MAX) = NULL
	
	DECLARE @session			NVARCHAR(50)
		   ,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalSubParlay		INT = 0

	DECLARE @CustIds			VARCHAR(MAX) = ''

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
		OddsSpread		MONEY,
		OddsId			INT,
		Transdesc		NVARCHAR(2000)
	)					
	
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #BeforeUpd (custid INT,balance MONEY)
	CREATE TABLE #AfterUpd(custid INT, balance MONEY)  
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	CREATE TABLE #BetDelete (
		grouptransid		BIGINT,
		transid				BIGINT PRIMARY KEY, 
		custid				INT, 
		recommend			INT, 
		mrecommend			INT, 
		srecommend			INT, 
		betfrom				NVARCHAR(3),
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
		FilterOddsSpread	MONEY,
		FilterOddsId		INT,
		FilterTransdesc	    NVARCHAR(2000),
		FilterOdds			MONEY,
		ActualStake			MONEY,
		main_ruben			TINYINT,
		main_custId			INT,
		OddsId				INT,
		SiteDBGroupId		SMALLINT
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
		SubOddsSpread		MONEY,
		SubOddsId			INT,
		SiteDBGroupId		SMALLINT
	)

	CREATE TABLE #CTE_CustInfo(custid INT, username VARCHAR(30), username2 VARCHAR(50), site VARCHAR(10), currency TINYINT)
	
	DECLARE @LogData NVARCHAR(500)
			,@CountTransId	INT

	DECLARE @tmpTrans_beforeUpd AS TABLE (transid BIGINT, custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, status VARCHAR(20), Bonusid INT, WalletType TINYINT, betdaqid BIGINT)
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY)
	
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
	DECLARE @SettlementStatus TINYINT = NULL, @sporttype SMALLINT = NULL, @ParentID INT = NULL, @ChildMatchType TINYINT = NULL
	SELECT @SettlementStatus = m.SettlementStatus
		   ,@Eventdate = m.eventdate 
		   ,@sporttype = m.sporttype
		   ,@ParentID = ISNULL(m.ParentID, 0)
		   ,@ChildMatchType = ISNULL(m.ChildMatchType, 0)
	FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId

	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
	IF @Eventdate <= @Movebetdate
	BEGIN
		SELECT 99 AS ErrorCode
		     , 'Match is under Movebet process, could not void ticket.' AS ErrorMsg
			 , @NegativeBalanceUsers AS NegativeBalanceUsers

		RETURN	
	END	
			
	-- Check password	
	IF NOT EXISTS (SELECT 1
					FROM custDB.dbo.customer WITH(NOLOCK)
					WHERE userpwd = @UserPassword
						AND custid = @UserID
						AND roleid>=5)
	BEGIN
		SELECT @LogData ='fail to void bet for matchid ' + CONVERT(VARCHAR(20), @MatchId) + ' reason: ' + @Reason
			
		EXEC WriteLog_UserLog 
			@UserID = @UserID, 
			@Doing	= @LogData
			
		SELECT 101 AS ErrorCode
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
		SELECT	101 AS ErrorCode
				, 'Invalid TransIds.' AS ErrorMsg	
				, @NegativeBalanceUsers AS NegativeBalanceUsers
		
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
			 , t.c.value('@OddsSpread', 'VARCHAR(500)') AS OddsSpread	-- Check columns : OddsSpread	 ; single value + multi-choice
			 , t.c.value('@OddsId','VARCHAR(1000)') AS OddsId			-- check columns : OddsId		 ; single value + multi-choice
			 , t.c.value('@Transdesc','NVARCHAR(2000)') AS Transdesc	-- check columns : Transdesc	 ; single value + multi-choice
		FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	),
	CTE_ParsedBettypes AS
	(
		SELECT cte.Id
			 , bt.value AS BetTeam 
			 , cte.[Set]
			 , cte.Game
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
		FROM CTE_ParsedBettypes_1 cte
			 CROSS APPLY STRING_SPLIT(cte.betteam, ',') bt
			 CROSS APPLY STRING_SPLIT(cte.BetOption, ',') bop
			 CROSS APPLY STRING_SPLIT(cte.[Value], ',') v
			 CROSS APPLY STRING_SPLIT(cte.ValueHdp1, ',') vhdp1
			 CROSS APPLY STRING_SPLIT(cte.OddsSpread, ',') os
			 CROSS APPLY STRING_SPLIT(cte.OddsId, ',') osid
			 CROSS APPLY STRING_SPLIT(cte.Transdesc, ',') td
	)	 
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc)
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
		 , cte.OddsId
		 , cte.Transdesc
	FROM CTE_ParsedBettypes cte		 		
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))	

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(bettype	SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes(bettype)
	
		--> Get status of match
		SELECT @IsHTCal = ISNULL(IsHTCal, 0)		 
		FROM match_remark (NOLOCK)
		WHERE matchid = @MatchId
	
		SELECT @eventstatus = ISNULL(eventstatus, '')
		FROM match (NOLOCK)
		WHERE matchid = @MatchId		
	
		--> Build bettype list supported for instant settlement based on settlement status of match
		IF @eventstatus <> @eventstatus_completed
		BEGIN
			IF @IsHTCal = 0
				INSERT INTO #InstantSettlementBettypes(bettype)
				SELECT T.bettype
				FROM dbo.f_TVS_GetInstantBettypes() T
				WHERE T.InstantType IN (1, 3) -- 01, 11
			ELSE
				INSERT INTO #InstantSettlementBettypes(bettype)
				SELECT T.bettype
				FROM dbo.f_TVS_GetInstantBettypes() T
				WHERE T.InstantType IN (2, 3) -- 10, 11			
		END	 	
	END			
	
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
	 
		-- Tuning EC2021
		INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
		SELECT @MatchId, bm.refno
		FROM #tblTransIds t 
			INNER LOOP JOIN dbo.bettransm bm WITH (NOLOCK) ON t.transid = bm.transid 
		WHERE bm.matchid  = @matchid  
			AND bm.statusID NOT IN (101, 102, 103)

		SET @totalSubParlay = @@ROWCOUNT
		IF @totalSubParlay > 0 
			SET @isExistParlay = 1
	END 

	EXEC dbo.NAP_Set_GlobalSettingSel 
			 @LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @matchid AS matchid, 1 AS KeyID WHERE @isExistSingle = 1 
	UNION ALL
	SELECT @MatchId AS matchid, 6 AS KeyId WHERE @isExistFM = 1
	UNION ALL
	SELECT @MatchId AS matchid, 7 AS KeyId WHERE @isExistFM2 = 1

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

			RETURN		
		END	
	END

	-- Apply for move match Cricket
	--Single & Parlay
	IF EXISTS ( SELECT TOP 1 1 
				FROM #tblTransIds t
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.transid = t.transid
				WHERE matchid <> @MatchId
			)
		OR EXISTS ( SELECT TOP 1 1 
				FROM #tblTransIds t
					INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON bm.transid = t.transid
				WHERE bm.matchid  <> @matchid  
			)
	BEGIN
		SELECT 99 AS ErrorCode
			, 'Some tickets not found.' AS ErrorMsg
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

		RETURN;
	END

	------------------***** Insert all data into #BetDelete *****------------------
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
			AND b.statusID NOT IN (101, 102, 103)
			AND b.betfrom <> 'p'
			AND b.SiteDBGroupID = @SiteDBGroupID
		
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
				,SubOddsId
				,SiteDBGroupId
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
				CASE WHEN bm.bettype = 646 THEN ABS(bm.hdp2) ELSE bm.hdp2 END AS SubHdp2, --646: Match Handicap & Total
				bm.odds As SubOdds,
				CASE WHEN bm.bettype = 229 THEN ABS(bm.oddsspread) ELSE bm.oddsspread END AS SubOddsSpread, -- 229:SABA HDP Time Machine
				bm.oddsid
				,bm.SiteDBGroupID
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
				AND bm.statusID NOT IN (101, 102, 103)
				AND bm.betfrom <> 'p'
				AND bm.SiteDBGroupID = @SiteDBGroupID
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
				,FilterOddsId
				,FilterTransdesc
				,ExtraInfo
				,ActualStake
				,main_ruben
				,main_custId
				,OddsId
				,SiteDBGroupId
				,FilterOdds
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
			WHERE tp.Id = b.FilterBettype 
				AND (	tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%' ))

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

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND (tp.OddsId IS NULL OR b.FilterOddsId = tp.OddsId))

		DELETE b
		FROM  #BetDelete b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
			WHERE tp.Id = b.FilterBettype AND  (tp.Transdesc IS NULL OR b.FilterTransdesc = tp.Transdesc))

		IF @OddsFilter IS NOT NULL
		BEGIN
			DELETE b
			FROM #BetDelete b
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
	------------------***** End of insert all data into #BetDelete *****------------------
	--------------------------------------------------------------------------------------			
	 --check no data
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete) AND NOT EXISTS (SELECT TOP 1 1 FROM #BetDeletem))
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
			INNER JOIN #BetDelete tmpmain ON main.transid = tmpmain.transid AND main.transid = tmpmain.grouptransid AND main.matchid = @matchid

		-- 1.4.  BackUp bettransm tickets into zzzbettrans
		INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
				winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID
		)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype , SYSDATETIME(), b.SiteDBGroupID
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r ON r.SubTransId=b.transid

		-- 1.5.  BackUp bettransm tickets into zzzbettransm
		INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				 winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
				 winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype , SYSDATETIME(), b.SiteDBGroupID
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r ON r.SubTransId=b.transid   
		
		-- Step 2: Update bettrans
		-- 2.1. Update normal tickets
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
						deleted.status
				INTO @tmpTrans_beforeUpd (transid, custid, winlost, actual_stake, playercomm, Bonusid, WalletType, betdaqid, status)
		FROM	dbo.bettrans main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #BetDelete tmpmain 
				ON	main.transid = tmpmain.transid 
				AND main.transid = tmpmain.grouptransid
				AND main.matchid = @matchid
		

		SET @transInfo = (
			SELECT	t.transId AS '@t'
					, b.winlost AS '@w'
					, b.ruben AS '@r'
					, b.creator AS '@cr'
					, b.awinlost AS '@aw'
					, b.mwinlost AS '@mw'
					, b.swinlost AS '@sw'
					, b.playercomm AS '@pc'
					, b.comm AS '@c'
					, b.acomm AS '@ac'
					, b.scomm AS '@sc'
					, b.statusID AS '@sid'
					, b.status AS '@s'
					, b.betid AS '@bid'
					, b.ExtraInfo AS '@ex'
					, b.FcUpdateTime AS '@rut'
			FROM	#BetDelete t 
				INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
			FOR XML PATH('r'),ROOT('root'), TYPE)
		
		IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
		BEGIN
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
			SELECT 'TVS', 'VoidSingleBet', 'bettrans', 'U', @matchid, @transInfo
		END

		-- Capture balance before updating Bettrans - New code for CO new Model
		INSERT INTO @BeforeUpd (matchid, custid, balanceType, BonusID, WalletType, balance)
		SELECT	@MatchId AS matchid
			  , tmp.custid
			  , 1 AS balanceType
			  , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			  , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			  , SUM (tmp.winlost - tmp.actual_stake + tmp.playercomm) AS balance
		FROM @tmpTrans_beforeUpd tmp
		GROUP BY custid
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets
		
		--> capture Before Balance Update		
		INSERT INTO #BeforeUpd(custid, balance)
		SELECT	b.custid , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM @tmpTrans_beforeUpd b
		GROUP BY b.CustID

		--Correct data captured before because CO happen when voiding ticket
		IF EXISTS (SELECT TOP(1) 1 FROM #BetDelete	b
						INNER JOIN @tmpTrans_beforeUpd t ON t.transid = b.transid
					WHERE b.IsCashOut = 0 AND t.betdaqid = -2 )
		BEGIN
			UPDATE b
			SET b.status = t.status
				, b.WinLost = t.winlost - t.actual_stake
				, b.ActualStake = t.actual_stake
				, b.betdaqid = -2
				, b.IsCashOut = 1
			FROM #BetDelete b 
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
			
			SET @transInfo = NULL
			SET @transInfo = (
					SELECT	transId AS '@t'
							, matchid AS '@mid'
							, STATUS AS '@s'
							, winlost AS '@w'
					FROM	@tmpTransInfo WHERE matchid = @MatchId 
					FOR XML PATH('r'),ROOT('root'), TYPE)

			IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
				SELECT 'TVS', 'VoidSingleBet', 'zzzbettrans', 'U', @matchid, @transInfo 
			END
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
			SELECT	main.custid
				  , main.BonusID
				  , main.WalletType
				  , main.winlost, main.actual_stake, main.playercomm
			FROM	dbo.bettrans main WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain
					ON	main.transid = tmpmain.transid 
						AND main.transid = tmpmain.grouptransid
						AND main.matchid = @matchid
			
		) tmp
		GROUP BY custid
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets

		---INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			  @BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd	
			, @ActionId				= 0			
		
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
					SELECT 100 AS ErrorCode
						, ERROR_MESSAGE()  AS ErrorMsg
						, @NegativeBalanceUsers AS NegativeBalanceUsers

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

				--Prepare for Max Payout
				SELECT @MainParlay_MaxPO = (SELECT t.main_custId AS '@custid'
									,t.main_ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #BetDelete t
								WHERE bettype = 29
								GROUP BY main_custId, main_ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)

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
					SELECT 100 AS ErrorCode
						, ERROR_MESSAGE()  AS ErrorMsg
						, @NegativeBalanceUsers AS NegativeBalanceUsers

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

		-- Update CashOutSelling [#165097]
		UPDATE c
		SET CashOutStatus = 6 --Void
		   ,ChangeDate = GETDATE()
		FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #BetDelete b ON c.TransID = b.transid AND c.MatchID = @MatchId
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
		DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL

		SET @MatchId_MaxPO = CASE WHEN @sporttype = 50 AND @ParentID <> 0 AND @ChildMatchType = 200 THEN @ParentID ELSE @MatchId END

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
					WHERE bettype NOT IN (29,2799)
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
		-------------------------------------------------------
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

		--1. Table return error code/ msg
		SELECT @ErrCode AS ErrorCode
			,@ErrMsg AS ErrorMsg
			,@NegativeBalanceUsers AS NegativeBalanceUsers
		
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
		INSERT INTO #CTE_CustInfo(custid, username, username2, site, currency)
		SELECT ci.custid
			, ci.username
			, ci.username2
			, ci.site
			, ci.currency
		FROM CustDB.dbo.Customer ci WITH(NOLOCK)
			INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid		
		
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
			,@SettlementStatus AS SettlementStatus
			,al.ActualStake
			,CASE 
				WHEN @eventstatus <> @eventstatus_completed
						THEN CASE
								WHEN al.statusID IN (111, 112, 113) AND ISNULL(al.betdaqid,0) <> -2
										AND EXISTS (SELECT TOP 1 1
													FROM #InstantSettlementBettypes
													WHERE bettype = al.bettype)
										THEN CAST(1 AS BIT)
								ELSE CAST(0 AS BIT)
							END
				ELSE CAST(0 AS BIT)
			END AS IsInstantSettlementTicket
			,@sporttype AS SportTypeId
			,al.SiteDBGroupId
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

	DROP TABLE #tblBettype
	DROP TABLE #tblTransIds
	DROP TABLE #tblMatchProcess
	DROP TABLE #BetDelete
	DROP TABLE #BetDeletem
	DROP TABLE #BeforeUpd  
	DROP TABLE #AfterUpd 
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tblMatchParlayProcess

END