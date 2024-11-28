/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_UnMarkedTickets_BetIds_Select]
	@TransIds				VARCHAR(MAX)	= NULL
AS
/*
    Created by: 20190325@Alan
	Task: Mark Ticket for Settlement Exclusion
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190520@Raymond.Le: Mark Tickets - Not allow to mark Waiting [113518]
		- 20200115@Max: Mark & Unmark tickets for Othersports [Redmine: #127035]
		- 20200225@Charles: Mark & Unmark tickets for Esport, Badminton and Tennis [129139]
		- 20200417@Charles: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210225@July: HotFix - Mark/unmark can not search CO by bet ID [Redmine: #150621]
		- 20210302@Max: TVS - Integrate Cricket AIO [Redmine: #150075] 
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]
		- 20240123@July: Separate group to view data of 777 site [Redmine: #198089]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240527@July: [TVS] Scaleout DBCUST [Redmine: #205629]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241125@Lani: [TVS] Change join type on 'recommend' and 'custid' columns [Redmine: #213451]

	Explanation's Param:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @InvalidTransIds	VARCHAR(MAX)	= ''
		   ,@MovedTransIds		VARCHAR(MAX)	= ''
	       ,@MarkedTransIds		VARCHAR(MAX)	= '' 
	       ,@SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes()) -- Outright, Mix Parlay,Bet Builder
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
		AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND pt.bettype NOT BETWEEN 1501 AND 1599	-- NOT IN Keno

	CREATE TABLE #Tickets
             (GroupID               BIGINT,
              transid               BIGINT,
              custid                INT,
              username              VARCHAR(50),
              oddsspread            MONEY,
              odds                  SMALLMONEY,
              modds					SMALLMONEY,
			  OddsType              INT,
              transdate             DATETIME,
              bettype               SMALLINT,
              betteam               NVARCHAR(10),
              betcheck              NVARCHAR(50),
              hdp1                  SMALLMONEY,
              hdp2                  SMALLMONEY,
              IsLiveIndicator       BIT,
              livehomescore         SMALLINT,
              liveawayscore         SMALLINT,
              Stake                 MONEY,
              CurrencyName          VARCHAR(10),
              IsDeposit             BIT DEFAULT(0),
              status                NVARCHAR(10),
              srecommend            INT,
              recommend             INT,
              SecAcceptFlag         BIT,
              betid                 BIGINT,
              betdaqid              BIGINT,
              TransDesc             NVARCHAR(1000),
              refno                 BIGINT,
              ExtraInfo             VARCHAR(1000),
              matchid               INT,
              WalletType            TINYINT,
              RefCode               BIGINT,
              BonusID               INT,
              MainTransId           BIGINT,
              WinLost               MONEY,
              SportType             TINYINT,
              HomeId                INT,
              AwayId                INT,
              LeagueId              INT,
              IsNeutral             BIT,
              SettlementStatus      TINYINT,
			  ActualStake			MONEY
             );

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	INSERT INTO #Tickets (
			GroupID
			,bettype
			,transid
			,betid
			,refno
			,hdp1
			,hdp2
			,odds
			,modds
			,oddsspread	
			,OddsType
			,STATUS	
			,stake
			,transdate
			,betteam
			,betcheck
			,IsLiveIndicator
			,custid	
			,livehomescore
			,liveawayscore
			,matchid
			,winlost
			,TransDesc
			,betdaqid
			,username
			,srecommend
			,recommend
			,ExtraInfo
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,ActualStake
		)
	SELECT
		b.transid AS GroupId
		,b.bettype
		,b.transid
		,isnull(b.BetID, 0) AS BetID
		,b.refno
		,b.hdp1
		,b.hdp2
		,b.odds
		,b.modds
		,b.oddsspread
		,b.OddsType
		,b.STATUS
		,b.stake
		,b.transdate
		,b.betteam
		,b.betcheck
		,b.liveindicator
		,b.custid
		,b.livehomescore
		,b.liveawayscore
		,b.matchid
		,(b.winlost - b.actual_stake) winlost
		,b.transdesc
		,b.betdaqid
		,b.username
		,b.srecommend
		,b.recommend
		,b.ExtraInfo
		,b.CurrencyName
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,b.actual_stake AS ActualStake
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN #transIdTemp temp ON b.transid = temp.transid
		INNER JOIN @bettype_tmp bt ON b.bettype = bt.bettype
	WHERE (b.statusID = 0 -- running
			AND NOT ( b.SecAcceptFlag = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)) -- not in waiting SecAccept
		AND b.betfrom <> 'p'
		AND b.SiteDBGroupID = @SiteDBGroupID

	UPDATE d
	SET  homeid 	= m.homeid
		,awayid 	= m.awayid
		,leagueid 	= m.leagueid
		,sporttype 	= m.sporttype
		,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
		,SettlementStatus = m.SettlementStatus
	FROM #Tickets d
		INNER JOIN dbo.match m WITH (NOLOCK) ON	d.matchid = m.matchid

	-- delete marked tickets
	DELETE t FROM #Tickets t
	WHERE EXISTS (SELECT TOP (1) 1 
				  FROM dbo.MarkedTransaction m WITH(NOLOCK) 
				  WHERE m.TransId = t.transid)

	--- Remove invalid sporttype	
	DELETE 
	FROM #Tickets
	WHERE (sporttype IS NULL OR bettype = 500 /*charge comm*/)

	UPDATE s
	SET IsDeposit = 1
	FROM #Tickets s
		INNER JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) ON s.srecommend = d.custid

	-- Group Name By Licensee
	BEGIN
		DECLARE @MBCGroup_Name VARCHAR(50) = 'MBC Group'
			  , @789y_Name	   VARCHAR(50) = '789y'
			  , @cn88_Name	   VARCHAR(50) = 'CN88'
			  , @777_Name	   VARCHAR(50) = '777'
			
		CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
		CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)
		CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))

		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT	s.site AS LicenseeName,  s.site AS GroupName 
		FROM CustDB.dbo.site s WITH(NOLOCK)
		WHERE	s.isLicensee = 1 AND s.isActive =1 AND s.siteID NOT IN (29,35)

		INSERT INTO #t_UIRepresentativeLicenseeGroupNames(GroupName)
		VALUES (@MBCGroup_Name), (@789y_Name), (@cn88_Name), (@777_Name)

		;WITH CTE_CreditSite AS
		(
			SELECT [site], ISNULL(SiteLabel,'') AS SiteLabel
			FROM CustDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0 AND isActive = 1
		)
		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM #t_UIRepresentativeLicenseeGroupNames AS t
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
	
	------------------------------------------------------------------------------
	--1. Table invald/moved transid
	;WITH t_invalid AS
	(
		SELECT	transid
				,ISNULL(bm.isMoved, CAST(0 AS BIT)) AS isMoved
				,ISNULL(m.isMarked, CAST(0 AS BIT)) AS isMarked
		FROM #transIdTemp temp
			OUTER APPLY (
				SELECT TOP (1) CAST(1 AS BIT) AS isMoved
				FROM dbo.bettrans14 WITH(NOLOCK) 
				WHERE transid = temp.transid AND SiteDBGroupID = @SiteDBGroupID
			) bm
			OUTER APPLY (
				SELECT TOP (1) CAST(1 AS BIT) AS isMarked
				FROM dbo.MarkedTransaction m WITH(NOLOCK) 
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON m.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
				WHERE m.transid = temp.transid AND b.bettype NOT IN (9, 29)
			) m
		WHERE NOT EXISTS (SELECT 1 FROM #Tickets WHERE transid = temp.transid OR refno = temp.transid)
	)
	SELECT @InvalidTransIds = @InvalidTransIds + CASE WHEN isMoved = 0 AND isMarked = 0
							  THEN CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + CAST(transid AS VARCHAR(50))
							  ELSE '' END
		 , @MovedTransIds = @MovedTransIds + CASE WHEN isMoved = 1
							THEN CASE WHEN @MovedTransIds <> '' THEN ',' ELSE '' END + CAST(transid AS VARCHAR(50))
							ELSE '' END
		 , @MarkedTransIds = @MarkedTransIds + CASE WHEN isMarked = 1
							THEN CASE WHEN @MarkedTransIds <> '' THEN ',' ELSE '' END + CAST(transid AS VARCHAR(50))
							ELSE '' END
		FROM t_invalid

	SELECT @InvalidTransIds AS InvalidTransIds
	      ,@MovedTransIds AS MovedTransIds
		  ,@MarkedTransIds AS MarkedTransIds

	--2. Table get tickets
	SELECT 
		b.Stake,
		b.BetCheck,
		b.BetId,
		b.BetTeam,
		b.BetType,
		b.CurrencyName,		
		b.Hdp1,
		b.Hdp2,
		b.IsLiveIndicator,
		b.LiveAwayScore,
		b.LiveHomeScore,
		b.Odds,
		b.oddsspread,
		b.OddsType,
		b.RefNo,
		b.Status,
		b.TransDate,
		b.TransDesc,
		b.TransId,
		b.UserName,
		b.WinLost,			
		CASE 
		  WHEN b.recommend IN (52466, 5707545) THEN '8RM/BARM' 
		  WHEN b.custid IN(1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
		  ELSE tl.GroupName
		END GroupName,
		b.betdaqid,
		b.ExtraInfo,
		b.WalletType,			
		b.MainTransId,		
		b.RefCode,
		b.homeid,
		b.awayid,
		b.leagueid,
		b.IsNeutral,
		b.sporttype,
		b.SettlementStatus,
		c.site AS LicenseeName,
		b.IsDeposit,
		b.ActualStake,
		b.modds AS MasterOdds,
		@SiteDBGroupID AS SiteDBGroupID
	FROM #Tickets b
		INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
		INNER JOIN #t_LicenseeNames tl WITH (NOLOCK) ON tl.LicenseeName = c.site 
	ORDER BY CASE
				WHEN b.recommend IN (52466, 5707545) THEN 1
				WHEN b.custid IN(1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 2
				WHEN tl.GroupName = @cn88_Name THEN 3
				WHEN tl.GroupName = @789y_Name THEN 4
				WHEN tl.GroupName = @MBCGroup_Name THEN 5
				WHEN tl.GroupName = @777_Name THEN 6
				ELSE 7
		     END ASC
		   , tl.GroupName ASC
		   , ISNULL(b.MainTransId, b.transid) ASC
		   , CASE WHEN b.BonusID IS NOT NULL
				THEN CASE WHEN b.MainTransId IS NULL THEN 1
				ELSE 2 END ELSE b.transid END

	DROP TABLE #Tickets
	DROP TABLE #transIdTemp
	DROP TABLE #t_LicenseeNames
	DROP TABLE #t_UIRepresentativeLicenseeGroupNames

SET NOCOUNT OFF
END
