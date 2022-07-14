/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverBet]
(
	@TransIds			VARCHAR(MAX), 	
	@UserId				INT,	
	@IP					VARCHAR(50),
	@ErrCode			INT				= 0		OUTPUT,
	@ErrMsg				NVARCHAR(200)	= ''	OUTPUT,
	@AutoReSettledTransIds   VARCHAR(MAX)	= '' OUTPUT
)
AS
/*
	Created: Kathy
	Date: 20131022
	DB: DBTXN/bodb02

	Revisions:   				   
		- 20140102@Kathy: - Add username2 column [Redmine:#10270]
		- 20140121@Elodie: Apply LAS system for special delete function [Redmine:#10701]
		- 20140210@Kathy: Correct winlost value
		- 20141017@Kathy: Support recover Sportting Solution bettypes [Redmine:#23129] (1301 -> 1324)
		- 20141125@Kathy: Add betid column [Redmine:#26489]	
		- 20141204@Kathy: Remove codes which are used in checking permission on DBPolicy [Redmine:#27058]	
		- 20150210@Kathy: allow the recovery of the "voided tickets" which have the winloss date before yesterday [Redmine:#30298]
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20150615@Dominic: BetTrade Integration 	[Redmine:#36964]
		- 20150630@Dominic: Add metric gaming bettype bettypes [Redmine:#38200]
        - 20150821@Kathy: Correct balance pending debit [Redmine:#40736]
		- 20150810@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20150917@Patrick: #43565: Show error-message in case user clicks void button but no tickets are found
		- 20151008@Kathy: insert bettrade tickets to send API [Redmine:#43233]
		- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 1)[Redmine:#43233]
		- 20151102@Kathy: Enhance performance [Redmine:#43233]
        - 20151209@Kathy: - get translog.siteid for MG API [Redmine:#49019]
						  - update bettypetime for 801
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20160706@Kathy: Get Refno for Lucky Single Ticket [Redmine:#55272]
		- 20160809@Bobby: #61984 - Apply new bussiess terms for bettrade bettype[904]
		- 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
		- 20161221@Kathy: Release lock after recovering tickets [Redmine:#68960]
		- 20170317@Kent: Integrate cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20180308@Helen: Recover sportbook bet - Cannot get ticket Super Live due to wrong table join [Redmine:#91543]
		- 20180306@Kathy: get Refcode value for Bonus [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread and Remove DateTime Column- Fast Markets Phase 2 [Redmine:#90667]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181004@Alan: Add new column SettlementStatus [102423]
		- 20190220@Alan: Support New Ticket Status Abnormal Bet [106654]
		- 20190419@Kathy: Change KeyId = 6 for FastMarket [Redmine:#108826]
		- 20190529@Raymond.Le: Implement recover for ScoreBox bettype (468, 469) [Redmine:#108826]
		- 20190305@Alan: Implement Bet Builder - [106898]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20190719@Raymond.Le: Extend days recover ticket unlimited [#115376]
		- 20191015@Raymond.Le: Remove <ab="1"> in ExtraInfo when recover AbnormalBet 468, 469 [#122065]
		- 20191101@Charles: Remove column IsMarked [122187]
		- 20191209@Charles: Add Column SportType to output tables [124675]
		- 20200507@Charles: PHAIO 5.1 for Penalty [132985]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20210514@July: SD - Remove unused code/products [Redmine: #121752]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]
		- 20220118@July: HotFix - Recover Cash Out Transaction NOT CALC PlayerComm for tickets double Comm [Redmine: #167687]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
		- 20220712@Kathy: Do not using SELECT INTO [Redmine:#175349]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;		
	
	DECLARE @LogData			NVARCHAR(500)
			,@Remark			VARCHAR(500) = ''
			,@today				DATETIME
			,@isExistMatch		BIT = 1
			,@isExistMG			BIT = 0
			,@isExistFM			BIT = 0
			,@IsExistBB			BIT = 0
			,@avaiableProcess	BIT	= 0
			,@isExistFM2		BIT = 0
			,@Movebetdate		DATETIME  
			,@RepUpdateTime		DATETIME2

	DECLARE @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)

	SELECT	@ErrCode = 0
			,@ErrMsg = ''

	CREATE TABLE #tblTransInfo (
		grouptransid	BIGINT
		,transid		BIGINT PRIMARY KEY
		,custid			INT
		,username		VARCHAR(30)
		,username2		VARCHAR(50)
		,transdate		DATETIME
		,odds			MONEY
		,oddsspread 	MONEY
		,oddstype		TINYINT
		,bettype		SMALLINT
		,winlost		money
		,betteam		NVARCHAR(10)
		,betcheck		NVARCHAR(50)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,betfrom		NVARCHAR(1)
		,stake			MONEY
		,matchid		INT
		,IsLiveIndicator	BIT
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,creator		INT
		,creatorName	VARCHAR(30)
		,currencyName	NVARCHAR(50)
		,status			VARCHAR(20)
		,leagueid		INT
		,SportType		TINYINT
		,homeid			INT
		,awayid			INT
		,betid			BIGINT
		,transdesc		NVARCHAR(1000)
		,refno			BIGINT	
		,betdaqid		BIGINT
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,SecAcceptFlag	BIT
		,site			VARCHAR(10)
		,ExtraInfo		VARCHAR(1000)
		,IsCashOut		BIT DEFAULT 0
		,zzzBetcheck	NVARCHAR(50)
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT		
		,MainTransId	BIGINT
		,winlostdate	DATETIME
		,ParentID		INT
		,ChildMatchType TINYINT
		,zzzwinlost		MONEY
		,modds			MONEY
		,ActualStake	MONEY
	)

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,matchid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)
	
	CREATE INDEX IX_#tblTransInfo_RefCode ON #tblTransInfo(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	CREATE TABLE #tbTransId (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	CREATE TABLE #t_match_completed(inputtransid BIGINT, custid INT, transdate DATETIME, odds MONEY, stake MONEY, winlost MONEY, status NVARCHAR(10))
	CREATE TABLE #CTE_bettrans(transid BIGINT, custid INT, transdate DATETIME, odds MONEY
		,oddsspread MONEY, oddstype TINYINT, bettype SMALLINT, actual_stake MONEY
		,betteam NVARCHAR(10), betcheck NVARCHAR(50), hdp1 SMALLMONEY, hdp2 SMALLMONEY, betfrom NVARCHAR(1), stake MONEY
		,matchid INT, liveindicator BIT, livehomescore SMALLINT, liveawayscore SMALLINT, CurrencyName NVARCHAR(50)
		,betid BIGINT, transdesc NVARCHAR(1000), refno BIGINT, betdaqid BIGINT, recommend INT, mrecommend INT, srecommend INT
		,SecAcceptFlag BIT, ExtraInfo VARCHAR(1000), IsCashOut BIT, WalletType TINYINT
		,RefCode BIGINT, BonusID INT, MainTransId BIGINT, winlostdate SMALLDATETIME
	)

	DECLARE @tblBeforeBalance TVP_BalanceWalletChange
		  , @tblAfterBalance  TVP_BalanceWalletChange

	BEGIN TRY
		INSERT INTO #tbTransId (transid)
		SELECT	s.value 
		FROM	STRING_SPLIT(isnull(@TransIds, ''), ',') s
		
		-- MG tickets
		INSERT INTO #tblTransInfo(
				grouptransid	
				,transid		
				,custid					
				,transdate		
				,odds
				,oddsspread
				,oddstype		
				,bettype		
				,winlost		
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2			
				,betfrom		
				,stake			
				,matchid		
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore	
				,creator		
				,currencyName	
				,status					
				,betid			
				,transdesc		
				,refno					
				,betdaqid
				,recommend
				,mrecommend
				,srecommend
				,SecAcceptFlag
				,zzzBetcheck
				,WalletType
				,RefCode
				,BonusID
				,winlostdate
				,zzzwinlost
				,modds
				,ActualStake
		)
		SELECT	z.transid
				,z.transid
				,z.custid
				,b.transdate
				,b.odds
				,b.oddsspread
				,b.oddstype
				,b.bettype
				,z.winlost - b.actual_stake
				,b.betteam
				,b.betcheck
				,b.hdp1
				,b.hdp2
				,b.betfrom
				,b.stake
				,b.matchid
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,z.creator
				,b.CurrencyName
				,z.status
				,b.betid
				,b.transdesc
				,b.refno
				,b.betdaqid
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.SecAcceptFlag
				,z.betcheck AS zzzBetcheck
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.winlostdate
				,z.winlost AS zzzwinlost
				,b.modds
				,b.actual_stake  AS ActualStake
		FROM	#tbTransId t			
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.transid = b.refno
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.refno = z.refno	
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype
		WHERE z.bettype BETWEEN 801 AND 806
		
		-- Normal tickets
		INSERT INTO #tblTransInfo(
				grouptransid	
				,transid		
				,custid					
				,transdate		
				,odds
				,oddsspread				
				,oddstype		
				,bettype		
				,winlost		
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2			
				,betfrom		
				,stake			
				,matchid		
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore	
				,creator		
				,currencyName	
				,status					
				,betid			
				,transdesc		
				,refno					
				,betdaqid
				,recommend
				,mrecommend
				,srecommend
				,SecAcceptFlag
				,ExtraInfo
				,IsCashOut
				,zzzBetcheck
				,WalletType
				,RefCode
				,BonusID
				,winlostdate
				,zzzwinlost
				,modds
				,ActualStake
		)
		SELECT	z.transid
				,z.transid
				,z.custid
				,b.transdate
				,b.odds
				,b.oddsspread
				,b.oddstype
				,b.bettype
				,z.winlost - b.actual_stake
				,b.betteam
				,b.betcheck
				,b.hdp1
				,b.hdp2
				,b.betfrom
				,b.stake
				,b.matchid
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,z.creator
				,b.CurrencyName
				,z.status
				,b.betid
				,b.transdesc
				,b.refno
				,b.betdaqid
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.SecAcceptFlag
				,b.ExtraInfo
				,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
				,z.betcheck AS zzzBetcheck
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,m.eventdate
				,z.winlost AS zzzwinlost
				,b.modds
				,b.actual_stake AS ActualStake
		FROM	#tbTransId t		
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.transid = b.transid
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = b.matchid
		WHERE	z.bettype NOT BETWEEN 801 AND 806
				AND (m.sporttype BETWEEN 1 AND 99 OR m.sporttype = 154)
				AND b.betfrom <> 'p'
				AND ISNULL(z.comstatus,'') <> 'CO'
		
		-- Outright
		INSERT INTO #tblTransInfo(
				grouptransid	
				,transid		
				,custid					
				,transdate		
				,odds	
				,oddsspread				
				,oddstype		
				,bettype		
				,winlost		
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2			
				,betfrom		
				,stake			
				,matchid		
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore	
				,creator		
				,currencyName	
				,status					
				,betid			
				,transdesc		
				,refno					
				,betdaqid
				,recommend
				,mrecommend
				,srecommend
				,SecAcceptFlag
				,leagueid
				,homeid
				,awayid
				,zzzBetcheck
				,WalletType
				,RefCode
				,BonusID
				,winlostdate
				,SportType
				,ActualStake
		)
		SELECT	z.transid
				,z.transid
				,z.custid
				,b.transdate
				,b.odds
				,b.oddsspread
				,b.oddstype
				,b.bettype
				,z.winlost - b.actual_stake
				,b.betteam
				,b.betcheck
				,b.hdp1
				,b.hdp2
				,b.betfrom
				,b.stake
				,b.matchid
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,z.creator
				,b.CurrencyName
				,z.status
				,b.betid
				,b.transdesc
				,b.refno
				,b.betdaqid
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.SecAcceptFlag
				,o.leagueid
				,o.teamid
				,0 AS awayid
				,z.betcheck AS zzzBetcheck
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,o.eventdate
				,l.sporttype
				,b.actual_stake AS ActualStake
		FROM	#tbTransId t			
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.transid = b.transid
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype			
			INNER JOIN dbo.outright o WITH(NOLOCK)
				ON o.orid = b.matchid
			INNER JOIN dbo.League l WITH (NOLOCK) ON o.leagueid = l.leagueid
		WHERE	z.bettype = 10
				AND b.betfrom <> 'p'
				
		-- Insert more bonus or cash ticket in case only one ticket appears in #tblTransInfo		
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, matchid, bettype, transid)
		SELECT RefCode, custid, matchid, bettype, MAX(transid)
		FROM #tblTransInfo
		WHERE RefCode IS NOT NULL
		GROUP BY RefCode, CustId, matchid, Bettype 
		HAVING COUNT(*) = 1
		
		IF @@ROWCOUNT > 0
		BEGIN
			
			INSERT INTO #CTE_bettrans(transid,custid,transdate,odds,oddsspread,oddstype,bettype
							,actual_stake,betteam,betcheck,hdp1
							,hdp2,betfrom,stake,matchid,liveindicator,livehomescore
							,liveawayscore,CurrencyName,betid,transdesc
							,refno,betdaqid,recommend,mrecommend
							,srecommend,SecAcceptFlag,ExtraInfo,IsCashOut	
							,WalletType,RefCode,BonusID,MainTransId,winlostdate)
			SELECT	 b.transid
					,b.custid
					,b.transdate
					,b.odds
					,b.oddsspread
					,b.oddstype
					,b.bettype
					,b.actual_stake
					,b.betteam
					,b.betcheck
					,b.hdp1
					,b.hdp2
					,b.betfrom
					,b.stake
					,b.matchid
					,b.liveindicator
					,b.livehomescore
					,b.liveawayscore		
					,b.CurrencyName				
					,b.betid
					,b.transdesc
					,b.refno
					,b.betdaqid
					,b.recommend
					,b.mrecommend
					,b.srecommend
					,b.SecAcceptFlag
					,b.ExtraInfo
					,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut				
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,r.transid AS MainTransId
					,b.winlostdate
			FROM #tmpRefCodeSummary r
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)					 
						 ON b.RefCode = r.RefCode
							AND b.transid <> r.transid
							AND b.matchid = r.matchid
							AND b.custid = r.custid
							AND b.bettype = r.bettype		
		
			INSERT INTO #tblTransInfo(
					grouptransid	
					,transid		
					,custid					
					,transdate		
					,odds
					,oddsspread					
					,oddstype		
					,bettype		
					,winlost		
					,betteam		
					,betcheck		
					,hdp1			
					,hdp2			
					,betfrom		
					,stake			
					,matchid		
					,IsLiveIndicator
					,livehomescore	
					,liveawayscore	
					,creator		
					,currencyName	
					,status					
					,betid			
					,transdesc		
					,refno					
					,betdaqid
					,recommend
					,mrecommend
					,srecommend
					,SecAcceptFlag				
					,ExtraInfo
					,IsCashOut
					,zzzBetcheck			
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
					,winlostdate
					,ActualStake
			)
			SELECT	 z.transid
					,z.transid
					,z.custid
					,b.transdate
					,b.odds
					,b.oddsspread
					,b.oddstype
					,b.bettype
					,z.winlost - b.actual_stake
					,b.betteam
					,b.betcheck
					,b.hdp1
					,b.hdp2
					,b.betfrom
					,b.stake
					,b.matchid
					,b.liveindicator
					,b.livehomescore
					,b.liveawayscore
					,z.creator
					,b.CurrencyName
					,z.status
					,b.betid
					,b.transdesc
					,b.refno
					,b.betdaqid
					,b.recommend
					,b.mrecommend
					,b.srecommend
					,b.SecAcceptFlag
					,b.ExtraInfo
					,b.IsCashOut
					,z.betcheck AS zzzBetcheck
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,b.MainTransId
					,b.winlostdate
					,b.actual_stake AS ActualStake
			FROM #CTE_bettrans b WITH (NOLOCK)
				 INNER JOIN dbo.zzzbettrans z WITH (NOLOCK)
						 ON	z.transid = b.transid
							AND z.custid = b.custid
							AND z.matchid = b.matchid					
							AND z.bettype = b.bettype
		END			 								
		
		/*Modify the way to get move bet date*/
		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

		IF EXISTS ( SELECT TOP 1 1 FROM #tblTransInfo WHERE winlostdate <= @Movebetdate )
		BEGIN
			SELECT @ErrCode = 102
				 , @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

			RETURN	
		END			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100,
				@ErrMsg = 'Invalid TransIds'						
						
		RETURN
	END CATCH

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tblTransInfo)
	BEGIN
		SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'				
		
		RETURN
	END

	;WITH CTE_matchProcess AS (
		SELECT	matchid
			, CASE 
				WHEN Bettype <> 38 AND  bettype NOT BETWEEN 801 AND 806 AND f.GroupId IS NULL THEN 1 --SB
				WHEN bettype BETWEEN 801 AND 806 THEN 3 --MG
				WHEN f.GroupId = 1 THEN 6
				WHEN Bettype = 38 THEN 5 -- Bet Builder
				WHEN f.GroupId = 2 THEN 7 -- Fast market 228
				ELSE 0 END AS KeyId
		FROM #tblTransInfo b
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	)
	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT matchid, KeyId
	FROM CTE_matchProcess
	GROUP BY matchid, KeyId
	
	SELECT @isExistMatch 	= MAX(CASE WHEN KeyId = 1 THEN 1 ELSE 0 END )
		, @isExistMG 		= MAX(CASE WHEN KeyId = 3 THEN 1 ELSE 0 END )
		, @isExistFM 		= MAX(CASE WHEN KeyId = 6 THEN 1 ELSE 0 END )
		, @isExistBB		= MAX(CASE WHEN KeyId = 5 THEN 1 ELSE 0 END)
		, @isExistFM2		= MAX(CASE WHEN KeyId = 7 THEN 1 ELSE 0 END)
	FROM #tblMatchProcess
	
	-- checking SD proccess
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @isExistMG 		= @isExistMG
		, @isExistFM 		= @isExistFM
		, @isExistBB		= @isExistBB
		, @isExistFM2		= @isExistFM2
		, @spName			= @spName
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		
		RETURN
	END
	
	INSERT INTO @tblBeforeBalance(matchid, custid, balanceType, BonusID, WalletType, balance)
	SELECT matchid
		 , custid
		 , CASE WHEN bettype BETWEEN 801 AND 806 THEN 4 ELSE 1 END AS BalanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) AS balance
	FROM   
	(
		-- normal, main bettrade, main cash-out, cash-out member bet ticket
		SELECT b.matchid, b.custid
			 , b.BonusID
			 , b.WalletType
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype
		FROM   dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tblTransInfo t
				ON	b.transid = t.grouptransid
					AND b.transid = t.transid
					AND b.matchid = t.matchid		
	) tmp
	GROUP BY matchid
		   , custid
		   , CASE WHEN bettype BETWEEN 801 AND 806 THEN 4 ELSE 1 END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END	
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets	

	DECLARE @newBettypeTime VARCHAR(50) = ''

	UPDATE t 
		SET	leagueid = m.leagueid
			,homeid = m.homeid
			,awayid = m.awayid
			,SportType = m.sporttype
			,ParentID = CASE WHEN m.sporttype = 50 THEN ISNULL(m.ParentID,0) ELSE 0 END
			,ChildMatchType = CASE WHEN m.SportType = 50 THEN ISNULL(m.ChildMatchType, 0) ELSE 0 END
	FROM	#tblTransInfo t
		INNER JOIN dbo.match m WITH(NOLOCK) ON	t.matchid = m.matchid

	---- recover : normal (NOT IN 468, 469), main bettrade, main cash-out, cash-out member bet ticket
	SET @RepUpdateTime = SYSDATETIME()
	UPDATE main
	SET winlost = 0
	    ,ruben = 0
	    ,statuswinlost = NULL
	    ,STATUS = 'running'
	    ,statusID = 0
	    ,creator = t.creator
		,actual_stake = CASE WHEN main.bettype BETWEEN 801 AND 806 THEN 0 ELSE main.actual_stake END
		,odds = CASE WHEN main.bettype = 376 THEN main.oddsspread ELSE main.odds END
		,@newBettypeTime = (SELECT TOP 1 custom1 FROM DBPRO.bodb02.dbo.ResultDetail3rd WITH(NOLOCK) WHERE resultId = main.betid)
		,transdesc = CASE WHEN main.bettype = 801 AND @newBettypeTime <> ''
							THEN STUFF(main.transdesc,CHARINDEX('bettypetime',main.transdesc)+12,CHARINDEX(';time',main.transdesc)-CHARINDEX('bettypetime',main.transdesc)-12,@newBettypeTime)       
							ELSE main.transdesc END
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',main.ExtraInfo,t.SportType, main.bettype)
		,RepUpdateTime  = @RepUpdateTime
	FROM bettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t ON main.transid = t.grouptransid AND main.transid = t.transid
	WHERE t.bettype NOT IN (468, 469)
		AND ISNULL(main.betdaqid, 0) <> -2


	--Update CashOutSelling for new CO Model
	IF EXISTS (SELECT TOP(1) 1 FROM #tblTransInfo WHERE IsCashOut = 1)
	BEGIN

		--> re-calculate stake, re-settle for main cash-out + update cash-out bet ticket			
		;WITH CTE_main_cashoutticket AS
		(
			SELECT transid
				 , 1 AS TicketType	 
				 , modds
				 , Stake	
				 , zzzwinlost AS winlost
				 , status
				 , CASE WHEN status = 'WON' THEN '112' 
									WHEN status = 'LOSE' THEN '113' 
									WHEN status = 'DRAW' THEN '111' 
								END AS StatusId
				 , creator
				 , SportType
			FROM #tblTransInfo
			WHERE IsCashOut = 1
		)
		UPDATE	b WITH(ROWLOCK, UPDLOCK)
		SET status = t.status
		  , statusID = t.StatusId
		  , stake = TRef.stake
		  , winlost = t.winlost
		  , awinlost = TCal.awinlost
		  , mWinLost = TCal.mWinLost
		  , swinlost = TCal.swinlost
	  
		  , playercomm = TCal.playercomm
		  , comm = TCal.comm
		  , acomm = TCal.acomm
		  , scomm = TCal.scomm

		  , ruben = b.ruben
		  , creator = t.creator
		  , ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',b.ExtraInfo,t.SportType, b.bettype)
		  , RepUpdateTime  = @RepUpdateTime
		FROM dbo.bettrans b 
			INNER JOIN CTE_main_cashoutticket AS t
					ON b.transid = t.transId	    			
			OUTER APPLY (
							SELECT b.stake
								 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 0 ELSE 1 END AS CommWinRate
								 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 2 ELSE 1 END AS CommLostRate
						) AS TRef		
			OUTER APPLY (SELECT t.winlost AS winlost
							 , CASE
									
									WHEN t.StatusId = 103 THEN 0
									WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.apositiontaking
									WHEN t.StatusId = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.apositiontaking
								END AS awinlost
							, CASE
									WHEN t.StatusId = 103 THEN 0
									WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.mpositiontaking
									WHEN t.StatusId = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.mpositiontaking
								END AS mWinLost
							, CASE
									WHEN t.StatusId = 103 THEN 0
									WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.spositiontaking
									WHEN t.StatusId = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.spositiontaking
								END AS swinlost
							  , CASE
									WHEN t.StatusId = 103 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.playerdiscount
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.playerdiscount
									ELSE TRef.CommLostRate * b.stake * b.playerdiscount
								END AS playercomm
							, CASE
									WHEN t.StatusId = 103 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.discount * (1-apositiontaking)
								END AS comm
							,CASE
									WHEN t.StatusId = 103 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
								END AS acomm
							,CASE
									WHEN t.StatusId = 103 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
								END AS scomm
						) AS TCal	
		
		--Update CO Selling
		UPDATE co
		SET co.CashOutStatus = 4
		   ,ChangeDate = GETDATE()
		FROM dbo.CashOutSelling co WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblTransInfo t ON co.transid = t.grouptransid AND co.transid = t.transid
		WHERE t.IsCashOut = 1
			AND co.CashOutStatus = 6
	END
	
	---- recover: bettype ScoreBox (468, 469)
	SET @RepUpdateTime = SYSDATETIME()
	;WITH CTE_Betcheck_1
	AS (
		SELECT t.transid
			,ROW_NUMBER() OVER (ORDER BY transid ASC) AS id
			,b.value AS betop
		FROM #tblTransInfo AS t
			CROSS APPLY STRING_SPLIT(t.betcheck, ',') AS b
		WHERE t.bettype IN (468, 469)
		)
		,CTE_Betcheck_2
	AS (
		SELECT b.transid
			,b.id
			,ROW_NUMBER() OVER (PARTITION BY b.id ORDER BY transid ASC) AS rank -- ([1]:[2])
			,CAST(op.value AS MONEY) AS value
		FROM CTE_Betcheck_1 AS b
			CROSS APPLY STRING_SPLIT(b.betop, ':') AS op
		)
		,CTE_Betcheck_Odds
	AS (
		SELECT t.transid AS transid
			,MIN(odds.value) AS odds
		FROM CTE_Betcheck_2 AS t
			LEFT JOIN CTE_Betcheck_2 AS odds ON t.transid = odds.transid
			AND t.id = odds.id
			AND odds.rank = 2
		GROUP BY t.transid
		)
		,CTE_Betcheck_Final
	AS (
		SELECT o.transid
			,score.value AS score
			,o.odds
		FROM CTE_Betcheck_Odds AS o
			LEFT JOIN CTE_Betcheck_2 AS t ON t.transid = o.transid
			AND t.rank = 2
			AND t.value = o.odds
			LEFT JOIN CTE_Betcheck_2 AS score ON score.transid = o.transid
			AND score.id = t.id
			AND score.rank = 1
		)
	UPDATE main WITH(ROWLOCK, UPDLOCK)
	SET winlost = 0
	    ,ruben = 0
	    ,statuswinlost = NULL
	    ,STATUS = 'running'
	    ,statusID = 0
	    ,creator = t.creator
		,odds = bc.odds
		,oddsspread = bc.score
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',main.ExtraInfo,t.SportType, main.bettype)
		,RepUpdateTime  = @RepUpdateTime
	FROM bettrans main 
		INNER JOIN #tblTransInfo t ON main.transid = t.grouptransid AND main.transid = t.transid
		LEFT JOIN CTE_Betcheck_Final AS bc ON bc.transid = t.transid
	WHERE t.bettype IN (468, 469)

	--update translog
	UPDATE tl
	SET    STATUS = 'running',
	       statusID = 0,
	       creator = t.creator,
	       @newBettypeTime = (SELECT TOP 1 custom1 FROM DBPRO.bodb02.dbo.ResultDetail3rd WITH(NOLOCK) WHERE resultId = tl.custom3),
		   transdesc = CASE WHEN tl.gameID = 801 AND @newBettypeTime <> ''
								THEN STUFF(tl.transdesc,CHARINDEX('bettypetime',tl.transdesc)+12,CHARINDEX(';time',tl.transdesc)-CHARINDEX('bettypetime',tl.transdesc)-12,@newBettypeTime)       
							 ELSE tl.transdesc 
							 END
	FROM   translog tl  WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t
			ON	tl.translogid = t.refno
				AND t.bettype BETWEEN 801 AND 806

	-- Re-Cal Bet Builder
	IF(@IsExistBB = 1)
	BEGIN
		BEGIN TRY
			CREATE TABLE #BetBuilderTransId(TransId BIGINT PRIMARY KEY);
			INSERT INTO #BetBuilderTransId
			SELECT b.TransId FROM #tblTransInfo b
			WHERE b.bettype = 38;

			DECLARE @xmlData xml;
			SET @xmlData = (SELECT TransId AS [@Id] FROM #BetBuilderTransId 
			FOR XML PATH('Resource'), ROOT('Resources'));

			DECLARE @Resources VARCHAR(MAX) = CAST(@xmlData AS VARCHAR(MAX));

			EXEC dbo.NAP_Admin_Settlement_BetBuilder_Recover
				@AdminId = @UserId, @Resources = @Resources, @Ip = @Ip
				,@ErrCode	= @ErrCode	OUTPUT
				,@ErrMsg	= @ErrMsg	OUTPUT
			
			SET @AutoReSettledTransIds = ''			
			SELECT @AutoReSettledTransIds = @AutoReSettledTransIds
											+ CASE WHEN @AutoReSettledTransIds <> '' THEN ',' ELSE '' END
											+ CAST(t.Transid AS VARCHAR(100))
			FROM #BetBuilderTransId t
				 INNER JOIN bettrans b (NOLOCK) ON t.TransId = b.transid
			WHERE b.statusID IN (111, 112, 113, 103)

			DROP TABLE #BetBuilderTransId;
		END TRY 
		BEGIN CATCH
			SELECT @ErrCode = 38
				,@ErrMsg = 'Called NAP_Admin_Settlement_BetBuilder_Recover with error.'
		END CATCH
	END
	
	-- get data after update
	INSERT INTO @tblAfterBalance(matchid, custid, balanceType, BonusID, WalletType, balance)
	SELECT matchid
		 , custid
		 , CASE WHEN bettype BETWEEN 801 AND 806 THEN 4 ELSE 1 END AS balanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm)	AS balance
	FROM   
	(
		-- normal, main bettrade, main cash-out, cash-out member bet ticket
		SELECT b.matchid, b.custid
			 , b.BonusID
			 , b.WalletType
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype
		FROM   dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tblTransInfo t
				ON	b.transid = t.grouptransid
					AND b.transid = t.transid
					AND b.matchid = t.matchid
		WHERE	b.bettype NOT BETWEEN 801 AND 806
		
		UNION ALL
		
		SELECT t.matchid, tl.custid
			 , 0 AS BonusID -- running metric gaming tickets always bet from cash wallet
			 , 2 AS WalletType -- running metric gaming tickets always bet from cash wallet
			 , 0 AS winlost, tl.actual_stake, 0 AS playercomm, tl.gameID AS bettype
		FROM   dbo.translog tl WITH(NOLOCK)
			INNER JOIN #tblTransInfo t
				ON	tl.translogid = t.refno
		WHERE	tl.gameID BETWEEN 801 AND 806
		
	) tmp
	GROUP BY matchid
		   , custid
		   , CASE WHEN bettype BETWEEN 801 AND 806 THEN 4 ELSE 1 END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets	
	
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @tblBeforeBalance
		, @BalanceWalletAfter	= @tblAfterBalance
		, @ActionId				= 0		
	
	---- list ticket: match is completed
	INSERT INTO #t_match_completed(inputtransid, custid, transdate, odds, stake, winlost, status)
	select	t.transid AS inputtransid,
			t.custid,
			t.transdate,
			t.odds,
			t.stake,
			t.winlost,
			t.status
	from	#tblTransInfo t
		inner JOIN match m WITH(NOLOCK) 
			ON	t.matchid = m.matchid
	where	m.eventstatus = 'completed'
			and t.bettype NOT IN (10, 38)
	UNION ALL
	select	t.transid AS inputtransid,
			t.custid,
			t.transdate,
			t.odds,
			t.stake,
			t.winlost,
			t.status
	from #tblTransInfo t
		inner JOIN outright o WITH(NOLOCK) 
			ON	t.matchid = o.orid
	where o.oddsstatus = 'completed'
	and t.bettype = 10			  
	
	UPDATE t 
		SET username = c.username
			,username2 = c.username2 
			,creatorName = cr.username
			,site = ag.site
	FROM	#tblTransInfo t
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON	t.custid = c.custid
		INNER JOIN CustDB.dbo.Customer cr WITH(NOLOCK)
			ON	t.creator = cr.custid
		INNER JOIN CustDB.dbo.Customer ag WITH(NOLOCK)
			ON	t.recommend = ag.custid
	
	UPDATE t
		SET transdesc = b.transdesc
	FROM	#tblTransInfo t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON	b.transid = t.transid
				AND b.matchid = t.matchid
				AND b.bettype = t.bettype 
				AND b.bettype BETWEEN 801 AND 806
	
	-- delete normal : normal, main bettrade, main cash-out, cash-out member bet ticket
	DELETE main
	FROM   zzzbettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t 
			ON	main.transid = t.transid
				AND main.custid = t.custid
				AND main.matchid = t.matchid
				AND main.bettype = t.bettype
				AND main.transid = t.grouptransid
				AND ISNULL(main.comstatus,'') <> 'CO'
	
	------ release data of TempVariableNumBer table
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMG 			= @isExistMG
		, @isExistMatch		= @isExistMatch
		, @isExistFM 		= @isExistFM
		, @isExistBB		= @isExistBB
		, @isExistFM2		= @isExistFM2
		, @IsReleased		= 1						
	
	DECLARE @IsITAdmin BIT = 0
	
	
	----------------Insert Max Payout Queue----------------
	DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL, @sporttype SMALLINT = NULL, @ParentID INT= NULL, @ChildMatchType TINYINT = NULL
	DECLARE @Match_tmp AS TABLE (matchId INT, sporttype SMALLINT, ParentID INT, ChildMatchType TINYINT, IsFinish BIT)

	INSERT INTO @Match_tmp (MatchId, sporttype, ParentID, ChildMatchType)
	SELECT DISTINCT t.matchid, t.sporttype, t.ParentID, t.ChildMatchType
	FROM #tblTransInfo t
		
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
				FROM #tblTransInfo b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
				WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype
				FOR XML PATH('r'), ROOT('root')
			)

		SET @MatchId_MaxPO = CASE WHEN @sporttype = 50 AND @ParentID <> 0 AND @ChildMatchType = 200 THEN @ParentID ELSE @MatchId_MaxPO END
		
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Recover
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO
	END
	-------------------------------------------------------
	
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
	
	;WITH CTE
	AS
	(	
		SELECT	t.grouptransid
				,t.site
				,CASE WHEN t.bettype BETWEEN 801 AND 806 THEN t.refno ELSE t.transid END transid
				,t.username
				,t.username2
				,t.transdate
				,t.odds
				,t.oddsspread
				,t.oddstype
				,t.bettype
				,t.winlost
				,t.betteam
				,t.betcheck
				,t.hdp1
				,t.hdp2
				,t.betfrom
				,t.stake
				,t.matchid
				,t.SportType
				,t.IsLiveIndicator
				,t.livehomescore
				,t.liveawayscore
				,t.creatorName AS creator
				,t.currencyName
				,t.status
				,t.leagueid
				,t.homeid
				,t.awayid				
				,t.betid
				,t.transdesc
				,t.refno
				,t.betdaqid
				,t.ExtraInfo
				,t.custid
				--,NULL AS SiteId
				,CASE
					WHEN T1.isExists = 1
						 OR (T2.isExists = 1 
							 AND @IsITAdmin = 0 -- Check UserID not in IT group
							 )
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				 END AS IsReal
				,CASE
					WHEN T1.isExists = 1 
						 AND @IsITAdmin = 1
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				 END AS IsItSupport
				,CASE
					WHEN T2.isExists = 1 
						 AND @IsITAdmin = 1
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				 END AS IsItQa
				,IsCashOut
				,CASE WHEN t.IsCashOut = 0 AND t_m.inputtransid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isSettled
				,t.WalletType
				,t.BonusID
				,t.MainTransId
				,t.RefCode
				,t.ActualStake
		FROM #tblTransInfo t
			 OUTER APPLY (SELECT TOP 1 1 AS isExists
						  FROM CustDB.dbo.Customer c WITH(NOLOCK) 
						  WHERE c.currency <> 20 
							AND c.roleid = 4 
							AND c.custid = t.srecommend) AS T1
			 OUTER APPLY (SELECT TOP 1 1 AS isExists
						  FROM CustDB.dbo.Customer c WITH(NOLOCK) 
						  WHERE c.currency = 20 
							AND c.roleid = 4 
							AND c.custid = t.srecommend) AS T2
			 LEFT JOIN #t_match_completed AS t_m
					ON t.transid = t_m.inputtransid
	)
	SELECT  t.site
			,t.transid
			,t.username
			,t.username2
			,t.transdate
			,t.odds
			,t.oddsspread
			,t.oddstype
			,t.bettype
			,t.winlost
			,t.betteam
			,t.betcheck
			,t.hdp1
			,t.hdp2
			,t.betfrom
			,t.stake
			,t.matchid
			,t.SportType
			,t.IsLiveIndicator
			,t.livehomescore
			,t.liveawayscore
			,t.creator
			,t.currencyName
			,t.status
			,t.leagueid
			,t.homeid
			,t.awayid			
			,t.betid
			,t.transdesc
			,t.refno
			,t.betdaqid
			,t.ExtraInfo
			,t.custid
			--,t.SiteId
			,t.IsReal
			,t.IsItSupport
			,t.IsItQa
			,t.IsCashOut
			,t.isSettled
			,t.WalletType
			,t.RefCode
			,m.SettlementStatus
			,m.GlobalShowTime
			,t.ActualStake
	FROM CTE t
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = t.matchid
	ORDER BY site
		   , ISNULL(t.MainTransId, t.transid)
		   , CASE WHEN t.BonusID IS NOT NULL
				THEN CASE WHEN t.MainTransId IS NULL THEN 1 ELSE 2 END
				ELSE t.transid
			 END		

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
	FROM	#tblTransInfo tmp
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON	tmp.transid = b.transid
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON tl.translogid = tmp.refno
	WHERE tmp.Bettype BETWEEN 801 AND 806  
	
	
	SELECT @LogData = 'Recover bet have transid: ' + @TransIds + ' IP: ' + @Ip
	
	EXEC WriteLog_UserLog 
	     @UserId = @UserId,
	     @Doing = @LogData 				
		
	RETURN;
END