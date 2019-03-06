/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_Select] @MatchID       INT,
                                                                @LicenseeNames VARCHAR(MAX),
                                                                @TicketType    VARCHAR(100) = 'All',
                                                                @CurrencyIDs   VARCHAR(MAX)
AS;
/*
	Created: Kent
	Date: 20161201
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161201@Kent: Search sportbook tickets by crrency to void [Redmine:#67987]
		- 20170313@Kent: Integrate cash-out [Redmine:#72059]
		- 20170418@Kent: Fix Returned Data Type For Bit Columns [Redmine:#75009]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170922@Kent: Void Parlay Bet & Support New site [Redmine:#54340]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread - Fast Markets Phase 2 [Redmine:#90667]
		- 20181004@Alan: Add new column SettlementStatus [102423]
		- 20190320@Alan: Add CN88 into Others Group [109858]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190228@Alan: Implement Bet Builder - [106898]
	Param's Explanation:			
			- @TicketType:
			'All': All
			'SingleTicket': Single ticket
			'ParlayTicket': Parlay ticket
*/
BEGIN
	SET NOCOUNT ON
	
	-- Constant
	DECLARE @MBCGroup_Name	VARCHAR(50) = 'MBC Group'
		  , @789y_Name		VARCHAR(50) = '789y'
		  , @y987_Name		VARCHAR(50) = 'y987'
		  , @cn88_Name		VARCHAR(50) = 'CN88'
	
	DECLARE @SearchSingle BIT
		  , @SearchParlay BIT

	DECLARE @SettlementStatus TINYINT = NULL
			,@GlobalShowTime SMALLDATETIME
	SELECT @SettlementStatus = m.SettlementStatus
			,@GlobalShowTime = m.GlobalShowTime
	FROM dbo.match m WHERE m.matchid = @MatchId
