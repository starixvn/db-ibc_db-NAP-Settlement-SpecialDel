/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTicket14_Select]
( 
	@VoidingHistoryIds VARCHAR(MAX) =''
   ,@OnlineServerId	   VARCHAR(10) = NULL
)
AS;
/*	Created by: 20211126@July
	Task: TVS - Void Archived Tickets [Redmine:#140180]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20211126@July: Create new SP [Redmine:#140180]
		- 20220820@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241126@Lani: [TVS] Change join type on 'recommend' and 'custid' columns [Redmine: #213451]
		- 20250328@Lani: [TVS] Upgrade ExchangeID data type [Redmine: #222191]
		- 20250828@July: [TVS] ScaleOut DBTrans [Phase 7] Manage Request page [Redmine: #236438]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpVoidingHistory TABLE (VoidingHistoryId INT)
	DECLARE @tmpOnlineServerId AS TABLE (ServerId SMALLINT)

	IF ISNULL(@OnlineServerId, '') <> ''
	BEGIN
		INSERT INTO @tmpOnlineServerId (ServerId)
		SELECT value AS ServerId
		FROM STRING_SPLIT(@OnlineServerId, ',')
		WHERE value <> ''
	END

	CREATE TABLE #tmpTicket
             (TransId         BIGINT,
              subTransId      BIGINT,
			  matchid         INT,
              custid          INT,
              TransDate       DATETIME,
              Stake           MONEY,
              Status          NVARCHAR(10),
              Betcheck        NVARCHAR(50),
              betdaqid        BIGINT,
              betid           BIGINT,
              betfrom         NVARCHAR(4),
              Betteam         NVARCHAR(10),
              Bettype         SMALLINT,
              Currency        SMALLINT,
              CurrencyName    NVARCHAR(50),
              Hdp1            SMALLMONEY,
              Hdp2            SMALLMONEY,
              LiveHomeScore   SMALLINT,
              LiveAwayScore   SMALLINT,
              Odds            SMALLMONEY,
              Oddsspread      MONEY,
              oddstype        TINYINT,
              WalletType      TINYINT,
              RefCode         BIGINT,
              ExtraInfo       VARCHAR(1000),
              TransDesc       NVARCHAR(1000),
              winlost         MONEY,
              Username        NVARCHAR(50),
              creator         INT,
              CreatorName     NVARCHAR(50),
              IsDeposit       BIT DEFAULT(0), --1: Deposit/ 0: Credit
              srecommend      INT,
              mrecommend      INT,
              recommend       INT,
              IsMixParlay     BIT DEFAULT(0),
              Refno           BIGINT,
              VoidedTime      DATETIME,
              IsCashOut       BIT DEFAULT(0),
              MainTransId     BIGINT,
              BonusId         INT,
			  LiveIndicator   BIT,
			  ActualStake	  MONEY,
			  VoidingHistoryId INT,
			  homeid          INT,
			  awayid          INT,
		      leagueid        INT,
			  sporttype       SMALLINT,
			  oddsid		  INT,
			  isNeutral       BIT,
			  matchcode		  NVARCHAR(50),
			  showtime        NVARCHAR(50),
			  modds           SMALLMONEY,
			  winlostdate	  DATETIME,
			  SiteDBGroupID	  SMALLINT
             );

	CREATE CLUSTERED INDEX CIX_tmpTicket_transId ON #tmpTicket (TransId)

	INSERT INTO @tmpVoidingHistory(VoidingHistoryId) 
	SELECT CAST(value AS INT)
	FROM STRING_SPLIT(@VoidingHistoryIds, ',')
	WHERE value <> ''

	-- single ticket
	INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, winlost, Refno, Bettype, Odds, VoidingHistoryId, oddsid, winlostdate, SiteDBGroupID)
	SELECT	z.transid			
			,z.matchid
			,z.status
			,z.VoidedTime
			,z.custid
			,z.winlost
			,z.refno
			,z.bettype
			,z.odds
			,vh.VoidingHistoryId
			,z.oddsid
			,z.winlostdate
			,z.SiteDBGroupID
	FROM	@tmpVoidingHistory vh 
		CROSS APPLY (
			SELECT	z.transid
					,z.matchid
					,z.status
					,z.transdate AS VoidedTime
					,z.custid
					,z.winlost
					,z.refno
					,z.bettype
					,z.odds
					,z.oddsid
					,z.winlostdate
					,z.SiteDBGroupID
			FROM	dbo.zzzbettrans z WITH(NOLOCK)
			WHERE	z.VoidingHistoryId = vh.VoidingHistoryId
				AND 1 = CASE WHEN z.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1
							 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
							 ELSE 0 END
		) z
		
	UPDATE t 
		SET Betcheck = b.betcheck
			,betdaqid = b.betdaqid
			,betid = b.betid
			,betteam = b.betteam
			,bettype = b.bettype
			,ExtraInfo = b.ExtraInfo
			,hdp1 = b.hdp1
			,hdp2 = b.hdp2
			,liveawayscore = b.liveawayscore
			,livehomescore = b.livehomescore
			,oddsspread = b.oddsspread
			,oddstype = b.oddstype
			,RefCode = b.RefCode
			,stake = b.stake
			,transdesc = b.transdesc
			,Username = b.Username
			,WalletType = b.WalletType
			,CurrencyName = b.CurrencyName
			,betfrom = b.betfrom
			,transdate = b.transdate
			,creator = b.creator
			,srecommend = b.srecommend
			,mrecommend = b.mrecommend
			,recommend = b.recommend
			,winlost = t.winlost - b.actual_stake
			,BonusID = b.BonusId
			,LiveIndicator = b.liveindicator
			,ActualStake = b.actual_stake
			,subTransId = b.transid
			,IsCashOut = CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END
			,modds = b.modds
	FROM	#tmpTicket t
		INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON t.TransId = b.transid AND b.SiteDBGroupID = t.SiteDBGroupID

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE t
		SET  matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
		FROM #tmpTicket t
			INNER JOIN dbo.match14 m WITH (NOLOCK) 
			ON	t.matchid = m.matchid
		WHERE t.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (10)))
	BEGIN
		UPDATE t
		SET  matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
		FROM #tmpTicket t
			INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) 
			ON	t.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE t.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE t
			SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= r.leagueid
				,sporttype 	= r.sporttype
				,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
		FROM #tmpTicket t
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
			ON t.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE t.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE IsMixParlay
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE t
		SET IsMixParlay = 1
		FROM #tmpTicket t
		WHERE t.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END

	-- update Isdeposit
	UPDATE al SET IsDeposit = 1
	FROM	#tmpTicket al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)
	
	;WITH CTE_OriginResult AS (
		--1. For Credit	 
		SELECT 
			   s.transid
			   ,s.subTransId
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.VoidedTime
			   ,s.creator
			   ,s.Stake
			   ,s.odds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.currencyname
			   ,s.betteam
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.IsMixParlay
			   ,s.Transdesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,CASE WHEN c.site = 'CN88' THEN 'CN88' ELSE 'Credit' END AS GroupName
			   ,s.WalletType	
			   ,s.RefCode
			   ,s.IsCashOut
			   ,s.winlost
			   ,s.MainTransId
			   ,s.BonusId
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.ActualStake
			   ,s.matchid
			   ,s.VoidingHistoryId
			   ,s.homeid
			   ,s.awayid
			   ,s.leagueid
			   ,s.sporttype
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.modds
			   ,s.IsDeposit
		FROM	#tmpTicket s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f ON s.custid = f.CustID
			LEFT JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = s.custid
		WHERE	f.CustID IS NULL
				AND (s.username <> '12EU')
				AND s.IsDeposit = 0
				AND s.mrecommend NOT IN (105181, 118473, 105183) -- MHC
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				AND s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)  -- Betfair: BFOS, BF, ITibc102, BF3
		UNION
		--2. For 8RM
		SELECT  
				s.transid
			   ,s.subTransId
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.VoidedTime
			   ,s.creator
			   ,s.Stake
			   ,s.odds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.currencyname
			   ,s.betteam
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.IsMixParlay
			   ,s.Transdesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,'8RM/BARM' AS GroupName
			   ,s.WalletType
			   ,s.RefCode
			   ,s.IsCashOut
			   ,s.winlost
			   ,s.MainTransId
			   ,s.BonusId
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.ActualStake
			   ,s.matchid
			   ,s.VoidingHistoryId
			   ,s.homeid
			   ,s.awayid
			   ,s.leagueid
			   ,s.sporttype
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.modds
		       ,s.IsDeposit
		FROM	#tmpTicket s 
			LEFT JOIN dbo.bettrans14 b WITH(NOLOCK) ON	s.betid = b.transid AND b.SiteDBGroupID = s.SiteDBGroupID
		WHERE	s.recommend IN (52466, 5707545)
		UNION
		--3. For Deposit
		SELECT  
				s.transid
			   ,s.subTransId
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.VoidedTime
			   ,s.creator
			   ,s.Stake
			   ,s.odds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.currencyname
			   ,s.betteam
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.IsMixParlay
			   ,s.Transdesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,'Deposit' AS GroupName
			   ,s.WalletType	
			   ,s.RefCode
			   ,s.IsCashOut
			   ,s.winlost
			   ,s.MainTransId
			   ,s.BonusId
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.ActualStake
			   ,s.matchid
			   ,s.VoidingHistoryId
			   ,s.homeid
			   ,s.awayid
			   ,s.leagueid
			   ,s.sporttype
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.modds
		       ,s.IsDeposit
		FROM	#tmpTicket s 
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f ON s.custid = f.CustID
		WHERE	f.CustID IS NULL -- Betdaq
				AND (s.username <> '12EU')
				AND s.IsDeposit = 1
				AND s.mrecommend NOT IN (105181, 118473, 105183)
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				AND s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3	
		UNION
		--4. For Betfair
		SELECT  
			s.transid
		   ,s.subTransId
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.VoidedTime
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.STATUS
		   ,s.currencyname
		   ,s.betteam
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.IsMixParlay
		   ,s.Transdesc
		   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,'Betfair' AS GroupName
		   ,s.WalletType
		   ,s.RefCode
		   ,s.IsCashOut
		   ,s.winlost
		   ,s.MainTransId
		   ,s.BonusId
		   ,s.recommend
		   ,s.LiveIndicator
		   ,s.ActualStake
		   ,s.matchid
		   ,s.VoidingHistoryId
		   ,s.homeid
		   ,s.awayid
		   ,s.leagueid
		   ,s.sporttype
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.modds
		   ,s.IsDeposit
		FROM	#tmpTicket s 
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	)
	SELECT s.transid
			,s.subTransId
			,s.MainTransId
			,s.BonusId
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.VoidedTime
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.STATUS
		   ,s.currencyname
		   ,s.betteam
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.IsMixParlay
		   ,s.Transdesc
		   ,s.IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.GroupName
		   ,s.WalletType
		   ,s.RefCode
		   ,s.IsCashOut
		   ,cr.username AS Creator
		   ,s.IsCashOut
		   ,s.winlost
		   ,c.site as LicenseeName
		   ,s.LiveIndicator AS IsLiveIndicator
		   ,s.ActualStake
		   ,s.matchid
		   ,s.VoidingHistoryId
		   ,s.homeid
		   ,s.awayid
		   ,s.leagueid
		   ,s.sporttype
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.modds AS MasterOdds
	       ,s.IsDeposit
	FROM CTE_OriginResult s
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK) ON s.creator = cr.custid
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.custid = c.custid
	ORDER BY CASE
				WHEN s.GroupName = 'CN88' THEN 1
				WHEN s.GroupName = 'Credit' THEN 2
				WHEN s.GroupName = '8RM/BARM' THEN 3
				WHEN s.GroupName = 'Deposit' THEN 4
				WHEN s.GroupName = 'Betfair' THEN 5
			 END ASC 
		   , ISNULL(s.MainTransId, s.transid) ASC
		   , CASE 
				WHEN s.BonusID IS NOT NULL
						THEN CASE 
								WHEN s.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE s.transid
			 END ASC

	DROP TABLE #tmpTicket
END
GO
