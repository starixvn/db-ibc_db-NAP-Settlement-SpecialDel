/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTicket_Select]
( 
	@VoidingHistoryIds VARCHAR(MAX) =''
	,@MatchId   INT = 0
)
AS;
/*	Created by: 20181212@Kathy
	Task: get voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20191118@Max: AdnormalBet TVS + Hotfix #124160 [Redmine:#123691]
		- 20200909@Max: HotFix - TVS - Danger Accept - void single when sub parlay process No. of ticket can not show ticket single [Redmine: #141124]
		- 20201127@Charles: God of fortune [Redmine: #146053]
		- 20201216@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210201@July: TVS - Archive process for Abnormal Account [Redmine: #149776]
		- 20210601@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20211117@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211210@July: Remove code CashOut [Redmine: #165097]
		- 20220820@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221201@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #TmpMatch (Matchid INT, SettlementStatus TINYINT, IsOutright BIT)
	DECLARE @tmpVoidingHistory TABLE (VoidingHistoryId INT)
	DECLARE @tmpChildMatchCricket TABLE (
		MatchId			INT
		,ChildMatchId			INT
	)

	CREATE TABLE #tmpTicket
             (TransId         BIGINT,
              matchid         INT,
              custid          INT,
              TransDate       DATETIME,
              Stake           MONEY,
              Status          NVARCHAR(10),
              Betcheck        NVARCHAR(50),
              betdaqid        BIGINT,
              betid           BIGINT,
              betfrom         NVARCHAR(3),
              Betteam         NVARCHAR(10),
              Bettype         SMALLINT,
              Currency        TINYINT,
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
              IsDeposit       BIT DEFAULT(0),
              srecommend      INT,
              mrecommend      INT,
              recommend       INT,
              IsMixParlay     BIT DEFAULT(0),
              subbetcheck     NVARCHAR(50),
              subOdds         SMALLMONEY,
              subbetteam      NVARCHAR(10),
              subbettype      SMALLINT,
              subhdp1         SMALLINT,
              subhdp2         SMALLINT,
              subtransdesc    NVARCHAR(1000),
              Refno           BIGINT,
              subTransId      BIGINT,
              VoidedTime      DATETIME,
              isITAdmin       BIT,
              IsCashOut       BIT DEFAULT(0),
              MainTransId     BIGINT,
              BonusId         INT,
              IsMarked        BIT,
			  LiveIndicator   BIT,
			  ActualStake	  MONEY,
			  oddsid		  INT,
			  winlostdate	  DATETIME,
			  IsCancelCashOut BIT
             );

	CREATE CLUSTERED INDEX CIX_tmpTicket_transId ON #tmpTicket (TransId)

	INSERT INTO @tmpVoidingHistory(VoidingHistoryId) 
	SELECT CAST(value AS INT)
	FROM STRING_SPLIT(@VoidingHistoryIds, ',')
	WHERE value <> ''

	-- single ticket
	INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, winlost, Refno, Bettype, Odds, oddsid, winlostdate, IsCancelCashOut)
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
			,CASE WHEN z.comstatus = 'CO' THEN 1 ELSE 0 END AS IsCancelCashOut
	FROM	@tmpVoidingHistory vh 
		INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON z.VoidingHistoryId = vh.VoidingHistoryId
	WHERE (z.MatchId = @MatchId OR @MatchId = 0)
		AND z.SiteDBGroupID = @SiteDBGroupID
		
	-- parlay ticket
	INSERT INTO #tmpTicket (subTransId, matchid, Refno, Status, VoidedTime, custid, IsMixParlay, oddsid, winlostdate)
	SELECT	zm.transid		
			,zm.matchid
			,zm.refno
			,zm.status
			,zm.transdate AS VoidedTime
			,zm.custid
			,1 AS IsMixParlay
			,zm.oddsid
			,zm.winlostdate
	FROM	@tmpVoidingHistory vh
		INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK) ON zm.VoidingHistoryId = vh.VoidingHistoryId 
	WHERE (zm.MatchId = @MatchId OR @MatchId = 0)
		AND zm.SiteDBGroupID = @SiteDBGroupID

	--Child match cricket
	IF EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH (NOLOCK) WHERE m.ParentID = @MatchId AND m.sporttype = 50)
	BEGIN
		INSERT INTO @tmpChildMatchCricket (MatchId, ChildMatchId)
		SELECT @MatchId, m.matchid
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.ParentID = @MatchId
			AND m.sporttype = 50 
			AND m.ChildMatchType = 200
	END

	IF EXISTS (SELECT TOP 1 1 FROM @tmpChildMatchCricket)
	BEGIN
		INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, winlost, Refno, Bettype, Odds, oddsid, winlostdate)
		SELECT	z.transid			
				,z.matchid
				,z.status
				,z.VoidedTime
				,z.custid
				,z.winlost
				,z.refno
				,z.bettype
				,z.odds
				,z.oddsid
				,z.winlostdate
		FROM	@tmpChildMatchCricket cm 
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
				FROM dbo.zzzbettrans z WITH(NOLOCK)
					INNER JOIN @tmpVoidingHistory vh ON vh.VoidingHistoryId = z.VoidingHistoryId
				WHERE (z.MatchId = cm.ChildMatchId OR @MatchId = 0)
					AND z.SiteDBGroupID = @SiteDBGroupID
			) z
	END

	INSERT INTO #TmpMatch (Matchid, SettlementStatus, IsOutright)
	SELECT DISTINCT t.MatchId, m.SettlementStatus, CASE WHEN t.Bettype = 10 THEN 1 ELSE 0 END
	FROM #tmpTicket t
		LEFT JOIN dbo.match m WITH(NOLOCK) ON t.MatchId = m.matchid

	--@IsMovebet = 0
	IF  EXISTS ( SELECT TOP 1 1 FROM #TmpMatch 
				 WHERE (SettlementStatus IS NOT NULL 
						OR (SettlementStatus IS NULL AND matchid IN (9,29,2799))
						OR (SettlementStatus IS NULL AND IsOutright = 1))
			)
	BEGIN
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
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.TransId = b.transid AND b.SiteDBGroupID = @SiteDBGroupID

		UPDATE	t
			SET transid = b.transid
				,Betcheck = b.betcheck
				,betdaqid = b.betdaqid
				,betid = b.betid
				,betteam = b.betteam
				,bettype = b.bettype
				,ExtraInfo = b.ExtraInfo
				,hdp1 = b.hdp1
				,hdp2 = b.hdp2
				,liveawayscore = bm.liveawayscore
				,livehomescore = bm.livehomescore
				,odds = b.odds
				,oddsspread = b.oddsspread
				,oddstype = b.oddstype
				,RefCode = b.RefCode
				,stake = b.stake
				,Status = b.status
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
				,winlost = b.winlost - b.actual_stake
				,subbetcheck = bm.betcheck
				,subOdds = bm.odds
				,subbetteam = bm.betteam
				,subbettype = bm.bettype
				,subhdp1 = bm.hdp1
				,subhdp2 = bm.hdp2
				,subtransdesc = bm.transdesc
				,LiveIndicator = bm.liveindicator
				,ActualStake = b.actual_stake
				,subTransId = bm.transid
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK) ON t.subTransId = bm.transid AND bm.SiteDBGroupID = @SiteDBGroupID
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.SiteDBGroupID = @SiteDBGroupID
	END

	--@IsMovebet = 1
	IF  EXISTS ( SELECT TOP 1 1 FROM #TmpMatch WHERE SettlementStatus IS NULL )
	BEGIN
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
				,subTransId = t.TransId
				,IsCashOut = CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON t.TransId = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
		
		UPDATE	t
			SET transid = b.transid
				,Betcheck = b.betcheck
				,betdaqid = b.betdaqid
				,betid = b.betid
				,betteam = b.betteam
				,bettype = b.bettype
				,ExtraInfo = b.ExtraInfo
				,hdp1 = b.hdp1
				,hdp2 = b.hdp2
				,liveawayscore = bm.liveawayscore
				,livehomescore = bm.livehomescore
				,odds = b.odds
				,oddsspread = b.oddsspread
				,oddstype = b.oddstype
				,RefCode = b.RefCode
				,stake = b.stake
				,Status = b.status
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
				,winlost = b.winlost - b.actual_stake
				,subbetcheck = bm.betcheck
				,subOdds = bm.odds
				,subbetteam = bm.betteam
				,subbettype = bm.bettype
				,subhdp1 = bm.hdp1
				,subhdp2 = bm.hdp2
				,subtransdesc = bm.transdesc
				,LiveIndicator = bm.liveindicator
				,ActualStake = b.actual_stake
				,subTransId = bm.transid
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm14 bm WITH(NOLOCK) ON	t.subTransId = bm.transid AND bm.SiteDBGroupID = @SiteDBGroupID
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29 AND b.SiteDBGroupID = @SiteDBGroupID

		IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket WHERE TransId IS NULL AND IsMixParlay = 1)
		BEGIN
			UPDATE	t
				SET transid = b.transid
					,Betcheck = b.betcheck
					,betdaqid = b.betdaqid
					,betid = b.betid
					,betteam = b.betteam
					,bettype = b.bettype
					,ExtraInfo = b.ExtraInfo
					,hdp1 = b.hdp1
					,hdp2 = b.hdp2
					,liveawayscore = bm.liveawayscore
					,livehomescore = bm.livehomescore
					,odds = b.odds
					,oddsspread = b.oddsspread
					,oddstype = b.oddstype
					,RefCode = b.RefCode
					,stake = b.stake
					,Status = b.status
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
					,winlost = b.winlost - b.actual_stake
					,subbetcheck = bm.betcheck
					,subOdds = bm.odds
					,subbetteam = bm.betteam
					,subbettype = bm.bettype
					,subhdp1 = bm.hdp1
					,subhdp2 = bm.hdp2
					,subtransdesc = bm.transdesc
					,LiveIndicator = bm.liveindicator
					,ActualStake = b.actual_stake
					,subTransId = t.subTransId
			FROM	#tmpTicket t
				INNER LOOP JOIN dbo.bettransm14 bm WITH(NOLOCK) ON	t.subTransId = bm.transid AND bm.SiteDBGroupID = @SiteDBGroupID
				INNER HASH JOIN dbo.bettrans14 b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29 AND b.SiteDBGroupID = @SiteDBGroupID
		END

	END

	-- UPDATE IsMixParlay
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (9, 29, 2799)))
	BEGIN
		UPDATE t
			SET IsMixParlay = 1
		FROM #tmpTicket t
		WHERE t.bettype IN (9, 29, 2799)
	END

	-- Update IsMarked
	UPDATE t
	SET t.IsMarked = CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END 
	FROM #tmpTicket  t
	LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON t.transid = m.TransId		

	-- update Isdeposit
	UPDATE al SET IsDeposit = 1
	FROM	#tmpTicket al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)
	
	;WITH CTE_OriginResult AS (
		--1. For Credit	 
		SELECT 
			   s.transid
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.VoidedTime
			   ,s.creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
			   ,s.IsMixParlay
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,CASE WHEN c.site = 'CN88' THEN 'CN88'
					 ELSE CASE WHEN s.betdaqid = -2 AND s.IsCancelCashOut <> 1 THEN 'Credit (CO)'
							   WHEN ISNULL(s.betdaqid,0) <> -2 AND s.IsCancelCashOut = 1 THEN 'Credit (Cancel CO)' --betdaqid = -1
							   ELSE 'Credit' END
					END AS GroupName
			   ,s.WalletType	
			   ,s.RefCode
			   ,s.IsCashOut
			   ,s.winlost
			   ,s.MainTransId
			   ,s.BonusId
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.subbettype
			   ,s.subtransdesc
			   ,s.ActualStake
			   ,s.matchid
			   ,s.winlostdate
			   ,s.IsCancelCashOut
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
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.VoidedTime
			   ,s.creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
			   ,s.IsMixParlay
			   ,b.transid AS followedId
			   ,b.Username AS followedUsername
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
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.subbettype
			   ,s.subtransdesc
			   ,s.ActualStake
			   ,s.matchid
			   ,s.winlostdate
			   ,s.IsCancelCashOut
		FROM	#tmpTicket s 
			LEFT JOIN dbo.bettrans b WITH(NOLOCK) ON s.betid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
		WHERE	s.recommend IN (52466, 5707545)
		UNION
		--3. For Deposit
		SELECT  
				s.transid
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.VoidedTime
			   ,s.creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
			   ,s.IsMixParlay
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,CASE WHEN s.betdaqid = -2 AND s.IsCancelCashOut <> 1 THEN 'Deposit (CO)' 
					 WHEN ISNULL(s.betdaqid,0) <> -2 AND s.IsCancelCashOut = 1 THEN 'Deposit (Cancel CO)' 
					 ELSE 'Deposit' END AS GroupName
			   ,s.WalletType	
			   ,s.RefCode
			   ,s.IsCashOut
			   ,s.winlost
			   ,s.MainTransId
			   ,s.BonusId
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.subbettype
			   ,s.subtransdesc
			   ,s.ActualStake
			   ,s.matchid
			   ,s.winlostdate
			   ,s.IsCancelCashOut
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
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.VoidedTime
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.STATUS
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.Subhdp1
		   ,s.Subhdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.SubBetcheck
		   ,s.IsMixParlay
		   ,NULL AS followedId
		   ,NULL AS followedUsername
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
		   ,s.IsMarked
		   ,s.recommend
		   ,s.LiveIndicator
		   ,s.subbettype
		   ,s.subtransdesc
		   ,s.ActualStake
		   ,s.matchid
		   ,s.winlostdate
		   ,s.IsCancelCashOut
		FROM	#tmpTicket s
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	)

	SELECT  s.transid
		   ,s.MainTransId
		   ,s.BonusId
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.VoidedTime
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.STATUS
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.Subhdp1
		   ,s.Subhdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.SubBetcheck
		   ,s.IsMixParlay
		   ,s.followedId
		   ,s.followedUsername
		   ,s.Transdesc
		   ,s.IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.GroupName
		   ,s.WalletType
		   ,s.RefCode
		   ,s.IsCashOut
		   ,m.SettlementStatus AS SettlementStatus
		   ,cr.username AS Creator
		   ,s.winlost
		   ,s.IsMarked
		   ,c.site as LicenseeName
		   ,s.LiveIndicator AS IsLiveIndicator
		   ,s.subbettype AS SubBettype
		   ,s.subtransdesc AS subTransdesc
		   ,s.ActualStake
		   ,s.matchid
		   ,s.winlostdate
		   ,ISNULL(s.IsCancelCashOut,0) AS IsCancelCashOut
	FROM CTE_OriginResult s
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK) ON s.creator = cr.custid
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
		INNER JOIN #TmpMatch m ON s.matchid = m.Matchid
	ORDER BY CASE
				WHEN s.GroupName = 'CN88' THEN 1
				WHEN s.GroupName = 'Credit' THEN 2
				WHEN s.GroupName = '8RM/BARM' THEN 3
				WHEN s.GroupName = 'Deposit' THEN 4
				WHEN s.GroupName = 'Betfair' THEN 5
				WHEN s.GroupName = 'Credit (CO)' THEN 6
				WHEN s.GroupName = 'Deposit (CO)' THEN 7
				WHEN s.GroupName = 'Credit (Cancel CO)' THEN 8
				WHEN s.GroupName = 'Deposit (Cancel CO)' THEN 9
			 END
		   , ISNULL(s.MainTransId, s.transid)
		   , CASE 
				WHEN s.BonusID IS NOT NULL
						THEN CASE 
								WHEN s.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE s.transid
			 END

	DROP TABLE #tmpTicket
	DROP TABLE #TmpMatch
	
END
GO
