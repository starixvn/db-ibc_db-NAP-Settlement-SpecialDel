USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_SpecialDelete_VoidByCurrency_Select]    Script Date: 04/25/2016 09:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_Select] 
	@MatchID		INT,
	@LicenseeNames	VARCHAR(MAX),
	@TicketType		VARCHAR(100) = 'All',
	@CurrencyIDs	VARCHAR(MAX)
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
	
	DECLARE @MBCGroup_Name VARCHAR(50) = 'MBC Group'
		  , @789y_Name	   VARCHAR(50) = '789y'
	
	DECLARE @SearchSingle BIT
		  , @SearchParlay BIT
	
	CREATE TABLE #SpecialDeleteBets (
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
			IsSecondAcceptFlag	BIT, 
			LiveAwayScore		SMALLINT,
			LiveHomeScore		SMALLINT,
			Odds				MONEY,
			IsMixParlay			BIT,
			OddsType			INT,
			RefNo				BIGINT,
			SportType			SMALLINT,
			Status				NVARCHAR(10),
			TransDate			DATETIME,
			TransDesc			NVARCHAR(1000),
			TransId				BIGINT,
			UserName			VARCHAR(30),
			NetWinLost			MONEY,
			srecommend			INT,
			GroupName			VARCHAR(10),
			betdaqid			BIGINT,	
			SoldId				BIGINT,
			IsBetTrade			BIT,
			
			SubTransId			BIGINT,
			SubBetCheck			NVARCHAR(50),
			SubBetTeam			NVARCHAR(10),
			SubBetType			SMALLINT,
			SubHdp1				SMALLMONEY,
			SubHdp2				SMALLMONEY,
			SubOdds				MONEY,
			SubStatus			NVARCHAR(10)
		)			
				
	CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(10))
	CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)	
	
	CREATE TABLE #t_exchanges(exchangeid INT, currency NVARCHAR(50))
	
	INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
	SELECT ss.val AS LicenseeName, ss.val AS GroupName
	FROM dbo.strSplit(@LicenseeNames, ',') ss		
	
	DELETE FROM #t_LicenseeNames WHERE LicenseeName = @MBCGroup_Name
	IF @@ROWCOUNT > 0
		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT [site] AS LicenseeName, @MBCGroup_Name AS GroupName
		FROM DBCUST.CUSTDB.dbo.Site WITH(NOLOCK) 
		WHERE isLicensee = 0		  
		  AND isActive = 1	
		  AND [site] <> @789y_Name -- '789y' is treated as special licensee as 'MBC Group'	  			  
	
	INSERT INTO #t_exchanges(exchangeid, currency)
	SELECT e.exchangeid, e.currency
	FROM dbo.strSplit(@CurrencyIDs, ',') ss
		 INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK)
				 ON CAST(ss.val AS INT) = e.exchangeid				 				 
	
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
					
					SubTransId,
					SubBetCheck,
					SubBetTeam,
					SubBetType,
					SubHdp1,
					SubHdp2,
					SubOdds,
					SubStatus	
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
				
				b.TransId AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
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
		
		IF EXISTS (SELECT TOP 1 1
				   FROM #SpecialDeleteBets
				   WHERE betdaqid	= 0)
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
						ROW_NUMBER() OVER (PARTITION  BY sub.refno ORDER BY sub.transId DESC ) AS BTNo				
				FROM #SpecialDeleteBets main
					 INNER JOIN bettrans sub WITH (NOLOCK)
							ON	main.TransId = sub.refno			 
				WHERE main.betdaqid	= 0
				  AND sub.matchid = @MatchID -- filer for @MatchID
				  AND sub.bettype = 901 -- get only sold records
				  AND sub.statusID 	IN (111,112,113,103) --WON/LOSE/DRAW/REFUND			  
			)	
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
					main.AwayId,
					main.BetCheck,
					main.BetType AS BetId,
					main.BetTeam,
					sub.BetType AS BetType,
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
					
					sub.TransId AS SubTransId,
					NULL AS SubBetCheck,
					NULL AS SubBetTeam,
					NULL AS SubBetType,
					NULL AS SubHdp1,
					NULL AS SubHdp2,
					NULL AS SubOdds,
					sub.status AS SubStatus
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
		END
	END
		
	--> parlay
	IF @SearchParlay = 1	
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
		
	SELECT  s.Stake,
			s.AwayId,
			s.BetCheck,
			s.BetId,
			s.BetTeam,
			s.BetType,
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
			
			s.SubTransId,
			s.SubBetCheck,
			s.SubBetTeam,
			s.SubBetType,
			s.SubHdp1,
			s.SubHdp2,
			s.SubOdds,
			s.SubStatus,
			ROW_NUMBER() OVER(ORDER BY CASE
											WHEN s.GroupName = @MBCGroup_Name THEN 1
											WHEN s.GroupName = @789y_Name THEN 2
											ELSE 3
									   END ASC
									 , s.GroupName ASC
									 , s.IsMixParlay ASC
									 , s.TransId ASC) AS RowNum
				INTO #Result								 
	FROM #SpecialDeleteBets s					 
		 CROSS APPLY (SELECT CASE
									WHEN EXISTS (SELECT d.custid 
												 FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) 
												 WHERE d.custid = s.srecommend)
											THEN 1
									ELSE 0
							 END AS IsDeposit) AS T1	
							 
	UPDATE sub
	SET RowNum = main.RowNum
	FROM #Result main
		 INNER JOIN #Result sub
				 ON main.transid = sub.RefNo									 
	WHERE main.betdaqid = 0	

	SELECT 
		s.Stake,
		s.AwayId,
		s.BetCheck,
		s.BetId,
		s.BetTeam,
		s.BetType,
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
		s.IsMixParlay,
		s.IsCricket,
		s.OddsType,
		s.RefNo,
		s.SportType,
		s.Status,
		s.TransDate,
		s.TransDesc,
		s.TransId,
		s.UserName,
		s.WinLost,			
		s.GroupName,
		s.SoldId,
		
		s.SubTransId,
		s.SubBetCheck,
		s.SubBetTeam,
		s.SubBetType,
		s.SubHdp1,
		s.SubHdp2,
		s.SubOdds,
		s.SubStatus
	FROM #Result s
	ORDER BY s.RowNum ASC, s.betdaqid ASC
			
	SET NOCOUNT OFF
END
GO

GRANT EXECUTE ON [dbo].[NAP_SpecialDelete_VoidByCurrency_Select]  TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_SpecialDelete_VoidByCurrency_Select]  TO [vnteam] AS [dbo]
GO
			