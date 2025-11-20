/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTicket_Select]
( 
	@VoidingHistoryIds 		VARCHAR(MAX) =''
	,@MatchId   			INT = 0
    ,@OnlineServerId	    VARCHAR(10) = NULL
)
AS;
/*	Created by: 20181212@Kathy
	Task: get voided ticket [Redmine:#90155]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
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
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230425@July: [TVS] [TVS] Support void Cricket tickets on TVS Abnormal Account [Redmine: #187051]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		- 20230529@July: Support case Cricket main in table match -> child in table match14 [Redmine: #188153]
		- 20230530@July: Return column IsCredit send ticket Letstalk [Redmine: #188152]
		- 20231113@Max: [TVS] Bet list on Delete Bet Check display WRONG HDP value for sub parlay ticket [Redmine: #196755]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]
		- 20241126@Lani: [TVS] Change join type on 'recommend' and 'custid' columns [Redmine: #213451]
		- 20250328@Lani: [TVS] Upgrade ExchangeID data type [Redmine: #222191]
		- 20250828@July: [TVS] ScaleOut DBTrans [Phase 7] Manage Request page [Redmine: #236438]
		- 20251028@July: [TVS] Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241502]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE  @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #TmpMatch (Matchid INT, SettlementStatus TINYINT, IsOutright BIT, IsMatch3rd BIT)
	DECLARE @tmpVoidingHistory TABLE (VoidingHistoryId INT)
	DECLARE @tmpChildMatchCricket TABLE (
		MatchId			INT
		,ChildMatchId			INT
	)
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
              subbetcheck     NVARCHAR(50),
              subOdds         SMALLMONEY,
              subbetteam      NVARCHAR(10),
              subbettype      SMALLINT,
              subhdp1         SMALLMONEY,
              subhdp2         SMALLMONEY,
              subtransdesc    NVARCHAR(1000),
              Refno           BIGINT,
              subTransId      BIGINT,
              VoidedTime      DATETIME,
              isITAdmin       BIT,
              IsCashOut       BIT DEFAULT(0),
              MainTransId     BIGINT,
              BonusId         INT,
              IsMarked        BIT DEFAULT(0),
			  LiveIndicator   BIT,
			  ActualStake	  MONEY,
			  oddsid		  INT,
			  winlostdate	  DATETIME,
			  IsCancelCashOut BIT DEFAULT(0),
			  homeid          INT,
			  awayid          INT,
			  leagueid        INT,
			  isNeutral       BIT,
			  matchcode       NVARCHAR(50),
			  showtime        NVARCHAR(50),
			  SettlementStatus	TINYINT,
			  eventstatus	  NVARCHAR(50),
			  sporttype       SMALLINT,
			  modds           SMALLMONEY,
			  VendorMatchId   VARCHAR(50),
			  SiteDBGroupID	  SMALLINT,
			  finalodds		  SMALLMONEY
             );

	CREATE CLUSTERED INDEX CIX_tmpTicket_transId ON #tmpTicket (TransId)

	INSERT INTO @tmpVoidingHistory(VoidingHistoryId) 
	SELECT CAST(value AS INT)
	FROM STRING_SPLIT(@VoidingHistoryIds, ',')
	WHERE value <> ''

	-- single ticket
	INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, winlost, Refno, Bettype, Odds, oddsid, winlostdate, IsCancelCashOut, SiteDBGroupID, IsMixParlay)
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
			,z.SiteDBGroupID
			,CASE WHEN EXISTS (SELECT 1 FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1) AND bettype = z.bettype) THEN 1 ELSE 0 END IsMixParlay
	FROM	@tmpVoidingHistory vh 
		INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON z.VoidingHistoryId = vh.VoidingHistoryId
	WHERE (z.MatchId = @MatchId OR @MatchId = 0)
			AND 1 = CASE WHEN z.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1
						 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
						 ELSE 0 END
		
	-- parlay ticket
	INSERT INTO #tmpTicket (subTransId, matchid, Refno, Status, VoidedTime, custid, IsMixParlay, oddsid, winlostdate, IsCancelCashOut, SiteDBGroupID)
	SELECT	zm.transid		
			,zm.matchid
			,zm.refno
			,zm.status
			,zm.transdate AS VoidedTime
			,zm.custid
			,1 AS IsMixParlay
			,zm.oddsid
			,zm.winlostdate
			,0 AS IsCancelCashOut
			,zm.SiteDBGroupID
	FROM	@tmpVoidingHistory vh
		INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK) ON zm.VoidingHistoryId = vh.VoidingHistoryId 
	WHERE (zm.MatchId = @MatchId OR @MatchId = 0)
			AND 1 = CASE WHEN zm.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = zm.SiteDBGroupID) THEN 1
						 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = zm.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
						 ELSE 0 END

	--Child match cricket
	IF EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH (NOLOCK) WHERE m.ParentID = @MatchId AND m.sporttype IN (50,8))
	BEGIN
		INSERT INTO @tmpChildMatchCricket (MatchId, ChildMatchId)
		SELECT @MatchId, m.matchid
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.ParentID = @MatchId AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
	END
	-- Support case Cricket main in table match -> child in table match14
	IF EXISTS (SELECT TOP 1 1 FROM dbo.match14 m WITH (NOLOCK) WHERE m.ParentID = @MatchId AND m.sporttype IN (50,8))
	BEGIN
		INSERT INTO @tmpChildMatchCricket (MatchId, ChildMatchId)
		SELECT @MatchId, m.matchid
		FROM dbo.match14 m WITH (NOLOCK)
		WHERE m.ParentID = @MatchId AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
	END
	IF EXISTS (SELECT TOP 1 1 FROM @tmpChildMatchCricket)
	BEGIN
		INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, winlost, Refno, Bettype, Odds, oddsid, winlostdate, IsCancelCashOut, SiteDBGroupID, IsMixParlay)
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
				,z.IsCancelCashOut
				,z.SiteDBGroupID
				,z.IsMixParlay
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
						,CASE WHEN z.comstatus = 'CO' THEN 1 ELSE 0 END AS IsCancelCashOut
						,z.SiteDBGroupID
						,CASE WHEN EXISTS (SELECT 1 FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1) AND bettype = z.bettype) THEN 1 ELSE 0 END IsMixParlay
				FROM dbo.zzzbettrans z WITH(NOLOCK)
					INNER JOIN @tmpVoidingHistory vh ON vh.VoidingHistoryId = z.VoidingHistoryId
				WHERE (z.MatchId = cm.ChildMatchId OR @MatchId = 0)
					AND 1 = CASE WHEN z.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1
								 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
								 ELSE 0 END
			) z
		
		-- parlay ticket
		INSERT INTO #tmpTicket (subTransId, matchid, Refno, Status, VoidedTime, custid, IsMixParlay, oddsid, winlostdate, IsCancelCashOut, SiteDBGroupID)
		SELECT	zm.transid		
				,cm.matchid
				,zm.refno
				,zm.status
				,zm.transdate AS VoidedTime
				,zm.custid
				,1 AS IsMixParlay
				,zm.oddsid
				,zm.winlostdate
				,0 AS IsCancelCashOut
				,zm.SiteDBGroupID
		FROM	@tmpChildMatchCricket cm 
			CROSS APPLY (
				SELECT	zm.transid
						,zm.matchid
						,zm.status
						,zm.transdate
						,zm.custid
						,zm.winlost
						,zm.refno
						,zm.oddsid
						,zm.winlostdate
						,zm.SiteDBGroupID
				FROM dbo.zzzbettransm zm WITH(NOLOCK)
					INNER JOIN @tmpVoidingHistory vh ON vh.VoidingHistoryId = zm.VoidingHistoryId
				WHERE (zm.MatchId = cm.ChildMatchId OR @MatchId = 0)
					AND 1 = CASE WHEN zm.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = zm.SiteDBGroupID) THEN 1
								 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = zm.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
								 ELSE 0 END
			) zm
	END

	INSERT INTO #TmpMatch (Matchid, SettlementStatus, IsOutright, IsMatch3rd)
	SELECT DISTINCT t.MatchId, m.SettlementStatus, CASE WHEN t.Bettype = 10 THEN 1 ELSE 0 END, ISNULL(m.IsMatch3rd,0)
	FROM #tmpTicket t
		OUTER APPLY(
			SELECT m.SettlementStatus, 0 AS IsMatch3rd
			FROM dbo.match m WITH(NOLOCK) 
			WHERE t.MatchId = m.matchid
			UNION ALL
			SELECT 0 AS SettlementStatus, 1 AS IsMatch3rd
			FROM dbo.Match3rd m WITH(NOLOCK) 
			WHERE t.matchid = m.Match3rdId
			UNION ALL
			SELECT 0 AS SettlementStatus, 1 AS IsMatch3rd
			FROM dbo.VSRaceInfo m WITH(NOLOCK) 
			WHERE t.matchid = m.EventID
		)m

	--@IsMovebet = 0
	IF  EXISTS ( SELECT TOP 1 1 FROM #TmpMatch 
				 WHERE (SettlementStatus IS NOT NULL 
						OR (SettlementStatus IS NULL AND matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)))
						OR (SettlementStatus IS NULL AND IsOutright = 1)
						OR (IsMatch3rd = 1))
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
				,modds = b.modds
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.TransId = b.transid AND b.SiteDBGroupID = t.SiteDBGroupID

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
				,modds = b.modds
				,finalodds = bm.finalodds
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK) ON t.subTransId = bm.transid AND bm.SiteDBGroupID = t.SiteDBGroupID
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.SiteDBGroupID = bm.SiteDBGroupID
	
		--Update odds support show betlist for Hybrid parlay
		IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket WHERE IsMixParlay = 1 AND oddsspread = 3) 
		BEGIN
			;WITH CTE_MaxSubOdds AS (
				SELECT t.transid, MAX(bm.odds) AS Max_SubOdds
				FROM #tmpTicket t
					INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON t.Refno = bm.Refno AND t.matchid = bm.matchid
				WHERE t.IsMixParlay = 1 AND t.oddsspread = 3
				GROUP BY t.transid
			)
			UPDATE b
			SET b.SubOdds = x.Max_SubOdds
			FROM #tmpTicket AS b
			INNER JOIN CTE_MaxSubOdds AS x ON b.transid = x.transid
			WHERE b.IsMixParlay = 1 AND b.oddsspread = 3;
		END 
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
				,modds = b.modds
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON t.TransId = b.transid AND b.SiteDBGroupID = t.SiteDBGroupID
		
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
				,modds = b.modds
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm14 bm WITH(NOLOCK) ON	t.subTransId = bm.transid AND bm.SiteDBGroupID = t.SiteDBGroupID
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29 AND b.SiteDBGroupID = bm.SiteDBGroupID

		
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
					,modds = b.modds
			FROM	#tmpTicket t
				INNER LOOP JOIN dbo.bettransm14 bm WITH(NOLOCK) ON	t.subTransId = bm.transid AND bm.SiteDBGroupID = t.SiteDBGroupID
				INNER HASH JOIN dbo.bettrans14 b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29 AND b.SiteDBGroupID = bm.SiteDBGroupID
		END

		--Update odds support show betlist for Hybrid parlay (for bettransm14)
		IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket WHERE IsMixParlay = 1 AND oddsspread = 3) 
		BEGIN
			;WITH CTE_MaxSubOdds AS (
				SELECT t.transid, MAX(bm.odds) AS Max_SubOdds
				FROM #tmpTicket t
					INNER JOIN dbo.bettransm14 bm WITH (NOLOCK) ON t.Refno = bm.Refno AND t.matchid = bm.matchid
				WHERE t.IsMixParlay = 1 AND t.oddsspread = 3
				GROUP BY t.transid
			)
			UPDATE b
			SET b.SubOdds = x.Max_SubOdds
			FROM #tmpTicket AS b
			INNER JOIN CTE_MaxSubOdds AS x ON b.transid = x.transid
			WHERE b.IsMixParlay = 1 AND b.oddsspread = 3;
		END 
	END

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE IsMixParlay = 0 AND bettype NOT IN (10)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
		FROM #tmpTicket d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.IsMixParlay = 0 AND bettype NOT IN (10)
	END
	
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (10)))
	BEGIN
		UPDATE d
		SET matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
			,eventstatus = ISNULL(odds.oddsstatus,'')
			,SettlementStatus = 0
		FROM #tmpTicket d
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	d.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE d.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (1231,1232,1233,1237,1238,2770,2771,15500,15501)))
	BEGIN
		UPDATE d
			SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= r.leagueid
				,sporttype 	= r.sporttype
				,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
				,eventstatus = ISNULL(o.eventstatus,'')
				,SettlementStatus = 0
				,VendorMatchId = CASE WHEN d.bettype IN (2770,2771,15500,15501) THEN r.VendorMatchId ELSE NULL END
		FROM #tmpTicket d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE d.bettype IN (1231,1232,1233,1237,1238,2770,2771,15500,15501)
	END

	-- UPDATE VS5, VS6
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype BETWEEN 11050 AND 11099 OR bettype BETWEEN 13000 AND 13199))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
		FROM #tmpTicket d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
		WHERE d.bettype BETWEEN 11050 AND 11099 OR bettype BETWEEN 13000 AND 13199
	END
	
	--Show highlight yellow for ticket marked transaction in betlist
	UPDATE d
	SET d.IsMarked = 1
	FROM #tmpTicket d
		CROSS APPLY (
			SELECT TOP 1 m.TransId, m.MarkType 
			FROM dbo.MarkedTransaction m WITH (NOLOCK) 
			WHERE d.matchid = m.MatchId 
				AND (m.TransId = d.transid  --Single/Subparlay for normal 
				 OR (m.TransId = d.SubTransid AND d.oddsspread = 3 AND d.IsMixParlay = 1)) --Subparlay for Hybrid
		)mt	

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
               ,s.homeid          
               ,s.awayid          
               ,s.leagueid        
               ,s.isNeutral       
               ,s.matchcode       
               ,s.showtime        
               ,s.SettlementStatus
               ,s.eventstatus	  
               ,s.sporttype       
			   ,s.modds
			   ,s.IsDeposit
			   ,s.VendorMatchId
			   ,s.finalodds
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
			   ,s.homeid          
               ,s.awayid          
               ,s.leagueid        
               ,s.isNeutral       
               ,s.matchcode       
               ,s.showtime        
               ,s.SettlementStatus
               ,s.eventstatus	  
               ,s.sporttype    
			   ,s.modds
			   ,s.IsDeposit
			   ,s.VendorMatchId
			   ,s.finalodds
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
			   ,s.homeid          
               ,s.awayid          
               ,s.leagueid        
               ,s.isNeutral       
               ,s.matchcode       
               ,s.showtime        
               ,s.SettlementStatus
               ,s.eventstatus	  
               ,s.sporttype 
			   ,s.modds
			   ,s.IsDeposit
			   ,s.VendorMatchId
			   ,s.finalodds
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
		   ,s.homeid          
           ,s.awayid          
           ,s.leagueid        
           ,s.isNeutral       
           ,s.matchcode       
           ,s.showtime        
           ,s.SettlementStatus
           ,s.eventstatus	  
           ,s.sporttype   
		   ,s.modds
		   ,s.IsDeposit
		   ,s.VendorMatchId
		   ,s.finalodds
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
		   ,s.homeid          
           ,s.awayid          
           ,s.leagueid        
           ,s.isNeutral       
           ,s.matchcode       
           ,s.showtime        
           ,s.SettlementStatus
           ,s.eventstatus	  
           ,s.sporttype       
		   ,s.IsDeposit
		   ,s.modds AS MasterOdds
		   ,s.VendorMatchId
		   ,s.finalodds
		   ,CASE WHEN s.IsMixParlay = 1 AND s.oddsspread = 3 THEN 1 ELSE 0 END AS IsHybrid
	FROM CTE_OriginResult s
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK) ON s.creator = cr.custid
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.custid = c.custid
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
		   , s.SubTransid ASC	

	DROP TABLE #tmpTicket
	DROP TABLE #TmpMatch
	
END
GO
