/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverBet]
(
	@TransIds			VARCHAR(MAX), 	
	@UserId				INT,	
	@IP					VARCHAR(50)
)
AS
/*
	Created: Kathy
	Date: 20131022
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

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
		- 20220825@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20220929@July: Fix recover Rep to central with Statuswinlost=0 [Redmine: #178374]
		- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185238]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20241125@Lani: [TVS] Change join type on 'recommend' and 'custid' columns, serverAlias [Redmine: #213451]
		- 20250623@Lani: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

	Param's Explanation:
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
			SET @sqlCommand = 'EXEC dbo.NAP_BettransRecoverBet '
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE '@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
				+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE  @isExistMatch		BIT = 1
			,@isExistFM			BIT = 0
			,@IsExistBB			BIT = 0
			,@avaiableProcess	BIT
			,@isExistFM2		BIT = 0
			,@Movebetdate		DATETIME  
			,@SiteDBGroupID     SMALLINT = 0
			,@TransInfo			VARBINARY(MAX)
			,@TransInfo3rd		VARBINARY(MAX)
			,@ActionId			INT = 200 --Void/Recover

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @ErrCode INT = 0
			,@ErrMsg NVARCHAR(200)	= ''
			,@AutoReSettledTransIds VARCHAR(MAX) = '' 

	CREATE TABLE #tblTransInfo (
		grouptransid	BIGINT
		,transid		BIGINT PRIMARY KEY
		,custid			INT
		,username		VARCHAR(30)
		,username2		VARCHAR(50)
		,transdate		DATETIME
		,odds			SMALLMONEY
		,oddsspread 	MONEY
		,oddstype		TINYINT
		,bettype		SMALLINT
		,winlost		MONEY
		,betteam		NVARCHAR(10)
		,betcheck		NVARCHAR(50)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,betfrom		NVARCHAR(4)
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
		,modds			SMALLMONEY
		,ActualStake	MONEY
	)

	CREATE TABLE #tbTransId (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #t_match_completed(inputtransid BIGINT, custid INT, transdate DATETIME, odds SMALLMONEY, stake MONEY, winlost MONEY, status NVARCHAR(10))
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, increased BIT)
	
	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY, ruben TINYINT, statuswinlost TINYINT, stake MONEY
			, statusID TINYINT, creator INT, actual_stake MONEY, odds SMALLMONEY, oddsspread MONEY, transdesc NVARCHAR(2000), ExtraInfo VARCHAR(1000), FcUpdateTime DATETIME2
			, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, transdate DATETIME, comstatus NVARCHAR(40)
			, bettype SMALLINT
			)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
	DECLARE @matchid INT

	DECLARE @tblBeforeBalance TVP_BalanceWalletChange
		  , @tblAfterBalance  TVP_BalanceWalletChange

	BEGIN TRY
		INSERT INTO #tbTransId (transid)
		SELECT value 
		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''

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
				ON	t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype
					AND z.SiteDBGroupID = b.SiteDBGroupID
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = b.matchid
		WHERE	(m.sporttype BETWEEN 1 AND 99 OR m.sporttype = 154)
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
				,modds
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
				,b.modds
		FROM	#tbTransId t			
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype			
					AND z.SiteDBGroupID = b.SiteDBGroupID
			INNER JOIN dbo.outright o WITH(NOLOCK)
				ON o.orid = b.matchid
			INNER JOIN dbo.League l WITH (NOLOCK) ON o.leagueid = l.leagueid
		WHERE	z.bettype = 10
				AND b.betfrom <> 'p'
				
		/*Modify the way to get move bet date*/
		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

		IF EXISTS ( SELECT TOP 1 1 FROM #tblTransInfo WHERE winlostdate <= @Movebetdate )
		BEGIN
			SELECT @ErrCode = 102, @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

			SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID
			RETURN	
		END			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100, @ErrMsg = 'Invalid TransIds'						
			
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID
		RETURN
	END CATCH

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tblTransInfo)
	BEGIN
		SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'				
		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID 
		RETURN
	END

	;WITH CTE_matchProcess AS (
		SELECT	matchid
			, CASE 
				WHEN Bettype <> 38 AND f.GroupId IS NULL THEN 1 --SB
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
		, @isExistFM 		= MAX(CASE WHEN KeyId = 6 THEN 1 ELSE 0 END )
		, @isExistBB		= MAX(CASE WHEN KeyId = 5 THEN 1 ELSE 0 END)
		, @isExistFM2		= MAX(CASE WHEN KeyId = 7 THEN 1 ELSE 0 END)
	FROM #tblMatchProcess
	
	-- checking SD proccess
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @isExistFM 		= @isExistFM
		, @isExistBB		= @isExistBB
		, @isExistFM2		= @isExistFM2
		, @spName			= @spName
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID
		RETURN
	END
	
	INSERT INTO @tblBeforeBalance(matchid, custid, balanceType, BonusID, WalletType, balance)
	SELECT b.matchid
		 , b.custid
		 , 1 AS BalanceType
		 , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
		 , ISNULL(b.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM   dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransInfo t
			ON	b.transid = t.grouptransid
				AND b.transid = t.transid
				AND b.matchid = t.matchid
	WHERE b.SiteDBGroupID = @SiteDBGroupID
	GROUP BY b.matchid
		   , b.custid
		   , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END	
		   , ISNULL(b.WalletType, 2) -- normal tickets are treated as cash tickets	

	UPDATE t 
		SET	leagueid = m.leagueid
			,homeid = m.homeid
			,awayid = m.awayid
			,SportType = m.sporttype
			,ParentID = CASE WHEN m.sporttype IN (50,8) THEN ISNULL(m.ParentID,0) ELSE 0 END
			,ChildMatchType = CASE WHEN m.SportType IN (50,8) THEN ISNULL(m.ChildMatchType, 0) ELSE 0 END
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
		,actual_stake = main.actual_stake
		,odds = CASE WHEN main.bettype = 376 THEN main.oddsspread ELSE main.odds END
		,transdesc = main.transdesc
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',main.ExtraInfo,t.SportType, main.bettype)
		,FcUpdateTime  = SYSDATETIME()
	OUTPUT deleted.matchid, deleted.transid, inserted.STATUS, inserted.winlost, inserted.ruben, inserted.statuswinlost
			, inserted.statusID, inserted.creator, inserted.actual_stake, inserted.odds, inserted.transdesc, inserted.ExtraInfo, inserted.FcUpdateTime, t.bettype
	INTO @tmpTransInfo (matchid, transid, status, winlost, ruben, statuswinlost, statusID, creator, actual_stake, odds, transdesc, ExtraInfo, FcUpdateTime, bettype)
	FROM bettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t ON main.transid = t.grouptransid AND main.transid = t.transid
	WHERE t.bettype NOT IN (468, 469)
		AND ISNULL(main.betdaqid, 0) <> -2
		AND main.SiteDBGroupID = @SiteDBGroupID

	IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
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
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, actual_stake AS 'astake'
					, odds AS 'o'
					, transdesc AS 'tdesc'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype NOT IN (10, 38)
			FOR JSON PATH))

			IF @TransInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo, 's'
			END

			--Betbuilder
			SET @TransInfo3rd = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, actual_stake AS 'astake'
					, odds AS 'o'
					, transdesc AS 'tdesc'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype IN (38)
			FOR JSON PATH))
		
			IF @TransInfo3rd IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo3rd, 's', 1
			END

			SET @TransInfo3rd = NULL
			--Outright
			SET @TransInfo3rd = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, actual_stake AS 'astake'
					, odds AS 'o'
					, transdesc AS 'tdesc'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype IN (10)
			FOR JSON PATH))
		
			IF @TransInfo3rd IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo3rd, 's', 2
			END
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
		SET @TransInfo = NULL
		SET @TransInfo3rd = NULL
	END

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

		UPDATE	b
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
		  , FcUpdateTime  = SYSDATETIME()
		OUTPUT deleted.matchid, deleted.transid, inserted.STATUS, inserted.statusID, inserted.stake
			, inserted.winlost, inserted.awinlost, inserted.mWinLost, inserted.swinlost, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm
			, inserted.ruben, inserted.creator,inserted.ExtraInfo, inserted.FcUpdateTime
		INTO @tmpTransInfo (matchid, transid, status, statusID, stake, winlost, awinlost, mWinLost, sWinLost
				, playercomm, Comm, aComm, sComm, ruben, creator, ExtraInfo, FcUpdateTime)
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
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
		WHERE b.SiteDBGroupID = @SiteDBGroupID

		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
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
				SET @TransInfo = COMPRESS((
				SELECT	matchid AS 'mid'
						, transId AS 't'
						, STATUS AS 's'
						, statusID AS 'sid'
						, stake AS 'stake'
						, winlost AS 'w'
						, aWinLost AS 'aw' 
						, mWinLost AS 'mw' 
						, sWinLost AS 'sw' 
						, PlayerComm AS 'pc' 
						, Comm AS 'c'  
						, aComm AS 'ac' 
						, sComm AS 'sc' 
						, ruben AS 'r'
						, creator AS 'cr'
						, ExtraInfo AS 'ex'
						, FcUpdateTime AS 'rut'
				FROM	@tmpTransInfo WHERE matchid = @MatchId 
				FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo, 's'
			END

			DELETE FROM @tmpMatchidInfo
			DELETE FROM @tmpTransInfo
			SET @TransInfo = NULL
			SET @TransInfo3rd = NULL
		END

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
	UPDATE main 
	SET winlost = 0
	    ,ruben = 0
	    ,statuswinlost = NULL
	    ,STATUS = 'running'
	    ,statusID = 0
	    ,creator = t.creator
		,odds = bc.odds
		,oddsspread = bc.score
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',main.ExtraInfo,t.SportType, main.bettype)
		,FcUpdateTime  = SYSDATETIME()
	OUTPUT deleted.matchid, deleted.transid, inserted.STATUS, inserted.winlost, inserted.ruben, inserted.statuswinlost
			, inserted.statusID, inserted.creator, inserted.odds, inserted.oddsspread, inserted.ExtraInfo, inserted.FcUpdateTime
	INTO @tmpTransInfo (matchid, transid, status, winlost, ruben, statuswinlost, statusID, creator, odds, oddsspread, ExtraInfo, FcUpdateTime)
	FROM bettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t ON main.transid = t.grouptransid AND main.transid = t.transid
		LEFT JOIN CTE_Betcheck_Final AS bc ON bc.transid = t.transid
	WHERE t.bettype IN (468, 469) AND main.SiteDBGroupID = @SiteDBGroupID

	IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
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
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, odds AS 'o'
					, oddsspread AS 'os'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo, 's'
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
		SET @TransInfo = NULL
		SET @TransInfo3rd = NULL
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
			WHERE b.statusID IN (111, 112, 113, 103) AND b.SiteDBGroupID = @SiteDBGroupID

			DROP TABLE #BetBuilderTransId;
		END TRY 
		BEGIN CATCH
			SELECT @ErrCode = 38, @ErrMsg = 'Called NAP_Admin_Settlement_BetBuilder_Recover with error.'		

		END CATCH
	END
	
	-- get data after update
	INSERT INTO @tblAfterBalance(matchid, custid, balanceType, BonusID, WalletType, balance)
	SELECT b.matchid
		 , b.custid
		 , 1 AS balanceType
		 , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
		 , ISNULL(b.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(b.winlost - b.actual_stake + b.playercomm)	AS balance
	FROM   dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransInfo t
			ON	b.transid = t.grouptransid
				AND b.transid = t.transid
				AND b.matchid = t.matchid
	WHERE b.SiteDBGroupID = @SiteDBGroupID
	GROUP BY b.matchid
		   , b.custid
		   , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
		   , ISNULL(b.WalletType, 2) -- normal tickets are treated as cash tickets
	
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @tblBeforeBalance
		, @BalanceWalletAfter	= @tblAfterBalance
		, @ActionId				= 0		
	
	INSERT INTO #Balance(custid, balance, increased)
	SELECT b.custid, SUM(a.balance) - SUM(b.balance), CASE WHEN SUM(a.balance) > SUM(b.balance) THEN 1 ELSE 0 END
	FROM @tblBeforeBalance AS b
		INNER JOIN @tblAfterBalance AS a ON b.custid = a.custid AND b.matchid = a.matchid
	WHERE a.balance <> b.balance
	GROUP BY b.custid
	
	--> Add Agency Cash Service - Negative Balance into BalanceNegative table  [#225390]
	IF OBJECT_ID('BalanceNegative','U') IS NOT NULL AND @SiteDBGroupID = 3 --Credit
	BEGIN
		INSERT INTO [dbo].[BalanceNegative]
					([ExecDate]
					,[MatchID]
					,[ActionID]
					,[GroupID]
					,[CustID]
					,[Balance]
					,[StatusID]
					,[SessionId]
					,[Remark])
		SELECT	 GETDATE()
				,0 --For case input multiple tickets across multiple matches
				,@ActionID
				,0		-- For Void/Recover
				,CustID
				,Balance
				,0
				,CAST(NEWID() AS NVARCHAR(50))
				,@spName
		FROM	#Balance
		WHERE	increased = 0
	END		        
	DROP TABLE #Balance

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
			,site = c.site
	FROM	#tblTransInfo t
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON	t.custid = c.custid
		INNER JOIN CustDB.dbo.Customer cr WITH(NOLOCK)
			ON	t.creator = cr.custid
	
	-- delete normal ticket
	DELETE main
		OUTPUT deleted.matchid, deleted.transid, deleted.transdate, deleted.comstatus, deleted.bettype
		INTO @tmpTransInfo (matchid, transid, transdate, comstatus, bettype)
	FROM zzzbettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t 
			ON	main.transid = t.transid
				AND main.custid = t.custid
				AND main.matchid = t.matchid
				AND main.bettype = t.bettype
				AND main.transid = t.grouptransid
				AND ISNULL(main.comstatus,'') <> 'CO'
				AND main.SiteDBGroupID = @SiteDBGroupID

	IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
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
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, transdate AS 'td'
					, comstatus AS 'cst'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype NOT IN (10, 38)
			FOR JSON PATH))

			IF @TransInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverSingleBet', 'zzzbettrans', 'D', @matchid, @TransInfo, 's'
			END

			--For match table; EventTable = 1
			SET @TransInfo3rd= COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, transdate AS 'td'
					, comstatus AS 'cst'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype IN (38)
			FOR JSON PATH))
			
			IF @TransInfo3rd IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'RecoverSingleBet', 'zzzbettrans', 'D', @matchid, @TransInfo3rd, 's', 1
			END

			SET @TransInfo3rd = NULL
			--For ouright table; EventTable = 2
			SET @TransInfo3rd= COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, transdate AS 'td'
					, comstatus AS 'cst'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype IN (10)
			FOR JSON PATH))
			
			IF @TransInfo3rd IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'RecoverSingleBet', 'zzzbettrans', 'D', @matchid, @TransInfo3rd, 's', 2
			END
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
		SET @TransInfo = NULL
		SET @TransInfo3rd = NULL
	END
	
	------ release data of TempVariableNumBer table
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= @isExistMatch
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
						WHEN s.SiteLabel = '789y' THEN 2 --789y
						ELSE 1 END AS '@sitetype'
					,b.TransId AS '@transid'
					,b.bettype AS '@bettype'
				FROM #tblTransInfo b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
				WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype
				FOR XML PATH('r'), ROOT('root')
			)

		SET @MatchId_MaxPO = CASE WHEN @sporttype IN (50,8) AND @ParentID <> 0 AND @ChildMatchType = 200 THEN @ParentID ELSE @MatchId_MaxPO END
		
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Recover
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO
	END

	------------------------------------------------------------------------------
	--1. Table return error code/ msg
	SELECT @ErrCode AS ErrorCode
	     , @ErrMsg AS ErrorMsg
	     , @AutoReSettledTransIds AS AutoReSettledTransIds
		 , @SiteDBGroupID AS SiteDBGroupID

	--2. Table get tickets
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
	
	SELECT	t.grouptransid
			,t.site
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
			,t.modds AS MasterOdds 
			,CASE WHEN T1.isExists = 1 OR (T2.isExists = 1 AND @IsITAdmin = 0 -- Check UserID not in IT group
							)THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsReal
			,CASE WHEN T1.isExists = 1 AND @IsITAdmin = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsItSupport
			,CASE WHEN T2.isExists = 1 AND @IsITAdmin = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsItQa
			,IsCashOut
			,CASE WHEN t.IsCashOut = 0 AND t_m.inputtransid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isSettled
			,t.WalletType
			,t.BonusID
			,t.MainTransId
			,t.RefCode
			,t.ActualStake
			,m.SettlementStatus
			,m.GlobalShowTime
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
			LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = t.matchid
	ORDER BY site
			, ISNULL(t.MainTransId, t.transid)
			, CASE WHEN t.BonusID IS NOT NULL
				THEN CASE WHEN t.MainTransId IS NULL THEN 1 ELSE 2 END
				ELSE t.transid
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

	DROP TABLE #t_match_completed
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblTransInfo
	DROP TABLE #tbTransId

	RETURN;
END