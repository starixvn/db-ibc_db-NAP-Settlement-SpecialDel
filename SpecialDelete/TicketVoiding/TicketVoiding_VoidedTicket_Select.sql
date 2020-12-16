/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTicket_Select]
( 
	@RequestId INT
	,@MatchId   INT
)
AS;
/*	Created by: Kathy
	Date 20181212
	Task: get voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20191118@Max: AdnormalBet TVS + Hotfix #124160 [Redmine:#123691]
		- 20200909@Max: HotFix - TVS - Danger Accept - void single when sub parlay process No. of ticket can not show ticket single [Redmine: #141124]
		- 20201127@Charles: God of fortune [Redmine: #146053]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SettlementStatus TINYINT
			,@IsMovebet BIT

	SET @SettlementStatus = NULL
	SET @IsMovebet = 0

	SELECT	@SettlementStatus = m.SettlementStatus 
	FROM	dbo.match m WITH(NOLOCK) 
	WHERE	m.matchid = @MatchId 

	IF @@rowcount = 0
		SET @IsMovebet = 1

	DECLARE @tmpVoidingHistory TABLE (VoidingHistoryId INT)

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
              betfrom         NVARCHAR(1),
              Betteam         NVARCHAR(10),
              Bettype         SMALLINT,
              OriginalBettype SMALLINT,
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
              IsCashOut       BIT,
              MainTransId     BIGINT,
              BonusId         INT,
              IsMarked        BIT,
			  LiveIndicator   BIT,
			  ActualStake	  MONEY
             );

	CREATE CLUSTERED INDEX CIX_tmpTicket_transId ON #tmpTicket (TransId)

	INSERT INTO @tmpVoidingHistory(VoidingHistoryId) 
	SELECT	vh.VoidingHistoryId
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
	WHERE	vh.RequestId = @RequestId AND vh.StatusId IN (2,3)

	-- single ticket
	INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, IsCashOut, winlost, Refno, Bettype, Odds)
	SELECT	z.transid			
			,z.matchid
			,z.status
			,z.VoidedTime
			,z.custid
			,z.IsCashOut
			,z.winlost
			,z.refno
			,z.bettype
			,z.odds
	FROM	@tmpVoidingHistory vh 
		CROSS APPLY (
			SELECT	z.transid
					,z.matchid
					,z.status
					,z.transdate AS VoidedTime
					,z.custid
					,CASE WHEN z.comstatus = 'CO' THEN 1 ELSE 0 END AS IsCashOut
					,z.winlost
					,z.refno
					,z.bettype
					,z.odds
			FROM	dbo.zzzbettrans z WITH(NOLOCK)
			WHERE	z.VoidingHistoryId = vh.VoidingHistoryId
					AND z.matchid = @MatchId
					AND 1 = CASE
								WHEN z.bettype = 911 THEN 1
								WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
								ELSE 0
							END
		) z
		
	-- parlay ticket
	INSERT INTO #tmpTicket (subTransId, matchid, Refno, Status, VoidedTime, custid, IsMixParlay)
	SELECT	zm.transid		
			,zm.matchid
			,zm.refno
			,zm.status
			,zm.VoidedTime
			,zm.custid
			,1 AS IsMixParlay
	FROM	@tmpVoidingHistory vh
		CROSS APPLY (
			SELECT	zm.transid
					,zm.matchid
					,zm.refno 
					,zm.status
					,zm.transdate AS VoidedTime
					,zm.custid
			FROM	dbo.zzzbettransm zm WITH(NOLOCK)
			WHERE	zm.VoidingHistoryId = vh.VoidingHistoryId
					AND zm.matchid = @MatchId
		) zm
		
	IF @IsMovebet = 0
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
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans b WITH(NOLOCK) ON	t.TransId = b.transid

	
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
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK) ON t.subTransId = bm.transid
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29
	END
	ELSE
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
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON t.TransId = b.transid
		
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
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm14 bm WITH(NOLOCK) ON	t.subTransId = bm.transid
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29

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
			FROM	#tmpTicket t
				INNER JOIN dbo.bettransm14 bm WITH(NOLOCK) ON	t.subTransId = bm.transid
				INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29
		END
	END

	-- Update IsMarked
	UPDATE t
	SET t.IsMarked = CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END 
	FROM #tmpTicket  t
	LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON t.transid = m.TransId		


	IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket WHERE Bettype = 911)
	BEGIN		
		UPDATE sub911
			SET OriginalBettype = main.bettype
				,odds = main.odds
				,MainTransId = main.TransId
				,IsMarked = main.IsMarked
		FROM	#tmpTicket sub911
			INNER JOIN #tmpTicket main WITH(NOLOCK)
				ON sub911.Refno = main.transid
		WHERE	sub911.Bettype = 911
		
		UPDATE subCO 
			SET MainTransId = sub911.MainTransId,
			IsMarked = sub911.IsMarked
		FROM	#tmpTicket subCO
			INNER JOIN #tmpTicket sub911 WITH(NOLOCK)
				ON subCO.Refno = sub911.transid
		WHERE	subCO.IsCashOut = 1
				AND sub911.bettype = 911
	END

	-- Update maintransid for bonus ticket
	IF EXISTS (SELECT * FROM #tmpTicket WHERE WalletType = 1)
	BEGIN
		UPDATE sub 
			SET maintransid = main.transid
			,IsMarked = main.IsMarked
		FROM	#tmpTicket sub  
			INNER JOIN #tmpTicket main 
				ON 	main.refcode = sub.refcode
					AND main.transid <> sub.transid
					AND main.custid = sub.custid
					AND main.bettype = sub.bettype
		WHERE	main.wallettype = 1
	END	

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
			   ,s.OriginalBettype
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
			   ,CASE WHEN c.site = 'CN88' THEN 'CN88' ELSE 'Credit' END AS GroupName
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
			   ,s.OriginalBettype
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
		FROM	#tmpTicket s 
			LEFT JOIN dbo.bettrans b WITH(NOLOCK) ON	s.betid = b.transid AND b.matchid = @matchid	
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
			   ,s.OriginalBettype
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
			   ,'Deposit' AS GroupName
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
		   ,s.OriginalBettype
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
		FROM	#tmpTicket s WITH (NOLOCK)
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	)
	SELECT s.transid
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
		   ,s.OriginalBettype
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
		   ,@SettlementStatus AS SettlementStatus
			,cr.username AS Creator
			,s.IsCashOut
			,s.winlost
			,s.IsMarked
			,c.site as LicenseeName
			,s.LiveIndicator AS IsLiveIndicator
			,s.subbettype AS SubBettype
			,s.subtransdesc AS subTransdesc
			,s.ActualStake
	FROM CTE_OriginResult s
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK) ON s.creator = cr.custid
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid

	ORDER BY CASE
				WHEN s.GroupName = 'CN88' THEN 1
				WHEN s.GroupName = 'Credit' THEN 2
				WHEN s.GroupName = '8RM/BARM' THEN 3
				WHEN s.GroupName = 'Deposit' THEN 4
				WHEN s.GroupName = 'Betfair' THEN 5
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
	
END
GO
