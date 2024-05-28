/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_Select] 
(
	@MatchID       INT,
    @LicenseeNames VARCHAR(MAX),
    @TicketType    VARCHAR(100) = 'All',
    @CurrencyIDs   VARCHAR(MAX),
	@IsOutright		BIT = 0
)
AS;
/*
	Created: 20161201@Kent
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

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
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20200422@Charles: Not support refund status [132661]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210326@Kathy: Tuning SP for EC [Redmine:#151103]
		- 20210827@Max: [TVS] Support Outright on Void By Currency [Redmine: #159540]
		- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230524@July: Support sport Cricket for all functions [Redmine: #188374]
		- 20240123@July: Separate group to view data of 777 site [Redmine: #198089]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
		- 20240527@July: [TVS] Scaleout DBCUST [Redmine: #205629]

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
		,@789y_Name			VARCHAR(50) = '789y'
		,@cn88_Name			VARCHAR(50) = 'CN88'
		,@777_Name			VARCHAR(50) = '777'
		,@SearchSingle		BIT
		,@SearchParlay		BIT
		,@SearchBetBuilder	BIT
		,@SettlementStatus	TINYINT = NULL
		,@GlobalShowTime	SMALLDATETIME
		,@AwayId			INT
		,@HomeId			INT
		,@IsNeutral			BIT
		,@SportType			SMALLINT
		,@SiteDBGroupID		SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpMatchId TABLE (MatchId INT)

	IF @IsOutright = 0 
	BEGIN
		SELECT @SettlementStatus = m.SettlementStatus
				,@GlobalShowTime = m.GlobalShowTime
				,@HomeId = homeid
				,@AwayId = awayid
				,@SportType = sporttype
				,@IsNeutral = ISNULL(IsNeutral,0)
		FROM	dbo.match m WITH(NOLOCK)
		WHERE	m.matchid = @MatchId
	
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
				,@HomeId = o.teamid
				,@AwayId = 0
				,@SportType = l.sporttype
				,@IsNeutral = 0
		FROM	dbo.outright o WITH(NOLOCK)
			INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = o.leagueid
		WHERE	o.orid = @MatchId
		
		INSERT INTO @tmpMatchId (MatchId)
		SELECT @MatchId
	END

	CREATE TABLE #SpecialDeleteBets(
		GroupID               BIGINT,	
        Stake                 MONEY,
        BetCheck              NVARCHAR(50),
        BetId                 BIGINT DEFAULT(0),
        BetTeam               NVARCHAR(10),
        BetType               SMALLINT,
        CurrencyCode          NVARCHAR(50),
        Creator               INT,
        Hdp1                  SMALLMONEY,
        Hdp2                  SMALLMONEY,
        IsLiveIndicator       BIT,
        IsSecondAcceptFlag    BIT,
        LiveAwayScore         SMALLINT,
        LiveHomeScore         SMALLINT,
        Odds                  SMALLMONEY,
        Oddsspread            MONEY,
        IsMixParlay           BIT DEFAULT(0),
        OddsType              INT,
        RefNo                 BIGINT,
		Status                NVARCHAR(10),
        TransDate             DATETIME,
        TransDesc             NVARCHAR(1000),
        TransId               BIGINT,
        UserName              VARCHAR(30),
        NetWinLost            MONEY,
        srecommend            INT,
        GroupName             VARCHAR(100),
        betdaqid              BIGINT,
        ExtraInfo             VARCHAR(1000),
        IsCashOut			  BIT DEFAULT(0),
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
        SubOdds               SMALLMONEY,
        SubStatus             NVARCHAR(10),
		ActualStake			  MONEY,
		IsMarked			  BIT DEFAULT(0),
		IsDeposit			  BIT DEFAULT(0), --1: Deposit/ 0: Credit
        modds                 SMALLMONEY,
		SiteDBGroupID		  SMALLINT
   );
				
	DECLARE @t_LicenseeNames TABLE(LicenseeName VARCHAR(100), GroupName VARCHAR(100))	
	DECLARE @t_UIRepresentativeLicenseeGroupNames TABLE (GroupName VARCHAR(100))	
	
	DECLARE @t_exchanges TABLE(exchangeid INT, currency NVARCHAR(50))
	
	--> Parse @LicenseeNames
	INSERT INTO @t_LicenseeNames(LicenseeName, GroupName)
	SELECT ss.value AS LicenseeName, ss.value AS GroupName
	FROM STRING_SPLIT(@LicenseeNames, ',') ss
	
	-- Replace all UI representative groups (MBCGroup and 789y) by their real credit licensees
	DELETE FROM @t_LicenseeNames 
	OUTPUT DELETED.GroupName 
			INTO @t_UIRepresentativeLicenseeGroupNames(GroupName)
	WHERE LicenseeName IN (@MBCGroup_Name, @789y_Name, @cn88_Name, @777_Name)
	
	IF @@ROWCOUNT > 0
	BEGIN
		;WITH CTE_CreditSite AS
		(
			SELECT [site], ISNULL(SiteLabel,'') AS SiteLabel
			FROM CustDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0		  
			  AND isActive = 1
		)
		INSERT INTO @t_LicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM @t_UIRepresentativeLicenseeGroupNames AS t
			 CROSS APPLY (
							SELECT cte.[site]
							FROM CTE_CreditSite cte
							WHERE 1 = CASE
										  WHEN t.GroupName = @MBCGroup_Name AND cte.[site] NOT IN (@cn88_Name) AND cte.SiteLabel NOT IN (@789y_Name, @777_Name) THEN 1
										  WHEN t.GroupName = @789y_Name AND cte.SiteLabel = @789y_Name THEN 1
										  WHEN t.GroupName = @cn88_Name AND cte.[site] IN (@cn88_Name) THEN 1 
										  WHEN t.GroupName = @777_Name AND cte.SiteLabel = @777_Name THEN 1
										  ELSE 0 
									  END
						 ) AS cte
	END					 				  			   	  	  			  
	
	--> Parse @CurrencyIDs
	INSERT INTO @t_exchanges(exchangeid, currency)
	SELECT e.exchangeid, e.currency
	FROM STRING_SPLIT(@CurrencyIDs, ',') ss
		 INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK)
				 ON CAST(ss.value AS INT) = e.exchangeid				 			 				 
	
	SELECT @SearchSingle = 0, @SearchParlay = 0, @SearchBetBuilder = 0
	IF @TicketType = 'All'	
		SELECT @SearchSingle = 1, @SearchParlay = 1, @SearchBetBuilder = 1
	ELSE IF @TicketType = 'SingleTicket'
		SET @SearchSingle = 1
	ELSE IF @TicketType = 'ParlayTicket'
		SELECT @SearchParlay = 1, @SearchBetBuilder = 1
	
	--> single, BB
	IF @SearchSingle = 1 OR @SearchBetBuilder = 1
	BEGIN
		INSERT INTO #SpecialDeleteBets(
					GroupID,
					Stake,
					BetCheck,
					BetId,
					BetTeam,
					BetType,
					CurrencyCode,
					Creator,
					Hdp1,
					Hdp2,
					IsLiveIndicator,
					IsSecondAcceptFlag,
					LiveAwayScore,
					LiveHomeScore,
					Odds,
					Oddsspread,
					IsMixParlay,
					OddsType,
					RefNo,
					Status,
					TransDate,
					TransDesc,
					TransId,
					UserName,
					NetWinLost,
					srecommend,
					GroupName,
					betdaqid,
					ExtraInfo,
					IsCashOut,
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
					ActualStake,
					modds,
					SiteDBGroupID
				)
		SELECT 	b.transid AS GroupID,
				b.Stake,
				b.BetCheck,
				b.BetId,
				b.BetTeam,
				b.BetType,
				te.currency AS CurrencyCode,
				b.Creator,
				b.Hdp1,
				b.Hdp2,
				b.LiveIndicator AS IsLiveIndicator,
				b.SecAcceptFlag AS IsSecondAcceptFlag,
				b.LiveAwayScore,
				b.LiveHomeScore,
				b.Odds,
				b.Oddsspread,
				0 AS IsMixParlay,
				b.OddsType,
				b.RefNo,
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
				b.ExtraInfo,
				CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut,
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
				b.actual_stake AS ActualStake,
				b.modds,
				b.SiteDBGroupID
		FROM bettrans b WITH (NOLOCK)
			 INNER JOIN @t_exchanges te
					 ON b.currency = te.exchangeid -- filter for @CurrencyCodes			 
			 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
					 ON b.recommend = c.custid
			 INNER JOIN @t_LicenseeNames tl
					 ON tl.LicenseeName = c.site -- filter for @LicenseeIDs	
		WHERE b.matchid IN (SELECT MatchId FROM @tmpMatchId)
			AND b.bettype = CASE 
								WHEN @SearchSingle = 1 AND b.bettype <> 38 THEN b.bettype
								WHEN @SearchBetBuilder = 1 THEN 38
							END
			AND b.bettype NOT BETWEEN 801 AND 806-- MG
			AND b.bettype NOT IN (500) -- exclude charge comm
			AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND b.betfrom <> 'P' -- exclude phone betting			
			AND b.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
			AND b.custid NOT IN (50057,103873,879241,78761,851668,878902) -- For Special bets: betdaq
			AND b.recommend NOT IN (11196380, 13423967) -- Foobet (Email to IT support, Foobet list), OneExchange (Email to IT support)			
			AND b.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)
			AND b.SiteDBGroupID = @SiteDBGroupID
	END
	
	--> parlay
	IF @SearchParlay = 1	
	BEGIN
		INSERT INTO #SpecialDeleteBets(
				Stake,					
				BetCheck,
				BetId,
				BetTeam,
				BetType,
				CurrencyCode,
				Creator,					
				Hdp1,
				Hdp2,
				IsLiveIndicator,
				IsSecondAcceptFlag,
				LiveAwayScore,
				LiveHomeScore,
				Odds,
				oddsspread,
				IsMixParlay,
				OddsType,
				RefNo,
				Status,
				TransDate,
				TransDesc,
				TransId,
				UserName,
				NetWinLost,
				srecommend,
				GroupName,
				betdaqid,
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
				modds,
				SiteDBGroupID
			)
		SELECT  main.Stake,
				main.BetCheck,
				main.BetId,
				main.BetTeam,
				main.BetType,
				te.currency AS CurrencyCode,
				main.Creator,				
				main.Hdp1,
				main.Hdp2,
				sub.LiveIndicator AS IsLiveIndicator,
				main.SecAcceptFlag AS IsSecondAcceptFlag,
				sub.LiveAwayScore,
				sub.LiveHomeScore,
				main.Odds,
				main.oddsspread,
				1 AS IsMixParlay,
				main.OddsType,
				main.RefNo,
				main.STATUS,
				main.transdate AS TransDate,
				sub.transdesc AS TransDesc,
				main.transid AS TransId,
				main.UserName,
				main.winlost - main.actual_stake AS NetWinLost,
				main.srecommend,				
				tl1.GroupName AS GroupName,
				main.betdaqid,
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
				main.modds,
				main.SiteDBGroupID
		FROM	dbo.bettransm sub WITH (NOLOCK)	
			 INNER HASH JOIN bettrans main WITH (NOLOCK)
					 ON main.refno = sub.refno
			 INNER JOIN @t_exchanges te
					 ON main.currency = te.exchangeid  -- filter for @CurrencyCodes
			 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
					 ON main.recommend = c.custid
			 INNER JOIN @t_LicenseeNames tl1
					 ON tl1.LicenseeName = c.site -- filter for @LicenseeIDs	
		WHERE main.matchid IN (9, 29) AND main.bettype IN (9, 29) -- parlay
			AND main.statusID NOT IN (101, 102) -- reject, void			
			AND main.betfrom <> 'P' -- exclude phone betting
			AND sub.matchid IN (SELECT MatchId FROM @tmpMatchId)
			AND sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND sub.betfrom <> 'P' -- exclude phone betting		
			AND main.username <> '12EU' --  12EU (Credit, email to IT support, 12EU list)
			AND main.recommend NOT IN (11196380) -- Foobet (Email to IT support, Foobet list)
			AND main.recommend NOT IN (13423967) -- OneExchange (Email to IT support)
			AND main.custid NOT IN (50057,103873,879241,78761,851668,878902) -- For Special bets: betdaq
			AND main.mrecommend NOT IN (105181, 118473, 105183) -- For member of master: MHCEU (105181), MHCRM (118473), MHCUS(105183)
			AND main.SiteDBGroupID = @SiteDBGroupID
	END

	UPDATE s
		SET  IsMarked = 1
	FROM	#SpecialDeleteBets s
		INNER JOIN dbo.MarkedTransaction m WITH(NOLOCK)
			ON m.TransId = s.GroupID

	-- update Isdeposit
	UPDATE al SET IsDeposit = 1
	FROM #SpecialDeleteBets al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)

	SELECT 
		s.Stake,
		@AwayId AS AwayId,
		s.BetCheck,
		s.BetId,
		s.BetTeam,
		s.BetType,
		s.CurrencyCode,		
		s.Hdp1,
		s.Hdp2,
		@HomeId AS HomeId,
		s.IsLiveIndicator,
		@IsNeutral AS IsNeutral,
		s.IsSecondAcceptFlag,
		s.LiveAwayScore,
		s.LiveHomeScore,
		s.Odds,
		s.oddsspread,
		s.IsMixParlay,
		CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket,
		s.OddsType,
		s.RefNo,
		@SportType AS SportType, 
		s.Status,
		s.TransDate,
		s.TransDesc,
		s.TransId,
		s.UserName,
		s.NetWinLost AS WinLost,			
		s.GroupName,
		s.betdaqid,
		s.ExtraInfo,
		s.IsCashOut,
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
		s.IsMarked,
		@GlobalShowTime AS GlobalShowTime,
		s.ActualStake,
		s.modds AS MasterOdds,
		s.SiteDBGroupID,
		s.IsDeposit
	FROM #SpecialDeleteBets s	
	ORDER BY CASE
				WHEN s.GroupName = @cn88_Name THEN 1
				WHEN s.GroupName = @789y_Name THEN 2
				WHEN s.GroupName = @MBCGroup_Name THEN 3
				WHEN s.GroupName = @777_Name THEN 4
				ELSE 5
		     END ASC
		   , s.GroupName ASC
		   , s.IsMixParlay ASC
		   , ISNULL(s.MainTransId, s.transid) ASC									 
		   , CASE WHEN s.BonusID IS NOT NULL THEN CASE WHEN s.MainTransId IS NULL THEN 1 ELSE 2 END ELSE s.transid END							 
	
	DROP TABLE #SpecialDeleteBets

	SET NOCOUNT OFF
END
GO
			