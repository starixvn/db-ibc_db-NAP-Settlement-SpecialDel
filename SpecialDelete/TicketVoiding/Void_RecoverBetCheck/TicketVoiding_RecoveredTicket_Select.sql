/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RecoveredTicket_Select]
( 
	@SingleTransIds VARCHAR(MAX) =''
   ,@SubParlayTransIds VARCHAR(MAX) = ''
)
AS;
/*	
	Created by: 20240102@July
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20240102@July: Create new SP [Redmine:#196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241126@Lani: [TVS] Change join type on 'recommend' and 'custid' columns [Redmine: #213451]

	Param's explanation:	
		- SingleTransIds: single & main parlay ticket
		- SubParlayTransIds: subparlay ticket
*/	
BEGIN
	SET NOCOUNT ON
	DECLARE  @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #TVSTicketBets (
		matchid				INT
		,transid			BIGINT
		,Subtransid			BIGINT
		,custid				INT        
		,transdate			DATETIME
		,checktime			DATETIME
		,hdp1				SMALLMONEY
		,hdp2				SMALLMONEY
		,livehomescore		SMALLINT
		,liveawayscore		SMALLINT
		,liveindicator		BIT
		,betteam			NVARCHAR(10)
		,creator			INT
		,refno				BIGINT
		,betid				BIGINT
		,bettype			SMALLINT
		,betdaqid			BIGINT
		,betfrom			NVARCHAR(4)
		,statusID			TINYINT
		,WalletType			TINYINT
		,RefCode			BIGINT
		,Subcustid			INT        
		,Sublivehomescore	SMALLINT
		,Subliveawayscore	SMALLINT
		,Subhdp1			SMALLMONEY
		,Subhdp2			SMALLMONEY
		,Subbetfrom			NVARCHAR(4)
		,Subbettype			SMALLINT
		,SubstatusID		TINYINT
		,Subtransdate		DATETIME
		,Subchecktime		DATETIME
		,Subliveindicator	BIT
		,recommend			INT
		,mrecommend			INT
		,srecommend			INT
		,statuswinlost		TINYINT
		,IsMixParlay		BIT
		,odds				MONEY
		,Subodds			MONEY
		,oddsspread			MONEY
		,oddstype			TINYINT
		,betcheck			NVARCHAR(50)
		,Subbetcheck		NVARCHAR(50)
		,stake				MONEY
		,CurrencyName		NVARCHAR(50)
		,Transdesc			NVARCHAR(1000)
		,ExtraInfo			VARCHAR(1000)
		,BonusID			INT
		,winlost			MONEY
		,actual_stake		MONEY
		,Status				NVARCHAR(10)
		,SubStatus			NVARCHAR(10)
		,Subbetteam			NVARCHAR(10)
		,Suboddsspread		MONEY
		,SubTransdesc		NVARCHAR(1000)
		,modds				SMALLMONEY
		,SiteDBGroupID		SMALLINT
		,oddsid				INT
		,winlostdate		SMALLDATETIME
		,MainTransId        BIGINT
		,IsCashOut			BIT DEFAULT(0)
		,IsCancelCashOut 	BIT
		,homeid				INT
		,awayid				INT
		,leagueid			INT
		,isNeutral			BIT
		,matchcode			NVARCHAR(50)
		,showtime			NVARCHAR(50)
		,SettlementStatus	TINYINT
		,eventstatus		NVARCHAR(50)
		,sporttype			SMALLINT
        ,IsDeposit			BIT DEFAULT(0) --1: Deposit/ 0: Credit
		,username			VARCHAR(50)
		,IsMove14			BIT DEFAULT(0)
		,TicketType			TINYINT 
		
	)

	CREATE TABLE #transIdTemp (
		transid		BIGINT PRIMARY KEY
	   ,TicketType	TINYINT --1: single & main parlay(exclude cancel CO), 2: sub parlay, 3: cancel CO
	) 

	INSERT INTO #transIdTemp (transid, TicketType)
	SELECT DISTINCT value, 1
	FROM STRING_SPLIT(@SingleTransIds, ',')
	WHERE value <> ''

	INSERT INTO #transIdTemp (transid, TicketType)
	SELECT DISTINCT value, 2
	FROM STRING_SPLIT(@SubParlayTransIds, ',')
	WHERE value <> ''

	--Search single tickets (active & archive 14)
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #transIdTemp WHERE TicketType = 1)
		BEGIN
			INSERT INTO #TVSTicketBets(
					matchid 
					,transid
					,Subtransid 
					,custid                
					,transdate 
					,checktime 
					,hdp1 
					,hdp2 
					,livehomescore 
					,liveawayscore 
					,liveindicator 
					,betteam 
					,creator 
					,refno 
					,betid 
					,bettype 
					,betdaqid 
					,betfrom 
					,statusID 
					,WalletType 
					,RefCode 
					,Subcustid         
					,Sublivehomescore 
					,Subliveawayscore 
					,Subhdp1 
					,Subhdp2 
					,Subbetfrom 
					,Subbettype 
					,SubstatusID 
					,Subtransdate 
					,Subchecktime 
					,Subliveindicator 
					,recommend 
					,mrecommend 
					,srecommend 
					,statuswinlost 
					,IsMixParlay 
					,odds 
					,Subodds 
					,oddsspread 
					,oddstype 
					,betcheck 
					,Subbetcheck 
					,stake 
					,CurrencyName 
					,Transdesc 
					,ExtraInfo 
					,BonusID 
					,winlost        
					,actual_stake 
					,Status
					,SubStatus 
					,Subbetteam  
					,Suboddsspread 
					,SubTransdesc  
					,modds 
					,SiteDBGroupID
					,oddsid
					,winlostdate
					,username
					,MainTransId
					,TicketType
				)
			SELECT b.matchid
				,b.TransId
				,b.transid AS SubTransID
				,b.custid
				,b.transdate
				,b.checktime
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.liveindicator
				,b.betteam
				,b.creator
				,b.refno
				,b.betid
				,b.bettype
				,b.betdaqid 
				,b.betfrom 
				,b.statusID 
				,b.WalletType 
				,b.RefCode 
				,b.custid Subcustid         
				,b.livehomescore AS Sublivehomescore 
				,b.liveawayscore AS Subliveawayscore 
				,b.hdp1 AS Subhdp1 
				,b.hdp2 AS Subhdp2 
				,b.betfrom AS Subbetfrom 
				,b.bettype AS Subbettype 
				,b.statusID AS SubstatusID 
				,b.transdate AS Subtransdate 
				,b.checktime AS Subchecktime 
				,b.liveindicator AS Subliveindicator 
				,b.recommend 
				,b.mrecommend 
				,b.srecommend 
				,b.statuswinlost 
				,0 AS IsMixParlay 
				,b.odds 
				,b.odds AS Subodds 
				,b.oddsspread
				,b.oddstype 
				,b.betcheck 
				,b.betcheck AS Subbetcheck 
				,b.stake 
				,b.CurrencyName 
				,b.Transdesc 
				,b.ExtraInfo 
				,b.BonusID 
				,(b.winlost - b.actual_stake)       
				,b.actual_stake 
				,b.Status
				,b.status AS SubStatus 
				,b.betteam AS Subbetteam  
				,b.oddsspread AS Suboddsspread 
				,b.transdesc SubTransdesc  
				,b.modds 
				,b.SiteDBGroupID
				,b.oddsid
				,b.winlostdate
				,b.Username
				,b.transid AS MainTransId
				,d.TicketType
			FROM #transIdTemp d 
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON d.transid = b.TransId
			WHERE b.statusID NOT IN (101, 102) --Reject, Void
				AND b.SiteDBGroupID = @SiteDBGroupID
		
			INSERT INTO #TVSTicketBets(
					matchid 
					,transid
					,Subtransid 
					,custid                
					,transdate 
					,checktime 
					,hdp1 
					,hdp2 
					,livehomescore 
					,liveawayscore 
					,liveindicator 
					,betteam 
					,creator 
					,refno 
					,betid 
					,bettype 
					,betdaqid 
					,betfrom 
					,statusID 
					,WalletType 
					,RefCode 
					,Subcustid         
					,Sublivehomescore 
					,Subliveawayscore 
					,Subhdp1 
					,Subhdp2 
					,Subbetfrom 
					,Subbettype 
					,SubstatusID 
					,Subtransdate 
					,Subchecktime 
					,Subliveindicator 
					,recommend 
					,mrecommend 
					,srecommend 
					,statuswinlost 
					,IsMixParlay 
					,odds 
					,Subodds 
					,oddsspread 
					,oddstype 
					,betcheck 
					,Subbetcheck 
					,stake 
					,CurrencyName 
					,Transdesc 
					,ExtraInfo 
					,BonusID 
					,winlost        
					,actual_stake 
					,Status
					,SubStatus 
					,Subbetteam  
					,Suboddsspread 
					,SubTransdesc  
					,modds 
					,SiteDBGroupID
					,oddsid
					,winlostdate
					,username
					,IsMove14
					,MainTransId
					,TicketType
				)
			SELECT b.matchid
				,b.TransId
				,b.transid AS SubTransID
				,b.custid
				,b.transdate
				,b.checktime
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.liveindicator
				,b.betteam
				,b.creator
				,b.refno
				,b.betid
				,b.bettype
				,b.betdaqid 
				,b.betfrom 
				,b.statusID 
				,b.WalletType 
				,b.RefCode 
				,b.custid Subcustid         
				,b.livehomescore AS Sublivehomescore 
				,b.liveawayscore AS Subliveawayscore 
				,b.hdp1 AS Subhdp1 
				,b.hdp2 AS Subhdp2 
				,b.betfrom AS Subbetfrom 
				,b.bettype AS Subbettype 
				,b.statusID AS SubstatusID 
				,b.transdate AS Subtransdate 
				,b.checktime AS Subchecktime 
				,b.liveindicator AS Subliveindicator 
				,b.recommend 
				,b.mrecommend 
				,b.srecommend 
				,b.statuswinlost 
				,0 AS IsMixParlay 
				,b.odds 
				,b.odds AS Subodds 
				,b.oddsspread
				,b.oddstype 
				,b.betcheck 
				,b.betcheck AS Subbetcheck 
				,b.stake 
				,b.CurrencyName 
				,b.Transdesc 
				,b.ExtraInfo 
				,b.BonusID 
				,(b.winlost - b.actual_stake)       
				,b.actual_stake 
				,b.Status
				,b.status AS SubStatus 
				,b.betteam AS Subbetteam  
				,b.oddsspread AS Suboddsspread 
				,b.transdesc SubTransdesc  
				,b.modds 
				,b.SiteDBGroupID
				,b.oddsid
				,b.winlostdate
				,b.Username
				,1 AS IsMove14
				,b.transid AS MainTransId
				,d.TicketType
			FROM #transIdTemp d 
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON d.transid = b.TransId
			WHERE b.statusID NOT IN (101, 102) --Reject, void
				AND b.SiteDBGroupID = @SiteDBGroupID
		END

		IF EXISTS (SELECT TOP 1 1 FROM #transIdTemp WHERE TicketType = 2)
		BEGIN
			INSERT INTO #TVSTicketBets(
				matchid 
				,transid
				,Subtransid 
				,custid                
				,transdate 
				,checktime 
				,hdp1 
				,hdp2 
				,livehomescore 
				,liveawayscore 
				,liveindicator 
				,betteam 
				,creator 
				,refno 
				,betid 
				,bettype 
				,betdaqid 
				,betfrom 
				,statusID 
				,WalletType 
				,RefCode 
				,Subcustid         
				,Sublivehomescore 
				,Subliveawayscore 
				,Subhdp1 
				,Subhdp2 
				,Subbetfrom 
				,Subbettype 
				,SubstatusID 
				,Subtransdate 
				,Subchecktime 
				,Subliveindicator 
				,recommend 
				,mrecommend 
				,srecommend 
				,statuswinlost 
				,IsMixParlay 
				,odds 
				,Subodds 
				,oddsspread 
				,oddstype 
				,betcheck 
				,Subbetcheck 
				,stake 
				,CurrencyName 
				,Transdesc 
				,ExtraInfo 
				,BonusID 
				,winlost        
				,actual_stake 
				,Status
				,SubStatus 
				,Subbetteam  
				,Suboddsspread 
				,SubTransdesc  
				,modds 
				,SiteDBGroupID
				,oddsid
				,winlostdate
				,username
				,MainTransId
				,TicketType
			)
			SELECT 
				bm.matchid
				,b.transid
				,bm.TransId AS SubTransId
				,b.custid
				,b.transdate
				,b.checktime
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.liveindicator
				,b.betteam
				,b.creator
				,b.refno
				,b.betid
				,b.bettype
				,b.betdaqid
				,b.betfrom
				,b.statusID
				,b.WalletType
				,b.refcode
				,bm.custid AS SubCustid
				,bm.livehomescore AS SubLivehomescore
				,bm.liveawayscore AS SubLiveawayscore
				,bm.hdp1 AS SubHdp1
				,bm.hdp2 AS SubHdp2
				,bm.betfrom AS SubBetfrom
				,bm.bettype AS SubBettype
				,bm.statusID AS SubStatusId
				,bm.transdate AS SubTransdate
				,bm.checktime AS SubChecktime
				,bm.liveindicator AS SubLiveindicator
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.statuswinlost
				,1 AS IsMixParlay
				,b.odds
				,bm.odds AS Subodds
				,b.oddsspread
				,b.oddstype
				,b.betcheck
				,bm.betcheck AS Subbetcheck
				,b.stake
				,b.CurrencyName
				,b.transdesc
				,b.ExtraInfo
				,b.BonusID
				,b.winlost
				,b.actual_stake
				,b.status
				,bm.status AS SubStatus
				,bm.betteam AS SubBetteam
				,bm.oddsspread AS SubOddsspread
				,bm.transdesc AS SubTransdesc
				,b.modds
				,bm.SiteDBGroupID
				,b.oddsid
				,b.winlostdate
				,b.Username
				,b.TransId AS MainTransId
				,t.TicketType
			FROM #transIdTemp AS t
			INNER JOIN dbo.bettransm AS bm ON t.transid = bm.TransId AND bm.SiteDBGroupID = @SiteDBGroupID
			INNER JOIN dbo.bettrans AS b ON b.refno = bm.refno AND b.SiteDBGroupID = bm.SiteDBGroupID
			WHERE bm.statusID NOT IN (101, 102)

		END
	END

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
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
		FROM #TVSTicketBets d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
	
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (10)))
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
		FROM #TVSTicketBets d
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	d.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE d.bettype IN (10)
	END
	
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (1231,1232,1233,1237,1238)))
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
		FROM #TVSTicketBets d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE d.bettype IN (1231,1232,1233,1237,1238)
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsMove14 = 1)
	BEGIN
		-- UPDATE eventtype = 1
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
		BEGIN
			UPDATE t
			SET matchcode 	= m.matchcode
				,homeid 	= m.homeid
				,awayid 	= m.awayid
				,leagueid 	= m.leagueid
				,sporttype 	= m.sporttype
				,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
				,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
				,matchid    = m.matchid
				,SettlementStatus = 0
				,eventstatus = m.eventstatus
			FROM #TVSTicketBets t
				INNER JOIN dbo.match14 m WITH (NOLOCK) 
				ON	t.matchid = m.matchid
			WHERE t.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) 
				AND t.IsMove14 = 1
		END
		
		-- UPDATE eventtype = 2 [Outright bettype]
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (10)))
		BEGIN
			UPDATE t
			SET matchcode 	= odds.matchcode
				,homeid		= odds.teamid
				,awayid 	= 0
				,leagueid 	= odds.leagueid
				,sporttype 	= l.sporttype
				,showtime	= ''
				,eventstatus = odds.oddsstatus
			FROM #TVSTicketBets t
				INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) 
				ON	t.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) 
				ON	odds.leagueid = l.leagueid
			WHERE t.bettype IN (10)
				AND t.IsMove14 = 1
		END
		
		-- UPDATE eventtype = 3 [VS range  bettypes]
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (1231,1232,1233,1237,1238)))
		BEGIN
			UPDATE t
				SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
					,homeid 	= o.RacerID
					,awayid 	= 0
					,leagueid 	= r.leagueid
					,sporttype 	= r.sporttype
					,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113)
					,eventstatus = o.EventStatus
			FROM #TVSTicketBets t
				INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
				ON t.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
				ON r.EventID = o.EventID
			WHERE t.bettype IN (1231,1232,1233,1237,1238)
				AND t.IsMove14 = 1
		END
	END

	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE d
		SET sporttype = sb.SportType
		FROM #TVSTicketBets d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- UPDATE IsMixParlay
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE TicketType = 1 AND bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE t
			SET IsMixParlay = 1
		FROM #TVSTicketBets t
		WHERE t.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END

	-- UPDATE Isdeposit
	UPDATE al SET IsDeposit = 1
	FROM	#TVSTicketBets al
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
			   ,s.BonusId
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.subbettype
			   ,s.subtransdesc
			   ,s.actual_stake
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
			   ,s.MainTransId
			   ,s.modds
			   ,s.IsDeposit
		FROM	#TVSTicketBets s
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
			   ,s.BonusId
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.subbettype
			   ,s.subtransdesc
			   ,s.actual_stake
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
			   ,s.MainTransId
			   ,s.modds
		       ,s.IsDeposit
		FROM	#TVSTicketBets s 
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
			   ,s.BonusId
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.subbettype
			   ,s.subtransdesc
			   ,s.actual_stake
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
			   ,s.MainTransId
			   ,s.modds
			   ,s.IsDeposit
		FROM	#TVSTicketBets s 
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
		   ,s.BonusId
		   ,s.recommend
		   ,s.LiveIndicator
		   ,s.subbettype
		   ,s.subtransdesc
		   ,s.actual_stake
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
		   ,s.MainTransId
		   ,s.modds
		   ,s.IsDeposit
		FROM	#TVSTicketBets s
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	)

	SELECT  s.transid
		   ,s.BonusId
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
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
		   ,cr.username AS Creator
		   ,s.winlost
		   ,c.site as LicenseeName
		   ,s.LiveIndicator AS IsLiveIndicator
		   ,s.subbettype AS SubBettype
		   ,s.subtransdesc AS subTransdesc
		   ,s.actual_stake
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
		   ,s.MainTransId
	       ,s.modds AS MasterOdds
	FROM CTE_OriginResult s
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK) ON s.creator = cr.custid
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.custid = c.custid
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
		   , CASE WHEN s.BonusID IS NOT NULL THEN 
												CASE WHEN s.MainTransId IS NULL THEN 1
													 ELSE 2 END
				ELSE s.transid END
	
	DROP TABLE #transIdTemp
	DROP TABLE #TVSTicketBets
	
END
GO
