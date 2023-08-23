/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_Update]
(
	@MatchID			INT = 0,
	@LicenseeNames		VARCHAR(MAX),
	@CurrencyIDs		VARCHAR(MAX),
	@TransIDs			VARCHAR(MAX),
	@UserID				INT,  
	@UserName			NVARCHAR(50),
	@UserPassword		NVARCHAR(50),  
	@Reason				NVARCHAR(500) = '',  
	@ReasonSC			NVARCHAR(500) = '',
	@IP					VARCHAR(15)  = '',
	@IsOutright			BIT = 0
)
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
		- 20210720@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210827@Max: [TVS] Support Outright on Void By Currency [Redmine: #159540]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
		- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
		- 20220531@July: [TVS] Send data to Jacktime for Cashout Basketball [Redmine: #173389]
		- 20220615@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230608@July: Support sport Cricket for all functions [Redmine: #188374]
		- 20230705@July: [SD] Enhance void log to detect more information [Redmine: #190590]
		- 20230822@July: [TVS] Instant Settlement of Basketball [Redmine: #185492]

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
	SET @LogActionId = 90514
	SET @SB_Error = 0

	SET @LogData = CASE WHEN @MatchId IS NULL THEN '' ELSE '@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
					+ CASE WHEN @TransIDs IS NULL THEN '' ELSE ',@TransIDs = ''' + CONVERT(NVARCHAR(MAX), @TransIDs) + '''' END
					+ CASE WHEN @LicenseeNames IS NULL THEN '' ELSE ',@LicenseeNames = ''' + CONVERT(NVARCHAR(MAX), @LicenseeNames) + '''' END
					+ CASE WHEN @CurrencyIDs IS NULL THEN '' ELSE ',@CurrencyIDs = ''' + CONVERT(NVARCHAR(MAX), @CurrencyIDs) + '''' END
					+ CASE WHEN @UserID IS NULL THEN '' ELSE ',@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
					+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
					+ CASE WHEN @UserPassword IS NULL THEN '' ELSE ',@UserPassword = ''' + CONVERT(NVARCHAR(50), @UserPassword) + '''' END
					+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
					+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END
					+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
					+ CASE WHEN @IsOutright IS NULL THEN '' ELSE ',@IsOutright = ''' + CONVERT(NVARCHAR(50), @IsOutright) + '''' END

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidByCurrency_Update '+ @LogData

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @ErrorMsg			NVARCHAR(200) = ''
		,@ErrorCode				INT  = 0 
		,@NegativeBalanceUsers	VARCHAR(MAX)	= ''
		,@SiteDBGroupID			SMALLINT
		,@transInfo				VARBINARY(MAX)
		,@transInfo3rd			VARBINARY(MAX)

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY)
	DECLARE @tmpMatchId TABLE (MatchId INT, isFinish INT)

	DECLARE @NegativeBalanceCustIds		VARCHAR(MAX) = ''
	DECLARE @SettlementStatus TINYINT = NULL
		   ,@GlobalShowTime   SMALLDATETIME
		   ,@Movebetdate	  DATETIME
		   ,@Eventdate		  DATETIME
		   ,@sporttype SMALLINT = NULL
		   ,@HomeId				INT
		   ,@AwayId				INT
		   ,@IsNeutral		BIT
		   ,@FCUpdateTime DATETIME2

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL
		   ,@MatchId_MaxPO	INT = NULL 
		   ,@TransIds_MaxPO VARCHAR(MAX) = ''

	IF @IsOutright = 0
	BEGIN
		SELECT @SettlementStatus = m.SettlementStatus
			  ,@GlobalShowTime = m.GlobalShowTime
			  ,@Eventdate = m.eventdate
			  ,@sporttype = m.sporttype
			  ,@MatchId_MaxPO = @MatchId
			  ,@HomeId = m.homeid
			  ,@AwayId = m.awayid
			  ,@IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0))
		FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId
	
		INSERT INTO @tmpMatchId (MatchId)
		SELECT MatchId
		FROM dbo.match WITH(NOLOCK)
		WHERE  1 = CASE WHEN @SportType <> 50 AND matchid = @MatchId THEN 1
						WHEN @SportType = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
						ELSE 0 END
	END
	ELSE
	BEGIN
		SELECT @SettlementStatus = NULL
			  ,@GlobalShowTime = NULL
			  ,@Eventdate = o.eventdate
			  ,@HomeId = o.teamid
			  ,@AwayId = 0
			  ,@IsNeutral = 0
			  ,@Sporttype = l.sporttype
			  ,@MatchId_MaxPO = @MatchId
		FROM dbo.outright o WITH (NOLOCK)
			INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = o.leagueid
		WHERE o.orid = @MatchId
		
		INSERT INTO @tmpMatchId (MatchId)
		SELECT @MatchId	
	END

	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
	IF @Eventdate <= @Movebetdate
	BEGIN
		SELECT @ErrorCode = 99
		     , @ErrorMsg = 'Match is under Movebet process, could not void ticket.'

		SELECT @ErrorCode AS ErrorCode
			,@ErrorMsg AS ErrorMsg
			,@NegativeBalanceUsers AS NegativeBalanceUsers
			,@SiteDBGroupID AS SiteDBGroupID

		RETURN	
	END	

	DECLARE @MBCGroup_Name		VARCHAR(50) = 'MBC Group'
		  , @789y_Name			VARCHAR(50) = '789y'	
		  , @y987_Name			VARCHAR(50) = 'y987'	  
		  , @cn88_Name		VARCHAR(50) = 'CN88'	  
	
	DECLARE @CountSingle		INT = 0
		  , @CountParlay		INT = 0
		  
	DECLARE @IsExistParlay		BIT = 0		  
		  , @isExistMatch		BIT = 0
		  , @isExistFM			BIT = 0
		  , @isExistFM2			BIT = 0
		  , @IsExistBB			BIT = 0
		  , @AvaiableProcess	BIT = 1	
		  , @isExistOutright	BIT = 0
		  
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))	
		   ,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting

	DECLARE @tblTransIds TABLE (transid BIGINT)	
	DECLARE @tblBeforeBalance TVP_BalanceWalletChange	
		  , @tblAfterBalance TVP_BalanceWalletChange
	
	DECLARE @tmpTrans_beforeUpd AS TABLE (matchid INT, transid BIGINT, custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, Bonusid INT, WalletType TINYINT, bettype INT, betdaqid BIGINT, status VARCHAR(20))

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
			Odds				SMALLMONEY,			
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
			betfrom				NVARCHAR(4),
			srecommend			INT,
			mrecommend			INT,
			recommend			INT,
			custid				INT,
			balance				MONEY,
			betdaqid			BIGINT,	
			ExtraInfo			VARCHAR(1000),
			IsCashOut			BIT DEFAULT(0),
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
			SubOdds				SMALLMONEY,
			SubStatus			NVARCHAR(10),
			ruben				TINYINT,
			SiteDBGroupId		SMALLINT,
			IsFinish			BIT
	)	
	
	SELECT * INTO #SpecialDeleteBets_Single FROM #SpecialDeleteBets WHERE 1 = 0	
	CREATE CLUSTERED INDEX IDX_SpecialDeleteBets_Single_betdaqid_transid ON #SpecialDeleteBets_Single(betdaqid, transid)
	CREATE INDEX IDX_SpecialDeleteBets_Single_BetType_custid_balance ON #SpecialDeleteBets_Single(BetType, custid, balance)	INCLUDE(transid)

	SELECT * INTO #SpecialDeleteBets_Parlay FROM #SpecialDeleteBets WHERE 1 = 0
	CREATE INDEX IDX_SpecialDeleteBets_Parlay_custid_balance ON #SpecialDeleteBets_Parlay(custid, balance) INCLUDE(transid)
	CREATE INDEX IDX_SpecialDeleteBets_Parlay_id ON #SpecialDeleteBets_Parlay(id) INCLUDE(TransId, SubTransId, refno)
	
	CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
	CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)	
	
	CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))
	
	CREATE TABLE #t_exchanges(exchangeid INT, currency NVARCHAR(50))
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)	
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)	
	CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	

	-------> Parse @LicenseeNames	
	INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
	SELECT ss.value AS LicenseeName, ss.value AS GroupName
	FROM STRING_SPLIT(@LicenseeNames, ',') ss
	
	-- Replace all UI representative groups (MBCGroup and 789y) by their real credit licensees
	DELETE FROM #t_LicenseeNames 
	OUTPUT DELETED.GroupName 
			INTO #t_UIRepresentativeLicenseeGroupNames(GroupName)
	WHERE LicenseeName IN (@MBCGroup_Name, @789y_Name, @cn88_Name)
	
	IF @@ROWCOUNT > 0
	BEGIN
		;WITH CTE_CreditSite AS
		(
			SELECT [site], ISNULL(SiteLabel,'') AS SiteLabel
			FROM DBCUST.CUSTDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0 AND isActive = 1
		)
		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM #t_UIRepresentativeLicenseeGroupNames AS t
			 CROSS APPLY (
							SELECT cte.[site]
							FROM CTE_CreditSite cte
							WHERE CASE
								WHEN t.GroupName = @MBCGroup_Name AND cte.[site] NOT IN (@789y_Name, @y987_Name, @cn88_Name) AND cte.SiteLabel <> @789y_Name THEN 1
								WHEN t.GroupName = @789y_Name AND cte.SiteLabel = @789y_Name THEN 1
								WHEN t.GroupName = @cn88_Name AND cte.[site] IN (@cn88_Name) THEN 1 ELSE 0  
								END = 1
						 ) AS cte
	END						 
	
	-------> Parse @CurrencyIDs	  
	INSERT INTO #t_exchanges(exchangeid, currency)
	SELECT e.exchangeid, e.currency
	FROM STRING_SPLIT(@CurrencyIDs, ',') ss
		 INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK)
				 ON CAST(ss.value AS INT) = e.exchangeid			 	
				 
	-------> Parse @MainTransIds
	INSERT INTO @tblTransIds(transid)
	SELECT ss.value AS transid
	FROM STRING_SPLIT(@TransIds, ',') ss

	IF NOT EXISTS (SELECT 1 FROM CustDB.dbo.Customer WITH(NOLOCK) WHERE userpwd = @UserPassword AND custid = @userId AND roleid >=5)
    BEGIN
        SELECT @ErrorMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!'  
                ,@ErrorCode = 113  
                
		SELECT @ErrorCode AS ErrorCode
			,@ErrorMsg AS ErrorMsg
			,@NegativeBalanceUsers AS NegativeBalanceUsers
			,@SiteDBGroupID AS SiteDBGroupID
        
        RETURN
    END
	
	IF NOT EXISTS (SELECT TOP 1 1
				   FROM @tblTransIds)
	BEGIN		
		SELECT @ErrorCode = 99, @ErrorMsg = 'No ticket found.'			
		
		SELECT @ErrorCode AS ErrorCode
			,@ErrorMsg AS ErrorMsg
			,@NegativeBalanceUsers AS NegativeBalanceUsers
			,@SiteDBGroupID AS SiteDBGroupID
		
		RETURN
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
						ExtraInfo,
						IsCashOut,
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
						SubStatus,
						SiteDBGroupId
					)
			SELECT 	b.transid AS GroupID,
					b.Stake,
					@AwayId,
					b.BetCheck,
					b.BetId,
					b.BetTeam,
					b.BetType,
					b.currency,
					te.currency AS CurrencyCode,
					b.Creator,
					b.Hdp1,
					b.Hdp2,
					@HomeId,
					b.LiveIndicator AS IsLiveIndicator,
					@IsNeutral,
					b.LiveAwayScore,
					b.LiveHomeScore,
					b.Odds,	
					b.Oddsspread,
					b.OddsType,
					b.RefNo,
					@Sporttype,
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
					b.ExtraInfo,
					CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut,
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
					NULL AS SubStatus,
					b.SiteDBGroupID
			FROM @tblTransIds t
				 INNER JOIN bettrans b WITH (NOLOCK)
						 ON t.transid = b.transid
				 INNER JOIN #t_exchanges te WITH (NOLOCK)
						 ON b.currency = te.exchangeid 	 
				 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
						 ON b.recommend = c.custid
				 INNER JOIN #t_LicenseeNames tl WITH (NOLOCK)
						 ON tl.LicenseeName = c.site -- filter for @LicenseeIDs	
			WHERE @Sporttype BETWEEN 1 AND 99 -- sportbook only				
				AND b.bettype NOT BETWEEN 801 AND 806-- MG
				AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND b.betfrom <> 'P' -- exclude phone betting
				AND b.matchid IN (SELECT MatchId FROM @tmpMatchId)
				AND b.bettype <> 500 -- exclude charge comm	
				AND b.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
				AND b.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
				AND b.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
				AND b.custid NOT IN (SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- For Special bets: betdaq
				AND b.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)		
				AND b.SiteDBGroupID = @SiteDBGroupID
		
			SET @CountSingle = @@ROWCOUNT																
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
						ActualStake,
						ruben,
						SiteDBGroupId,
						matchid
					)
			SELECT  main.Stake,
					@AwayId,
					main.BetCheck,
					main.BetId,
					main.BetTeam,
					main.BetType,
					main.currency,
					te.currency AS CurrencyCode,
					main.Creator,					
					main.Hdp1,
					main.Hdp2,
					@HomeId,
					sub.LiveIndicator AS IsLiveIndicator,
					@IsNeutral,					
					sub.LiveAwayScore,
					sub.LiveHomeScore,
					main.Odds,
					main.Oddsspread,					
					main.OddsType,
					main.RefNo,
					@Sporttype,
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
					main.actual_stake AS ActualStake,
					main.ruben,
					main.SiteDBGroupID,
					sub.matchid
			FROM @tblTransIds t				 				 						 			 				 					 				 
				 INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON t.transid = sub.transid
				 INNER HASH JOIN bettrans main WITH (NOLOCK) ON sub.refno = main.refno
				INNER JOIN #t_exchanges te WITH (NOLOCK)
					     ON main.currency = te.exchangeid 
				INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
						 ON main.recommend = c.custid
				INNER JOIN #t_LicenseeNames tl1 WITH (NOLOCK)
						 ON c.site = tl1.LicenseeName -- filter for @LicenseeIDs						 
			WHERE main.matchid =29 AND main.bettype = 29 -- parlay
				AND main.statusID NOT IN (101, 102) -- reject, void				
				AND main.betfrom <> 'P' -- exclude phone betting
				AND @Sporttype BETWEEN 1 AND 99 -- sportbook only				
				AND sub.matchid IN (SELECT MatchId FROM @tmpMatchId)
				AND sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND sub.betfrom <> 'P' -- exclude phone betting	
				AND main.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
				AND main.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
				AND main.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
				AND main.custid NOT IN (SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- For Special bets: betdaq
				AND main.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)
				AND main.SiteDBGroupID = @SiteDBGroupID
			
			SET @CountParlay = @@ROWCOUNT	

		END

		-------> Check No ticket found
		IF @CountSingle + @CountParlay = 0
		BEGIN			
			SELECT @ErrorCode = 99
				 , @ErrorMsg = 'No ticket found.'

			SELECT @ErrorCode AS ErrorCode
			,@ErrorMsg AS ErrorMsg
			,@NegativeBalanceUsers AS NegativeBalanceUsers
			,@SiteDBGroupID AS SiteDBGroupID

			RETURN
		END
		ELSE
		BEGIN
			IF @CountSingle > 0
			BEGIN
				INSERT INTO #tblMatchProcess (matchid, KeyID)
				SELECT DISTINCT matchid
					,  CASE WHEN b.BetType NOT IN (38, 10) AND f.GroupID IS NULL THEN 1
							WHEN f.GroupId = 1 THEN 6 -- FM
							WHEN b.BetType = 38 THEN 5 -- Bet Builder
							WHEN f.GroupId = 2 THEN 7 -- FM 228
							WHEN b.BetType = 10 THEN 2 --Outright
							ELSE 0
						END AS KeyID 
				FROM #SpecialDeleteBets_Single b
				OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
				)f

				SELECT	@isExistMatch	  = MAX(CASE WHEN KeyID  = 1 THEN 1 ELSE 0 END)
						,@isExistFM		  = MAX(CASE WHEN KeyID  = 6 THEN 1 ELSE 0 END)
						,@isExistBB		  = MAX(CASE WHEN KeyID  = 5 THEN 1 ELSE 0 END)
						,@isExistFM2	  = MAX(CASE WHEN KeyID  = 7 THEN 1 ELSE 0 END)
						,@isExistOutright = MAX(CASE WHEN KeyID  = 2 THEN 1 ELSE 0 END)
				FROM #tblMatchProcess
			END
			
			IF @CountParlay > 0
			BEGIN
				SET @IsExistParlay = 1

				INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
				SELECT matchid, RefNo
				FROM #SpecialDeleteBets_Parlay	
			END
			
			EXEC dbo.NAP_Set_GlobalSettingSel 
					 @LockName = 'ParlayRefno'
					,@ThreadHold = @ThreadHold OUTPUT
			
			-- check and not allow attempt to void tickets of this match while it's being calculated
			-- Apply new way to lock parlay tickets	
			IF @CountParlay = 0 OR @CountParlay <= @ThreadHold
			BEGIN
				IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
				BEGIN
					-- checking single proccess		
					EXEC dbo.NAP_Admin_CheckingProcess   
						@isExistMatch		= @isExistMatch	
						, @isExistFM		= @isExistFM				
						, @isExistBB		= @isExistBB
						, @isExistFM2		= @isExistFM2
						, @isExistOutright  = @isExistOutright
						, @spName			= @spName
						, @avaiableProcess  = @avaiableProcess OUTPUT  
						, @ErrCode			= @ErrorCode OUTPUT  
						, @ErrMsg			= @ErrorMsg OUTPUT
					
					IF(@ErrorCode <> 0 OR @avaiableProcess = 0) 
					BEGIN
						SELECT @ErrorCode AS ErrorCode
							,@ErrorMsg AS ErrorMsg
							,@NegativeBalanceUsers AS NegativeBalanceUsers
							,@SiteDBGroupID AS SiteDBGroupID

						RETURN		
					END	 
				END
				
				IF @CountParlay > 0
				BEGIN
					-- checking refno parlay proccess
					EXEC dbo.NAP_Admin_CheckingProcess
						 @IsLockingByRefno	= 1
						, @spName			= @spName
						, @Session			= @Session
						, @avaiableProcess 	= @avaiableProcess OUTPUT
						, @ErrCode			= @ErrorCode OUTPUT
						, @ErrMsg			= @ErrorMsg OUTPUT 

					IF(@ErrorCode <> 0 OR @avaiableProcess = 0) 
					BEGIN
						------ releasing single process
						EXEC dbo.NAP_Admin_CheckingProcess
							@isExistMatch	= @isExistMatch	
							,@isExistFM		= @isExistFM		
							,@isExistBB		= @isExistBB		
							,@isExistFM2	= @isExistFM2
							,@isExistOutright = @isExistOutright
							,@IsReleased	= 1	

						SELECT @ErrorCode AS ErrorCode
							,@ErrorMsg AS ErrorMsg
							,@NegativeBalanceUsers AS NegativeBalanceUsers
							,@SiteDBGroupID AS SiteDBGroupID
										
						RETURN		
					END
				END
			END
			ELSE IF @CountParlay > @ThreadHold
			BEGIN
				-- checking SD proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					  @IsReleased		= 0
					, @isExistMatch		= @isExistMatch	
					, @isExistFM		= @isExistFM				
					, @IsExistParlay	= @IsExistParlay
					, @isExistBB		= @isExistBB
					, @isExistFM2		= @isExistFM2
					, @isExistOutright  = @isExistOutright
					, @spName			= @spName
					, @avaiableProcess 	= @AvaiableProcess OUTPUT
					, @ErrCode			= @ErrorCode OUTPUT
					, @ErrMsg			= @ErrorMsg OUTPUT

				IF(@ErrorCode <> 0 OR @AvaiableProcess = 0) 
				BEGIN
					SELECT @ErrorCode AS ErrorCode
						,@ErrorMsg AS ErrorMsg
						,@NegativeBalanceUsers AS NegativeBalanceUsers
						,@SiteDBGroupID AS SiteDBGroupID

					RETURN
				END
			END	
			
		END
		
		--> capture Before Balance Update
		IF @CountSingle > 0
		BEGIN
			INSERT INTO #NegativeBalance (transid)  
			SELECT	b.transid
			FROM  #SpecialDeleteBets_Single b WITH (NOLOCK)
		END		
		
		IF @CountParlay > 0
		BEGIN
			INSERT INTO #NegativeBalance (transid)  
			SELECT	b.transid
			FROM  #SpecialDeleteBets_Parlay b WITH (NOLOCK)
		END

		-------> Insert backups	
		--> backups for single
		IF @CountSingle > 0
		BEGIN
			-- backup for normal ticket
			INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
						winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
						winlostdate,betfrom,
						betcheck,
						checktime,matchid, bettype, RepUpdateTime, SiteDBGroupID)
			SELECT  main.transid, main.custid, CURRENT_TIMESTAMP, main.oddsid, main.hdp1, main.hdp2, main.odds, main.stake, main.status, 
					main.winlost, main.livehomescore, main.liveawayscore, main.liveindicator, main.betteam, main.creator , main.refno, 
					main.winlostdate, main.betfrom, main.betcheck,
					main.checktime, main.matchid, main.bettype, SYSDATETIME(), main.SiteDBGroupID
			FROM #SpecialDeleteBets_Single tmpmain
				 INNER JOIN dbo.bettrans main WITH (nolock)
						 ON tmpmain.transid = main.transid
		END				
		
		--> backups for parlay	
		IF @CountParlay > 0
		BEGIN
			-- BackUp bettransm tickets into zzzbettrans  
			INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
					winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
					winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID
			)  
			SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
					b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
					b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, SYSDATETIME(), b.SiteDBGroupID
			FROM #SpecialDeleteBets_Parlay AS r 	  
				INNER JOIN dbo.bettransm AS b WITH (nolock)
					ON	r.SubTransId = b.transid			 

			--BackUp tickets of bettransm  
			INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
					 winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
					 winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID)  
			SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
					b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
					b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, SYSDATETIME(), b.SiteDBGroupID
			FROM #SpecialDeleteBets_Parlay AS r	 
				INNER JOIN dbo.bettransm AS b WITH (nolock)  
					ON	r.SubTransId=b.transid						
		END
		
		-------> update status for tickets to void		
		--> update status for single
		IF @CountSingle > 0
		BEGIN
			DELETE FROM @tmpMatchId
			INSERT INTO @tmpMatchId(MatchId)
			SELECT DISTINCT MatchId FROM #SpecialDeleteBets_Single
			
			WHILE (1=1)
			BEGIN
				UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
				FROM @tmpMatchId p
				WHERE p.IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK

				-- update status for normal ticket
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
						,FcUpdateTime = @FCUpdateTime
							OUTPUT deleted.Transid,
							deleted.custid,  
							deleted.winlost,
							deleted.actual_stake,
							deleted.playercomm,
							deleted.BonusID,
							deleted.WalletType,
							deleted.bettype,
							deleted.betdaqid,
							deleted.status,
							deleted.matchid
					INTO @tmpTrans_beforeUpd (transid, custid, winlost, actual_stake, playercomm,Bonusid, WalletType, bettype, betdaqid, status, matchid)
				FROM	dbo.bettrans main WITH (ROWLOCK, UPDLOCK)
					INNER JOIN #SpecialDeleteBets_Single tmpmain
						ON	main.transid = tmpmain.transid					
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
					FROM	#SpecialDeleteBets_Single t 
						INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
					WHERE t.BetType NOT IN (10, 38) AND t.matchid = @MatchId
					FOR JSON PATH))

				IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
					SELECT 'TVS', 'VoidCurrency', 'bettrans', 'U', @matchid, @transInfo, 's'
				END
			
				--For match table; EventTable = 1
				SET @transInfo3rd = COMPRESS((
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
					FROM	#SpecialDeleteBets_Single t 
						INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
					WHERE t.BetType IN (38) AND t.matchid = @MatchId
					FOR JSON PATH))
					
				IF @SiteDBGroupID <> 0 AND @transInfo3rd IS NOT NULL
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
					SELECT 'TVS', 'VoidCurrency', 'bettrans', 'U', @matchid, @transInfo3rd, 's', 1
				END

				--For ouitright table; EventTable = 2
				SET @transInfo3rd = COMPRESS((
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
					FROM	#SpecialDeleteBets_Single t 
						INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
					WHERE t.BetType IN (10) AND t.matchid = @MatchId
					FOR JSON PATH))
					
				IF @SiteDBGroupID <> 0 AND @transInfo3rd IS NOT NULL
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
					SELECT 'TVS', 'VoidCurrency', 'bettrans', 'U', @matchid, @transInfo3rd, 's', 2
				END
			END
		END	
		
		-------> Capture before balance		
		INSERT INTO @tblBeforeBalance (matchid
									 , custid  			 
									 , balanceType
									 , BonusID
									 , WalletType 
									 , balance)
		SELECT T.matchid
			 , T.custid  
			 , 1 AS balanceType
			 , CASE WHEN T.BonusID > 0 AND T.WalletType = 1 THEN T.BonusID ELSE 0 END AS BonusID
			 , ISNULL(T.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(T.winlost - T.actual_stake + T.playercomm) balance
		FROM (
				-- normal ticket
				SELECT	b.custid
					  , b.BonusID
					  , b.WalletType
					  , b.winlost, b.actual_stake, b.playercomm, b.bettype, b.matchid
				FROM @tmpTrans_beforeUpd b	

				UNION ALL
				-- parlay				
				SELECT b.custid
					 , 0 AS BonusID -- parlay tickets always bet from cash wallet
					 , 2 AS WalletType -- parlay tickets always bet from cash wallet
					 , b.winlost, b.actual_stake, b.playercomm, b.bettype, t.matchid
				FROM #SpecialDeleteBets_Parlay t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid				
			 ) AS T
		GROUP BY T.matchid, T.custid			   
			   , CASE WHEN T.BonusID > 0 AND T.WalletType = 1 THEN T.BonusID ELSE 0 END
			   , ISNULL(T.WalletType, 2) -- normal tickets are treated as cash tickets

		INSERT INTO #BeforeUpd(custid, balance)
		SELECT	b.custid , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM @tmpTrans_beforeUpd b
		WHERE transid IN (SELECT transid FROM #NegativeBalance)			
		GROUP BY b.CustID

		--Correct data captured before because CO happen when voiding ticket
		IF EXISTS (SELECT TOP(1) 1 FROM #SpecialDeleteBets_Single	b
						INNER JOIN @tmpTrans_beforeUpd t ON t.transid = b.transid
					WHERE b.IsCashOut = 0 AND t.betdaqid = -2 )
		BEGIN
			UPDATE b
			SET b.status = t.status
				, b.NetWinLost = t.winlost - t.actual_stake
				, b.ActualStake = t.actual_stake
				, b.betdaqid = -2
				, b.IsCashOut = 1
			FROM #SpecialDeleteBets_Single b 
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
			
			DELETE FROM @tmpMatchId 
			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT matchid FROM @tmpTransInfo
			
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
					SELECT 'TVS', 'VoidCurrency', 'zzzbettrans', 'U', @matchid, @transInfo, 's' 
				END
			END
		END

		--> update status for parlay
		IF @CountParlay > 0
		BEGIN
			DECLARE @matchdate		DATETIME				
				  , @transid_tmp	VARCHAR(2000) 		
				  , @transids_29	VARCHAR(MAX) = ''  
				  , @refnos_29		VARCHAR(MAX) = ''				  						  			  		   		
			
			DECLARE @tmpTransIDBatch TABLE (transid BIGINT)

			DELETE FROM @tmpMatchId
			INSERT INTO @tmpMatchId(MatchId)
			SELECT DISTINCT MatchId FROM #SpecialDeleteBets_Parlay

			WHILE (1=1)
			BEGIN
				SET @transids_29 =''
				SET @refnos_29 =''

				UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
				FROM @tmpMatchId p
				WHERE p.IsFinish IS NULL
		
				IF @@ROWCOUNT = 0 BREAK

				SELECT	@matchdate = eventdate 				  
				FROM	match WITH(NOLOCK)   
				WHERE	matchid = @matchid
			
				SELECT	@transids_29 = @transids_29 + CONVERT(VARCHAR(20), transid) + ','
					  , @refnos_29 = @refnos_29 + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid) + ','  
				FROM	#SpecialDeleteBets_Parlay									
				WHERE	matchid = @matchid

				WHILE (1=1)
				BEGIN
					DELETE @tmpTransIDBatch
					SET @transid_tmp = ''
		
					UPDATE TOP(100) t
					SET isFinish = 1
						OUTPUT deleted.SubTransId
						INTO @tmpTransIDBatch(transid)
					FROM #SpecialDeleteBets_Parlay t
					WHERE isFinish IS NULL AND t.MatchId = @MatchId

					IF @@ROWCOUNT = 0 BREAK

					SELECT	@transid_tmp = @transid_tmp + CONVERT(VARCHAR(50), TransId) + ','
					FROM	@tmpTransIDBatch

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
		END
		
		-------> Capture after balance		
		INSERT INTO @tblAfterBalance (matchid
									 , custid  			 
									 , balanceType
									 , BonusID
									 , WalletType 
									 , balance)
		SELECT T.matchid
			 , T.custid  
			 , 1 AS balanceType
			 , CASE WHEN T.BonusID > 0 AND T.WalletType = 1 THEN T.BonusID ELSE 0 END AS BonusID
			 , ISNULL(T.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(T.winlost - T.actual_stake + T.playercomm) balance
		FROM (
				-- normal ticket
				SELECT	b.custid
					  , b.BonusID
					  , b.WalletType
					  , b.winlost, b.actual_stake, b.playercomm, b.bettype, b.matchid
				FROM #SpecialDeleteBets_Single t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid
				UNION ALL
				-- parlay				
				SELECT b.custid
					 , 0 AS BonusID -- parlay tickets always bet from cash wallet
					 , 2 AS WalletType -- parlay tickets always bet from cash wallet
					 , b.winlost, b.actual_stake, b.playercomm, b.bettype, t.matchid
				FROM #SpecialDeleteBets_Parlay t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid				
			 ) AS T
		GROUP BY T.matchid, T.custid			   
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
			 
		-- Update CashOutSelling [#165097]
		UPDATE c
		SET CashOutStatus = 6 --Void
		   ,ChangeDate = GETDATE()
		FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #SpecialDeleteBets_Single b ON c.TransID = b.transid AND c.MatchID = @MatchID
		WHERE b.betdaqid = -2 

		IF @CountParlay = 0 OR @CountParlay  <= @ThreadHold
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistMatch	= @isExistMatch	
					,@isExistFM		= @isExistFM		
					,@isExistBB		= @isExistBB		
					,@isExistFM2	= @isExistFM2
					,@isExistOutright  = @isExistOutright
					,@IsReleased	= 1
			END
			
			IF @CountParlay > 0 
			BEGIN		
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
					,@Session	= @Session
					,@IsReleased = 1
			END
		
		END
		ELSE IF @CountParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess
				 @IsReleased	= 1						
				,@isExistMatch	= @isExistMatch	
				,@isExistFM		= @isExistFM		
				,@isExistBB		= @isExistBB		
				,@isExistParlay	= @isExistParlay
				,@isExistFM2	= @isExistFM2
				,@isExistOutright  = @isExistOutright
		END
			
		----------------Insert Max Payout Queue----------------
		SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
						,CASE 
							WHEN dp.custid IS NOT NULL THEN 3 --deposit 
							WHEN s.SiteLabel = '789y' THEN 2 --789y
							ELSE 1 END AS '@sitetype'
						,b.TransId AS '@transid'
						,b.BetType AS '@bettype'
					FROM #SpecialDeleteBets_Single b
						INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
						INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
						LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
					FOR XML PATH('r'), ROOT('root')
				)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO
		
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
									,t.ruben AS '@ruben'
									,t.TransId AS '@transid'
								FROM #SpecialDeleteBets_Parlay t
								GROUP BY custid, ruben, TransId
								FOR XML PATH('r'), ROOT('root')
							)

		If @MainParlay_MaxPO IS NOT NULL
		BEGIN
			--Insert Max Payout Queue
			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
				@MatchId= 29
				,@TransidList = @MainParlay_MaxPO
		END
		----------------Done Insert Max Payout Queue----------------

		DELETE FROM @tmpMatchId
		INSERT INTO @tmpMatchId(MatchId)
		SELECT DISTINCT MatchId FROM #SpecialDeleteBets_Single
		UNION  
		SELECT DISTINCT MatchId FROM #SpecialDeleteBets_Parlay

		BEGIN -- Instant Settlement declaration
			
			DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
			CREATE TABLE #CTE_match (matchid INT)
			CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

			INSERT INTO #CTE_match (matchid)
			SELECT DISTINCT t.matchid
			FROM @tmpMatchId t
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
					INNER JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) ON rd.matchid = m.matchid
				WHERE ResultStatusID in (2,5)
					AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 

				INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
				SELECT DISTINCT c.matchid, f.bettype, f.betid
				FROM #CTE_isCal c
					CROSS APPLY (
							SELECT bettype, betid
							FROM dbo.f_TVS_GetInstantBettypes()
							WHERE InstantType IS NULL
							AND ResourceId NOT IN (SELECT ResourceId FROM #CTE_isCal)
					)f	 	
			END
			
			DROP TABLE #CTE_match
			DROP TABLE #CTE_isCal
		END	

		-------> Data for sending mail
		DECLARE @IsITAdmin BIT = 0
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

		--1. Return table validate
		SELECT @ErrorCode AS ErrorCode
				,@ErrorMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@SiteDBGroupID AS SiteDBGroupID
		
		SELECT  s.Stake,				
				s.BetCheck,
				s.BetId,
				s.BetTeam,
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
				s.betdaqid,
				s.ExtraInfo,
				s.IsCashOut,
				s.RefCode,
				s.betfrom,
				s.WalletType,
				s.IsLiveIndicator AS IsLive,
				s.BetType AS BetTypeId,
				s.Hdp1 AS Handicap1,
				s.Hdp2 AS Handicap2,
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
				s.NetWinLost AS Winlost,
				s.MainTransId,
				s.custid,
				s.UserName,
				ci.username2,
				s.recommend,
				s.mrecommend,
				s.srecommend,
				ac.username AS AgUserName,
				mc.username AS MagUserName,
				sc.username AS SagUserName,
				CASE WHEN LOWER(s.Status) IN ('won', 'lose', 'draw') AND ISNULL(s.betdaqid,0) <> -2
						THEN CASE
								WHEN @sporttype = 1
										AND EXISTS (SELECT TOP 1 1
													FROM #InstantSettlementBettypes
													WHERE bettype = al.bettype)
										THEN 1
								WHEN @sporttype = 2 
									AND EXISTS (SELECT TOP 1 1
												FROM #InstantSettlementBettypes
												WHERE bettype = al.bettype AND betid = al.betid)
									THEN 1
								ELSE 0
							END
					ELSE 0
					END AS IsInstantSettlementTicket
				,CASE WHEN s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' ELSE s.site END AS EmailGroup
				,CASE WHEN T2.a IS NOT NULL AND @IsITAdmin = 1 THEN 1 ELSE 0	END AS IsItSupport
				,CASE WHEN dc.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
				,@sporttype AS SportTypeId
				,s.SiteDBGroupId
				,s.matchid
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
		IF @CountParlay = 0 OR @CountParlay <= @ThreadHold
		BEGIN
			IF EXISTS(SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				-------> Release process
				EXEC dbo.NAP_Admin_CheckingProcess
					  @IsReleased		= 1						
					, @isExistMatch		= @isExistMatch
			END
			
			IF @CountParlay > 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1
			END

		END
		ELSE IF @CountParlay > @ThreadHold
		BEGIN
			-------> Release process
			EXEC dbo.NAP_Admin_CheckingProcess
				  @IsReleased		= 1						
				, @isExistMatch		= @isExistMatch			
				, @isExistParlay	= @isExistParlay
		END	
	
		SELECT @ErrorCode = 100,
				@ErrorMsg = 'Unable to void these tickets'

		SELECT @ErrorCode AS ErrorCode
			,@ErrorMsg AS ErrorMsg
			,@NegativeBalanceUsers AS NegativeBalanceUsers
			,@SiteDBGroupID AS SiteDBGroupID

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
			
		-- Write Log
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

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #SpecialDeleteBets_Single
	DROP TABLE #SpecialDeleteBets_Parlay
	DROP TABLE #t_LicenseeNames 
	DROP TABLE #t_UIRepresentativeLicenseeGroupNames
	DROP TABLE #t_exchanges  
	DROP TABLE #tblMatchProcess 
	DROP TABLE #BeforeUpd  
	DROP TABLE #AfterUpd 
	DROP TABLE #NegativeBalance
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tblMatchParlayProcess

	SET NOCOUNT OFF
END
GO
			