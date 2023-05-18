/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void14_Select] 
(
    @RequestId			INT = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
)
AS
/*	Created by: July
	Date 20211123
	Task: TVS - Void Archived Tickets [Redmine:#140180]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20211123@July: Create new SP - view voided ticket [Redmine:#140180]
		- 20220620@July: Remove code instant settlement for archive ticket [Redmine: #174122]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@Max: [TVS] Increase data size when sending data between web and DB [Redmine:	#180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230517@Max: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	CREATE TABLE #TVSTicketBets (
		GroupID               BIGINT,
        transid               BIGINT,
        SubTransid            BIGINT,
        refno                 BIGINT,
        custid                INT,
        username              VARCHAR(30),
        odds                  SMALLMONEY,
        SubOdds               SMALLMONEY,
        oddsspread            MONEY,
        OddsType              INT,
        transdate             DATETIME,
        bettype               SMALLINT,
        betteam               NVARCHAR(10),
        SubBetTeam            NVARCHAR(10),
        betcheck              NVARCHAR(50),
        SubBetcheck           NVARCHAR(50),
        Subhdp1               SMALLMONEY,
        Subhdp2               SMALLMONEY,
        hdp1                  SMALLMONEY,
        hdp2                  SMALLMONEY,
        livehomescore         SMALLINT,
        liveawayscore         SMALLINT,
        creator               INT,
        creatorName           VARCHAR(30),
        Stake                 MONEY,
        currencyname          VARCHAR(20),
        IsDeposit             BIT DEFAULT(0),
        STATUS                NVARCHAR(10),
        SubStatus             NVARCHAR(10),
        srecommend            INT,
        mrecommend            INT,
        recommend             INT,
        SubLeagueId           INT,
        betid                 BIGINT DEFAULT(0),
        Transdesc             NVARCHAR(1000),
        betdaqid              BIGINT,
        ParlayType            SMALLINT DEFAULT(0),-- sub bettype of parlay 
        IsMixParlay           BIT DEFAULT(0),
        sporttype             SMALLINT,
        modds                 SMALLMONEY,
        ExtraInfo             VARCHAR(1000),
        IsCashOut			  BIT DEFAULT(0),
        matchid               INT,
        WalletType            TINYINT,
        RefCode               BIGINT,
        BonusID               INT,
        MainTransId           BIGINT,
        WinLost               MONEY,
        LiveIndicator		  BIT,
		mainstatusid		  TINYINT,
		ActualStake			  MONEY,
		oddsid                INT,
		homeid                INT,
        awayid                INT,
		leagueid              INT,
		isNeutral             BIT,
		matchcode             NVARCHAR(50),
		showtime              NVARCHAR(50),
		winlostdate			  SMALLDATETIME,
		statusID			  TINYINT,
		SiteDBGroupID		  SMALLINT
    )
	CREATE TABLE #tmpTransInfo(
			   matchid INT
			  ,transid BIGINT PRIMARY KEY
			  ,Subtransid BIGINT
			  ,refno BIGINT
			  ,custid INT	
			  ,hdp1 SMALLMONEY
			  ,hdp2 SMALLMONEY
			  ,livehomescore SMALLINT
			  ,liveawayscore SMALLINT
			  ,liveindicator BIT
			  ,odds SMALLMONEY
			  ,oddsid INT
			  ,oddsspread MONEY
			  ,betfrom NVARCHAR(4)
			  ,bettype SMALLINT
			  ,betteam NVARCHAR(10)
			  ,betcheck NVARCHAR(50)
			  ,Status NVARCHAR(10)
			  ,transdate DATETIME
			  ,checktime DATETIME
			  ,betid BIGINT
			  ,Transdesc NVARCHAR(1000)
			  ,statusID TINYINT
			  ,Subcustid INT
			  ,Subhdp1 SMALLMONEY
			  ,Subhdp2 SMALLMONEY
			  ,Sublivehomescore SMALLINT
			  ,Subliveawayscore SMALLINT
			  ,Subliveindicator BIT
			  ,Subodds SMALLMONEY
			  ,Suboddsspread MONEY
			  ,Subbetfrom NVARCHAR(4)
			  ,Subbettype SMALLINT
			  ,Subbetteam  NVARCHAR(10)
			  ,Subbetcheck NVARCHAR(50)
			  ,SubStatus NVARCHAR(10)
			  ,Subtransdate DATETIME
			  ,SubTransdesc  NVARCHAR(1000)
			  ,SubstatusID TINYINT
			  ,srecommend INT
			  ,mrecommend INT
			  ,recommend INT
			  ,creator INT
			  ,WalletType TINYINT
			  ,RefCode BIGINT
			  ,stake MONEY
			  ,oddstype TINYINT
			  ,CurrencyName NVARCHAR(50)
			  ,betdaqid BIGINT
			  ,ExtraInfo VARCHAR(1000)
			  ,BonusID INT
			  ,winlost	MONEY
			  ,actual_stake MONEY
			  ,winlostdate SMALLDATETIME
			  ,modds SMALLMONEY
			  ,IsMixParlay BIT
			  ,SiteDBGroupID SMALLINT
			)

	INSERT INTO #tmpTransInfo( 
		    matchid,transid ,Subtransid ,refno ,custid ,hdp1 ,hdp2 ,livehomescore ,liveawayscore ,liveindicator ,odds ,oddsid,oddsspread 
           ,betfrom ,bettype ,betteam ,betcheck ,Status ,transdate ,betid ,Transdesc ,statusID 
		   ,Subcustid ,Subhdp1 ,Subhdp2 ,Sublivehomescore ,Subliveawayscore ,Subliveindicator
		   ,Subodds ,Suboddsspread ,Subbetfrom ,Subbettype ,Subbetteam  ,Subbetcheck ,SubStatus ,Subtransdate ,SubTransdesc  ,SubstatusID 
	       ,srecommend ,mrecommend ,recommend ,creator ,WalletType ,RefCode ,stake ,oddstype ,CurrencyName ,betdaqid ,ExtraInfo ,BonusID ,winlost	
	       ,actual_stake ,winlostdate ,modds ,IsMixParlay ,SiteDBGroupID 
		)
	SELECT mid, t, s_t, ref, c, hdp1, hdp2, lh, la, li, o, oid, os
		, bfr, btype, bteam, bcheck, s, tdate, bid, tdes, sid
		, s_c, s_hdp1, s_hdp2, s_lh, s_la, s_li
		, s_o, s_os, s_bfr, s_btype, s_bteam, s_bcheck, s_s, s_tdate, s_tdes, s_sid
		, sre, mre, re, cr, wt, refc, stake, ost, curr, bdaq, ex, bo, w
		, acstake, wld, m, isP, sitedb
	FROM string_split(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid, t, s_t, ref, c, hdp1, hdp2, lh, la, li, o, oid, os
						, bfr, btype, bteam, bcheck, s, tdate, bid, tdes, sid
						, s_c, s_hdp1, s_hdp2, s_lh, s_la, s_li
						, s_o, s_os, s_bfr, s_btype, s_bteam, s_bcheck, s_s, s_tdate, s_tdes, s_sid
						, sre, mre, re, cr, wt, refc, stake, ost, curr, bdaq, ex, bo, w
						, acstake, wld, m, isP, sitedb
				FROM OPENJSON(t.Decompress_TransInfoJson) 
					WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT, li BIT, o SMALLMONEY, oid INT, os MONEY
						, bfr NVARCHAR(3), btype SMALLINT, bteam NVARCHAR(10), bcheck NVARCHAR(50), s NVARCHAR(10), tdate DATETIME, bid BIGINT, tdes NVARCHAR(1000), sid TINYINT
						, s_c INT, s_hdp1 SMALLMONEY, s_hdp2 SMALLMONEY, s_lh SMALLINT, s_la SMALLINT, s_li BIT
						, s_o SMALLMONEY, s_os MONEY, s_bfr NVARCHAR(3), s_btype SMALLINT, s_bteam NVARCHAR(10), s_bcheck NVARCHAR(50), s_s NVARCHAR(10), s_tdate DATETIME, s_tdes NVARCHAR(1000), s_sid  TINYINT
						, sre INT, mre INT, re INT, cr INT, wt TINYINT, refc BIGINT, stake MONEY, ost TINYINT, curr NVARCHAR(50), bdaq BIGINT, ex VARCHAR(1000), bo INT, w MONEY
						, acstake MONEY, wld SMALLDATETIME, m SMALLMONEY, isP BIT, sitedb SMALLINT
					)
		) tbl
	WHERE f.value <> ''

	INSERT INTO #TVSTicketBets(
			GroupID			
			,transid		
			,SubTransid		
			,refno			
			,custid			
			,odds			
			,SubOdds	
			,oddsspread			
			,OddsType		
			,transdate		
			,bettype 		
			,betteam 		
			,SubBetTeam
			,betcheck	
			,SubBetcheck	
			,hdp1 			
			,hdp2 			
			,livehomescore 	
			,liveawayscore 	
			,creator		
			,Stake			
			,currencyname		
			,STATUS			
			,SubStatus	
			,srecommend
			,mrecommend		
			,recommend		
			,betid			
			,Transdesc		
			,betdaqid	
			,ExtraInfo
			,IsCashOut
			,WalletType
			,RefCode
			,BonusID
			,WinLost
			,LiveIndicator
			,mainstatusid
			,ActualStake
			,matchid
			,SiteDBGroupID
			,winlostdate
		)
	SELECT 
			b.transid AS GroupID
			,b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.odds
			,b.odds AS SubOdds
			,b.oddsspread			
			,b.OddsType
			,b.transdate
			,b.bettype
			,b.betteam
			,b.betteam AS SubBetteam
			,b.betcheck
			,b.betcheck AS SubBetcheck
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.creator
			,b.stake
			,b.CurrencyName
			,b.STATUS
			,b.SubStatus
			,b.srecommend
			,b.mrecommend
			,b.recommend
			,b.betid
			,b.Transdesc
			,b.betdaqid
			,b.ExtraInfo
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,b.WinLost - b.actual_stake AS WinLost
			,b.liveindicator
			,b.statusID AS mainstatusid
			,b.actual_stake AS ActualStake
			,b.matchid
			,b.SiteDBGroupID
			,b.winlostdate
	FROM	#tmpTransInfo b
		CROSS APPLY (
			SELECT TOP(1) s.TransId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
			WHERE s.RequestId = @RequestId AND b.transid = s.TransId
		)s
	WHERE  b.statusID NOT IN (101, 102, 103) -- reject, void, refund


	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
		FROM #TVSTicketBets d
			INNER JOIN dbo.match14 m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29, 2799)
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
		FROM #TVSTicketBets d
			INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) 
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
		FROM #TVSTicketBets d
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE d.bettype IN (1231,1232,1233,1237,1238)
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

	-- UPDATE IsMixParlay = 1 [MixParlay bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (9, 29, 2799)))
	BEGIN
		UPDATE d
		SET IsMixParlay = 1
		FROM #TVSTicketBets d
		WHERE d.bettype IN (9, 29, 2799)
	END

	--- Remove invalid sporttype
	DELETE 
	FROM #TVSTicketBets
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		)	

	-- update username/creatorname column
	UPDATE al
		SET username = ci.username
			,creatorName = cr.username
			,SubLeagueId = al.Leagueid
	FROM	#TVSTicketBets al
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
			ON al.custid = ci.custid
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK)
			ON al.creator = cr.custid
			
	-- update Isdeposit
	UPDATE al 
		SET IsDeposit = 1
	FROM	#TVSTicketBets al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)
	
	-- TICKET SECTION
	;WITH CTE_OriginResult AS (
		--1. For Credit	 
		SELECT 
			   s.transid
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.creatorName AS creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
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
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.GroupId
			   ,CASE WHEN c.site = 'CN88' THEN 'CN88' ELSE 'Credit' END AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsCashOut
			   ,s.SiteDBGroupID
		FROM	#TVSTicketBets s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #TVSTicketBets sub
				ON	s.GroupID = sub.GroupID
					AND s.transid <> sub.transid
			LEFT JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = s.recommend		
		WHERE	f.CustID IS NULL
				AND (s.username <> '12EU' AND ISNULL(sub.username,'') <> '12EU')
				AND s.IsDeposit = 0
				AND s.mrecommend NOT IN (105181, 118473, 105183) -- MHC
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				AND (s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 
					AND ISNULL(sub.custid,0) NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
				)  -- Betfair: BFOS, BF, ITibc102, BF3				
		UNION
		--2. For 8RM
		SELECT  
				s.transid
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.creatorName AS creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
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
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername			   
			   ,s.Transdesc
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.GroupId
			   ,'8RM/BARM' AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsCashOut
			   ,s.SiteDBGroupID
		FROM	#TVSTicketBets s 
			--LEFT JOIN dbo.bettrans14 b WITH(NOLOCK)
			--	ON	s.betid = b.transid
			--		AND b.matchid = s.matchid	
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
			   ,s.creatorName AS creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
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
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.GroupId
			   ,'Deposit' AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsCashOut
			   ,s.SiteDBGroupID
		FROM	#TVSTicketBets s 
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #TVSTicketBets sub
				ON	s.GroupID = sub.GroupID
					AND s.transid <> sub.transid
		WHERE	f.CustID IS NULL -- Betdaq
				AND (s.username <> '12EU' AND ISNULL(sub.username,'') <> '12EU')
				AND s.IsDeposit = 1
				AND s.mrecommend NOT IN (105181, 118473, 105183)
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				AND (s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 
				AND ISNULL(sub.custid,0) NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)) -- Betfair: BFOS, BF, ITibc102, BF3	
		UNION
		--4. For Betfair
		SELECT  
			s.transid
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.creatorName AS creator
		   ,s.Stake
		   ,s.odds
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.STATUS
		   ,s.SubStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.SubLeagueId
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
		   ,s.ParlayType
		   ,NULL AS followedId
		   ,NULL AS followedUsername
		   ,s.Transdesc
		   ,s.sporttype
		   ,s.modds
		   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.GroupId
		   ,'Betfair' AS OriginGroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.BonusID
		   ,s.RefCode
		   ,s.WinLost
		   ,s.recommend
		   ,s.LiveIndicator
		   ,s.mainstatusid
		   ,s.ActualStake
		   ,s.matchid
		   ,s.homeid    
		   ,s.awayid    
		   ,s.leagueid  
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.statusID
		   ,s.IsCashOut
		   ,s.SiteDBGroupID
		FROM	#TVSTicketBets s
			LEFT JOIN #TVSTicketBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
	)
	
	SELECT s.transid
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
		   ,s.SubStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.SubLeagueId
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
		   ,s.ParlayType AS SubBettype
		   ,s.followedId
		   ,s.followedUsername
		   ,s.Transdesc
		   ,s.sporttype
		   ,s.modds
		   ,s.IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.OriginGroupName AS GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.RefCode
		   ,0 AS SettlementStatus
		   ,s.WinLost
		   ,c.site as LicenseeName
		   ,s.LiveIndicator AS IsLiveIndicator
		   ,s.ActualStake
		   ,s.matchid
		   ,s.homeid    
		   ,s.awayid    
		   ,s.leagueid  
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.statusID
		   ,s.IsCashOut
		   ,s.SiteDBGroupID
	FROM CTE_OriginResult s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
	ORDER BY CASE
				WHEN s.OriginGroupName = 'CN88' THEN 1
				WHEN s.OriginGroupName = 'Credit' THEN 2
				WHEN s.OriginGroupName = '8RM/BARM' THEN 3
				WHEN s.OriginGroupName = 'Deposit' THEN 4
				WHEN s.OriginGroupName = 'Betfair' THEN 5 
			 END
		   , ISNULL(s.MainTransId, s.transid)
		  
	
	DROP TABLE #TVSTicketBets
	DROP TABLE #tmpTransInfo
END

GO