CREATE TABLE #SpecialDeleteBets
             (GroupID               BIGINT,
	
              Stake                 MONEY,
              AwayId                INT,
              BetCheck              NVARCHAR(50),
              BetId                 BIGINT DEFAULT(0),
              BetTeam               NVARCHAR(10),
              BetType               SMALLINT,
              OriginalBetType       SMALLINT,
              CurrencyCode          NVARCHAR(50),
              Creator               INT,
              Hdp1                  SMALLMONEY,
              Hdp2                  SMALLMONEY,
              HomeId                INT,
              IsLiveIndicator       BIT,
              IsNeutral             BIT,
              IsSecondAcceptFlag    BIT,
              LiveAwayScore         SMALLINT,
              LiveHomeScore         SMALLINT,
              Odds                  MONEY,
              Oddsspread            MONEY,
              IsMixParlay           BIT,
              OddsType              INT,
              RefNo                 BIGINT,
              SportType             SMALLINT,
              Status                NVARCHAR(10),
              TransDate             DATETIME,
              TransDesc             NVARCHAR(1000),
              TransId               BIGINT,
              UserName              VARCHAR(30),
              NetWinLost            MONEY,
              srecommend            INT,
              GroupName             VARCHAR(10),
              betdaqid              BIGINT,
              SoldId                BIGINT,
              IsBetTrade            BIT,
              ExtraInfo             VARCHAR(1000),
              IsCashOutMemberTicket BIT DEFAULT 0,
              MainCashoutId         BIGINT,
              matchid               INT,
              custid                INT,
              WalletType            TINYINT,
              RefCode               BIGINT,
              BonusID               INT,
              MainTransId           BIGINT,
              SubTransId            BIGINT,
              SubBetCheck           NVARCHAR(50),
              SubBetTeam            NVARCHAR(10),
              SubBetType            SMALLINT,
              SubHdp1               SMALLMONEY,
              SubHdp2               SMALLMONEY,
              SubOdds               MONEY,
              SubStatus             NVARCHAR(10),
		    IsMarked			 BIT
             );
   CREATE TABLE #tmpRefCodeSummary
             (RefCode  BIGINT,
              custid   INT,
              bettype  SMALLINT,
              transid  BIGINT,
              IsMarked BIT
             );

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)			
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	
				
	CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
	CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)
	
	CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))	
	
	CREATE TABLE #t_exchanges(exchangeid INT, currency NVARCHAR(50))
	
	--> Parse @LicenseeNames
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
								WHEN t.GroupName = @cn88_Name AND cte.[site] IN (@cn88_Name) THEN 1 ELSE 0 
								END = 1
						 ) AS cte
	END					 				  			   	  	  			  
	
	--> Parse @CurrencyIDs
	INSERT INTO #t_exchanges(exchangeid, currency)
	SELECT e.exchangeid, e.currency
	FROM dbo.f_SplitString(@CurrencyIDs, ',') ss
		 INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK)
				 ON CAST(ss.val AS INT) = e.exchangeid	
	OPTION (maxrecursion 0)				 			 				 
	
	SELECT @SearchSingle = 0, @SearchParlay = 0
	IF @TicketType = 'All'	
		SELECT @SearchSingle = 1, @SearchParlay = 1
	ELSE IF @TicketType = 'SingleTicket'
		SET @SearchSingle = 1
	ELSE IF @TicketType = 'ParlayTicket'
		SET @SearchParlay = 1
	
	--> single
	IF @SearchSingle = 1
	BEGIN
		INSERT INTO #SpecialDeleteBets(
					GroupID,
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
					IsSecondAcceptFlag,
					LiveAwayScore,
					LiveHomeScore,
					Odds,
					Oddsspread,
					IsMixParlay,
					OddsType,
					RefNo,
					SportType,
					Status,
					TransDate,
					TransDesc,
					TransId,
					UserName,
					NetWinLost,
					srecommend,
					GroupName,
					betdaqid,
					IsBetTrade,	
					ExtraInfo,
					MainCashoutId,
					custid,	
					WalletType,
					RefCode,
					BonusID,																	
					SubTransId,
					SubBetCheck,
					SubBetTeam,
					SubBetType,
					SubHdp1,
					SubHdp2,
					SubOdds,
					SubStatus,
					IsMarked
				)
		SELECT 	b.transid AS GroupID,
				b.Stake,
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
				b.SecAcceptFlag AS IsSecondAcceptFlag,
				b.LiveAwayScore,
				b.LiveHomeScore,
				b.Odds,
				b.Oddsspread,
				0 AS IsMixParlay,
				b.OddsType,
				b.RefNo,
				m.SportType,
				CASE 
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP 
						THEN 'waiting'
					ELSE b.status 
				END AS STATUS,
				b.TransDate,
				b.TransDesc,
				b.TransId,
				b.UserName,
				b.WinLost - b.actual_stake AS NetWinLost,
				b.srecommend,
				tl.GroupName AS GroupName,
				b.betdaqid,	
				CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN 1 ELSE 0 END AS IsBetTrade,
				b.ExtraInfo,
				CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId,
				b.custid,
				b.WalletType,
				b.RefCode,
				b.BonusID,							
				
				b.TransId AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				b.status AS SubStatus,
				CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked		
		FROM bettrans b WITH (NOLOCK)
			 INNER JOIN #t_exchanges te WITH (NOLOCK)
					 ON b.currency = te.exchangeid -- filter for @CurrencyCodes			 
			 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
					 ON b.recommend = c.custid
			 INNER JOIN #t_LicenseeNames tl WITH (NOLOCK)
					 ON tl.LicenseeName = c.site -- filter for @LicenseeIDs	
			 INNER JOIN match m WITH (NOLOCK)
					 ON b.matchid = m.matchid	
			 LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK) ON b.transid = mt.TransId		 							 		 
		WHERE m.sporttype BETWEEN 1 AND 99 -- sportbook only			
			AND b.bettype NOT BETWEEN 801 AND 806-- MG
			AND b.bettype NOT BETWEEN 901 AND 910 -- BT subticket			
			AND b.bettype NOT BETWEEN 911 AND 914 -- Cash-out subticket	
			AND b.statusID NOT IN (101, 102) -- reject, void
			AND b.betfrom <> 'P' -- exclude phone betting
			AND b.matchid = @MatchID -- filer for @MatchID	
			AND b.bettype <> 500 -- exclude charge comm
			AND b.bettype <> 38 -- exclude Bet Builder
			
			AND b.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
			AND b.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
			AND b.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
			AND b.custid NOT IN (SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- For Special bets: betdaq
			AND b.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)
					
		-- delete cash-out member bet tickets
		DELETE t
		FROM #SpecialDeleteBets t
		WHERE EXISTS (SELECT TOP 1 1
					  FROM bettrans sub911 (NOLOCK)
					  WHERE sub911.bettype = 911
						AND sub911.transid = t.refno)				
		
		-- update MainTransId
		IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)
		BEGIN
			UPDATE sub
			SET MainTransId = main.transid
			FROM #SpecialDeleteBets main
				 INNER JOIN #SpecialDeleteBets sub
						 ON main.RefCode = sub.RefCode
							AND main.transid <> sub.transid	
							AND main.custid = sub.custid
							AND main.bettype = sub.bettype
			WHERE main.WalletType = 1
		  
			-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets
			INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, IsMarked,transid)
			SELECT RefCode, custid, bettype,IsMarked
				 , MAX(transid) AS transid
			FROM #SpecialDeleteBets
			WHERE	RefCode IS NOT NULL
			GROUP BY RefCode, custid, bettype, IsMarked
			HAVING COUNT(*) = 1
		
			IF @@ROWCOUNT > 0
			BEGIN
				INSERT INTO #SpecialDeleteBets(
							GroupID,
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
							IsSecondAcceptFlag,
							LiveAwayScore,
							LiveHomeScore,
							Odds,
							IsMixParlay,
							OddsType,
							RefNo,
							SportType,
							Status,
							TransDate,
							TransDesc,
							TransId,
							UserName,
							NetWinLost,
							srecommend,
							GroupName,
							betdaqid,
							IsBetTrade,
							ExtraInfo,
							MainCashoutId,
							custid,
							WalletType,
							RefCode,
							BonusID,
							MainTransId,					
					
							SubTransId,
							SubBetCheck,
							SubBetTeam,
							SubBetType,
							SubHdp1,
							SubHdp2,
							SubOdds,
							SubStatus,
							IsMarked	
						)
				SELECT 	b.transid AS GroupID,
						b.Stake,
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
						b.SecAcceptFlag AS IsSecondAcceptFlag,
						b.LiveAwayScore,
						b.LiveHomeScore,
						b.Odds,
						0 AS IsMixParlay,
						b.OddsType,
						b.RefNo,
						m.SportType,
						CASE 
							WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP 
								THEN 'waiting'
							ELSE b.status 
						END AS STATUS,
						b.TransDate,
						b.TransDesc,
						b.TransId,
						b.UserName,
						b.WinLost - b.actual_stake AS NetWinLost,
						b.srecommend,
						tl.GroupName AS GroupName,
						b.betdaqid,	
						CASE WHEN b.betdaqid = 0 THEN 1 ELSE 0 END AS IsBetTrade,				
						b.ExtraInfo,
						CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL
						END AS MainCashoutId,				
						b.custid,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						t.transid AS MainTransId,			
				
						b.TransId AS SubTransId,
						NULL AS SubBetCheck,
						NULL AS SubBetTeam,
						NULL AS SubBetType,
						NULL AS SubHdp1,
						NULL AS SubHdp2,
						NULL AS SubOdds,
						b.status AS SubStatus,
						IsMarked
				FROM #tmpRefCodeSummary t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON b.RefCode = t.RefCode
								AND b.transid <> t.transid
								AND b.matchid = @MatchId
								AND b.custid = t.custid
								AND b.bettype = t.bettype
					 INNER JOIN #t_exchanges te WITH (NOLOCK)
							 ON b.currency = te.exchangeid 			 
					 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
							 ON b.recommend = c.custid
					 INNER JOIN #t_LicenseeNames tl WITH (NOLOCK)
							 ON tl.LicenseeName = c.site
					 INNER JOIN match m WITH (NOLOCK)
							 ON b.matchid = m.matchid
				WHERE b.statusID NOT IN (101,102 ) -- reject, void		
			END  	  																					
		END

		IF EXISTS (SELECT TOP 1 1
				   FROM #SpecialDeleteBets
				   WHERE betdaqid	= 0
				     AND extrainfo is null)
		BEGIN
			-- get sold records for bettrade tickets
			;WITH CTE_LastTransBT AS (
				SELECT  sub.BetId,					
						sub.RefNo,					
						sub.TransDate,					
						sub.TransId,
						sub.UserName,
						sub.winlost - sub.actual_stake AS NetWinLost,
						sub.srecommend,
						sub.betdaqid,
						sub.status,
						sub.bettype,
						sub.ExtraInfo,
						sub.WalletType,
						sub.RefCode,
						sub.BonusID,
						main.transid AS MainTransId,
						ROW_NUMBER() OVER (PARTITION  BY sub.refno ORDER BY sub.transId DESC ) AS BTNo				
				FROM #SpecialDeleteBets main
					 INNER JOIN bettrans sub WITH (NOLOCK)
							ON	main.TransId = sub.refno			 
				WHERE main.betdaqid	= 0
				  AND main.extrainfo is null
				  AND sub.matchid = @MatchID -- filer for @MatchID
				  AND sub.bettype = 901 -- get only sold records
				  AND sub.statusID 	IN (111,112,113,103) --WON/LOSE/DRAW/REFUND			  
			)	
			INSERT INTO #SpecialDeleteBets(
						GroupID,
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
						OriginalBetType,
						CurrencyCode,
						Creator,					
						Hdp1,
						Hdp2,
						HomeId,
						IsLiveIndicator,
						IsNeutral,
						IsSecondAcceptFlag,
						LiveAwayScore,
						LiveHomeScore,
						Odds,
						Oddsspread,
						IsMixParlay,
						OddsType,
						RefNo,
						SportType,
						Status,
						TransDate,
						TransDesc,
						TransId,
						UserName,
						NetWinLost,
						srecommend,
						GroupName,
						betdaqid,					
						IsBetTrade,
						ExtraInfo,	
						WalletType,
						RefCode,
						BonusID,
						MainTransId,										
						
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds,
						SubStatus,
						IsMarked
					)
			SELECT  main.transid AS GroupID,
					main.Stake,
					main.AwayId,
					main.BetCheck,
					main.BetType AS BetId,
					main.BetTeam,
					sub.BetType AS BetType,
					main.bettype AS OriginalBetType,
					main.CurrencyCode,
					main.Creator,					
					main.Hdp1,
					main.Hdp2,
					main.HomeId,
					main.IsLiveIndicator,
					main.IsNeutral,
					main.IsSecondAcceptFlag,
					main.LiveAwayScore,
					main.LiveHomeScore,
					main.Odds,
					main.Oddsspread,
					main.IsMixParlay,
					main.OddsType,
					sub.RefNo,
					main.SportType,
					'SOLD' AS Status,
					sub.TransDate,
					main.TransDesc,
					sub.TransId,
					sub.UserName,
					sub.NetWinLost,
					sub.srecommend,
					main.GroupName,
					sub.betdaqid,
					CAST(1 AS BIT) AS IsBetTrade,
					sub.ExtraInfo AS ExtraInfo,	
					sub.WalletType,
					sub.RefCode,
					sub.BonusID,
					sub.MainTransId,								
					
					sub.TransId AS SubTransId,
					NULL AS SubBetCheck,
					NULL AS SubBetTeam,
					NULL AS SubBetType,
					NULL AS SubHdp1,
					NULL AS SubHdp2,
					NULL AS SubOdds,
					sub.status AS SubStatus,
					main.IsMarked
			FROM #SpecialDeleteBets main
				 INNER JOIN CTE_LastTransBT sub WITH (NOLOCK)
						 ON	main.TransId = sub.refno			 
			WHERE sub.BTNo = 1
			
			-- update SoldId column: if main ticket is BT, update SoldId = transid of subticket(901)			
			UPDATE	main
			SET main.SoldId = bt.transid
			FROM #SpecialDeleteBets main 
				INNER JOIN #SpecialDeleteBets bt
				ON main.transId = bt.refno					
			WHERE main.betdaqid = 0 -- main ticket is BTrade
			  AND main.extrainfo is null
		END
		
		IF EXISTS (SELECT TOP 1 1
				   FROM #SpecialDeleteBets
				   WHERE betdaqid = 0
					 AND charindex ('p25',extrainfo)> 0)
		BEGIN
			-- get sub ticket of Cash-out (911)
			INSERT INTO #SpecialDeleteBets(
						GroupID,
						Stake,
						AwayId,
						BetCheck,
						BetId,
						BetTeam,
						BetType,
						OriginalBetType,
						CurrencyCode,
						Creator,					
						Hdp1,
						Hdp2,
						HomeId,
						IsLiveIndicator,
						IsNeutral,
						IsSecondAcceptFlag,
						LiveAwayScore,
						LiveHomeScore,
						Odds,
						oddsspread,
						IsMixParlay,
						OddsType,
						RefNo,
						SportType,
						Status,
						TransDate,
						TransDesc,
						TransId,
						UserName,
						NetWinLost,
						srecommend,
						GroupName,
						betdaqid,					
						IsBetTrade,
						ExtraInfo,
						MainCashoutId,
						matchid,
						WalletType,
						RefCode,
						BonusID,
						MainTransId,						
						
						SubTransId,
						SubBetCheck,
						SubBetTeam,
						SubBetType,
						SubHdp1,
						SubHdp2,
						SubOdds,
						SubStatus,
						IsMarked
					)
			SELECT  sub911.transid AS GroupID,
					sub911.Stake,
					main.AwayId,
					main.BetCheck,
					main.BetType AS BetId,
					main.BetTeam,
					sub911.BetType AS BetType,
					main.bettype  AS OriginalBetType,
					main.CurrencyCode,
					main.Creator,					
					main.Hdp1,
					main.Hdp2,
					main.HomeId,
					main.IsLiveIndicator,
					main.IsNeutral,
					main.IsSecondAcceptFlag,
					main.LiveAwayScore,
					main.LiveHomeScore,
					main.Odds,
					main.oddsspread,
					main.IsMixParlay,
					main.OddsType,
					sub911.RefNo,
					main.SportType,
					'Cash out' AS Status,
					sub911.TransDate,
					main.TransDesc,
					sub911.TransId,
					sub911.UserName,
					sub911.winlost - sub911.actual_stake AS NetWinLost,
					sub911.srecommend,
					main.GroupName,
					sub911.betdaqid,
					CAST(0 AS BIT) AS IsBetTrade,
					sub911.ExtraInfo AS ExtraInfo,
					main.transid AS MainCashoutId,
					sub911.matchid,
					sub911.WalletType,
					sub911.RefCode,
					sub911.BonusID,
					main.transid AS MainTransId,					
					
					sub911.TransId AS SubTransId,
					NULL AS SubBetCheck,
					NULL AS SubBetTeam,
					NULL AS SubBetType,
					NULL AS SubHdp1,
					NULL AS SubHdp2,
					NULL AS SubOdds,
					sub911.status AS SubStatus,
					main.IsMarked					
			FROM dbo.bettrans sub911 WITH(NOLOCK)
				 INNER JOIN #SpecialDeleteBets main 
						ON	sub911.refno = main.transid	
							AND sub911.custid = main.custid					
							AND main.betdaqid = 0
							AND charindex ('p25',main.extrainfo)> 0			
							AND sub911.bettype = 911
							AND sub911.matchid = @matchid
			WHERE sub911.statusID NOT IN (102, 101) -- VOID, REJECT		
			
			-- get cash-out member bet tickets
			INSERT INTO #SpecialDeleteBets(
					GroupID,
					Stake,
					AwayId,
					BetCheck,
					BetId,
					BetTeam,
					BetType,
					OriginalBetType,
					CurrencyCode,
					Creator,					
					Hdp1,
					Hdp2,
					HomeId,
					IsLiveIndicator,
					IsNeutral,
					IsSecondAcceptFlag,
					LiveAwayScore,
					LiveHomeScore,
					Odds,
					oddsspread,
					IsMixParlay,
					OddsType,
					RefNo,
					SportType,
					Status,
					TransDate,
					TransDesc,
					TransId,
					UserName,
					NetWinLost,
					srecommend,
					GroupName,
					betdaqid,
					IsBetTrade,	
					ExtraInfo,
					IsCashOutMemberTicket,
					MainCashoutId,
					WalletType,
					RefCode,
					BonusID,
					MainTransId,								
					
					SubTransId,
					SubBetCheck,
					SubBetTeam,
					SubBetType,
					SubHdp1,
					SubHdp2,
					SubOdds,
					SubStatus,
					IsMarked
				)
		SELECT 	sub911.transid AS GroupID,
				b.Stake,
				m.AwayId,
				b.BetCheck,
				b.BetId,
				b.BetTeam,
				b.BetType,
				sub911.OriginalBetType,
				te.currency AS CurrencyCode,
				b.Creator,				
				b.Hdp1,
				b.Hdp2,
				m.HomeId,
				b.LiveIndicator AS IsLiveIndicator,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.SecAcceptFlag AS IsSecondAcceptFlag,
				b.LiveAwayScore,
				b.LiveHomeScore,
				b.Odds,
				b.oddsspread,
				0 AS IsMixParlay,
				b.OddsType,
				b.RefNo,
				m.SportType,
				CASE 
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP 
						THEN 'waiting'
					ELSE b.status 
				END AS STATUS,
				b.TransDate,
				b.TransDesc,
				b.TransId,
				b.UserName,
				b.WinLost - b.actual_stake AS NetWinLost,
				b.srecommend,
				sub911.GroupName,
				b.betdaqid,	
				CAST(0 AS BIT) AS IsBetTrade,
				b.ExtraInfo,	
				1 AS IsCashOutMemberTicket,
				sub911.MainCashoutId AS MainCashoutId,
				b.WalletType,
				b.RefCode,
				b.BonusID,
				sub911.MainTransId,					
				
				b.TransId AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				b.status AS SubStatus,
				sub911.IsMarked
			FROM #SpecialDeleteBets sub911
				 CROSS APPLY (
								  SELECT b.*
								  FROM dbo.bettrans b WITH (NOLOCK)
								  WHERE b.refno = sub911.transid
									AND b.matchid = sub911.matchid
									AND b.bettype = sub911.OriginalBetType
									AND b.statusID NOT IN (102, 101) -- VOID, REJECT
							 ) AS b			 				 
				 LEFT JOIN match m WITH (NOLOCK)
						 ON b.matchid = m.matchid
				 LEFT JOIN CustDB.dbo.exchange te WITH(NOLOCK)
						 ON b.currency = te.exchangeid						 						 							
			WHERE sub911.bettype = 911
		END					 
	END
		
	--> parlay
	IF @SearchParlay = 1	
	BEGIN
		INSERT INTO #SpecialDeleteBets(
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
					IsSecondAcceptFlag,
					LiveAwayScore,
					LiveHomeScore,
					Odds,
					oddsspread,
					IsMixParlay,
					OddsType,
					RefNo,
					SportType,
					Status,
					TransDate,
					TransDesc,
					TransId,
					UserName,
					NetWinLost,
					srecommend,
					GroupName,
					betdaqid,
					IsBetTrade,														
					
					SubTransId,
					SubBetCheck,
					SubBetTeam,
					SubBetType,
					SubHdp1,
					SubHdp2,
					SubOdds,
					SubStatus		
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
				main.SecAcceptFlag AS IsSecondAcceptFlag,
				sub.LiveAwayScore,
				sub.LiveHomeScore,
				main.Odds,
				main.oddsspread,
				1 AS IsMixParlay,
				main.OddsType,
				main.RefNo,
				m.SportType,
				main.STATUS,
				main.transdate AS TransDate,
				sub.transdesc AS TransDesc,
				main.transid AS TransId,
				main.UserName,
				main.winlost - main.actual_stake AS NetWinLost,
				main.srecommend,
				tl1.GroupName AS GroupName,
				main.betdaqid,
				CAST(0 AS BIT) AS IsBetTrade,								 			
				
				sub.transid AS SubTransId,
				sub.betcheck AS SubBetCheck,
				sub.betteam AS SubBetTeam,
				sub.bettype AS SubBetType,
				sub.hdp1 AS SubHdp1,
				sub.hdp2 AS SubHdp2,
				sub.odds AS SubOdds,
				sub.status AS SubStatus
		FROM bettrans main WITH (NOLOCK)
			 INNER JOIN #t_exchanges te WITH (NOLOCK)
					 ON main.currency = te.exchangeid  -- filter for @CurrencyCodes
			 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
					 ON main.recommend = c.custid
			 INNER JOIN #t_LicenseeNames tl1 WITH (NOLOCK)
					 ON tl1.LicenseeName = c.site -- filter for @LicenseeIDs			 			 				 					 
			 
			 INNER JOIN dbo.bettransm sub WITH (NOLOCK)	
					 ON main.refno = sub.refno
			 INNER JOIN match m WITH (NOLOCK)
					 ON sub.matchid = m.matchid
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
		-- Insert Bet Builder
		INSERT INTO #SpecialDeleteBets(
					GroupID,
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
					IsSecondAcceptFlag,
					LiveAwayScore,
					LiveHomeScore,
					Odds,
					Oddsspread,
					IsMixParlay,
					OddsType,
					RefNo,
					SportType,
					Status,
					TransDate,
					TransDesc,
					TransId,
					UserName,
					NetWinLost,
					srecommend,
					GroupName,
					betdaqid,
					IsBetTrade,	
					ExtraInfo,
					MainCashoutId,
					custid,	
					WalletType,
					RefCode,
					BonusID,
					SubTransId,
					SubStatus
				)
		SELECT 	b.transid AS GroupID,
				b.Stake,
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
				b.SecAcceptFlag AS IsSecondAcceptFlag,
				b.LiveAwayScore,
				b.LiveHomeScore,
				b.Odds,
				b.Oddsspread,
				0 AS IsMixParlay,
				b.OddsType,
				b.RefNo,
				m.SportType,
				CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP 
					THEN 'waiting' ELSE b.status END AS STATUS,
				b.TransDate,
				b.TransDesc,
				b.TransId,
				b.UserName,
				b.WinLost - b.actual_stake AS NetWinLost,
				b.srecommend,
				tl.GroupName AS GroupName,
				b.betdaqid,	
				CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN 1 ELSE 0 END AS IsBetTrade,
				b.ExtraInfo,
				CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
						THEN b.transid ELSE NULL END AS MainCashoutId,
				b.custid,
				b.WalletType,
				b.RefCode,
				b.BonusID,
				b.TransId AS SubTransId,
				b.status AS SubStatus
		FROM bettrans b WITH (NOLOCK)
			 INNER JOIN #t_exchanges te WITH (NOLOCK)
					 ON b.currency = te.exchangeid -- filter for @CurrencyCodes			 
			 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
					 ON b.recommend = c.custid
			 INNER JOIN #t_LicenseeNames tl WITH (NOLOCK)
					 ON tl.LicenseeName = c.site -- filter for @LicenseeIDs	
			 INNER JOIN match m WITH (NOLOCK)
					 ON b.matchid = m.matchid			 							 		 
		WHERE m.sporttype BETWEEN 1 AND 99 -- sportbook only			
			AND b.bettype = 38 -- Bet Builder
			AND b.statusID NOT IN (101, 102) -- reject, void
			AND b.betfrom <> 'P' -- exclude phone betting
			AND b.matchid = @MatchID -- filer for @MatchID
			
			AND b.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
			AND b.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
			AND b.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
			AND b.custid NOT IN (SELECT CustID FROM  [f_GetBetDaqCustomer] (1)) -- For Special bets: betdaq
			AND b.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)	
	END

	SELECT 
		s.Stake,
		s.AwayId,
		s.BetCheck,
		s.BetId,
		s.BetTeam,
		s.BetType,
		s.OriginalBetType,
		s.CurrencyCode,		
		s.Hdp1,
		s.Hdp2,
		s.HomeId,
		s.IsLiveIndicator,
		s.IsNeutral,
		s.IsSecondAcceptFlag,
		s.LiveAwayScore,
		s.LiveHomeScore,
		s.Odds,
		s.oddsspread,
		s.IsMixParlay,
		CASE WHEN s.bettype = 501 AND T1.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket,
		s.OddsType,
		s.RefNo,
		s.SportType,
		s.Status,
		s.TransDate,
		s.TransDesc,
		s.TransId,
		s.UserName,
		s.NetWinLost AS WinLost,			
		s.GroupName,
		s.SoldId,
		s.betdaqid,
		s.ExtraInfo,
		s.MainCashoutId,
		s.WalletType,			
		s.MainTransId,		
		s.RefCode,
		
		s.SubTransId,
		s.SubBetCheck,
		s.SubBetTeam,
		s.SubBetType,
		s.SubHdp1,
		s.SubHdp2,
		s.SubOdds,
		s.SubStatus,
		@SettlementStatus AS SettlementStatus,
		s.IsMarked
		@GlobalShowTime AS GlobalShowTime
	FROM #SpecialDeleteBets s					 
		 CROSS APPLY (SELECT CASE
									WHEN EXISTS (SELECT d.custid 
												 FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) 
												 WHERE d.custid = s.srecommend)
											THEN 1
									ELSE 0
							 END AS IsDeposit) AS T1						 
	ORDER BY CASE
				WHEN s.GroupName = @cn88_Name THEN 1
				WHEN s.GroupName = @789y_Name THEN 2
				WHEN s.GroupName = @MBCGroup_Name THEN 3
				ELSE 4
		     END ASC
		   , s.GroupName ASC
		   , s.IsMixParlay ASC
		   , ISNULL(s.MainTransId, s.transid) ASC									 
		   , CASE WHEN s.BonusID IS NOT NULL THEN CASE WHEN s.MainTransId IS NULL THEN 1 ELSE 2 END ELSE s.transid END							 
			
	SET NOCOUNT OFF
END
GO
			