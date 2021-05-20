/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverBet]
	@TransIds			VARCHAR(MAX),
	@TransIdSolds		VARCHAR(MAX)	= '', -- just for BetTrade's subticket (transid of bettype 901)  	

	@UserId				INT,	
	@IP					VARCHAR(50),
	
	@ErrCode			INT				= 0		OUTPUT,
	@ErrMsg				NVARCHAR(200)	= ''	OUTPUT,
	@InvalidTransIds	VARCHAR(MAX)	= ''	OUTPUT,
	@AutoReSettledTransIds   VARCHAR(MAX)	= '' OUTPUT
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
			,@isExistBT			BIT = 0
			,@isExistCashOut	BIT = 0
			,@IsExistBB			BIT = 0
			,@avaiableProcess	BIT	= 0
			,@isExistFM2		BIT = 0

	SELECT	@ErrCode = 0
			,@ErrMsg = ''
			,@InvalidTransIds = ''

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
		,OriginalBetType SMALLINT
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
		,IsBettrade		BIT DEFAULT 0
		,IsCashOut		BIT DEFAULT 0
		,IsCashOutMemberTicket BIT DEFAULT 0
		,MainCashoutId	BIGINT
		,zzzBetcheck	NVARCHAR(50)
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT		
		,MainTransId	BIGINT
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
	
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	
	DECLARE @tblCustBT902 TABLE (custid INT, matchid INT) --store BT's custid 
	DECLARE @tblCustCashOut912 TABLE (custid INT, matchid INT) --store Cash-out's custid 
	
	CREATE TABLE #CashOutSubTicket
	(
		transid				BIGINT PRIMARY KEY,
		bettype				SMALLINT,
		zzzBetcheck			NVARCHAR(50),
		OriginalBetType		SMALLINT,
		MainCashoutId		BIGINT,
		matchid				INT,
		custid				INT,
		MainTransId			BIGINT
	) -- store 911,912,913		
	
	DECLARE @tblBeforeBalance TVP_BalanceWalletChange
		  , @tblAfterBalance  TVP_BalanceWalletChange

	BEGIN TRY
		INSERT INTO #tbTransId (transid)
		SELECT	s.val 
		FROM	dbo.f_SplitString(isnull(@TransIds, ''), ',') s
		OPTION (maxrecursion 0)
		
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
				,MainCashoutId
				,WalletType
				,RefCode
				,BonusID
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
				,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId
				,b.WalletType
				,b.RefCode
				,b.BonusID
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
				,IsBettrade
				,IsCashOut
				,zzzBetcheck
				,MainCashoutId
				,WalletType
				,RefCode
				,BonusID
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
				,CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN 1 ELSE 0 END AS IsBettrade
				,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN 1 ELSE 0 END AS IsCashOut
				,z.betcheck AS zzzBetcheck
				,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId
				,b.WalletType
				,b.RefCode
				,b.BonusID
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
				,MainCashoutId
				,WalletType
				,RefCode
				,BonusID
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
				,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId
				,b.WalletType
				,b.RefCode
				,b.BonusID
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
					,CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN 1 ELSE 0 END AS IsBettrade
					,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN 1 ELSE 0 END AS IsCashOut				
					,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,r.transid AS MainTransId
						INTO #CTE_bettrans
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
					,IsBettrade
					,IsCashOut
					,zzzBetcheck
					,MainCashoutId				
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
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
					,b.IsBettrade
					,b.IsCashOut
					,z.betcheck AS zzzBetcheck
					,b.MainCashoutId
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,b.MainTransId
			FROM #CTE_bettrans b WITH (NOLOCK)
				 INNER JOIN dbo.zzzbettrans z WITH (NOLOCK)
						 ON	z.transid = b.transid
							AND z.custid = b.custid
							AND z.matchid = b.matchid					
							AND z.bettype = b.bettype
		END			 								
		
		-- checking cash-out process
		INSERT INTO #tblCashOutProcess(transid)
		SELECT transid
		FROM #tblTransInfo	
		WHERE betdaqid = 0 
		  AND charindex ('p25',extrainfo)> 0
		
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Recover'
			  , @IsReleased = 0
		
		DELETE bd
		FROM #tblTransInfo bd
			 INNER JOIN #tblCashOutProcess rp
					 ON bd.transid = rp.transid					
						AND rp.IsAvailable = 0
						
		-- return invalid transId	
		SELECT @InvalidTransIds = @InvalidTransIds + CAST(transid AS VARCHAR(20)) + ','
		FROM #tblCashOutProcess
		WHERE IsAvailable = 0					
		
		--- check exists BT, Cash-out, Bet Builder
		SELECT @isExistBT 		= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
			 , @isExistCashOut	= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
		FROM #tblTransInfo
		
		IF (@isExistBT = 1 AND ISNULL(@TransIdSolds, '') <> '')
		BEGIN
			INSERT INTO #tblTransInfo(
					grouptransid	
					,transid		
					,custid					
					,transdate		
					,odds
					,oddsspread					
					,oddstype		
					,bettype
					,OriginalBetType		
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
					,IsBettrade
					,zzzBetcheck
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
			)
			SELECT	tmpmain.transid
					,z.transid
					,z.custid
					,sub.transdate
					,tmpmain.odds
					,tmpmain.oddsspread
					,tmpmain.oddstype
					,z.bettype
					,tmpmain.bettype AS OriginalBetType
					,z.winlost - sub.actual_stake
					,tmpmain.betteam
					,tmpmain.betcheck
					,tmpmain.hdp1
					,tmpmain.hdp2
					,tmpmain.betfrom
					,tmpmain.stake
					,tmpmain.matchid
					,tmpmain.IsLiveIndicator
					,tmpmain.livehomescore
					,tmpmain.liveawayscore
					,z.creator
					,sub.currencyName
					,'SOLD'
					,tmpmain.bettype AS betid
					,sub.transdesc
					,sub.refno
					,sub.betdaqid
					,sub.recommend
					,sub.mrecommend
					,sub.srecommend
					,sub.SecAcceptFlag
					,sub.ExtraInfo					
					,1 AS IsBettrade
					,z.betcheck AS zzzBetcheck
					,sub.WalletType
					,sub.RefCode
					,sub.BonusID
					,tmpmain.transid AS MainTransId
			FROM	dbo.zzzbettrans z WITH(NOLOCK)
				INNER JOIN dbo.bettrans sub WITH(NOLOCK)
					ON	z.transid = sub.transid
						AND z.custid = sub.custid
						AND z.matchid = sub.matchid					
						AND z.bettype = sub.bettype
				INNER JOIN #tblTransInfo tmpmain
					ON	z.refno = tmpmain.transid
						AND z.bettype = 901
						AND tmpmain.betdaqid = 0
						AND tmpmain.extrainfo is null
			WHERE	z.transid IN (SELECT s.val FROM dbo.strSplit(isnull(@TransIdSolds, ''), ',') s)					
			
			--insert custBT 
			INSERT INTO @tblCustBT902( custid, matchid )
			SELECT sub902.custid, sub902.matchid
			FROM dbo.bettrans sub902 WITH (NOLOCK)
				INNER JOIN #tblTransInfo tmpmain with(NOLOCK)
				ON	sub902.refno = tmpmain.transid
					AND sub902.matchid = tmpmain.matchid									
			WHERE sub902.bettype 		= 902
				AND tmpmain.betdaqid 	= 0
				AND tmpmain.extrainfo is null				
			GROUP BY sub902.custid, sub902.matchid
		END			
		
		IF (@isExistCashOut = 1)
		BEGIN						
			-- get sub ticket of Cash-out (911)	
			INSERT INTO #tblTransInfo(
					grouptransid	
					,transid		
					,custid					
					,transdate		
					,odds	
					,oddsspread					
					,oddstype		
					,bettype
					,OriginalBetType		
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
					,MainCashoutId
					,IsCashOut
					,zzzBetcheck
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
			)
			OUTPUT inserted.transid
				 , inserted.bettype
				 , inserted.zzzBetcheck
				 , inserted.OriginalBetType
				 , inserted.MainCashoutId
				 , inserted.matchid
				 , inserted.custid
				 , inserted.MainTransId
					INTO #CashOutSubTicket(transid
										 , bettype
										 , zzzBetcheck
										 , OriginalBetType
										 , MainCashoutId
										 , matchid
										 , custid
										 , MainTransId)
			SELECT	tmpmain.transid
					,z.transid
					,z.custid
					,sub.transdate
					,tmpmain.odds
					,tmpmain.oddsspread
					,tmpmain.oddstype
					,z.bettype
					,tmpmain.bettype AS OriginalBetType
					,z.winlost - sub.actual_stake
					,tmpmain.betteam
					,tmpmain.betcheck
					,tmpmain.hdp1
					,tmpmain.hdp2
					,tmpmain.betfrom
					,z.stake
					,tmpmain.matchid
					,tmpmain.IsLiveIndicator
					,tmpmain.livehomescore
					,tmpmain.liveawayscore
					,z.creator
					,sub.currencyName
					,'Cash out'
					,tmpmain.bettype AS betid
					,sub.transdesc
					,sub.refno
					,sub.betdaqid
					,sub.recommend
					,sub.mrecommend
					,sub.srecommend
					,sub.SecAcceptFlag
					,sub.ExtraInfo
					,tmpmain.transid AS MainCashoutId
					,1 AS IsCashOut
					,z.betcheck AS zzzBetcheck
					,sub.WalletType
					,sub.RefCode
					,sub.BonusID
					,tmpmain.transid AS MainTransId
			FROM	dbo.zzzbettrans z WITH(NOLOCK)
				INNER JOIN dbo.bettrans sub WITH(NOLOCK)
					ON	z.transid = sub.transid
						AND z.custid = sub.custid
						AND z.matchid = sub.matchid
						AND z.bettype = sub.bettype
				INNER JOIN #tblTransInfo tmpmain
					ON	z.refno = tmpmain.transid
						AND z.betcheck = tmpmain.zzzBetcheck
						AND z.custid = tmpmain.custid
						AND z.matchid = tmpmain.matchid
						AND z.bettype = 911
						AND tmpmain.betdaqid = 0 -- main ticket is Cash-out
						AND charindex ('p25',tmpmain.extrainfo)> 0 -- main ticket is Cash-out
			
			-- get cash-out member bet tickets
			INSERT INTO #tblTransInfo(
					grouptransid	
					,transid		
					,custid					
					,transdate		
					,odds
					,oddsspread					
					,oddstype		
					,bettype
					,OriginalBetType		
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
					,MainCashoutId
					,IsCashOutMemberTicket
					,IsCashOut
					,zzzBetcheck
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
			)
			SELECT	z.transid
					,z.transid
					,z.custid
					,b.transdate
					,b.odds
					,b.oddsspread
					,b.oddstype
					,b.bettype
					,sub911.OriginalBetType
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
					,sub911.MainCashoutId
					,1 AS IsCashOutMemberTicket
					,1 AS IsCashOut
					,z.betcheck AS zzzBetcheck
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,sub911.MainTransId
			FROM #tblTransInfo sub911
			 CROSS APPLY (
							  SELECT b.transdate
							  		,b.transid
							  		,b.custid
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
									,b.WalletType
									,b.RefCode
									,b.BonusID
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid
								AND b.bettype = sub911.OriginalBetType
						 ) AS b
					INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)				
						ON	z.transid = b.transid	
						AND z.custid = b.custid
						AND z.matchid = b.matchid
						AND z.bettype = b.bettype
						AND z.betcheck = sub911.zzzBetcheck
			WHERE sub911.bettype = 911						
						
			-- insert 912,913
			INSERT INTO #CashOutSubTicket(transid
										, bettype
										, zzzBetcheck
										, OriginalBetType
										, MainCashoutId
										, matchid
										, custid
										, MainTransId)															
			SELECT sub_912_913.transid
				 , sub_912_913.bettype
				 , sub911.zzzBetcheck
				 , sub911.OriginalBetType
				 , sub911.MainCashoutId
				 , sub_912_913.matchid
				 , sub_912_913.custid
				 , sub911.MainTransId
			FROM #CashOutSubTicket sub911
				 INNER JOIN bettrans sub_912_913 (nolock)
						 ON sub911.transid = sub_912_913.refno
							AND sub911.matchid = sub_912_913.matchid						    
							AND sub_912_913.bettype IN (912,913)																		
			
			-- insert custCashOut912
			INSERT INTO @tblCustCashOut912( custid, matchid )
			SELECT DISTINCT custid, matchid
			FROM #tblTransInfo						
			WHERE IsCashOutMemberTicket = 1						
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100,
				@ErrMsg = 'Invalid TransIds'						
		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Recover'
			  , @IsReleased = 1	
						
		RETURN
	END CATCH

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tblTransInfo)
	BEGIN
		IF @InvalidTransIds = ''
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'				
		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Recover'
			  , @IsReleased = 1	
		
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
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Recover'
			  , @IsReleased = 1	
		
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
			 , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 0 ELSE b.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
			 , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 2 ELSE b.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype
		FROM   dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tblTransInfo t
				ON	b.transid = t.grouptransid
					AND b.transid = t.transid
					AND b.matchid = t.matchid
		UNION ALL
		
		-- bettrade subticket (901,902,903)
		SELECT sub.matchid, sub.custid
			 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype
		FROM   bettrans sub WITH(NOLOCK)
			INNER JOIN #tblTransInfo t
				ON	sub.refno = t.transid
					AND sub.matchid = t.matchid
					AND sub.bettype BETWEEN 901 AND 910
					AND t.betdaqid = 0	
					AND t.extrainfo is null
		WHERE @isExistBT = 1
		
		UNION ALL
		
		-- cash-out subticket (911,912,913)
		SELECT b.matchid, b.custid
			 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype
		FROM   bettrans b WITH (nolock)
				INNER JOIN #CashOutSubTicket sub
					 ON b.transid = sub.transid
		WHERE @isExistCashOut = 1				
				
		UNION ALL
		
		-- BT-WLSharing (904)
		SELECT	sub904.matchid, sub904.custid
			  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			  , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype
		FROM	bettrans sub904 WITH (NOLOCK)
			INNER JOIN @tblCustBT902 temp
			ON sub904.custid = temp.custid
				AND sub904.matchid = temp.matchid									
		WHERE sub904.bettype = 904
		
		UNION ALL
		
		-- cash-out summary 914
		SELECT	sub914.matchid, sub914.custid
			  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype
		FROM	bettrans sub914 WITH (NOLOCK)
			INNER JOIN @tblCustCashOut912 temp
			ON sub914.custid = temp.custid
				AND sub914.matchid = temp.matchid									
		WHERE sub914.bettype = 914
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
	FROM	#tblTransInfo t
		INNER JOIN dbo.match m WITH(NOLOCK) ON	t.matchid = m.matchid

	---- recover : normal (NOT IN 468, 469), main bettrade, main cash-out, cash-out member bet ticket
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
	FROM bettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t ON main.transid = t.grouptransid AND main.transid = t.transid
	WHERE t.bettype NOT IN (468, 469)

	---- recover: bettype ScoreBox (468, 469)
	;WITH CTE_Betcheck_1
	AS (
		SELECT t.transid
			,b.id
			,b.val AS betop
		FROM #tblTransInfo AS t
			CROSS APPLY dbo.strSplit(t.betcheck, ',') AS b
		WHERE t.bettype IN (468, 469)
		)
		,CTE_Betcheck_2
	AS (
		SELECT b.transid
			,b.id
			,op.rank -- ([1]:[2])
			,CAST(op.val AS MONEY) AS val
		FROM CTE_Betcheck_1 AS b
			CROSS APPLY dbo.strSplit(b.betop, ':') AS op
		)
		,CTE_Betcheck_Odds
	AS (
		SELECT t.transid AS transid
			,MIN(odds.val) AS odds
		FROM CTE_Betcheck_2 AS t
			LEFT JOIN CTE_Betcheck_2 AS odds ON t.transid = odds.transid
			AND t.id = odds.id
			AND odds.rank = 2
		GROUP BY t.transid
		)
		,CTE_Betcheck_Final
	AS (
		SELECT o.transid
			,score.val AS score
			,o.odds
		FROM CTE_Betcheck_Odds AS o
			LEFT JOIN CTE_Betcheck_2 AS t ON t.transid = o.transid
			AND t.rank = 2
			AND t.val = o.odds
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
	        
	---- recover subtickets : BetTrade (901, 902, 903) + Cash-out (911, 912, 913)
	IF (@isExistBT = 1 OR @isExistCashOut = 1)
	BEGIN
		IF (@isExistBT = 1)
		BEGIN
			UPDATE	sub901 WITH(ROWLOCK, UPDLOCK)
				SET winlost = sub902.actual_stake
					,awinlost = sub901.actual_stake - sub902.actual_stake
					,status = CASE 
								WHEN sub902.actual_stake > sub901.actual_stake THEN 'WON'
								WHEN sub902.actual_stake < sub901.actual_stake THEN 'LOSE'
								ELSE 'DRAW'
								END
					,statusID = CASE 
								WHEN sub902.actual_stake > sub901.actual_stake THEN 112
								WHEN sub902.actual_stake < sub901.actual_stake THEN 113
								ELSE 111
								END
					,statuswinlost = NULL
					,creator = tmp901.creator
			FROM	dbo.bettrans sub901
				INNER JOIN dbo.bettrans sub902 WITH(NOLOCK)
					ON	sub901.refno = sub902.refno
						AND sub901.bettype = 901
						AND sub902.bettype = 902
						AND sub901.matchid = sub902.matchid
				INNER JOIN #tblTransInfo tmp901
					ON	sub901.transid = tmp901.transid
						
			UPDATE	sub902 WITH(ROWLOCK, UPDLOCK)
				SET winlost = sub901.actual_stake
					,awinlost = sub902.actual_stake - sub901.actual_stake
					,status = CASE 
								WHEN sub901.actual_stake > sub902.[actual_stake] THEN 'WON'
								WHEN sub901.actual_stake < sub902.[actual_stake] THEN 'LOSE'
								ELSE 'DRAW'
								END
					,statusID = CASE 
								WHEN sub901.actual_stake > sub902.[actual_stake] THEN 112
								WHEN sub901.actual_stake < sub902.[actual_stake] THEN 113
								ELSE 111
								END
					,statuswinlost = NULL
					,creator = tmp901.creator
			FROM	dbo.bettrans sub902
				INNER JOIN dbo.bettrans sub901 WITH(NOLOCK)
					ON	sub901.refno = sub902.refno
						AND sub901.bettype = 901
						AND sub902.bettype = 902
						AND sub901.matchid = sub902.matchid
				INNER JOIN #tblTransInfo tmp901
					ON	sub901.transid = tmp901.transid
			
			--UPDATED: Use odds to store the deduction rate of OW , here is 50% of 3% BetTrade Commision
			UPDATE	sub903 WITH(ROWLOCK, UPDLOCK)
				SET winlost = sub901.winlost * sub903.odds 
					,awinlost = sub903.discount * sub901.winlost
					,status = CASE 
								WHEN 0 > sub903.[actual_stake] THEN 'WON'
								WHEN 0 < sub903.[actual_stake] THEN 'LOSE'
								ELSE 'DRAW'
								END
					,statusID = CASE 
								WHEN 0 > sub903.[actual_stake] THEN 112
								WHEN 0 < sub903.[actual_stake] THEN 113
								ELSE 111
								END
					,statuswinlost = NULL
					,creator = tmp901.creator
			FROM	dbo.bettrans sub903
				INNER JOIN dbo.bettrans sub901 WITH(NOLOCK)
					ON	sub901.refno = sub903.refno
						AND sub901.bettype = 901
						AND sub903.bettype = 903
						AND sub901.matchid = sub903.matchid
				INNER JOIN #tblTransInfo tmp901
					ON	sub901.transid = tmp901.transid
			
			--Pre-CAL 904
			BEGIN TRY
				DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
				INSERT INTO @TempData(MatchId, CustIds)
				SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
									   FROM #tblTransInfo tt 
									   where tt.MatchId = t.MatchId 
									     AND tt.betdaqid = 0
									     AND tt.extrainfo is null
									   FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
				FROM #tblTransInfo t
				WHERE t.betdaqid = 0
				  AND t.extrainfo is null
				GROUP BY MatchId
				
				DECLARE @RowId INT, @MatchIdTmp INT, @CustIds VARCHAR(MAX)
				SELECT @RowId = 1
				WHILE EXISTS (SELECT TOP 1 1 FROM @TempData WHERE RowId = @RowId)
				BEGIN
					SELECT @MatchIdTmp = MatchId
						, @CustIds = CustIds
					FROM @TempData t 
					WHERE RowId = @RowId
					
					EXEC dbo.NAP_Admin_Calculate_904 
						@MatchId 	= @MatchIdTmp
						, @Action 	= 'RECOVER'
						, @CustIds 	= @CustIds
						
					SET @RowId = @RowId + 1
				END
				
			END TRY 
			BEGIN CATCH
				SELECT	@ErrCode = 904
					,@ErrMsg = 'Called NAP_Admin_Calculate_904 with error.'
			END CATCH
		END
		
		IF (@isExistCashOut = 1)
		BEGIN
			-- update sub911
			UPDATE	sub911 WITH(ROWLOCK, UPDLOCK)
				SET winlost = sub912.actual_stake
					,awinlost = sub911.actual_stake - sub912.actual_stake
					,status = CASE 
								WHEN sub912.actual_stake > sub911.actual_stake THEN 'WON'
								WHEN sub912.actual_stake < sub911.actual_stake THEN 'LOSE'
								ELSE 'DRAW'
								END
					,statusID = CASE 
								WHEN sub912.actual_stake > sub911.actual_stake THEN 112
								WHEN sub912.actual_stake < sub911.actual_stake THEN 113
								ELSE 111
								END
					,statuswinlost = NULL
					,creator = tmp911.creator
			FROM	dbo.bettrans sub911
				INNER JOIN dbo.bettrans sub912 WITH(NOLOCK)
					ON	sub911.transid = sub912.refno
						AND sub911.bettype = 911
						AND sub912.bettype = 912
						AND sub911.matchid = sub912.matchid
				INNER JOIN #tblTransInfo tmp911
					ON	sub911.transid = tmp911.transid
			
			-- update sub912
			UPDATE	sub912 WITH(ROWLOCK, UPDLOCK)
				SET winlost = sub911.actual_stake
					,awinlost = sub912.actual_stake - sub911.actual_stake
					,status = CASE 
								WHEN sub911.actual_stake > sub912.[actual_stake] THEN 'WON'
								WHEN sub911.actual_stake < sub912.[actual_stake] THEN 'LOSE'
								ELSE 'DRAW'
								END
					,statusID = CASE 
								WHEN sub911.actual_stake > sub912.[actual_stake] THEN 112
								WHEN sub911.actual_stake < sub912.[actual_stake] THEN 113
								ELSE 111
								END
					,statuswinlost = NULL
					,creator = tmp911.creator
			FROM	dbo.bettrans sub912
				INNER JOIN dbo.bettrans sub911 WITH(NOLOCK)
					ON	sub911.transid = sub912.refno
						AND sub911.bettype = 911
						AND sub912.bettype = 912
						AND sub911.matchid = sub912.matchid
				INNER JOIN #tblTransInfo tmp911
					ON	sub911.transid = tmp911.transid
			
			--UPDATED: Use odds to store the deduction rate of OW , here is 50% of 3% BetTrade Commision (sub913)
			UPDATE	sub913 WITH(ROWLOCK, UPDLOCK)
				SET winlost = sub911.winlost * sub913.odds 
					,awinlost = sub913.discount * sub911.winlost
					,status = CASE 
								WHEN 0 > sub913.[actual_stake] THEN 'WON'
								WHEN 0 < sub913.[actual_stake] THEN 'LOSE'
								ELSE 'DRAW'
								END
					,statusID = CASE 
								WHEN 0 > sub913.[actual_stake] THEN 112
								WHEN 0 < sub913.[actual_stake] THEN 113
								ELSE 111
								END
					,statuswinlost = NULL
					,creator = tmp911.creator
			FROM	dbo.bettrans sub913
				INNER JOIN dbo.bettrans sub911 WITH(NOLOCK)
					ON	sub911.transid = sub913.refno
						AND sub911.bettype = 911
						AND sub913.bettype = 913
						AND sub911.matchid = sub913.matchid
				INNER JOIN #tblTransInfo tmp911
					ON	sub911.transid = tmp911.transid
			
			--Pre-CAL 914
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
		
		-- Update BetTradeSelling
		-- Update [BetTradeSellingCancelled]
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
		SELECT DISTINCT custid FROM #tblTransInfo
		
		INSERT INTO #CustList(custid, Balance)
		SELECT T.custid, SUM(T.Balance)
		FROM
		(
			SELECT	b.custid, b.winlost - b.actual_stake + b.playercomm AS Balance				
			FROM	#CustIdList c
				INNER JOIN dbo.bettrans b WITH(NOLOCK, FORCESEEK)
					ON  c.custid = b.custid
				LEFT JOIN dbo.translog tl WITH(NOLOCK, FORCESEEK)
					ON	b.refno = tl.translogid
						AND b.matchid = tl.eventID				
			WHERE	(tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))								
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
				INNER JOIN #tblTransInfo d 
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
			
		UPDATE btc
		SET
			[Remark] = 'SB recover ticket',
			[BTBuyBack] = -[BTBuyBack],
			[Cancelled] = 0,
			[ChangeDate] = GETDATE(),
			AfterBalance = tcust.Balance
		FROM [dbo].[BetTradeSellingCancelled] btc WITH (ROWLOCK, UPDLOCK)
			INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)
					ON bts.TradeID = btc.TradeID					   
			INNER JOIN #tblTransInfo t
					ON bts.TicketID = t.refno -- bettrade + cash-out
					  AND CASE
								WHEN t.bettype = 911 -- cash-out													 
										THEN CASE
												WHEN bts.SoldTicketID = t.transid THEN 1
												ELSE 0
											 END																							
								ELSE 1
						  END = 1	
			INNER JOIN #CustList tcust
					ON t.custid = tcust.custid
		WHERE t.BetType IN (901,911) 					   						
		
		-- Insert bettrade tickets to send API
		IF (@isExistBT = 1)
		BEGIN
			DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))
			;WITH cteMainTicket
			AS(
				SELECT  transid
				FROM	#tblTransInfo
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
					,'RECOVER'
					,b.BuyBackNo
					,b.PayOut
					,'SB recover tickets'
			FROM	dbo.BetTradeSelling b WITH(NOLOCK)
			WHERE	b.TicketID IN (SELECT transid FROM cteMainTicket)
					AND b.[Status] IN ('Accept', 'Confirm')
		END
	END

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
			 , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 0 ELSE b.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
			 , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 2 ELSE b.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
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
		
		UNION ALL
		
		-- bettrade subticket (901,902,903)
		SELECT sub.matchid, sub.custid
			 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype
		FROM   bettrans sub WITH(NOLOCK)
			INNER JOIN #tblTransInfo t
			ON	sub.refno = t.transid
				AND sub.matchid = t.matchid
				AND sub.bettype BETWEEN 901 AND 910
				AND t.betdaqid = 0	
				AND t.extrainfo is null
		WHERE @isExistBT = 1
		
		UNION ALL
		
		-- cash-out subticket (911,912,913)
		SELECT b.matchid, b.custid
			 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype
		FROM   bettrans b WITH (nolock)
				INNER JOIN #CashOutSubTicket sub
					 ON b.transid = sub.transid
		WHERE @isExistCashOut = 1				
				
		UNION ALL
		
		-- BT-WLSharing (904)
		SELECT	sub904.matchid, sub904.custid
			  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
			  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
			  , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype
		FROM	bettrans sub904 WITH (NOLOCK)
			INNER JOIN @tblCustBT902 temp
			ON sub904.custid = temp.custid
				AND sub904.matchid = temp.matchid									
		WHERE sub904.bettype = 904
		
		UNION ALL
		
		-- cash-out summary 914
		SELECT	sub914.matchid, sub914.custid
			  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype
		FROM	bettrans sub914 WITH (NOLOCK)
			INNER JOIN @tblCustCashOut912 temp
			ON sub914.custid = temp.custid
				AND sub914.matchid = temp.matchid									
		WHERE sub914.bettype = 914
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
	select	t.transid AS inputtransid,
			t.custid,
			t.transdate,
			t.odds,
			t.stake,
			t.winlost,
			t.status
				INTO #t_match_completed
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
				
	--Delete bettrade subtickets 
	IF (@isExistBT = 1)              
		DELETE sub
		FROM   zzzbettrans sub WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblTransInfo t
				ON	sub.refno = t.transid
					AND t.betdaqid = 0
					AND t.extrainfo is null
					AND sub.bettype IN (901, 902, 903)
				
	--Delete cash-out subtickets (911,912,913)
	IF (@isExistCashOut = 1)
		DELETE b
		FROM   zzzbettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #CashOutSubTicket sub
						 ON b.transid = sub.transid
							AND b.custid = sub.custid
							AND b.matchid = sub.matchid
							AND b.bettype = sub.bettype						
	
	------ release data of TempVariableNumBer table
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMG 			= @isExistMG
		, @isExistMatch		= @isExistMatch
		, @isExistFM 		= @isExistFM
		, @isExistBB		= @isExistBB
		, @isExistFM2		= @isExistFM2
		, @IsReleased		= 1	
		
	------ releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess
			@Mode = 'Original' 
		  , @Action = 'Recover'
		  , @IsReleased = 1							
	
	DECLARE @IsITAdmin BIT = 0
	
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
				,t.OriginalBetType
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
				,t.MainCashoutId
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
				,IsBettrade
				,IsCashOut
				,CASE WHEN t_m.inputtransid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isSettled
				,t.WalletType
				,t.BonusID
				,t.MainTransId
				,t.RefCode
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
			,t.OriginalBetType
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
			,t.MainCashoutId
			,t.custid
			--,t.SiteId
			,t.IsReal
			,t.IsItSupport
			,t.IsItQa
			,t.IsBettrade
			,t.IsCashOut
			,t.isSettled
			,t.WalletType
			,t.RefCode
			,m.SettlementStatus
			,m.GlobalShowTime
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