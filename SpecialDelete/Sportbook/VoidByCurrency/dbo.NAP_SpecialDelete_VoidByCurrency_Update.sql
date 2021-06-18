/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_Update] 
	@MatchID			INT = 0,
	@LicenseeNames		VARCHAR(MAX),
	@CurrencyIDs		VARCHAR(MAX),
	@TransIDs			VARCHAR(MAX),
	@SoldTransIds		VARCHAR(MAX) = '', -- just for BetTrade's subticket (transid of bettype 901)		

	@UserID				INT,  
	@UserName			NVARCHAR(50),
	@UserPassword		NVARCHAR(50),  
	@Reason				NVARCHAR(500) = '',  
	@ReasonSC			NVARCHAR(500) = '',
	@IP					VARCHAR(15)  = '',  
	@ErrorMsg			NVARCHAR(200) = '' OUTPUT,  
	@ErrorCode			INT  = 0  OUTPUT,
	@InvalidTransIds	VARCHAR(MAX) = '' OUTPUT, -- invalid trans of BTrade
	@NegativeBalanceUsers	VARCHAR(MAX)	= ''	OUTPUT
AS
/*
	Created: Kent
	Date: 20161201
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161201@Kent: Search sportbook tickets by crrency to void [Redmine:#67987]
		- 20170313@Kent: Integrate cash-out [Redmine:#72059]
		- 20170418@Kent: Fix Returned Data Type For Bit Columns [Redmine:#75009]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20170922@Kent: Void Parlay Bet & Support New site [Redmine:#54340]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread and Remove DateTime - Fast Markets Phase 2 [Redmine:#90667]
		- 20180509@Alan: Change result for new template email [Redmine:#93296]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181017@Alan: Write log new reason chinese simplified [102918]
		- 20181004@Alan: Add new column SettlementStatus [102423]
		- 20181228@Alan: E-Sports Phase 2b - Support In-play status [106456]
		- 20190320@Alan: Add CN88 into Others Group [109858]
		- 20190419@Kathy: Mark Ticket for Settlement Exclusion [Redmine:#108826]
		- 20190228@Alan: Implement Bet Builder - [106898]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20190909@Kathy: Do not update statuswinlost when voiding ticket [Redmine:#115376]
		- 20191101@Charles: Remove column IsMarked [122187]
		- 20191106@Helen: SP Tuning -  [Redmine: 121209]
		- 20200422@Charles: Void settled for sub parlay bet [132661]
		- 20200609@Charles: Remove notify when void tickets [131865]
		- 20201002@Charles: Letstalk notification for void settled bets [141828]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20201211@Charles: TVS - Enhance letstalk notification for settled tickets [Redmine: #145103]
		- 20210514@July: SD - Remove unused code/products [Redmine: #121752]
		- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]

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
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidByCurrency_Update '
				+ CASE WHEN @MatchId IS NULL THEN '' ELSE '@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
				+ CASE WHEN @LicenseeNames IS NULL THEN '' ELSE ',@LicenseeNames = ''' + CONVERT(NVARCHAR(MAX), @LicenseeNames) + '''' END
				+ CASE WHEN @CurrencyIDs IS NULL THEN '' ELSE ',@CurrencyIDs = ''' + CONVERT(NVARCHAR(MAX), @CurrencyIDs) + '''' END
				+ CASE WHEN @TransIDs IS NULL THEN '' ELSE ',@TransIDs = ''' + CONVERT(NVARCHAR(MAX), @TransIDs) + '''' END
				+ CASE WHEN @SoldTransIds IS NULL THEN '' ELSE ',@SoldTransIds = ''' + CONVERT(NVARCHAR(MAX), @SoldTransIds) + '''' END
				+ CASE WHEN @UserID IS NULL THEN '' ELSE ',@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
				+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
				+ CASE WHEN @UserPassword IS NULL THEN '' ELSE ',@UserPassword = ''' + CONVERT(NVARCHAR(50), @UserPassword) + '''' END
				+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
				+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	SELECT @ErrorCode = 0
		 , @ErrorMsg = ''  
		 , @InvalidTransIds = ''
	
	-- Constant
	DECLARE @NegativeBalanceCustIds		VARCHAR(MAX) = ''
	SET @NegativeBalanceUsers = ''
	DECLARE @SettlementStatus TINYINT = NULL
		   ,@GlobalShowTime   SMALLDATETIME
		   ,@Movebetdate	  DATETIME
		   ,@Eventdate		  DATETIME

	SELECT @SettlementStatus = m.SettlementStatus
		  ,@GlobalShowTime = m.GlobalShowTime
		  ,@Eventdate = m.eventdate
	FROM dbo.match m WHERE m.matchid = @MatchId

	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
	IF @Eventdate <= @Movebetdate
	BEGIN
		SELECT @ErrCode = 100
		     , @ErrMsg = 'Match is under Movebet process, could not void/recover ticket.'

		RETURN	
	END	

	DECLARE @MBCGroup_Name		VARCHAR(50) = 'MBC Group'
		  , @789y_Name			VARCHAR(50) = '789y'	
		  , @y987_Name			VARCHAR(50) = 'y987'	  
		  , @cn88_Name		VARCHAR(50) = 'CN88'	  
		  , @VoidPatchSize		INT = 100
	
	DECLARE @LogData			NVARCHAR(500) = ''
		  , @GeneralErrMsg		NVARCHAR(200) = 'Unable to void these tickets'
		  , @CurrencyCodes		VARCHAR(MAX)
		  , @SearchSingle		BIT = 0
		  , @CountSingle		INT = 0
		  , @SearchParlay		BIT = 0
		  , @CountParlay		INT = 0
		  
	DECLARE @IsExistParlay		BIT = 0		  
		  , @isExistMatch		BIT = 0
		  , @isExistFM					BIT = 0
		  , @isExistFM2			BIT = 0
		  , @IsExistBB			BIT = 0
		  , @AvaiableProcess	BIT = 1	
		  , @isExistBT			BIT = 0 
		  , @isExistCashOut		BIT = 0
		  
	DECLARE @CustIds_BT_CashOut VARCHAR(MAX) = ''	
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))	
	DECLARE @tblTransIds TABLE (transid BIGINT)	
	DECLARE @tblInputSoldTransIds TABLE (transid BIGINT)	
	DECLARE @tblBeforeBalance TVP_BalanceWalletChange	
		  , @tblAfterBalance TVP_BalanceWalletChange
	CREATE TABLE #NegativeBalance (transid BIGINT)
	CREATE TABLE #BeforeUpd (custid INT,balance MONEY)
	CREATE TABLE #AfterUpd(custid INT, balance MONEY)  
	
	CREATE TABLE #SpecialDeleteBets (
			id					INT IDENTITY,
			GroupID				BIGINT,
			Stake				MONEY,
			AwayId				INT,
			BetCheck			NVARCHAR(50),
			BetId				BIGINT DEFAULT (0),
			BetTeam				NVARCHAR(10),
			BetType				SMALLINT,
			OriginalBetType		SMALLINT,
			Currency			TINYINT,
			CurrencyCode		NVARCHAR(50),
			Creator				INT,			
			Hdp1				SMALLMONEY,
			Hdp2				SMALLMONEY,
			HomeId				INT,
			IsLiveIndicator		BIT, 
			IsNeutral			BIT,			
			LiveAwayScore		SMALLINT,
			LiveHomeScore		SMALLINT,
			Odds				MONEY,			
			Oddsspread 			MONEY,
			OddsType			INT,
			RefNo				BIGINT,
			SportType			SMALLINT,
			Status				NVARCHAR(10),
			TransDate			DATETIME,
			TransDesc			NVARCHAR(1000),
			TransId				BIGINT,
			UserName			VARCHAR(30),
			NetWinLost			MONEY,
			site				VARCHAR(10),
			betfrom				NVARCHAR(1),
			srecommend			INT,
			mrecommend			INT,
			recommend			INT,
			custid				INT,
			balance				MONEY,
			betdaqid			BIGINT,	
			IsBetTrade			BIT,			
			BettradeGroupID		BIGINT,
			ExtraInfo			VARCHAR(1000),
			IsCashOutMemberTicket BIT DEFAULT 0,
			MainCashoutId		BIGINT,
			awinlost			MONEY,
			matchid				INT,
			WalletType			TINYINT,
			RefCode				BIGINT,
			BonusID				INT,
			MainTransId			BIGINT,
			ActualStake			MONEY,
					
			SubTransDesc		NVARCHAR(1000),
			SubTransId			BIGINT,
			SubBetCheck			NVARCHAR(50),
			SubBetTeam			NVARCHAR(10),
			SubBetType			SMALLINT,
			SubHdp1				SMALLMONEY,
			SubHdp2				SMALLMONEY,
			SubOdds				MONEY,
			SubStatus			NVARCHAR(10)
	)	

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)
	
	SELECT * INTO #SpecialDeleteBets_Single FROM #SpecialDeleteBets WHERE 1 = 0	
	CREATE CLUSTERED INDEX IDX_SpecialDeleteBets_Single_betdaqid_transid ON #SpecialDeleteBets_Single(betdaqid, transid)
	CREATE INDEX IDX_SpecialDeleteBets_Single_BetType_custid_balance ON #SpecialDeleteBets_Single(BetType, custid, balance)	INCLUDE(transid)
	
	CREATE INDEX IDX_SpecialDeleteBets_Single_RefCode ON #SpecialDeleteBets_Single(RefCode)		
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	

	SELECT * INTO #SpecialDeleteBets_Parlay FROM #SpecialDeleteBets WHERE 1 = 0
	CREATE INDEX IDX_SpecialDeleteBets_Parlay_custid_balance ON #SpecialDeleteBets_Parlay(custid, balance) INCLUDE(transid)
	CREATE INDEX IDX_SpecialDeleteBets_Parlay_id ON #SpecialDeleteBets_Parlay(id) INCLUDE(TransId, SubTransId, refno)
	
	-- BT transaction
	CREATE TABLE #tblTransIdSolds (grouptransid BIGINT, transid BIGINT PRIMARY KEY)
	
	CREATE TABLE #BTTransActive (
		custid			INT
		, refno			BIGINT
		, matchid		INT
		, bettype		SMALLINT
		, transId		BIGINT
		, awinlost		MONEY
		, BetId			BIGINT DEFAULT (0)
		, TransDate		DATETIME
		, UserName		VARCHAR(30)
		, NetWinLost	MONEY
		, srecommend	INT
		, mrecommend	INT
		, recommend		INT
		, balance		MONEY
		, betdaqid		BIGINT
		, ExtraInfo		VARCHAR(1000)
		, WalletType	TINYINT
		, RefCode		BIGINT
		, BonusID		INT
		, MainTransId	BIGINT
	)
	CREATE CLUSTERED INDEX IDX_BTTransActive_bettype_refno ON #BTTransActive(bettype, refno)
	CREATE INDEX IDX_BTTransActive_bettype_custid_matchid ON #BTTransActive(bettype, custid)
	CREATE INDEX IDX_BTTransActive_custid_balance ON #BTTransActive(custid, balance) INCLUDE(transId)
	
	CREATE TABLE #CashOutTransActive (		
		transId				BIGINT PRIMARY KEY,
		bettype				SMALLINT,				
		OriginalBetType		SMALLINT,
		MainCashoutId		BIGINT,
		matchid				INT	,
		MainTransId			BIGINT		
	) -- store 911,912,913		
	
	-- store invalid BT transid
	DECLARE @tblInvalidTrans TABLE (transid BIGINT) 
	
	--store BT's custid			
	DECLARE @tblCustBT902 TABLE 
	(
		custid INT	  
	)
	
	--store Cash-Out's custid
	DECLARE @tblCustCashOut912 TABLE 
	(
		custid INT
	)
	
	CREATE TABLE #t_CustID_501(custid INT PRIMARY KEY)				
	
	CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
	CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)	
	
	CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))
	
	CREATE TABLE #t_exchanges(exchangeid INT, currency NVARCHAR(50))
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)	
	
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)	

	-------> Parse @LicenseeNames	
	INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
	SELECT ss.val AS LicenseeName, ss.val AS GroupName
	FROM dbo.f_SplitString(@LicenseeNames, ',') ss
	OPTION (maxrecursion 0)
	
	-- Replace all UI representative groups (MBCGroup and 789y) by their real credit licensees
	DELETE FROM #t_LicenseeNames 
	OUTPUT DELETED.GroupName 
			INTO #t_UIRepresentativeLicenseeGroupNames(GroupName)
	WHERE LicenseeName IN (@MBCGroup_Name, @789y_Name, @cn88_Name)
	
	IF @@ROWCOUNT > 0
	BEGIN
		;WITH CTE_CreditSit AS
		(
			SELECT [site]
			FROM DBCUST.CUSTDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0		  
			  AND isActive = 1
		)
		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM #t_UIRepresentativeLicenseeGroupNames AS t
			 CROSS APPLY (
							SELECT cte.[site]
							FROM CTE_CreditSit cte
							WHERE CASE
								WHEN t.GroupName = @MBCGroup_Name AND cte.[site] NOT IN (@789y_Name, @y987_Name, @cn88_Name) THEN 1
								WHEN t.GroupName = @789y_Name AND cte.[site] IN (@789y_Name, @y987_Name) THEN 1
								WHEN t.GroupName = @cn88_Name AND cte.[site] IN (@cn88_Name) THEN 1
								ELSE 0
							END = 1
						 ) AS cte
	END						 
	
	-------> Parse @CurrencyIDs	  
	INSERT INTO #t_exchanges(exchangeid, currency)
	SELECT e.exchangeid, e.currency
	FROM dbo.f_SplitString(@CurrencyIDs, ',') ss
		 INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK)
				 ON CAST(ss.val AS INT) = e.exchangeid
	OPTION (maxrecursion 0)				 	
				 
	-------> Parse @MainTransIds
	INSERT INTO @tblTransIds(transid)
	SELECT ss.val AS transid
	FROM dbo.f_SplitString(@TransIds, ',') ss
	OPTION (maxrecursion 0)
	
	-------> Parse @SoldTransIds
	INSERT INTO @tblInputSoldTransIds(transid)
	SELECT ss.val AS transid
	FROM dbo.f_SplitString(@SoldTransIds, ',') ss 
	OPTION (maxrecursion 0)
	
	-------> Build string @CurrencyCodes
	SET @CurrencyCodes = ''
	SELECT @CurrencyCodes = @CurrencyCodes
							+ CASE WHEN @CurrencyCodes <> '' THEN ',' ELSE '' END
							+ currency
	FROM #t_exchanges


	-------> Build @LogData	
	SET @LogData = 'Void currency transaction for matchid ' + CONVERT(VARCHAR(20), @matchid) 
		+ ' for ' + @LicenseeNames + ' ' + @CurrencyCodes + ' IP=' + @IP + ' reason: ' + @Reason + ' - ' + @ReasonSC
		
	IF NOT EXISTS (SELECT 1 FROM CustDB.dbo.Customer WITH(NOLOCK) WHERE userpwd = @UserPassword AND custid = @userId AND roleid >=5)
    BEGIN
        SELECT @ErrorMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!'  
                ,@ErrorCode = 101  
                
        EXEC [dbo].[WriteLog_UserLog] @UserID = @UserID ,@Doing = @LogData                
        
        RETURN
    END
	
	IF NOT EXISTS (SELECT TOP 1 1
				   FROM @tblTransIds)
	BEGIN		
		SELECT @ErrorCode = 99, @ErrorMsg = 'No ticket found.'						
		
		RETURN
	END

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(bettype	SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes(bettype)
	
		--> Get status of match
		SELECT @IsHTCal = ISNULL(IsHTCal, 0)		 
		FROM match_remark (NOLOCK)
		WHERE matchid = @MatchID
	
		SELECT @eventstatus = ISNULL(eventstatus, '')
		FROM match (NOLOCK)
		WHERE matchid = @MatchID		
	
		--> Build bettype list supported for instant settlement based on settlement status of match
		IF @eventstatus <> @eventstatus_completed
		BEGIN
			IF @IsHTCal = 0
				INSERT INTO #InstantSettlementBettypes(bettype)
				SELECT T.bettype
				FROM dbo.f_Set_Instant_GetBettypes() T
				WHERE T.InstantType IN (1, 3) -- 01, 11
			ELSE
				INSERT INTO #InstantSettlementBettypes(bettype)
				SELECT T.bettype
				FROM dbo.f_Set_Instant_GetBettypes() T
				WHERE T.InstantType IN (2, 3) -- 10, 11			
		END	 	
	END						 	  

	BEGIN TRY	
		-------> Get tickets to void
		--> Get single tickets	
		BEGIN
			INSERT INTO #SpecialDeleteBets_Single(
						GroupID,
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
						Currency,
						CurrencyCode,
						Creator,
						Hdp1,
						Hdp2,
						HomeId,
						IsLiveIndicator,
						IsNeutral,
						LiveAwayScore,
						LiveHomeScore,
						Odds,
						Oddsspread,
						OddsType,
						RefNo,
						SportType,
						Status,
						TransDate,
						TransDesc,
						TransId,
						UserName,
						NetWinLost,
						site,
						betfrom,
						srecommend,
						mrecommend,
						recommend,
						custid,
						balance,
						betdaqid,
						IsBetTrade,
						BettradeGroupID,
						ExtraInfo,
						MainCashoutId,
						awinlost,
						matchid,
						WalletType,
						RefCode,
						BonusID,
						ActualStake,
						
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds,
						SubStatus		
					)
			SELECT 	b.transid AS GroupID,
					b.Stake,
					m.AwayId,
					b.BetCheck,
					b.BetId,
					b.BetTeam,
					b.BetType,
					b.currency,
					te.currency AS CurrencyCode,
					b.Creator,
					b.Hdp1,
					b.Hdp2,
					m.HomeId,
					b.LiveIndicator AS IsLiveIndicator,
					ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
					b.LiveAwayScore,
					b.LiveHomeScore,
					b.Odds,	
					b.Oddsspread,
					b.OddsType,
					b.RefNo,
					m.SportType,
					b.status AS STATUS,
					b.TransDate,
					b.TransDesc,
					b.TransId,
					b.UserName,
					b.WinLost - b.actual_stake AS NetWinLost,
					c.site,
					b.betfrom,
					b.srecommend,
					b.mrecommend,
					b.recommend,
					b.custid,
					b.winlost - b.actual_stake + b.playercomm AS balance,
					b.betdaqid,
					CASE WHEN b.betdaqid = 0 AND b.ExtraInfo IS NULL THEN 1 ELSE 0 END AS IsBetTrade,
					b.transid AS BettradeGroupID,
					b.ExtraInfo,
					CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId,
					b.awinlost,
					b.matchid,
					b.WalletType,
					b.RefCode,
					b.BonusID,
					b.actual_stake AS ActualStake,
					
					b.TransId AS SubTransId,
					NULL AS SubBetCheck,
					NULL AS SubBetTeam,
					NULL AS SubBetType,
					NULL AS SubHdp1,
					NULL AS SubHdp2,
					NULL AS SubOdds,
					NULL AS SubStatus
			FROM @tblTransIds t
				 INNER JOIN bettrans b WITH (NOLOCK)
						 ON t.transid = b.transid
				 INNER JOIN #t_exchanges te WITH (NOLOCK)
						 ON b.currency = te.exchangeid -- filter for @CurrencyCodes			 
				 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
						 ON b.recommend = c.custid
				 INNER JOIN #t_LicenseeNames tl WITH (NOLOCK)
						 ON tl.LicenseeName = c.site -- filter for @LicenseeIDs	
				 INNER JOIN match m WITH (NOLOCK)
						 ON b.matchid = m.matchid
			WHERE m.sporttype BETWEEN 1 AND 99 -- sportbook only				
				AND b.bettype NOT BETWEEN 801 AND 806-- MG
				AND b.bettype NOT BETWEEN 901 AND 910 -- BT subticket				
				AND b.bettype NOT BETWEEN 911 AND 914 -- Cash-out subticket
				AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND b.betfrom <> 'P' -- exclude phone betting
				AND b.matchid = @MatchID -- filer for @MatchID
				AND b.bettype <> 500 -- exclude charge comm	
				
				AND b.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
				AND b.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
				AND b.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
				AND b.custid NOT IN (SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- For Special bets: betdaq
				AND b.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)									
		
			SET @CountSingle = @@ROWCOUNT						
			
			-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets			
			INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, transid)
			SELECT RefCode, custid, bettype, MAX(transid)
			FROM #SpecialDeleteBets_Single
			WHERE RefCode IS NOT NULL		
			GROUP BY RefCode, custid, bettype
			HAVING COUNT(*) = 1

			IF @@ROWCOUNT > 0
			BEGIN			
				INSERT INTO #SpecialDeleteBets_Single(
							GroupID,
							Stake,
							AwayId,
							BetCheck,
							BetId,
							BetTeam,
							BetType,
							Currency,
							CurrencyCode,
							Creator,						
							Hdp1,
							Hdp2,
							HomeId,
							IsLiveIndicator,
							IsNeutral,						
							LiveAwayScore,
							LiveHomeScore,
							Odds,						
							OddsType,
							RefNo,
							SportType,
							Status,
							TransDate,
							TransDesc,
							TransId,
							UserName,
							NetWinLost,
							site,
							betfrom,
							srecommend,
							mrecommend,
							recommend,
							custid,
							balance,
							betdaqid,
							IsBetTrade,						
							BettradeGroupID,
							ExtraInfo,
							MainCashoutId,
							awinlost,
							matchid,
							WalletType,
							RefCode,
							BonusID,
							MainTransId,
							ActualStake,
						
							SubTransId,
							SubBetCheck,
							SubBetTeam,
							SubBetType,
							SubHdp1,
							SubHdp2,
							SubOdds,
							SubStatus
						)
				SELECT 	b.transid AS GroupID,
						b.Stake,
						m.AwayId,
						b.BetCheck,
						b.BetId,
						b.BetTeam,
						b.BetType,
						b.currency,
						te.currency AS CurrencyCode,
						b.Creator,					
						b.Hdp1,
						b.Hdp2,
						m.HomeId,
						b.LiveIndicator AS IsLiveIndicator,
						ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,					
						b.LiveAwayScore,
						b.LiveHomeScore,
						b.Odds,					
						b.OddsType,
						b.RefNo,
						m.SportType,
						b.status AS STATUS,
						b.TransDate,
						b.TransDesc,
						b.TransId,
						b.UserName,
						b.WinLost - b.actual_stake AS NetWinLost,
						c.site,
						b.betfrom,
						b.srecommend,
						b.mrecommend,
						b.recommend,
						b.custid,
						b.winlost - b.actual_stake + b.playercomm AS balance,
						b.betdaqid,
						CASE WHEN b.betdaqid = 0 THEN 1 ELSE 0 END AS IsBetTrade,					
						b.transid AS BettradeGroupID,
						b.ExtraInfo,
						CASE
							WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
									THEN b.transid
							ELSE NULL
						END AS MainCashoutId,
						b.awinlost,
						b.matchid,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						r.transid AS MainTransId,
						b.actual_stake AS ActualStake,
					
						b.TransId AS SubTransId,
						NULL AS SubBetCheck,
						NULL AS SubBetTeam,
						NULL AS SubBetType,
						NULL AS SubHdp1,
						NULL AS SubHdp2,
						NULL AS SubOdds,
						NULL AS SubStatus
				FROM #tmpRefCodeSummary r
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON b.RefCode = r.RefCode
								AND b.transid <> r.transid
								AND b.matchid = @MatchId
								AND b.custid = r.custid
								AND b.bettype = r.bettype
					 INNER JOIN #t_exchanges te WITH (NOLOCK)
						 ON b.currency = te.exchangeid 			 
					 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
							 ON b.recommend = c.custid
					 INNER JOIN #t_LicenseeNames tl WITH (NOLOCK)
							 ON tl.LicenseeName = c.site
					 INNER JOIN match m WITH (NOLOCK)
							 ON b.matchid = m.matchid
				WHERE b.statusID NOT IN (101,102,103) -- reject, void, refund
			END
			
			SET @CountSingle = @CountSingle + @@ROWCOUNT
			
			IF ISNULL(@SoldTransIds,'') <> ''
			BEGIN				
				INSERT INTO #tblTransIdSolds(grouptransid, transid)
				SELECT  
					sub.refno
					, sub.transid
				
				FROM dbo.bettrans sub WITH(NOLOCK)					
				WHERE sub.matchid 	= @MatchID
					AND sub.bettype 	= 901
					AND EXISTS (
						SELECT TOP 1 1 
						FROM @tblInputSoldTransIds 
						WHERE transid = sub.transid
					) 
			END
			
			-- delete main ticket if it's BT but subticket is not exists in SOLD list
			DELETE
			FROM	#SpecialDeleteBets_Single
			OUTPUT	DELETED.TransId
			INTO	@tblInvalidTrans (transid)			
			WHERE	betdaqid = 0 
					AND extrainfo is null
					AND transid NOT IN (SELECT grouptransid FROM #tblTransIdSolds)
			SET @CountSingle = @CountSingle - @@ROWCOUNT					
			
			-- delete main ticket if it's not BT but have subticket in SOLD list
			DELETE
			FROM	#SpecialDeleteBets_Single
			OUTPUT	DELETED.TransId
			INTO	@tblInvalidTrans (transid)			
			WHERE	betdaqid = -1 
					AND extrainfo is null
					AND transid IN (SELECT grouptransid FROM #tblTransIdSolds)	
			SET @CountSingle = @CountSingle - @@ROWCOUNT	
			
			-- checking cash-out process
			INSERT INTO #tblCashOutProcess(transid)
			SELECT transid
			FROM #SpecialDeleteBets_Single	
			WHERE betdaqid = 0 
			  AND charindex ('p25',extrainfo)> 0
			
			EXEC dbo.NAP_Admin_CheckingCashOutProcess 
					@Mode = 'Original'
				  , @Action = 'Void'
				  , @IsReleased = 0
			
			DELETE bd
			FROM #SpecialDeleteBets_Single bd
				 INNER JOIN #tblCashOutProcess rp ON bd.TransId = rp.transid AND rp.IsAvailable = 0	
			SET @CountSingle = @CountSingle - @@ROWCOUNT										
					
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
			
			--- check exists BT + Cash-out or not
			SELECT @isExistBT 	= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
				 , @isExistCashOut = MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
			FROM #SpecialDeleteBets_Single
			
			IF (@isExistBT = 1)
			BEGIN
				--Insert multiple Bet trade transaction (901,902,903)
				INSERT INTO #BTTransActive (custid, refno, matchid, bettype, transId, awinlost
										  , BetId, TransDate, UserName, NetWinLost, srecommend, mrecommend, recommend, balance, betdaqid
										  , ExtraInfo
										  , WalletType, RefCode, BonusID, MainTransId)
				SELECT bt.custid, bt.refno, bt.matchid, bt.bettype, bt.transId, bt.awinlost
					 , bt.BetId, bt.TransDate, bt.UserName, bt.NetWinLost, bt.srecommend, bt.mrecommend, bt.recommend, bt.balance, bt.betdaqid
					 , bt.ExtraInfo
					 , bt.WalletType, bt.RefCode, bt.BonusID, bt.MainTransId
				FROM (
					SELECT sub.custid
						, sub.refno
						, sub.matchid
						, sub.bettype
						, sub.transId
						, sub.awinlost
						, sub.betid
						, sub.TransDate
						, sub.UserName
						, sub.winlost - sub.actual_stake AS NetWinLost
						, sub.srecommend
						, sub.mrecommend
						, sub.recommend	
						, sub.winlost - sub.actual_stake + sub.playercomm AS balance	
						, sub.betdaqid
						, sub.ExtraInfo
						, sub.WalletType
						, sub.RefCode
						, sub.BonusID
						, main.transid AS MainTransId						
						, ROW_NUMBER() OVER ( PARTITION  BY sub.custid, sub.refno, sub.matchid, sub.bettype ORDER BY sub.transId DESC ) AS BTNo 
						
					FROM #SpecialDeleteBets_Single main
						INNER JOIN dbo.bettrans sub WITH(NOLOCK)					
								ON main.transId = sub.refno						
					WHERE main.betdaqid = 0
						AND main.extrainfo is null
						AND sub.matchid = @MatchID
						AND sub.bettype BETWEEN 901 AND 910
						AND sub.statusID IN (111,112,113,103)					
				) AS bt
				WHERE bt.BTNo = 1
				
				-- insert 901
				INSERT INTO #SpecialDeleteBets_Single(
							GroupID,
							Stake,
							AwayId,
							BetCheck,
							BetId,
							BetTeam,
							BetType,
							OriginalBetType,
							Currency,
							CurrencyCode,
							Creator,						
							Hdp1,
							Hdp2,
							HomeId,
							IsLiveIndicator,
							IsNeutral,						
							LiveAwayScore,
							LiveHomeScore,
							Odds,		
							Oddsspread,							
							OddsType,
							RefNo,
							SportType,
							Status,
							TransDate,
							TransDesc,
							TransId,
							UserName,
							NetWinLost,
							site,
							betfrom,
							srecommend,
							mrecommend,
							recommend,
							custid,
							balance,
							betdaqid,
							IsBetTrade,						
							BettradeGroupID,
							ExtraInfo,							
							awinlost,
							WalletType,
							RefCode,
							BonusID,
							MainTransId,
							ActualStake,
							
							SubTransId,
							SubBetCheck,
							SubBetTeam,
							SubBetType,
							SubHdp1,
							SubHdp2,
							SubOdds,
							SubStatus
						)
				SELECT  tmpmain.TransId AS GroupID,
						tmpmain.Stake,
						tmpmain.AwayId,
						tmpmain.BetCheck,
						tmpmain.BetType AS BetId,
						tmpmain.BetTeam,
						sub.BetType,
						tmpmain.BetType AS OriginalBetType,
						tmpmain.Currency,
						tmpmain.CurrencyCode,
						tmpmain.Creator,						
						tmpmain.Hdp1,
						tmpmain.Hdp2,
						tmpmain.HomeId,
						tmpmain.IsLiveIndicator,
						tmpmain.IsNeutral,						
						tmpmain.LiveAwayScore,
						tmpmain.LiveHomeScore,
						tmpmain.Odds,
						tmpmain.Oddsspread,						
						tmpmain.OddsType,
						sub.RefNo,
						tmpmain.SportType,
						'SOLD' AS Status,
						sub.TransDate,
						tmpmain.TransDesc,
						sub.TransId,
						sub.UserName,
						sub.NetWinLost,
						tmpmain.site,
						tmpmain.betfrom,
						sub.srecommend,
						sub.mrecommend,
						sub.recommend,
						sub.custid,
						sub.balance,
						sub.betdaqid,
						CAST(1 AS BIT) AS IsBetTrade,					
						sub.refno AS BettradeGroupID,
						sub.ExtraInfo,						
						sub.awinlost,
						sub.WalletType,
						sub.RefCode,
						sub.BonusID,
						sub.MainTransId,
						tmpmain.ActualStake,
						
						sub.TransId AS SubTransId,
						NULL AS SubBetCheck,
						NULL AS SubBetTeam,
						NULL AS SubBetType,
						NULL AS SubHdp1,
						NULL AS SubHdp2,
						NULL AS SubOdds,
						NULL AS SubStatus
				FROM #SpecialDeleteBets_Single tmpmain										
					 INNER JOIN #BTTransActive sub
							 ON tmpmain.transid = sub.refno															
				WHERE tmpmain.betdaqid = 0
				  AND tmpmain.extrainfo is null
				  AND sub.bettype = 901
				
				SET @CountSingle = @CountSingle + @@ROWCOUNT
				
				--insert custBT 
				INSERT INTO @tblCustBT902( custid)
				SELECT DISTINCT bt.custid
				FROM #BTTransActive bt			
				WHERE bt.bettype = 902	
			END	
			
			IF (@isExistCashOut = 1)
			BEGIN
				-- insert 911
				INSERT INTO #SpecialDeleteBets_Single(
							GroupID,
							Stake,
							AwayId,
							BetCheck,
							BetId,
							BetTeam,
							BetType,
							OriginalBetType,
							Currency,
							CurrencyCode,
							Creator,						
							Hdp1,
							Hdp2,
							HomeId,
							IsLiveIndicator,
							IsNeutral,						
							LiveAwayScore,
							LiveHomeScore,
							Odds,	
							Oddsspread,							
							OddsType,
							RefNo,
							SportType,
							Status,
							TransDate,
							TransDesc,
							TransId,
							UserName,
							NetWinLost,
							site,
							betfrom,
							srecommend,
							mrecommend,
							recommend,
							custid,
							balance,
							betdaqid,
							IsBetTrade,						
							BettradeGroupID,
							ExtraInfo,
							MainCashoutId,
							awinlost,
							matchid,
							WalletType,
							RefCode,
							BonusID,
							MainTransId,
							ActualStake,
							
							SubTransId,
							SubBetCheck,
							SubBetTeam,
							SubBetType,
							SubHdp1,
							SubHdp2,
							SubOdds,
							SubStatus
						)
				OUTPUT inserted.transid
					 , inserted.bettype 
					 , inserted.OriginalBetType
				     , inserted.MainCashoutId
				     , inserted.matchid
				     , inserted.MainTransId
						INTO #CashOutTransActive(transid
											   , bettype
											   , OriginalBetType
											   , MainCashoutId
											   , matchid
											   , MainTransId)						
				SELECT  sub.TransId AS GroupID,
						sub.Stake,
						tmpmain.AwayId,
						tmpmain.BetCheck,
						tmpmain.BetType AS BetId,
						tmpmain.BetTeam,
						sub.BetType,
						tmpmain.BetType AS OriginalBetType,
						tmpmain.Currency,
						tmpmain.CurrencyCode,
						tmpmain.Creator,						
						tmpmain.Hdp1,
						tmpmain.Hdp2,
						tmpmain.HomeId,
						tmpmain.IsLiveIndicator,
						tmpmain.IsNeutral,						
						tmpmain.LiveAwayScore,
						tmpmain.LiveHomeScore,
						tmpmain.Odds,
						tmpmain.Oddsspread,						
						tmpmain.OddsType,
						sub.RefNo,
						tmpmain.SportType,
						'Cash out' AS Status,
						sub.TransDate,
						tmpmain.TransDesc,
						sub.TransId,
						sub.UserName,
						sub.winlost - sub.actual_stake AS NetWinLost,
						tmpmain.site,
						tmpmain.betfrom,
						sub.srecommend,
						sub.mrecommend,
						sub.recommend,
						sub.custid,
						sub.balance,
						sub.betdaqid,
						CAST(0 AS BIT) AS IsBetTrade,					
						sub.refno AS BettradeGroupID,
						sub.ExtraInfo,
						tmpmain.transid AS MainCashoutId,
						sub.awinlost,
						sub.matchid,
						sub.WalletType,
						sub.RefCode,
						sub.BonusID,
						tmpmain.TransId AS MainTransId,
						tmpmain.ActualStake,
						
						sub.TransId AS SubTransId,
						NULL AS SubBetCheck,
						NULL AS SubBetTeam,
						NULL AS SubBetType,
						NULL AS SubHdp1,
						NULL AS SubHdp2,
						NULL AS SubOdds,
						NULL AS SubStatus
				FROM dbo.bettrans sub WITH(NOLOCK)
					 INNER JOIN #SpecialDeleteBets_Single tmpmain
							 ON	sub.refno = tmpmain.transid	
								AND sub.matchid = tmpmain.matchid
								AND sub.custid = tmpmain.custid													
								AND tmpmain.betdaqid = 0
								AND charindex ('p25',tmpmain.extrainfo)> 0			
								AND sub.bettype = 911								
				WHERE sub.statusID NOT IN (102, 101, 103) -- VOID, REJECT, REFUND
				
				SET @CountSingle = @CountSingle + @@ROWCOUNT
				
				-- insert cash-out member bet tickets
				INSERT INTO #SpecialDeleteBets_Single(
						GroupID,
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
						OriginalBetType,
						Currency,
						CurrencyCode,
						Creator,						
						Hdp1,
						Hdp2,
						HomeId,
						IsLiveIndicator,
						IsNeutral,						
						LiveAwayScore,
						LiveHomeScore,
						Odds,
						Oddsspread,						
						OddsType,
						RefNo,
						SportType,
						Status,
						TransDate,
						TransDesc,
						TransId,
						UserName,
						NetWinLost,
						site,
						betfrom,
						srecommend,
						mrecommend,
						recommend,
						custid,
						balance,
						betdaqid,
						IsBetTrade,						
						BettradeGroupID,
						ExtraInfo,
						MainCashoutId,
						IsCashOutMemberTicket,
						awinlost,
						WalletType,
						RefCode,
						BonusID,
						MainTransId,
						ActualStake,
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds,
						SubStatus	
					)
				SELECT  sub911.TransId AS GroupID,
						b.Stake,
						m.AwayId,
						b.BetCheck,
						b.BetId,
						b.BetTeam,
						b.BetType,
						sub911.OriginalBetType,
						b.Currency,
						te.currency AS CurrencyCode,
						b.Creator,					
						b.Hdp1,
						b.Hdp2,
						m.HomeId,
						b.LiveIndicator AS IsLiveIndicator,
						ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,					
						b.LiveAwayScore,
						b.LiveHomeScore,
						b.Odds,	
						b.Oddsspread,						
						b.OddsType,
						b.RefNo,
						m.SportType,
						b.status AS STATUS,
						b.TransDate,
						b.TransDesc,
						b.TransId,
						b.UserName,
						b.WinLost - b.actual_stake AS NetWinLost,
						c.site,
						b.betfrom,
						b.srecommend,
						b.mrecommend,
						b.recommend,
						b.custid,
						b.winlost - b.actual_stake 
						+ b.playercomm AS balance,
						b.betdaqid,
						CAST(0 AS BIT) AS IsBetTrade,					
						b.transid AS BettradeGroupID,
						b.ExtraInfo,
						sub911.MainCashoutId,
						1 AS IsCashOutMemberTicket,
						b.awinlost,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						sub911.MainTransId,
						sub911.ActualStake,
						b.TransId AS SubTransId,
						NULL AS SubBetCheck,
						NULL AS SubBetTeam,
						NULL AS SubBetType,
						NULL AS SubHdp1,
						NULL AS SubHdp2,
						NULL AS SubOdds,
						NULL AS SubStatus
				FROM #SpecialDeleteBets_Single sub911
			 		CROSS APPLY (
							  SELECT b.Stake,
							  		b.BetCheck,
									b.BetId,
									b.BetTeam,
									b.BetType,
									b.Currency,
									b.Creator,					
									b.Hdp1,
									b.Hdp2,
									b.LiveIndicator,				
									b.LiveAwayScore,
									b.LiveHomeScore,
									b.Odds,	
									b.Oddsspread,						
									b.OddsType,
									b.RefNo,
									b.status,
									b.TransDate,
									b.TransDesc,
									b.TransId,
									b.UserName,
									b.WinLost,
									b.actual_stake,
									b.betfrom,
									b.srecommend,
									b.mrecommend,
									b.recommend,
									b.custid,
									b.playercomm,
									b.betdaqid,	
									b.ExtraInfo,
									b.awinlost,
									b.WalletType,
									b.RefCode,
									b.BonusID,
									b.matchid
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID NOT IN (102, 101, 103) -- VOID, REJECT, REFUND
						 ) AS b
						LEFT JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
						 	ON b.recommend = c.custid					
					 	LEFT JOIN (SELECT [site] AS LicenseeName
									 , CASE 
											WHEN isLicensee = 0		  
												 AND isActive = 1	
												 AND [site] NOT IN (@789y_Name, @cn88_Name)
													THEN @MBCGroup_Name
											ELSE [site]
									   END AS GroupName
								FROM DBCUST.CUSTDB.dbo.Site WITH(NOLOCK)) tl
							 ON tl.LicenseeName = c.site
					 	LEFT JOIN match m WITH (NOLOCK)
							 ON b.matchid = m.matchid
					 	LEFT JOIN CustDB.dbo.exchange te WITH(NOLOCK)
							 ON b.currency = te.exchangeid
				WHERE sub911.bettype = 911

				SET @CountSingle = @CountSingle + @@ROWCOUNT
				
				--Insert multiple cash-out transaction (912,913)
				INSERT INTO #CashOutTransActive(bettype, transId, MainTransId)
				SELECT sub_912_913.bettype, sub_912_913.transId, sub911.MainTransId									
				FROM #CashOutTransActive sub911
					INNER JOIN dbo.bettrans sub_912_913 WITH(NOLOCK)					
							ON sub911.transId = sub_912_913.refno
							   AND sub911.matchid = sub_912_913.matchid							   					
							   AND sub_912_913.bettype IN (912,913)
							   AND sub_912_913.statusID NOT IN (102, 101, 103) -- VOID, REJECT, REFUND
							   				
				--insert custCashOut912
				INSERT INTO @tblCustCashOut912( custid)
				SELECT DISTINCT custid
				FROM #SpecialDeleteBets_Single
				WHERE IsCashOutMemberTicket = 1	
			END		
		END
		
		--> Get parlay tickets	
		BEGIN
			INSERT INTO #SpecialDeleteBets_Parlay(
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
						Currency,
						CurrencyCode,
						Creator,						
						Hdp1,
						Hdp2,
						HomeId,
						IsLiveIndicator,
						IsNeutral,						
						LiveAwayScore,
						LiveHomeScore,
						Odds,
						Oddsspread,						
						OddsType,
						RefNo,
						SportType,
						Status,
						TransDate,
						TransDesc,
						TransId,
						UserName,
						NetWinLost,
						site,
						betfrom,
						srecommend,
						mrecommend,
						recommend,
						custid,
						balance,
						betdaqid,
						IsBetTrade,						
						BettradeGroupID,
						SubTransDesc,					
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds,
						SubStatus,
						ExtraInfo,
						ActualStake
					)
			SELECT  main.Stake,
					m.AwayId,
					main.BetCheck,
					main.BetId,
					main.BetTeam,
					main.BetType,
					main.currency,
					te.currency AS CurrencyCode,
					main.Creator,					
					main.Hdp1,
					main.Hdp2,
					m.HomeId,
					sub.LiveIndicator AS IsLiveIndicator,
					ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,					
					sub.LiveAwayScore,
					sub.LiveHomeScore,
					main.Odds,
					main.Oddsspread,					
					main.OddsType,
					main.RefNo,
					m.SportType,
					main.status AS STATUS,
					main.transdate AS TransDate,
					main.transdesc AS TransDesc,
					main.transid AS TransId,
					main.UserName,
					main.winlost - main.actual_stake AS NetWinLost,
					c.site,
					main.betfrom,
					main.srecommend,
					main.mrecommend,
					main.recommend,
					main.custid,
					main.winlost - main.actual_stake + main.playercomm AS balance,
					main.betdaqid,
					CAST(0 AS BIT) AS IsBetTrade,					
					main.transid AS BettradeGroupID,
					sub.transdesc AS SubTransDesc,					
					sub.transid AS SubTransId,
					sub.betcheck AS SubBetCheck,
					sub.betteam AS SubBetTeam,
					sub.bettype AS SubBetType,
					sub.hdp1 AS SubHdp1,
					sub.hdp2 AS SubHdp2,
					sub.odds AS SubOdds,
					sub.status AS SubStatus,
					main.ExtraInfo,
					main.actual_stake AS ActualStake
			FROM @tblTransIds t				 				 						 			 				 					 				 
				 INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON t.transid = sub.transid
				 INNER HASH JOIN bettrans main WITH (NOLOCK) ON sub.refno = main.refno
				 INNER JOIN match m WITH (NOLOCK)
						 ON sub.matchid = m.matchid
				
				INNER JOIN #t_exchanges te WITH (NOLOCK)
					     ON main.currency = te.exchangeid  -- filter for @CurrencyCodes
				INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
						 ON main.recommend = c.custid
				INNER JOIN #t_LicenseeNames tl1 WITH (NOLOCK)
						 ON c.site = tl1.LicenseeName -- filter for @LicenseeIDs						 
			WHERE main.matchid =29 AND main.bettype = 29 -- parlay
				AND main.statusID NOT IN (101, 102) -- reject, void				
				AND main.betfrom <> 'P' -- exclude phone betting
				
				AND m.sporttype BETWEEN 1 AND 99 -- sportbook only				
				AND sub.matchid = @matchid -- filer for @MatchID
				AND sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND sub.betfrom <> 'P' -- exclude phone betting	
				
				AND main.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
				AND main.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
				AND main.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
				AND main.custid NOT IN (SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- For Special bets: betdaq
				AND main.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)
			SET @CountParlay = @@ROWCOUNT				
		END

		-------> Check No ticket found
		IF @CountSingle + @CountParlay = 0
		BEGIN			
			IF @InvalidTransIds = ''
				SELECT @ErrorCode = 99
					 , @ErrorMsg = 'No ticket found.'
			
			-------> releasing cash-out process
			EXEC dbo.NAP_Admin_CheckingCashOutProcess 
					@Mode = 'Original'
				  , @Action = 'Void'
				  , @IsReleased = 1			
			
			RETURN
		END
		ELSE
		BEGIN
			IF @CountSingle > 0
			BEGIN

				SELECT	@isExistMatch	= MAX (CASE WHEN b.Bettype <> 38 AND f.GroupID IS NULL THEN 1 ELSE 0 END)  
					,@isExistFM = MAX(CASE WHEN f.GroupID = 1 THEN 1 ELSE 0 END)
					,@isExistBB		= MAX (CASE WHEN b.Bettype = 38 THEN 1 ELSE 0 END)
					,@isExistFM2 = MAX(CASE WHEN f.GroupID = 2 THEN 1 ELSE 0 END)
				FROM #SpecialDeleteBets_Single b
					OUTER APPLY (
								SELECT GroupId
								FROM dbo.f_TVS_CheckingProcessGroupBettypes()
								WHERE Bettype = b.Bettype
						)f
			
					 			 

				INSERT INTO #tblMatchProcess (matchid, KeyID)
				SELECT @matchid AS matchid, 1 AS KeyID WHERE @isExistMatch = 1 
				UNION ALL
				SELECT @matchid AS matchid ,6 AS KeyID WHERE @isExistFM = 1
				UNION ALL
				SELECT @matchid AS matchid, 5 AS KeyID WHERE @isExistBB = 1
				UNION ALL
				SELECT @matchid AS matchid, 7 AS KeyID WHERE @isExistFM2 = 1
			END
			
			IF @CountParlay > 0
				SET @IsExistParlay = 1
				
			-------> Check concurrent single, parlay
			EXEC dbo.NAP_Admin_CheckingProcess
				  @IsReleased	= 0
				, @isExistMatch		= @isExistMatch	
				, @isExistFM		= @isExistFM				
				, @IsExistParlay	= @IsExistParlay
				, @isExistBB		= @isExistBB
				, @isExistFM2		= @isExistFM2
				, @spName			= @spName
				, @avaiableProcess 	= @AvaiableProcess OUTPUT
				, @ErrCode			= @ErrorCode OUTPUT
				, @ErrMsg			= @ErrorMsg OUTPUT
				
			IF(@ErrorCode <> 0 OR @AvaiableProcess = 0) 
			BEGIN				
				-------> releasing cash-out process
				EXEC dbo.NAP_Admin_CheckingCashOutProcess 
						@Mode = 'Original'
					  , @Action = 'Void'
					  , @IsReleased = 1
				RETURN
			END

			-- Apply for move match Cricket
			IF EXISTS ( SELECT TOP 1 1 
						FROM @tblTransIds t
						INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.transid = t.transid
						WHERE matchid <> @MatchId
					)
			BEGIN
				SELECT	@ErrorCode = 99
						,@ErrorMsg = 'Some tickets not found.'

				EXEC dbo.NAP_Admin_CheckingProcess
					  @IsReleased		= 1						
					, @isExistMatch		= @isExistMatch	
					, @isExistFM		= @isExistFM		
					, @isExistBB		= @isExistBB		
					, @isExistParlay	= @isExistParlay
					, @isExistFM2		= @isExistFM2

				RETURN
			END
			--Parlay
			IF EXISTS ( SELECT TOP 1 1 
						FROM @tblTransIds t
							INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON bm.transid = t.transid
							INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON bm.refno = b.refno  
						WHERE b.matchid = 29  
							AND b.bettype = 29   
							AND bm.matchid  <> @matchid  
					)
			BEGIN
				SELECT	@ErrorCode = 99
						,@ErrorMsg = 'Some tickets not found.'

				EXEC dbo.NAP_Admin_CheckingProcess
					  @IsReleased		= 1						
					, @isExistMatch		= @isExistMatch	
					, @isExistFM		= @isExistFM		
					, @isExistBB		= @isExistBB		
					, @isExistParlay	= @isExistParlay
					, @isExistFM2		= @isExistFM2
				RETURN
			END 

		END
		
		INSERT INTO #t_CustID_501(custid)
		SELECT DISTINCT custid 
		FROM #SpecialDeleteBets_Single 
		WHERE BetType = 501		
		
		--> capture Before Balance Update
		IF @CountSingle > 0
		BEGIN
			INSERT INTO #NegativeBalance (transid)  
			SELECT	b.transid
			FROM  #SpecialDeleteBets_Single b WITH (NOLOCK)
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets_Single sub911 (NOLOCK)
						WHERE sub911.bettype = 911 AND sub911.transid = b.refno) -- exclude Cash out
				AND CASE WHEN b.betdaqid = 0 AND b.extrainfo IS NULL THEN 0 ELSE 1 END = 1 -- exclude BT member
		END		
		
		IF @CountParlay > 0
		BEGIN
			INSERT INTO #NegativeBalance (transid)  
			SELECT	b.transid
			FROM  #SpecialDeleteBets_Parlay b WITH (NOLOCK)
		END
		

		INSERT INTO #BeforeUpd(custid, balance)
		SELECT	b.custid , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE transid IN (SELECT transid FROM #NegativeBalance)			
		GROUP BY b.CustID

		-------> Insert backups	
		--> backups for single
		IF @CountSingle > 0
		BEGIN
			-- backup for normal ticket, main bettrade, main cash-out, cash-out member bet tickets
			INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
						winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
						winlostdate,betfrom,
						betcheck,
						checktime,matchid, bettype)
			SELECT  main.transid, main.custid, CURRENT_TIMESTAMP, main.oddsid, main.hdp1, main.hdp2, main.odds, main.stake, main.status, 
					main.winlost, main.livehomescore, main.liveawayscore, main.liveindicator, main.betteam, main.creator , main.refno, 
					main.winlostdate, main.betfrom, 
					CASE
						WHEN (tmpmain.betdaqid = 0 AND charindex ('p25',tmpmain.extrainfo)> 0) -- main ticket is Cash-out
							 OR tmpmain.IsCashOutMemberTicket = 1
								THEN @session
						ELSE main.betcheck
					END AS betcheck, 
					main.checktime, main.matchid, main.bettype
			FROM #SpecialDeleteBets_Single tmpmain
				 INNER JOIN dbo.bettrans main WITH (nolock)
						 ON tmpmain.transid = main.transid
			WHERE tmpmain.BetType NOT BETWEEN 901 AND 910
			  AND tmpmain.BetType NOT BETWEEN 911 AND 914
			
			-- backups for bettrade sub ticket (901,902,903)
			IF (@isExistBT = 1)
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
				FROM #BTTransActive bt
					INNER JOIN dbo.bettrans AS sub WITH (NOLOCK)
							ON bt.transId = sub.transId
				
			-- backups for cash-out sub ticket (911,912,913)
			IF (@isExistCashOut = 1)			
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
				FROM #CashOutTransActive bt
					INNER JOIN dbo.bettrans AS sub WITH (NOLOCK)
							ON bt.transId = sub.transId			
		END				
		
		--> backups for parlay	
		IF @CountParlay > 0
		BEGIN
			-- BackUp bettransm tickets into zzzbettrans  
			INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
					winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
					winlostdate, betfrom, betcheck, checktime, matchid, bettype
			)  
			SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
					b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
					b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype  
			FROM #SpecialDeleteBets_Parlay AS r 	  
				INNER JOIN dbo.bettransm AS b WITH (nolock)
					ON	r.SubTransId = b.transid			 

			--BackUp tickets of bettransm  
			INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
					 winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
					 winlostdate, betfrom, betcheck, checktime, matchid, bettype)  
			SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
					b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
					b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype  
			FROM #SpecialDeleteBets_Parlay AS r	 
				INNER JOIN dbo.bettransm AS b WITH (nolock)  
					ON	r.SubTransId=b.transid						
		END
		
		-------> Capture before balance		
		INSERT INTO @tblBeforeBalance (matchid
									 , custid  			 
									 , balanceType
									 , BonusID
									 , WalletType 
									 , balance)
		SELECT @MatchId AS matchid
			 , custid  
			 , 1 AS balanceType
			 , CASE WHEN T.BonusID > 0 AND T.WalletType = 1 THEN T.BonusID ELSE 0 END AS BonusID
			 , ISNULL(T.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(T.winlost - T.actual_stake + T.playercomm) balance
		FROM (
				-- normal, main bettrade, main cash-out, cash-out member bet ticket
				SELECT	b.custid
					  , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 0 ELSE b.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
					  , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 2 ELSE b.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
					  , b.winlost, b.actual_stake, b.playercomm, b.bettype
				FROM #SpecialDeleteBets_Single t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid
				WHERE t.BetType NOT BETWEEN 901 AND 910
				  AND t.BetType NOT BETWEEN 911 AND 914
				UNION ALL
				-- sub bettrade (901,902,903)
				SELECT sub.custid
					 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
					 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
					 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype
				FROM dbo.bettrans sub WITH (NOLOCK)
					INNER JOIN #BTTransActive bt 
						ON sub.transId = bt.transId				
				UNION ALL
				-- sub cash-out (911,912,913)
				SELECT sub.custid
					 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
					 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
					 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype
				FROM dbo.bettrans sub WITH (NOLOCK)
					INNER JOIN #CashOutTransActive bt 
						ON sub.transId = bt.transId										
				UNION ALL
				-- parlay				
				SELECT b.custid
					 , 0 AS BonusID -- parlay tickets always bet from cash wallet
					 , 2 AS WalletType -- parlay tickets always bet from cash wallet
					 , b.winlost, b.actual_stake, b.playercomm, b.bettype
				FROM #SpecialDeleteBets_Parlay t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid				
				UNION ALL
				-- Cricket charge comm			  
			    SELECT b.custid
					 , 0 AS BonusID -- cricket tickets always bet from cash wallet
					 , 2 AS WalletType -- cricket tickets always bet from cash wallet
					 , b.winlost, b.actual_stake, b.playercomm, b.bettype
				FROM #t_CustID_501 t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON t.custid = b.custid
				WHERE b.bettype = 500
				  AND b.matchid = @MatchID				
				UNION ALL
				-- BT-WLSharing (904)								
				SELECT sub904.custid
					 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
					 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
					 , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype
				FROM bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp
					ON sub904.custid = temp.custid
						AND sub904.matchid = @MatchID											
				WHERE sub904.bettype = 904				
				UNION ALL
				-- cash-out summary 914
				SELECT sub914.custid
					 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
					 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
					 , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype
				FROM bettrans sub914 WITH (NOLOCK)
					INNER JOIN @tblCustCashOut912 temp
					ON sub914.custid = temp.custid
						AND sub914.matchid = @MatchID											
				WHERE sub914.bettype = 914				
			 ) AS T
		GROUP BY T.custid			   
			   , CASE WHEN T.BonusID > 0 AND T.WalletType = 1 THEN T.BonusID ELSE 0 END
			   , ISNULL(T.WalletType, 2) -- normal tickets are treated as cash tickets
		
		-------> update status for tickets to void		
		--> update status for single
		IF @CountSingle > 0
		BEGIN
			-- update status for normal, main bettrade, main cash-out, cash-out member bet ticket
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
				INNER JOIN #SpecialDeleteBets_Single tmpmain
					ON	main.transid = tmpmain.transid					
						AND main.matchid = @matchid	
						AND tmpmain.Bettype NOT BETWEEN 901 AND 910
						AND tmpmain.Bettype NOT BETWEEN 911 AND 914
			
			IF (@isExistBT = 1 OR @isExistCashOut = 1)
			BEGIN
				-- update status for sub bettrade ticket (901,902,903)
				IF (@isExistBT = 1)
					UPDATE sub
					SET winlost = sub.actual_stake
						,ruben = 1
						--,statuswinlost = 6
						,creator = @UserID
						,mwinlost = 0
						,swinlost = 0
						,awinlost = 0
						,playercomm = 0
						,comm = 0
						,acomm = 0
						,scomm = 0
						,statusID = 102
						,status = 'VOID'
					FROM dbo.bettrans AS sub WITH (ROWLOCK, UPDLOCK)
						INNER JOIN #BTTransActive bt
						ON sub.transId = bt.transId
				
				-- update status for sub cash-out ticket (911,912,913)
				IF (@isExistCashOut = 1)
					UPDATE sub
					SET winlost = sub.actual_stake
						,ruben = 1
						--,statuswinlost = 6
						,creator = @UserID
						,mwinlost = 0
						,swinlost = 0
						,awinlost = 0
						,playercomm = 0
						,comm = 0
						,acomm = 0
						,scomm = 0
						,statusID = 102
						,status = 'VOID'
					FROM dbo.bettrans AS sub WITH (ROWLOCK, UPDLOCK)
						INNER JOIN #CashOutTransActive bt
						ON sub.transId = bt.transId
				
				--Pre-CAL 904
				IF (@isExistBT = 1)	
				BEGIN
					SET @CustIds_BT_CashOut = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
													 FROM @tblCustBT902 tt								    
													 FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')											    
					EXEC dbo.NAP_Admin_Calculate_904 
							@MatchId 	= @MatchID
							, @Action 	= 'VOID'
							, @CustIds 	= @CustIds_BT_CashOut
				END
				
				--Pre-CAL 914
				IF (@isExistCashOut = 1)
				BEGIN
					SET @CustIds_BT_CashOut = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
													 FROM @tblCustCashOut912 tt								    
													 FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')											    
					EXEC dbo.NAP_Admin_Calculate_914 
							@MatchId 	= @MatchID
							, @Action 	= 'VOID'
							, @CustIds 	= @CustIds_BT_CashOut
				END
				
				-- Update BetTrade selling information
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
				SELECT DISTINCT custid FROM #SpecialDeleteBets_Single
				
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
						INNER JOIN #SpecialDeleteBets_Single d 
								 ON bal.CustId = d.CustId 
									AND bal.MatchId = @MatchId 
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
					FROM #SpecialDeleteBets_Single tmpsub						 											 
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
						FROM	#SpecialDeleteBets_Single 
						WHERE	betdaqid = 0 -- main ticket
						  AND	extrainfo is null
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
		END				
		
		--> update status for parlay
		IF @CountParlay > 0
		BEGIN
			DECLARE @matchdate		DATETIME				
					,@rowcount		INT
					,@step			INT
					,@transid_tmp	VARCHAR(2000) 		
			DECLARE @transids_29 VARCHAR(MAX) = ''  
				  , @refnos_29  VARCHAR(MAX) = ''				  						  			  		   		
			
			SELECT	@matchdate = eventdate,  				  
					@step = 0  
			FROM	match WITH(NOLOCK)   
			WHERE	matchid = @matchid
			
			SELECT	@transids_29 = @transids_29 + CONVERT(VARCHAR(20), transid) + ','
				  , @refnos_29 = @refnos_29 + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid) + ','  
			FROM	#SpecialDeleteBets_Parlay									
			
			-- update bettransm,BetParlayDetail			
			WHILE @step < @CountParlay  
			BEGIN  
				SET @transid_tmp = ''  

				SELECT	@transid_tmp  = @transid_tmp + CONVERT(VARCHAR(20),SubTransId)  + ','   
				FROM	#SpecialDeleteBets_Parlay  
				WHERE	id > @step 
						AND id <= @step + @VoidPatchSize  
				 
				SET @step = @step + @VoidPatchSize  

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
			
			-- call pre-cal-29: update BetParlayResult		  
			EXEC dbo.NAP_Admin_Calculate_MP_broker   
				@matchid = @matchid  
				,@matchdate = @matchdate  
				,@strXML = @transids_29  
				,@mode  = 'PRECAL-29'
			
			-- call cal_29: update bettrans
			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchdate = @MatchDate
				,@strXML	= @refnos_29  -- main transid + refno: refno|transid,refno|transid...
				,@mode		= '29' 
		END	
		
		--> re-calculate Cricket - charge comm			
		IF EXISTS (SELECT TOP 1 1
				   FROM #t_CustID_501)
		BEGIN
			DECLARE @CustIds VARCHAR(MAX)
			
			SET @CustIds = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
								  FROM #t_CustID_501								  
								  FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
									
			EXEC dbo.NAP_Admin_Calculate_500 @MatchId	= @MatchID
						, @Action = 'VOID'
						, @CustIds = @CustIds									
		END
		
		-------> Capture after balance		
		INSERT INTO @tblAfterBalance (matchid
									 , custid  			 
									 , balanceType
									 , BonusID
									 , WalletType 
									 , balance)
		SELECT @MatchId AS matchid
			 , custid  
			 , 1 AS balanceType
			 , CASE WHEN T.BonusID > 0 AND T.WalletType = 1 THEN T.BonusID ELSE 0 END AS BonusID
			 , ISNULL(T.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(T.winlost - T.actual_stake + T.playercomm) balance
		FROM (
				-- normal, main bettrade, main cash-out, cash-out member bet ticket
				SELECT	b.custid
					  , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 0 ELSE b.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
					  , CASE WHEN t.IsCashOutMemberTicket = 1 THEN 2 ELSE b.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
					  , b.winlost, b.actual_stake, b.playercomm, b.bettype
				FROM #SpecialDeleteBets_Single t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid
				WHERE t.BetType NOT BETWEEN 901 AND 910
				  AND t.BetType NOT BETWEEN 911 AND 914				
				UNION ALL
				-- sub bettrade (901,902,903)												
				SELECT sub.custid
					 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
					 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
					 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype
				FROM dbo.bettrans sub WITH (NOLOCK)
					INNER JOIN #BTTransActive bt 
						ON sub.transId = bt.transId				
				UNION ALL
				-- sub cash-out (911,912,913)
				SELECT sub.custid
					 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
					 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
					 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype
				FROM dbo.bettrans sub WITH (NOLOCK)
					INNER JOIN #CashOutTransActive bt 
						ON sub.transId = bt.transId										
				UNION ALL
				-- parlay				
				SELECT b.custid
					 , 0 AS BonusID -- parlay tickets always bet from cash wallet
					 , 2 AS WalletType -- parlay tickets always bet from cash wallet
					 , b.winlost, b.actual_stake, b.playercomm, b.bettype
				FROM #SpecialDeleteBets_Parlay t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid				
				UNION ALL
				-- Cricket charge comm			  
			    SELECT b.custid
					 , 0 AS BonusID -- cricket tickets always bet from cash wallet
					 , 2 AS WalletType -- cricket tickets always bet from cash wallet
					 , b.winlost, b.actual_stake, b.playercomm, b.bettype
				FROM #t_CustID_501 t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON t.custid = b.custid
				WHERE b.bettype = 500
				  AND b.matchid = @MatchID				
				UNION ALL
				-- BT-WLSharing (904)								
				SELECT sub904.custid
					 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
					 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
					 , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype
				FROM bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp
					ON sub904.custid = temp.custid
						AND sub904.matchid = @MatchID											
				WHERE sub904.bettype = 904				
				UNION ALL
				-- cash-out summary 914
				SELECT sub914.custid
					 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
					 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
					 , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype
				FROM bettrans sub914 WITH (NOLOCK)
					INNER JOIN @tblCustCashOut912 temp
					ON sub914.custid = temp.custid
						AND sub914.matchid = @MatchID											
				WHERE sub914.bettype = 914				
			 ) AS T
		GROUP BY T.custid			   
			   , CASE WHEN T.BonusID > 0 AND T.WalletType = 1 THEN T.BonusID ELSE 0 END
			   , ISNULL(T.WalletType, 2) -- normal tickets are treated as cash tickets
		
		-------> Update balance for members	
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				  @BalanceWalletBefore	= @tblBeforeBalance
				, @BalanceWalletAfter	= @tblAfterBalance
				, @ActionId				= 0
		
		--> Capture balance after update	
		INSERT INTO #AfterUpd(custid, balance)
		SELECT	b.custid , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE transid IN (SELECT transid FROM #SpecialDeleteBets_Single UNION ALL SELECT transid FROM #SpecialDeleteBets_Parlay)
		GROUP BY b.CustID

		SET @NegativeBalanceUsers = ''
		SELECT @NegativeBalanceCustIds = @NegativeBalanceCustIds + 
			CASE WHEN @NegativeBalanceCustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20), b.custid)
		FROM #BeforeUpd b
			 INNER JOIN	#AfterUpd a ON a.custid = b.custid
		WHERE b.balance > a.balance

		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @NegativeBalanceCustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			 
		-------> Release process
		EXEC dbo.NAP_Admin_CheckingProcess
			  @IsReleased		= 1						
			, @isExistMatch		= @isExistMatch	
			, @isExistFM		= @isExistFM		
			, @isExistBB		= @isExistBB		
			, @isExistParlay	= @isExistParlay
			, @isExistFM2		= @isExistFM2
			
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1				 
			
		-------> write log		
		EXEC WriteLog_UserLog 
			 @UserId = @UserId,
			 @Doing = @LogData			
			 
		-------> Data for sending mail
		DECLARE @IsITAdmin BIT = 0
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
		
		SELECT  s.Stake,				
				s.BetCheck,
				s.BetId,
				s.BetTeam,
				s.OriginalBetType,
				s.Currency,
				s.CurrencyCode AS CurrencyName,	
				s.IsNeutral,				
				s.LiveAwayScore,
				s.LiveHomeScore,
				s.Odds,
				s.oddsspread,
				s.OddsType,
				s.RefNo,
				s.Status,
				s.TransDate,
				s.TransDesc,
				s.TransId,
				s.site,
				s.IsBetTrade,
				CASE WHEN s.IsCashOutMemberTicket = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isCashOut,
				s.betdaqid,
				s.ExtraInfo,
				s.MainCashoutId,
				s.RefCode,
				s.betfrom,
				s.WalletType,
				s.IsLiveIndicator AS IsLive,
				s.BetType AS BetTypeId,
				s.Hdp1 AS Handicap1,
				s.Hdp2 AS Handicap2,
				s.NetWinLost AS WinLost,

				s.IsMixParlay,
				s.SubTransDesc,
				s.SubBetType,
				s.SubHdp1,
				s.SubHdp2,
				s.SubOdds,
				s.SubStatus,
				s.SubBetTeam,
				s.SubBetCheck,
				@SettlementStatus AS SettlementStatus,
				@GlobalShowTime AS GlobalShowTime,
				s.ActualStake,
				s.MainTransId,
				-----------------------
				s.custid,
				s.UserName,
				ci.username2,
				s.recommend,
				s.mrecommend,
				s.srecommend,
				ac.username AS AgUserName,
				mc.username AS MagUserName,
				sc.username AS SagUserName,
				CASE 
					WHEN @eventstatus <> @eventstatus_completed
							THEN CASE
									WHEN LOWER(s.Status) IN ('won', 'lose', 'draw')
											AND EXISTS (SELECT TOP 1 1
														FROM #InstantSettlementBettypes
														WHERE bettype = s.bettype)
											THEN CAST(1 AS BIT)
									ELSE CAST(0 AS BIT)
								END
					ELSE CAST(0 AS BIT)
				END AS IsInstantSettlementTicket,
				-----------------------
				CASE
					WHEN s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
					ELSE s.site
				END AS EmailGroup,
				CASE
					WHEN T2.a IS NOT NULL 
						 AND @IsITAdmin = 1
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)							
				END AS IsItSupport,
				CASE WHEN dc.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
							
		FROM (
				SELECT CAST(0 AS BIT) AS IsMixParlay, * FROM #SpecialDeleteBets_Single				
				UNION ALL
				SELECT CAST(1 AS BIT) AS IsMixParlay, * FROM #SpecialDeleteBets_Parlay
			 ) s
			 INNER JOIN CustDB.dbo.Customer ci WITH(NOLOCK) ON s.custid = ci.custid
			 LEFT JOIN CustDB.dbo.Customer sc WITH(NOLOCK) ON s.srecommend = sc.custid
			 LEFT JOIN CustDB.dbo.Customer mc WITH(NOLOCK) ON s.mrecommend = mc.custid
			 LEFT JOIN CustDB.dbo.Customer ac WITH(NOLOCK) ON s.recommend = ac.custid
			 LEFT JOIN custdb.dbo.Dep_CustSuper dc with(nolock) ON s.srecommend = dc.custid  
			 OUTER APPLY (SELECT CASE
									WHEN sc.currency <> 20 
										 AND sc.roleid = 4 
											THEN 1
									ELSE NULL
								 END AS a) AS T2
		ORDER BY s.IsMixParlay ASC
			   , ISNULL(s.MainTransId, s.transid) ASC
			   , CASE 
					WHEN s.BonusID IS NOT NULL
							THEN CASE 
									WHEN s.MainTransId IS NULL THEN 1
									ELSE 2 
								 END
					ELSE s.transid
				 END
	END TRY
	BEGIN CATCH
		-------> Release process
		EXEC dbo.NAP_Admin_CheckingProcess
			  @IsReleased		= 1						
			, @isExistMatch		= @isExistMatch			
			, @isExistParlay  = @isExistParlay
			
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1						  
	
		SELECT @ErrorCode = 100,
				@ErrorMsg = @GeneralErrMsg

		RETURN				
	END CATCH		
	
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN     
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, @MatchID, GETDATE(),@SubmittedDate)
		END      
	END TRY
	BEGIN CATCH
	END CATCH
			
	SET NOCOUNT OFF

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #SpecialDeleteBets_Single
	DROP TABLE #SpecialDeleteBets_Parlay
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #BTTransActive
	DROP TABLE #CashOutTransActive
	DROP TABLE #t_CustID_501  
	DROP TABLE #t_LicenseeNames 
	DROP TABLE #t_UIRepresentativeLicenseeGroupNames
	DROP TABLE #t_exchanges  
	DROP TABLE #tblMatchProcess 
	DROP TABLE #tblCashOutProcess
	DROP TABLE #BeforeUpd  
	DROP TABLE #AfterUpd 
	DROP TABLE #NegativeBalance
	DROP TABLE #InstantSettlementBettypes

END
GO
			