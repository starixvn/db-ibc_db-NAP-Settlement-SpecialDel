USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_SpecialDelete_VoidByCurrency_Update]    Script Date: 04/25/2016 09:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_Update] 
	@MatchID		INT = 0,
	@LicenseeNames	VARCHAR(MAX),
	@TicketType		VARCHAR(100) = 'All',
	@CurrencyIDs	VARCHAR(MAX),
	@TransIDs		VARCHAR(MAX),
	@SoldTransIds	VARCHAR(MAX) = '', -- just for BetTrade's subticket (transid of bettype 901)		

	@UserID			INT,  
	@UserName		NVARCHAR(50),
	@UserPassword   NVARCHAR(50),  
	@Reason			NVARCHAR(500) = '',  
	@IP				VARCHAR(15)  = '',  
	@ErrorMsg		NVARCHAR(200) = '' OUTPUT,  
	@ErrorCode		INT  = 0  OUTPUT,
	@InvalidTrans	VARCHAR(MAX) = '' OUTPUT -- invalid trans of BTrade 
AS
/*
	Created: Kent
	Date: 20161201
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161201@Kent: Search sportbook tickets by crrency to void [Redmine:#67987]
		- 20170418@Kent: Fix Returned Data Type For Bit Columns [Redmine:#75009]
	
	Param's Explanation:			
			- @TicketType:
			'All': All
			'SingleTicket': Single ticket
			'ParlayTicket': Parlay ticket
*/
BEGIN
	SET NOCOUNT ON
	
	SET @InvalidTrans = ''
	
	DECLARE @MBCGroup_Name VARCHAR(50) = 'MBC Group'
		  , @789y_Name	   VARCHAR(50) = '789y'		  
		  , @VoidPatchSize INT = 100
	
	DECLARE @LogData					NVARCHAR(500) = ''
		  , @GeneralErrMsg				NVARCHAR(200) = 'Unable to void these tickets'
		  , @CurrencyCodes				VARCHAR(MAX)
		  , @UserIDNotInITGroup			BIT
		  , @SearchSingle				BIT = 0
		  , @CountSingle				INT = 0
		  , @SearchParlay				BIT = 0
		  , @CountParlay				INT = 0
		  
	DECLARE @IsExistParlay				BIT = 0		  
		  , @isExistMatch				BIT = 0
		  , @KeyID						INT
		  , @AvaiableProcess			BIT = 1			  			  	  	  
	
	DECLARE @tblTransIds TABLE (transid BIGINT)
	
	DECLARE @tblInputSoldTransIds TABLE (transid BIGINT)
	
	DECLARE @tblBeforeBalance TABLE (custid INT PRIMARY KEY, balance MONEY)
	
	DECLARE @tblAfterBalance TABLE (custid INT PRIMARY KEY, balance MONEY)
	
	DECLARE @tblDebitPending TVP_BalanceList
	
	DECLARE @tblCreditPending TVP_BalanceList
	
	CREATE TABLE #SpecialDeleteBets (
			id					INT IDENTITY,
	
			Stake				MONEY,
			AwayId				INT,
			BetCheck			NVARCHAR(50),
			BetId				BIGINT DEFAULT (0),
			BetTeam				NVARCHAR(10),
			BetType				SMALLINT,
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
			
			SubTransId			BIGINT,
			SubBetCheck			NVARCHAR(50),
			SubBetTeam			NVARCHAR(10),
			SubBetType			SMALLINT,
			SubHdp1				SMALLMONEY,
			SubHdp2				SMALLMONEY,
			SubOdds				MONEY						
		)
		
	SELECT * INTO #SpecialDeleteBets_Single FROM #SpecialDeleteBets WHERE 1 = 0	
	CREATE CLUSTERED INDEX IDX_SpecialDeleteBets_Single_betdaqid_transid ON #SpecialDeleteBets_Single(betdaqid, transid)
	CREATE INDEX IDX_SpecialDeleteBets_Single_BetType_custid_balance ON #SpecialDeleteBets_Single(BetType, custid, balance)	INCLUDE(transid)		
	
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
	)
	CREATE CLUSTERED INDEX IDX_BTTransActive_bettype_refno ON #BTTransActive(bettype, refno)
	CREATE INDEX IDX_BTTransActive_bettype_custid_matchid ON #BTTransActive(bettype, custid)
	CREATE INDEX IDX_BTTransActive_custid_balance ON #BTTransActive(custid, balance) INCLUDE(transId)	
	
	-- store invalid BT transid
	DECLARE @tblInvalidTrans TABLE (transid BIGINT) 
	
	--store BT's custid			
	DECLARE @tblCustBT902 TABLE 
	(
		custid INT	  
	)
	
	CREATE TABLE #t_CustID_501(custid INT PRIMARY KEY)
		
	SELECT  s.Stake,			
			s.BetCheck,
			s.BetId,
			s.BetTeam,
			s.BetType,
			s.CurrencyCode,			
			s.Hdp1,
			s.Hdp2,			
			s.IsLiveIndicator,
			s.IsNeutral,				
			s.LiveAwayScore,
			s.LiveHomeScore,
			s.Odds,
			CAST(1 AS BIT) AS IsMixParlay,
			s.OddsType,
			s.RefNo,
			s.SportType,
			s.Status,
			s.TransDate,
			s.TransDesc,
			s.TransId,
			s.UserName,
			s.NetWinLost AS WinLost,				
			CAST('' AS VARCHAR(50)) AS EmailGroup,
			s.site,
			CAST(1 AS BIT) AS IsDeposit,
			s.custid,
			s.recommend,
			CAST('' AS VARCHAR(30)) AS AgUserName,
			s.mrecommend,
			CAST('' AS VARCHAR(30)) AS MagUserName,
			s.srecommend,
			CAST('' AS VARCHAR(30)) AS SagUserName,
			CAST(1 AS BIT) AS IsBetTrade,
			
			s.SubTransId,
			s.SubBetCheck,
			s.SubBetTeam,
			s.SubBetType,
			s.SubHdp1,
			s.SubHdp2,
			s.SubOdds,
						
			CAST(1 AS BIT) AS IsItSupport,
			s.betfrom,
			CURRENT_TIMESTAMP AS [DateTime]
				INTO #t
	FROM #SpecialDeleteBets s
	WHERE 1 = 0	
	
	CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100))
	CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)	
	
	CREATE TABLE #t_exchanges(exchangeid INT, currency NVARCHAR(50))
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)		
	
	-------> Parse @LicenseeNames	
	INSERT INTO #t_LicenseeNames(LicenseeName)
	SELECT ss.val
	FROM dbo.f_SplitString(@LicenseeNames, ',') ss
	OPTION (maxrecursion 0)
	
	DELETE FROM #t_LicenseeNames WHERE LicenseeName = @MBCGroup_Name
	IF @@ROWCOUNT > 0
		INSERT INTO #t_LicenseeNames(LicenseeName)
		SELECT [site]
		FROM DBCUST.CUSTDB.dbo.Site WITH(NOLOCK) 
		WHERE isLicensee = 0		   
		  AND isActive = 1	
		  AND [site] <> @789y_Name -- '789y' is treated as special licensee as 'MBC Group'
	
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
	SET @LogData = 'Void currency transaction for matchid ' + CONVERT(VARCHAR(20), @matchid) + ' for ' + @LicenseeNames + ' ' + @CurrencyCodes + ' IP=' + @IP + ' reason: ' + @Reason
		
	IF NOT EXISTS (SELECT 1 FROM CustDB.dbo.Customer WITH(NOLOCK) WHERE userpwd = @UserPassword AND custid = @userId AND roleid >=5)
    BEGIN
        SELECT @ErrorMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!'  
                ,@ErrorCode = 101  
                
        EXEC [dbo].[WriteLog_UserLog] @UserID = @UserID ,@Doing = @LogData
        
        SELECT * FROM #t
        
        RETURN
    END
	
	IF NOT EXISTS (SELECT TOP 1 1
				   FROM @tblTransIds)
	BEGIN		
		SELECT @ErrorCode = 99, @ErrorMsg = 'No ticket found.'
		
		SELECT * FROM #t		
		
		RETURN
	END						 	  
			
	IF @TicketType = 'All'	
		SELECT @SearchSingle = 1
			 , @SearchParlay = 1	
	ELSE IF @TicketType = 'SingleTicket'	
		SELECT @SearchSingle = 1			 			 			 				 			 			
	ELSE IF @TicketType = 'ParlayTicket'	
		SELECT @SearchParlay = 1			 		 
	ELSE
	BEGIN	
		SELECT * FROM #t										
					 
		RETURN		 
	END		
	
	BEGIN TRY	
		-------> Get tickets to void
		--> Get single tickets		
		IF @SearchSingle = 1
		BEGIN
			INSERT INTO #SpecialDeleteBets_Single(
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
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
						
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds		
					)
			SELECT 	b.Stake,
					m.AwayId,
					b.BetCheck,
					b.BetId,
					b.BetTeam,
					b.BetType,
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
					
					b.TransId AS SubTransId,
					NULL AS SubBetCheck,
					NULL AS SubBetTeam,
					NULL AS SubBetType,
					NULL AS SubHdp1,
					NULL AS SubHdp2,
					NULL AS SubOdds		
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
				AND b.statusID NOT IN (101, 102) -- reject, void
				AND b.betfrom <> 'P' -- exclude phone betting
				AND b.matchid = @MatchID -- filer for @MatchID
				AND b.bettype <> 500 -- exclude charge comm	
				
				AND b.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
				AND b.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
				AND b.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
				AND b.custid NOT IN (SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- For Special bets: betdaq
				AND b.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)					
		
			SET @CountSingle = @@ROWCOUNT
			
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
					AND transid NOT IN (SELECT grouptransid FROM #tblTransIdSolds)
			SET @CountSingle = @CountSingle - @@ROWCOUNT					
			
			-- delete main ticket if it's not BT but have subticket in SOLD list
			DELETE
			FROM	#SpecialDeleteBets_Single
			OUTPUT	DELETED.TransId
			INTO	@tblInvalidTrans (transid)			
			WHERE	betdaqid = -1 
					AND transid IN (SELECT grouptransid FROM #tblTransIdSolds)	
			SET @CountSingle = @CountSingle - @@ROWCOUNT					
					
			-- return invalid transId	
			SELECT @InvalidTrans = @InvalidTrans + CAST(transid AS VARCHAR(20)) + ','
			FROM @tblInvalidTrans
			
			IF @InvalidTrans <> ''
				SET @InvalidTrans = 'Failed to void the ticket(s): ' + LEFT(@InvalidTrans,LEN(@InvalidTrans) -1)											
			
			--Insert multiple Bet trade transaction
			INSERT INTO #BTTransActive (custid, refno, matchid, bettype, transId, awinlost
									  , BetId, TransDate, UserName, NetWinLost, srecommend, mrecommend, recommend, balance, betdaqid)
			SELECT bt.custid, bt.refno, bt.matchid, bt.bettype, bt.transId, bt.awinlost
				 , bt.BetId, bt.TransDate, bt.UserName, bt.NetWinLost, bt.srecommend, bt.mrecommend, bt.recommend, bt.balance, bt.betdaqid
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
					, ROW_NUMBER() OVER ( PARTITION  BY sub.custid, sub.refno, sub.matchid, sub.bettype ORDER BY sub.transId DESC ) AS BTNo 
					
				FROM #SpecialDeleteBets_Single main
					INNER JOIN dbo.bettrans sub WITH(NOLOCK)					
							ON main.transId = sub.refno						
				WHERE main.betdaqid = 0
					AND sub.matchid = @MatchID
					AND sub.bettype BETWEEN 901 AND 910
					AND sub.statusID IN (111,112,113,103)					
			) AS bt
			WHERE bt.BTNo = 1
			
			INSERT INTO #SpecialDeleteBets_Single(
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
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
						
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds
					)
			SELECT  tmpmain.Stake,
					tmpmain.AwayId,
					tmpmain.BetCheck,
					tmpmain.BetType AS BetId,
					tmpmain.BetTeam,
					sub.BetType,
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
					
					sub.TransId AS SubTransId,
					NULL AS SubBetCheck,
					NULL AS SubBetTeam,
					NULL AS SubBetType,
					NULL AS SubHdp1,
					NULL AS SubHdp2,
					NULL AS SubOdds
			FROM #SpecialDeleteBets_Single tmpmain										
				 INNER JOIN #BTTransActive sub
						 ON tmpmain.transid = sub.refno															
			WHERE tmpmain.betdaqid = 0
			  AND sub.bettype = 901
			
			SET @CountSingle = @CountSingle + @@ROWCOUNT
			
			--insert custBT 
			INSERT INTO @tblCustBT902( custid)
			SELECT DISTINCT bt.custid
			FROM #BTTransActive bt			
			WHERE bt.bettype = 902				
		END
		
		--> Get parlay tickets		
		IF @SearchParlay = 1
		BEGIN
			INSERT INTO #SpecialDeleteBets_Parlay(
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
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
						
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds		
					)
			SELECT  main.Stake,
					m.AwayId,
					main.BetCheck,
					main.BetId,
					main.BetTeam,
					main.BetType,
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
					main.OddsType,
					main.RefNo,
					m.SportType,
					main.status AS STATUS,
					main.transdate AS TransDate,
					sub.transdesc AS TransDesc,
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
					
					sub.transid AS SubTransId,
					sub.betcheck AS SubBetCheck,
					sub.betteam AS SubBetTeam,
					sub.bettype AS SubBetType,
					sub.hdp1 AS SubHdp1,
					sub.hdp2 AS SubHdp2,
					sub.odds AS SubOdds		
			FROM @tblTransIds t				 				 						 			 				 					 				 
				 INNER JOIN dbo.bettransm sub WITH (NOLOCK)	
						 ON t.transid = sub.transid
				 INNER JOIN match m WITH (NOLOCK)
						 ON sub.matchid = m.matchid
						 
				INNER JOIN bettrans main WITH (NOLOCK)
						 ON sub.refno = main.refno
				INNER JOIN #t_exchanges te WITH (NOLOCK)
					     ON main.currency = te.exchangeid  -- filter for @CurrencyCodes
				INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
						 ON main.recommend = c.custid
				INNER JOIN #t_LicenseeNames tl1 WITH (NOLOCK)
						 ON c.site = tl1.LicenseeName -- filter for @LicenseeIDs						 
			WHERE main.matchid IN (9, 29) AND main.bettype IN (9, 29) -- parlay
				AND main.statusID NOT IN (101, 102) -- reject, void				
				AND main.betfrom <> 'P' -- exclude phone betting
				
				AND m.sporttype BETWEEN 1 AND 99 -- sportbook only				
				AND sub.matchid = @matchid -- filer for @MatchID
				AND sub.statusID NOT IN (101, 102) -- reject, void
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
			SET @ErrorCode = 99
			
			IF @InvalidTrans <> '' -- when all single tickets are deleted due to invalid bettrade
				SET @ErrorMsg = @InvalidTrans
			ELSE
				SET @ErrorMsg = 'No ticket found.'
			
			SELECT * FROM #t		
			
			RETURN
		END
		ELSE
		BEGIN
			IF @CountSingle > 0
			BEGIN
				SELECT @KeyID = 1					 
					 , @isExistMatch = 1			 			 
							
				INSERT INTO #tblMatchProcess (matchid, KeyID)
				SELECT @matchid AS matchid
					 , @KeyID 	AS KeyID
			END
			
			IF @CountParlay > 0
				SET @IsExistParlay = 1
				
			-------> Check concurrent single, parlay
			EXEC dbo.NAP_Admin_CheckingProcess
				  @IsReleased	= 0								
				, @isExistMatch		= @isExistMatch				
				, @IsExistParlay	= @IsExistParlay				
				, @avaiableProcess 	= @AvaiableProcess OUTPUT
				, @ErrCode			= @ErrorCode OUTPUT
				, @ErrMsg			= @ErrorMsg OUTPUT				
				
			IF(@ErrorCode <> 0 OR @AvaiableProcess = 0) 
			BEGIN
				SELECT * FROM #t			
				
				RETURN
			END									
		END
		
		INSERT INTO #t_CustID_501(custid)
		SELECT DISTINCT custid 
		FROM #SpecialDeleteBets_Single 
		WHERE BetType = 501		
		
		-------> Insert backups	
		--> backups for single
		IF @CountSingle > 0
		BEGIN
			-- backup for normal ticket
			INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
						winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
						winlostdate,betfrom,betcheck,checktime,matchid, bettype)
			SELECT  main.transid, main.custid, CURRENT_TIMESTAMP, main.oddsid, main.hdp1, main.hdp2, main.odds, main.stake, main.status, 
					main.winlost, main.livehomescore, main.liveawayscore, main.liveindicator, main.betteam, main.creator , main.refno, 
					main.winlostdate, main.betfrom, main.betcheck, main.checktime, main.matchid, main.bettype
			FROM #SpecialDeleteBets_Single tmpmain
				 INNER JOIN dbo.bettrans main WITH (nolock)
						 ON tmpmain.transid = main.transid
			WHERE tmpmain.BetType NOT BETWEEN 901 AND 910
			
			-- backups for bettrade ticket
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
		INSERT INTO @tblBeforeBalance (custid, balance)
		SELECT T.custid, SUM(T.balance) balance
		FROM (
				  -- normal and main bettrade
				SELECT	t.custid
						,SUM (b.winlost - b.actual_stake + b.playercomm) balance
				FROM #SpecialDeleteBets_Single t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid
				WHERE t.BetType NOT BETWEEN 901 AND 910
				GROUP BY t.CustID
				-- bettrade
				UNION ALL
				SELECT bt.custid
					  ,SUM(sub.winlost - sub.actual_stake + sub.playercomm) AS balance
				FROM dbo.bettrans sub WITH (NOLOCK)
					INNER JOIN #BTTransActive bt 
						ON sub.transId = bt.transId					
				GROUP BY bt.custid
				-- parlay
				UNION ALL
				SELECT	t.custid
						,SUM (b.winlost - b.actual_stake + b.playercomm) balance
				FROM #SpecialDeleteBets_Parlay t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid																		
				GROUP BY t.CustID
				UNION ALL
				-- Cricket charge comm			  
			    SELECT b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) balance
				FROM #t_CustID_501 t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON t.custid = b.custid
				WHERE b.bettype = 500
				  AND b.matchid = @MatchID					
				GROUP BY b.CustID
				-- BT-WLSharing
				UNION ALL
				SELECT	sub904.custid
					   ,SUM(sub904.winlost - sub904.actual_stake + sub904.playercomm) AS balance
				FROM	bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp
					ON sub904.custid = temp.custid
						AND sub904.matchid = @MatchID											
				WHERE sub904.bettype = 904
				GROUP BY sub904.custid
			 ) AS T
		GROUP BY T.custid
		
		-------> update status for tickets to void		
		--> update status for single, BT
		IF @CountSingle > 0
		BEGIN
			-- update status for normal ticket, main bettrade
			UPDATE	main
				SET winlost		= main.actual_stake
					,ruben			= 1
					,statuswinlost	= 6
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
						
			-- update status for sub bettrade ticket
			UPDATE sub
			SET winlost = sub.actual_stake
				,ruben = 1
				,statuswinlost = 6
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
			
			--Pre-CAL 904
			DECLARE @CustIdsBT VARCHAR(MAX)
			SET @CustIdsBT = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
								    FROM @tblCustBT902 tt								    
								    FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')											    
			EXEC dbo.NAP_Admin_Calculate_904 
					@MatchId 	= @MatchID
					, @Action 	= 'VOID'
					, @CustIds 	= @CustIdsBT
					
			-- Insert BetTradeSellingCancel	
			INSERT INTO [dbo].[BetTradeSellingCancelled]  
						  ([TicketID]  
						  ,[Remark]  
						  ,[BTBuyBack]  
						  ,[BTComission]  
						  ,[AfterBalance]  
						  ,[Owner]  
						  ,[Cancelled]  
						  ,[ChangeDate]  
						  ,[CreateDate]  
						  ,TradeID
						)  
			   SELECT	bt.refno
						, 'SB void ticket due to ' + @Reason
						,bt.awinlost
						,0
						,0
						,'SB'
						,1
						,GETDATE()
						,GETDATE()
						,bts.TradeID
				FROM #BTTransActive AS bt
					INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)
						ON bts.TicketID = bt.refno
					LEFT JOIN [dbo].[BetTradeSellingCancelled] c WITH(NOLOCK) 
						ON c.[TicketID] = bt.refno						
				WHERE bt.bettype 		= 901 
					AND c.[BTBuyBack] 	IS NULL 
					AND ( bts.Status 	= 'Accept' OR bts.Status = 'Confirm')
					
			-- Update	
			UPDATE main
			SET
				[Remark] 		= 'SB void ticket due to ' + @Reason,
				[BTBuyBack] 	= ISNULL(bt.awinlost, 0),
				[BTComission] 	= 0,
				[Owner] 		= 'SB',
				[Cancelled] 	= 1,
				[ChangeDate] 	= GETDATE(),
				AfterBalance 	= ISNULL(bl.AfterBalance, 0)
			FROM [dbo].[BetTradeSellingCancelled] main WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #BTTransActive bt 
					ON main.[TicketID] = bt.refno
				OUTER APPLY (
					SELECT SUM(
							CASE 
								WHEN b.ruben = 1
								THEN b.winlost - b.actual_stake + b.playercomm
								ELSE 0
							END
						) AS AfterBalance
					FROM dbo.bettrans b WITH (NOLOCK)
					WHERE b.custid = bt.custid
				) bl
			WHERE bt.bettype = 901
			
			-- Insert bettrade tickets to send API
			DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))	
			;WITH cteMainTicket
			AS(
				SELECT	transid
				FROM	#SpecialDeleteBets_Single 
				WHERE	betdaqid = 0 -- main ticket
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
		INSERT INTO @tblAfterBalance (custid, balance)
		SELECT T.custid, SUM(T.balance) balance
		FROM (
				-- normal and main bettrade
				SELECT	t.custid
						,SUM (b.winlost - b.actual_stake + b.playercomm) balance
				FROM #SpecialDeleteBets_Single t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid
				WHERE t.BetType NOT BETWEEN 901 AND 910
				GROUP BY t.CustID
				-- bettrade
				UNION ALL
				SELECT bt.custid
					  ,SUM(sub.winlost - sub.actual_stake + sub.playercomm) AS balance
				FROM dbo.bettrans sub WITH (NOLOCK)
					INNER JOIN #BTTransActive bt 
						ON sub.transId = bt.transId					
				GROUP BY bt.custid
				-- parlay
				UNION ALL
				SELECT	t.custid
						,SUM (b.winlost - b.actual_stake + b.playercomm) balance
				FROM #SpecialDeleteBets_Parlay t	
					INNER JOIN bettrans b WITH (NOLOCK) 
							ON t.transid = b.transid																		
				GROUP BY t.CustID
				UNION ALL
				-- Cricket charge comm			  
			    SELECT b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) balance
				FROM #t_CustID_501 t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON t.custid = b.custid
				WHERE b.bettype = 500
				  AND b.matchid = @MatchID					
				GROUP BY b.CustID
				-- BT-WLSharing
				UNION ALL
				SELECT	sub904.custid
					   ,SUM(sub904.winlost - sub904.actual_stake + sub904.playercomm) AS balance
				FROM	bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp
					ON sub904.custid = temp.custid
						AND sub904.matchid = @MatchID											
				WHERE sub904.bettype = 904
				GROUP BY sub904.custid
			 )	AS T
		GROUP BY T.custid
		
		-------> Update balance for members	
		--> update credit balance of cust
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT		a.custid, (a.balance - b.balance) AS Balance
		FROM		@tblBeforeBalance b
		INNER JOIN	@tblAfterBalance a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) > 0
				
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 1 -- Sports		

		--> update dedit balance of cust
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT		a.custid, ABS(a.balance - b.balance) AS Balance
		FROM		@tblBeforeBalance b
		INNER JOIN	@tblAfterBalance a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) < 0	
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 1 -- Sports
		
		-------> Update odds
		UPDATE odds  
		SET hometotal = hometotal - (CASE WHEN b.betteam = 'h' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
					  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
			   ELSE 0 END )  
		,awaytotal = awaytotal - (CASE WHEN b.betteam = 'a' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
					  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
				ELSE 0 END)  
		FROM #SpecialDeleteBets_Single AS bd
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON bd.TransID  = b.transid
			INNER JOIN dbo.odds o WITH (ROWLOCK,UPDLOCK)   
				ON o.matchid = b.matchid 
				   AND o.oddsid = b.oddsid  
				   AND b.matchid = @MatchID			
			INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON c.custid = b.custid  
			INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON c.currency = e.exchangeid	
		WHERE bd.Bettype NOT BETWEEN 901 AND 910  --BetTrade subtickets 																								
			 
		-------> Release process
		EXEC dbo.NAP_Admin_CheckingProcess
			  @IsReleased		= 1						
			, @isExistMatch		= @isExistMatch			
			, @isExistParlay  = @isExistParlay
			
		-------> write log		
		EXEC WriteLog_UserLog 
			 @UserId = @UserId,
			 @Doing = @LogData			
			 
		-------> Data for sending mail
		SET @UserIDNotInITGroup = 0
		IF NOT EXISTS (SELECT TOP 1 1 
					   FROM DBPOLICY.bodb02.dbo.accCustomer_1 a 
					   WHERE a.GroupID = 1
				  		 AND a.custid = @UserID)
			SET @UserIDNotInITGroup = 1		
		SELECT  s.Stake,				
				s.BetCheck,
				s.BetId,
				s.BetTeam,
				s.BetType,
				s.CurrencyCode,				
				s.Hdp1,
				s.Hdp2,				
				s.IsLiveIndicator,
				s.IsNeutral,				
				s.LiveAwayScore,
				s.LiveHomeScore,
				s.Odds,
				s.IsMixParlay,
				s.OddsType,
				s.RefNo,
				s.SportType,
				s.Status,
				s.TransDate,
				s.TransDesc,
				s.TransId,
				s.UserName,
				s.NetWinLost AS WinLost,				
				CASE 
					WHEN s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
					ELSE s.site 
				END AS EmailGroup,
				s.site,
				CASE
					WHEN EXISTS (SELECT d.custid 
								 FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) 
								 WHERE d.custid = s.srecommend)
							THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				END AS IsDeposit,
				s.custid,
				s.recommend,
				ac.username AS AgUserName,
				s.mrecommend,
				mc.username AS MagUserName,
				s.srecommend,
				sc.username AS SagUserName,
				s.IsBetTrade,
				
				s.SubTransId,
				s.SubBetCheck,
				s.SubBetTeam,
				s.SubBetType,
				s.SubHdp1,
				s.SubHdp2,
				s.SubOdds,
								
				CASE
					WHEN T2.a IS NOT NULL 
						 AND @UserIDNotInITGroup = 0
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)							
				END AS IsItSupport,
				s.betfrom,
				CURRENT_TIMESTAMP AS [DateTime]				
		FROM (
				SELECT CAST(0 AS BIT) AS IsMixParlay, * FROM #SpecialDeleteBets_Single
				UNION ALL
				SELECT CAST(1 AS BIT) AS IsMixParlay, * FROM #SpecialDeleteBets_Parlay
			 ) s			 
			 LEFT JOIN CustDB.dbo.Customer sc WITH(NOLOCK)
					 ON s.srecommend = sc.custid
			 LEFT JOIN CustDB.dbo.Customer mc WITH(NOLOCK)
					 ON s.mrecommend = mc.custid
			 LEFT JOIN CustDB.dbo.Customer ac WITH(NOLOCK)
					 ON s.recommend = ac.custid
			 OUTER APPLY (SELECT CASE
									WHEN sc.currency <> 20 
										 AND sc.roleid = 4 
											THEN 1
									ELSE NULL
								 END AS a) AS T2
		ORDER BY s.IsMixParlay ASC, s.BettradeGroupID ASC, s.betdaqid ASC									 			 						  			 	
	END TRY
	BEGIN CATCH
		-------> Release process
		EXEC dbo.NAP_Admin_CheckingProcess
			  @IsReleased		= 1						
			, @isExistMatch		= @isExistMatch			
			, @isExistParlay  = @isExistParlay			  
	
		SELECT @ErrorCode = 100,
				@ErrorMsg = @GeneralErrMsg							
				
		SELECT * FROM #t					
							
		RETURN				
	END CATCH		
			
	SET NOCOUNT OFF
END
GO

GRANT EXECUTE ON [dbo].[NAP_SpecialDelete_VoidByCurrency_Update]  TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_SpecialDelete_VoidByCurrency_Update]  TO [vnteam] AS [dbo]
GO
			