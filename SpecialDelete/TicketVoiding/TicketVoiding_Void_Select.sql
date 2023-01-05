/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void_Select] 
(
	 @MatchId			INT
    ,@RequestId			INT = NULL
    ,@IssueTypeId		INT = NULL
	,@BetTypes			XML = NULL
	,@LiveHomeScore		SMALLINT = NULL
	,@LiveAwayScore		SMALLINT = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200405@Max: Enhance EKO Issue Type - [Redmine: #126418]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200819@Max: HotFix - [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
	    - 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785] 
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201127@Charles: God of fortune [Redmine: #146053]
		- 20201216@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210401@Max: [TVS] EC2020 Preparation [Redmine: #151103]
		- 20210420@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20210427@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210504@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20211117@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211207@July: Implement New Cash Out Model - Remove code CO [Redmine: #165097] 
		- 20220110@Max: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220221@Max: Remove SABA of league name for China View sites [Redmine: #168651]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220404@Max: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
		- 20220620@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@Max: [TVS] Increase data size when sending data between web and DB [Redmine:	#180863]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	
	DECLARE @ValueDefault SMALLMONEY = 9999.00

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
        IsMarked              BIT DEFAULT(0),
        LiveIndicator		  BIT,
		FilterBettype		  SMALLINT,
        FilterBetTeam		  NVARCHAR(10),
        FilterSet			  VARCHAR(50),
        FilterGame			  VARCHAR(50),
        FilterValue			  SMALLMONEY,
		FilterHdp1		      SMALLMONEY,
		FilterHdp2		      SMALLMONEY,
        FilterGoal			  BIGINT,
        FilterBetOption		  NVARCHAR(50),
        FilterTimeInterval	  SMALLMONEY,
		FilterOddsSpread	  MONEY,
		mainstatusid		  TINYINT, -- store statusid of normal ticket
		ActualStake			  MONEY,
		oddsid                INT,
		homeid                INT,
        awayid                INT,
		leagueid              INT,
		isNeutral             BIT,
		matchcode             NVARCHAR(50),
		showtime              NVARCHAR(50),
		SettlementStatus	  TINYINT,
		winlostdate			  DATETIME,
		statusID			  TINYINT,
		eventstatus			  NVARCHAR(50),
		SiteDBGroupID		  SMALLINT
    )

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(250),
		[Value]			VARCHAR(500),
		ValueHdp1		VARCHAR(500),
		ValueHdp2		VARCHAR(20),
		Goal			VARCHAR(10),
		OddsSpread		VARCHAR(20)
	)

	CREATE TABLE #tblBetType_Detail
	(
		Id				SMALLINT,
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(50),
		[Value]			SMALLMONEY,
		ValueHdp1		SMALLMONEY,
		ValueHdp2		SMALLMONEY,
		TimeInterval	SMALLMONEY,	
		Goal			BIGINT,
		OddsSpread		MONEY
	)
	
	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	

	DECLARE @SettledType VARCHAR(100) = 'All'
		   ,@StatusIds	 VARCHAR(50) =''
		   ,@FilterBy	 TINYINT = NULL
	
	CREATE TABLE #tmpTransInfo(
			   matchid INT
			  ,transid BIGINT
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
			  ,betfrom NVARCHAR(3)
			  ,bettype SMALLINT
			  ,betteam NVARCHAR(10)
			  ,betcheck NVARCHAR(50)
			  ,Status NVARCHAR(10)
			  ,transdate DATETIME
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
			  ,Subbetfrom NVARCHAR(3)
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
		    matchid,transid,Subtransid ,refno ,custid,hdp1,hdp2 ,livehomescore ,liveawayscore,liveindicator,odds,oddsid,oddsspread 
           ,betfrom ,bettype,betteam,betcheck,Status,transdate,betid,Transdesc,statusID 
	       ,Subcustid,Subhdp1,Subhdp2,Sublivehomescore,Subliveawayscore,Subliveindicator 
	       ,Subodds,Suboddsspread,Subbetfrom,Subbettype,Subbetteam ,Subbetcheck,SubStatus,Subtransdate,SubTransdesc,SubstatusID 
	       ,srecommend,mrecommend,recommend,creator,WalletType,RefCode,stake,oddstype,CurrencyName,betdaqid ,ExtraInfo ,BonusID ,winlost	
	       ,actual_stake ,winlostdate,modds ,IsMixParlay ,SiteDBGroupID 
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

	IF @IssueTypeId IN (11,15) --11: AbnormalBet, 15: AB(RealMember)
	BEGIN
		IF @IssueTypeId = 11
		BEGIN
			SELECT @FilterBy = FilterBy
			FROM dbo.TicketVoiding_RequestDetail WITH (NOLOCK)
			WHERE RequestId = @RequestId
		END

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
				,IsMarked
				,LiveIndicator
				,mainstatusid
				,ActualStake
				,matchid
				,IsMixParlay
				,winlostdate
				,SiteDBGroupID
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
				,b.Status
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
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
				,b.actual_stake AS ActualStake
				,b.matchid
				,CASE WHEN @IssueTypeId = 11 AND @FilterBy = 1 THEN 1 ELSE 0 END AS IsMixParlay
				,b.winlostdate
				,b.SiteDBGroupID
		FROM #tmpTransInfo b 
			CROSS APPLY (
					SELECT TOP 1 TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single  WITH (NOLOCK)
					WHERE RequestId = @RequestId AND b.transid = TransId AND b.matchid = MatchId
			)ts
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
		WHERE  b.statusID NOT IN (101, 102, 103) -- reject, void, refund
	END
	ELSE IF @IssueTypeId IN (1, 10, 3, 4, 5, 6, 7) -- Danger Accept, Red Card, WrongScore, WrongHDP, Wrong OU
	BEGIN
		IF @BetTypes IS NOT NULL
		BEGIN
			-- Parse xml @BetTypes
			INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread)
			SELECT t.c.value('@Id','SMALLINT') AS Id
					, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
					, t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
					, t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
					, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
					, t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
					, t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1		-- check columns : hdp1	 ; single-choice + multi-choice
					, t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2		-- check columns : hdp2	 ; single-choice
					, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
					, t.c.value('@OddsSpread', 'VARCHAR(20)') AS OddsSpread	-- Check columns : OddsSpread ; single value
			FROM @BetTypes.nodes('BetTypes/BetType') t(c)
			OPTION (OPTIMIZE FOR (@BetTypes = NULL))
			 
			INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, TimeInterval, Goal, OddsSpread)
			SELECT cte.Id
				 , CASE
						WHEN cte.Id = 30 AND cte.BetTeam = '4:0up' THEN '4:0' -- replace row [bettype 30 - betteam '4:0up'] by [bettype 30 - betteam '4:0'] 
						WHEN cte.Id = 30 AND cte.BetTeam = '0:4up' THEN '0:4' -- replace row [bettype 30 - betteam '0:4up'] by [bettype 30 - betteam '0:4']
						WHEN cte.Id = 179 AND cte.BetTeam = 'G4&Over' THEN 'G4' -- replace row [bettype 179 - betteam 'G4&Over'] by [bettype 179 - betteam 'G4'] 
						ELSE cte.BetTeam
				   END AS BetTeam
				 , cte.[Set]
				 , cte.Game
				 , cte.BetOption
				 , CAST(CASE WHEN (cte.GroupId IS NULL) AND (cte.Id NOT IN (479, 481)) THEN cte.[Value]
							ELSE @ValueDefault END AS SMALLMONEY) AS [Value]
				 , cte.ValueHdp1
		 		 , cte.ValueHdp2
				 , CAST(CASE WHEN (cte.GroupId IN (1,2)) OR (cte.Id IN (479, 481)) THEN cte.[Value]
							ELSE @ValueDefault END AS SMALLMONEY) AS TimeInterval
				 , cte.Goal
				 , cte.OddsSpread
			FROM (
				SELECT cte.Id
					 , bt.value AS BetTeam 
					 , cte.[Set]
					 , cte.Game
					 , bop.value AS BetOption
					 , CAST(CASE WHEN v.value = 'ALL' THEN @ValueDefault 
								ELSE v.value END AS SMALLMONEY) AS [Value]
					 , CAST(CASE WHEN vhdp1.value = 'ALL' THEN @ValueDefault 
							ELSE vhdp1.value END AS SMALLMONEY) AS ValueHdp1
					 , CAST(CASE WHEN cte.ValueHdp2 = 'ALL' THEN @ValueDefault 
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2
					 , CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
								ELSE cte.Goal END AS BIGINT) AS Goal
					 , CAST(CASE WHEN cte.OddsSpread = 'ALL' THEN @ValueDefault 
								ELSE cte.OddsSpread END AS MONEY) AS OddsSpread
					 ,f.GroupId
				FROM #tblBetType cte
					 CROSS APPLY STRING_SPLIT(cte.betteam, ',') bt
					 CROSS APPLY STRING_SPLIT(cte.BetOption, ',') bop
					 CROSS APPLY STRING_SPLIT(cte.[Value], ',') v
					 CROSS APPLY STRING_SPLIT(cte.ValueHdp1, ',') vhdp1
					 OUTER APPLY (
									SELECT GroupId
									FROM dbo.f_TVS_CheckingProcessGroupBettypes()
									WHERE Bettype = cte.Id
								)f
			) cte	
			WHERE CASE WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
					WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
					ELSE 1 END = 1

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
					,IsMarked
					,LiveIndicator
					,FilterBettype
					,FilterBetTeam
					,FilterSet
					,FilterGame	
					,FilterValue
					,FilterHdp1
					,FilterHdp2
					,FilterGoal
					,FilterBetOption
					,FilterTimeInterval
					,mainstatusid
					,FilterOddsSpread
					,ActualStake
					,matchid
					,SiteDBGroupID
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
					,b.Status
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
					,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
					,b.liveindicator
					,b.bettype AS FilterBetType
					,b.betteam AS FilterBetTeam
					,b.betid AS FilterSet
					,RIGHT(b.betid, 2) AS FilterGame
					,b.hdp1 + b.hdp2 AS FilterValue
					,b.hdp1 AS FilterHdp1
					,CASE WHEN bt.id = 646 THEN ABS(b.hdp2) ELSE b.hdp2 END AS FilterHdp2 --646: Match Handicap & Total
					,ISNULL(b.betid, 0) AS FilterGoal
					,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
					,b.hdp1 AS FilterTimeInterval
					,b.statusID AS mainstatusid
					,CASE WHEN bt.id = 229 THEN ABS(b.oddsspread) ELSE b.oddsspread END AS FilterOddsSpread --229:SABA HDP Time Machine
					,b.actual_stake AS ActualStake
					,b.matchid
					,b.SiteDBGroupID
			FROM #tmpTransInfo b	
				LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
				CROSS APPLY (
							SELECT TOP (1) transid
							FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
							WHERE transid = b.transid
								AND matchid = b.matchid
								AND RequestId = @RequestId
					) ts
				INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = b.bettype
			WHERE	b.matchId = @MatchId
					AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
					AND b.bettype NOT IN (805, 806, 9, 29)			
					AND b.bettype NOT BETWEEN 901 AND 920
					AND b.IsMixParlay = 0
					AND b.betfrom <> 'P'
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE b.liveawayscore END
		
			---get sub ticket of a mix parlay	
			IF EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo bm WHERE bm.IsMixParlay = 1 AND bm.matchid = @MatchId)
			BEGIN		
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
						,Subhdp1
						,Subhdp2
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
						,Transdesc		
						,ParlayType		
						,IsMixParlay
						,modds
						,WinLost
						,IsMarked
						,LiveIndicator
						,FilterBettype
						,FilterBetTeam
						,FilterSet
						,FilterGame	
						,FilterValue
						,FilterHdp1
						,FilterHdp2
						,FilterGoal
						,mainstatusid
						,FilterOddsSpread
						,ExtraInfo
						,ActualStake
						,matchid
						,SiteDBGroupID
					)
				SELECT 
						bm.transid AS GroupID
						,bm.transid 
						,bm.SubTransID
						,bm.refno
						,bm.Subcustid				
						,bm.odds
						,bm.SubOdds
						,bm.Suboddsspread
						,bm.OddsType
						,bm.Subtransdate
						,bm.bettype
						,bm.betteam
						,bm.Subbetteam
						,bm.betcheck				
						,bm.Subbetcheck
						,bm.Subhdp1
						,bm.Subhdp2
						,bm.hdp1
						,bm.hdp2
						,bm.Sublivehomescore
						,bm.Subliveawayscore
						,bm.creator
						,bm.stake
						,bm.currencyname				
						,bm.STATUS
						,bm.SubStatus
						,bm.srecommend
						,bm.mrecommend
						,bm.recommend
						,bm.SubTransdesc
						,bm.Subbettype
						,bm.IsMixParlay
						,bm.modds
						,bm.winlost - bm.actual_stake AS WinLost
						,0
						,bm.Subliveindicator
						,bm.Subbettype AS FilterBetType
						,bm.Subbetteam AS FilterBetTeam
						,bm.Subbetcheck AS FilterSet
						,RIGHT(bm.Subbetcheck, 2) AS FilterGame
						,bm.Subhdp1 + bm.Subhdp2 AS FilterValue
						,bm.Subhdp1 AS FilterHdp1
						,CASE WHEN tp.id = 646 THEN ABS(bm.Subhdp2) ELSE bm.Subhdp2 END AS FilterHdp2 --646: Match Handicap & Total
						,ISNULL(bm.Subbetcheck, 0) AS FilterGoal
						,bm.statusID AS mainstatusid
						,CASE WHEN tp.id = 229 THEN ABS(bm.Suboddsspread) ELSE bm.Suboddsspread END AS FilterOddsSpread --229:SABA HDP Time Machine
						,bm.ExtraInfo
						,bm.actual_stake AS ActualStake
						,bm.matchid
						,bm.SiteDBGroupID
				  FROM #tmpTransInfo bm
						INNER JOIN #tblBettype tp
							ON	bm.Subbettype = tp.Id
						CROSS APPLY (
									SELECT TOP (1) transid
									FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
									WHERE transid = bm.Subtransid AND matchid = bm.matchid AND RequestId = @RequestId
							) ts
				WHERE	bm.matchid = @MatchId
						AND bm.SubstatusID NOT IN (101, 102, 103) -- reject, void, refund
						AND bm.IsMixParlay = 1
						AND bm.Subbetfrom <> 'P'
						AND bm.Sublivehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE bm.Sublivehomescore END
						AND bm.Subliveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE bm.Subliveawayscore END
			END 

			/*
				filter for [Set] (+ [Quarter])
				[Set] : 8xx; 1324 : 8xxyy
				[Quarter] : 80X; 613 : 80XYY		
				filter for Game : Only handle for bettype 1324		 
				filter for BetOption : Only handle for bettypes 221 -> 227		 
				filter for [Value]
				filter for ValueHdp1	
				filter for ValueHdp2	
				filter for TimeInterval		 
				filter for Goal
			*/			
			BEGIN
				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND 
						CASE
							WHEN tp.Id <> 376 THEN CASE WHEN tp.BetTeam = 'All' OR b.FilterBetTeam = tp.BetTeam THEN 1 ELSE 0 END
							ELSE 
								CASE tp.BetTeam
									 WHEN 'All-All' THEN 1
									 WHEN 'All-S' THEN CASE WHEN b.FilterBetTeam LIKE '%S%' THEN 1 ELSE 0 END
									 WHEN 'All-M' THEN CASE WHEN b.FilterBetTeam LIKE '%M%' THEN 1 ELSE 0 END
									 WHEN 'H-All' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) <> '-----' THEN 1 ELSE 0 END
									 WHEN 'A-All' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) <> '-----' THEN 1 ELSE 0 END
									 WHEN 'H-S' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) LIKE '%S%' THEN 1 ELSE 0 END
									 WHEN 'H-M' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) LIKE '%M%' THEN 1 ELSE 0 END
									 WHEN 'A-S' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) LIKE '%S%' THEN 1 ELSE 0 END
									 WHEN 'A-M' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) LIKE '%M%' THEN 1 ELSE 0 END
									 ELSE 0
								END
						END = 1
				)

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%'  ))

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ) OR b.bettype = 29)

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.FilterHdp2 = tp.ValueHdp2 ))

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.TimeInterval = 9999 OR b.FilterTimeInterval = tp.TimeInterval ) OR b.bettype = 29) 

				DELETE b
				FROM  #TVSTicketBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread ))
			END
		END
		ELSE
		BEGIN
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
					,IsMarked
					,LiveIndicator
					,mainstatusid
					,ActualStake
					,matchid
					,SiteDBGroupID
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
					,b.Status
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
					,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
					,b.liveindicator
					,b.statusID AS mainstatusid
					,b.actual_stake AS ActualStake
					,b.matchid
					,b.SiteDBGroupID
			FROM	#tmpTransInfo b
			   LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
			   CROSS APPLY (
							SELECT TOP (1) transid
							FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
							WHERE transid = b.transid AND matchid = b.matchid AND RequestId = @RequestId
					) ts
			WHERE b.matchid = @MatchId AND b.IsMixParlay = 0
					AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
					AND b.bettype NOT IN (805, 806, 9, 29)			
					AND b.bettype NOT BETWEEN 901 AND 920
					AND b.betfrom <> 'P'
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE b.liveawayscore END
					
			---get sub ticket of a mix parlay	
			IF EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo AS bm  WHERE bm.IsMixParlay = 1 AND bm.matchid = @MatchId)
			BEGIN		
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
						,Subhdp1
						,Subhdp2
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
						,Transdesc		
						,ParlayType		
						,IsMixParlay
						,modds
						,WinLost
						,IsMarked
						,LiveIndicator
						,mainstatusid
						,ExtraInfo
						,ActualStake
						,matchid
						,SiteDBGroupID
					)
				SELECT 
						bm.transid AS GroupID
						,bm.transid AS TransId
						,bm.SubTransID
						,bm.refno
						,bm.custid				
						,bm.odds
						,bm.SubOdds
						,bm.Suboddsspread
						,bm.OddsType
						,bm.Subtransdate
						,bm.bettype
						,bm.betteam
						,bm.Subbetteam
						,bm.betcheck				
						,bm.Subbetcheck
						,bm.Subhdp1
						,bm.Subhdp2
						,bm.hdp1
						,bm.hdp2
						,bm.Sublivehomescore
						,bm.Subliveawayscore
						,bm.creator
						,bm.stake
						,bm.currencyname				
						,bm.STATUS
						,bm.SubStatus
						,bm.srecommend
						,bm.mrecommend
						,bm.recommend
						,bm.SubTransdesc
						,bm.Subbettype
						,bm.IsMixParlay
						,bm.modds
						,bm.winlost - bm.actual_stake AS WinLost
						,0
						,bm.Subliveindicator
						,bm.statusID AS mainstatusid
						,bm.ExtraInfo
						,bm.actual_stake AS ActualStake
						,bm.matchid
						,bm.SiteDBGroupID
				FROM	#tmpTransInfo bm 
						CROSS APPLY (
									SELECT TOP (1) transid
									FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
									WHERE transid = bm.Subtransid AND matchid = bm.matchid AND RequestId = @RequestId
							) ts
				WHERE	bm.matchid = @MatchId
						AND bm.SubstatusID NOT IN (101, 102, 103) -- reject, void, refund
						AND bm.Subbetfrom <> 'P' AND bm.IsMixParlay = 1
						AND bm.Sublivehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE bm.Sublivehomescore END
						AND bm.Subliveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE bm.Subliveawayscore END
			END 
		END
	END
	ELSE IF @IssueTypeId = 13 -- Abnormal account
	BEGIN
		SET @StatusIds = (SELECT TOP 1 TicketStatusIds FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK) WHERE RequestId = @RequestId)
		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@StatusIds, ',')

		INSERT INTO #TVSTicketBets (
			GroupID			
			,transid
			,SubTransid		
			,betid			
			,refno		
			,hdp1			
			,hdp2			
			,odds
			,oddsspread				
			,OddsType		
			,STATUS	
			,SubStatus				
			,stake							
			,transdate		
			,bettype		
			,betteam		
			,betcheck		
			,liveindicator	
			,modds			
			,custid						
			,livehomescore	
			,liveawayscore						
			,matchid					
			,winlost		
			,TransDesc		
			,betdaqid
			,recommend
			,ExtraInfo
			,IsCashOut
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,IsMarked
			,oddsid
			,srecommend
			,mrecommend	
			,winlostdate
			,statusID
			,ActualStake
			,mainstatusid
			,creator
			,SiteDBGroupID
		)
		SELECT	
			b.transid AS GroupId
			,b.transid
			,b.transid AS SubTransid	
			,ISNULL(b.BetID, 0) AS BetID
			,b.refno			
			,b.hdp1
			,b.hdp2
			,b.odds
			,b.oddsspread
			,b.OddsType
			,b.STATUS
			,b.SubStatus
			,b.stake				
			,b.transdate
			,b.bettype
			,b.betteam
			,b.betcheck
			,b.liveindicator
			,b.modds
			,b.custid
			,b.livehomescore
			,b.liveawayscore				
			,b.matchid				
			,(b.winlost - b.actual_stake) winlost
			,b.transdesc
			,b.betdaqid
			,b.recommend			
			,b.ExtraInfo
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.oddsid
			,b.srecommend
			,b.mrecommend
			,b.winlostdate
			,b.statusID
			,b.actual_stake AS ActualStake
			,b.statusID AS mainstatusid
			,b.creator
			,b.SiteDBGroupID
		FROM #tmpTransInfo b 
			CROSS APPLY (
					SELECT TOP 1 TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single  WITH (NOLOCK)
					WHERE RequestId = @RequestId AND b.transid = TransId AND b.matchid = MatchId
			)ts
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
		WHERE b.statusID NOT IN (101, 102, 103)
				
	END
	ELSE IF @IssueTypeId in (8,9) AND @RequestId <> 0 --EKO, WKO
	BEGIN
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
				,IsMarked
				,LiveIndicator
				,mainstatusid
			    ,ActualStake
				,matchid
				,SiteDBGroupID
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
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
			    ,b.actual_stake AS ActualStake
				,b.matchid
				,b.SiteDBGroupID
		FROM #tmpTransInfo b 
			CROSS APPLY (
					SELECT TOP 1 TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single  WITH (NOLOCK)
					WHERE RequestId = @RequestId AND b.transid = TransId AND b.matchid = MatchId
			)ts
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
		WHERE b.IsMixParlay = 0 AND b.statusID NOT IN (101, 102, 103) 
		
		---get sub ticket of a mix parlay	
		IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo AS bm  WHERE bm.IsMixParlay = 1)
		BEGIN		
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
					,Subhdp1
					,Subhdp2
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
					,Transdesc		
					,ParlayType		
					,IsMixParlay
					,modds
					,WinLost
					,IsMarked
					,LiveIndicator
					,mainstatusid
					,ExtraInfo
					,ActualStake
					,matchid
					,SiteDBGroupID
				)
			SELECT 
					bm.transid AS GroupID
					,bm.transid 
					,bm.SubTransID
					,bm.refno
					,bm.Subcustid				
					,bm.odds
					,bm.SubOdds
					,bm.Suboddsspread
					,bm.OddsType
					,bm.Subtransdate
					,bm.bettype
					,bm.betteam
					,bm.Subbetteam
					,bm.betcheck				
					,bm.Subbetcheck
					,bm.Subhdp1
					,bm.Subhdp2
					,bm.hdp1
					,bm.hdp2
					,bm.Sublivehomescore
					,bm.Subliveawayscore
					,bm.creator
					,bm.stake
					,bm.currencyname				
					,bm.Status
					,bm.SubStatus
					,bm.srecommend
					,bm.mrecommend
					,bm.recommend
					,bm.SubTransdesc
					,bm.Subbettype
					,1 AS IsMixParlay
					,bm.modds
					,bm.winlost - bm.actual_stake AS WinLost
					,0
					,bm.Subliveindicator
					,bm.statusID AS mainstatusid
					,bm.ExtraInfo
					,bm.actual_stake AS ActualStake
					,bm.matchid
					,bm.SiteDBGroupID
			FROM	#tmpTransInfo bm
					CROSS APPLY (
							SELECT TOP 1 rs.TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
							WHERE rs.TransId = bm.Subtransid AND rs.MatchId = bm.matchid AND rs.RequestId = @RequestId
						)tmp
			WHERE	bm.IsMixParlay = 1
					AND bm.statusID NOT IN (101, 102, 103)
		END 
	END
	ELSE IF @IssueTypeId in (8,9) AND @RequestId = 0
	BEGIN
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
				,IsMarked
				,LiveIndicator
				,mainstatusid
			    ,ActualStake
				,matchid
				,modds
				,SiteDBGroupID
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
				,b.Status
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
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
			    ,b.actual_stake AS ActualStake
				,b.matchid
				,b.modds
				,b.SiteDBGroupID
		FROM #tmpTransInfo b
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
		WHERE b.IsMixParlay = 0

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
					,Subhdp1
					,Subhdp2
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
					,Transdesc		
					,ParlayType		
					,IsMixParlay
					,modds
					,WinLost
					,IsMarked
					,LiveIndicator
					,mainstatusid
					,ExtraInfo
					,ActualStake
					,matchid
					,SiteDBGroupID
				)
			SELECT 
					t.transid AS GroupID
					,t.transid AS TransId
					,t.Subtransid
					,t.refno
					,t.Subcustid				
					,t.odds
					,t.Subodds
					,t.Suboddsspread
					,t.OddsType
					,t.Subtransdate
					,t.bettype
					,t.betteam
					,t.Subbetteam
					,t.betcheck				
					,t.Subbetcheck
					,t.Subhdp1
					,t.Subhdp2
					,t.hdp1
					,t.hdp2
					,t.Sublivehomescore
					,t.Subliveawayscore
					,t.creator
					,t.stake
					,t.currencyname				
					,t.STATUS
					,t.SubStatus
					,t.srecommend
					,t.mrecommend
					,t.recommend
					,t.SubTransdesc
					,t.Subbettype AS parlaytype
					,1 AS IsMixParlay
					,t.modds
					,t.winlost - t.actual_stake AS WinLost
					,0
					,t.Subliveindicator
					,t.statusID AS mainstatusid
					,t.ExtraInfo
					,t.actual_stake AS ActualStake
					,t.matchid
					,t.SiteDBGroupID
			FROM	#tmpTransInfo t		
			WHERE IsMixParlay = 1
	END	

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
			,eventstatus = ISNULL(m.eventstatus,'')
			,SubLeagueId = m.leagueid
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
		FROM #TVSTicketBets d
			INNER JOIN dbo.match m WITH (NOLOCK) 
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
			,eventstatus = ISNULL(odds.oddsstatus,'')
			,SubLeagueId = odds.leagueid
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
				,SubLeagueId = r.leagueid
				,SettlementStatus = 0
		FROM #TVSTicketBets d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
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
		AND ( sporttype IS NULL OR bettype = 500) /*charge comm*/
			
	-- update username/creatorname column
	UPDATE al
		SET username = ci.username
			,creatorName = cr.username
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
	
	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		
		--> Get status of match
		;WITH cte_match AS
		(
			SELECT DISTINCT t.matchid
			FROM #TVSTicketBets t
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
		)
		,cte_isCalHT AS
		(
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM cte_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
		)
		--> Build bettype list supported for instant settlement based on settlement status of match
		INSERT INTO #InstantSettlementBettypes (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM cte_isCalHT c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_TVS_GetInstantBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							ELSE 0 END
			)f	 	
	END	

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
			   ,s.IsCashOut
			   ,s.GroupId
			   ,CASE WHEN ISNULL(s.betdaqid,0) <> -2 THEN 'Credit' ELSE 'Credit (CO)' END AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
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
			   ,s.IsDeposit
			   ,s.eventstatus
			   ,s.SettlementStatus
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
			   ,s.IsCashOut
			   ,s.GroupId
			   ,'8RM/BARM' AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
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
			   ,s.IsDeposit
			   ,s.eventstatus
			   ,s.SettlementStatus
			   ,s.SiteDBGroupID
		FROM	#TVSTicketBets s 
			--LEFT JOIN dbo.bettrans b WITH(NOLOCK)
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
			   ,s.IsCashOut
			   ,s.GroupId
			   ,CASE WHEN ISNULL(s.betdaqid,0) <> -2 THEN 'Deposit' ELSE 'Deposit (CO)' END AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
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
			   ,s.IsDeposit
			   ,s.eventstatus
			   ,s.SettlementStatus
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
		   ,s.IsCashOut
		   ,s.GroupId
		   ,'Betfair' AS OriginGroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.BonusID
		   ,s.RefCode
		   ,s.WinLost
		   ,s.IsMarked
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
		   ,s.IsDeposit
		   ,s.eventstatus
		   ,s.SettlementStatus
		   ,s.SiteDBGroupID
		FROM	#TVSTicketBets s WITH (NOLOCK)
			LEFT JOIN #TVSTicketBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
	)
	, CTE_InstantSettlementSubgrouping AS (
		/*
			Cases for dividing for instant settlement subgroup :
				1. Before match is kicked off : No ticketes in group 'Instant Settlement'.
				2. Before HT calculated : Ticketes that are settled ('WON', 'LOSE', 'DRAW')
										  and their bettype in list of HT instant settlement bettypes are in group 'Instant Settlement'
				3. After HT calculated : Ticketes that are settled  ('WON', 'LOSE', 'DRAW')
										 and bettype in list of FT instant settlement bettypes are in group 'Instant Settlement'
				4. After match is completed : No ticketes in group 'Instant Settlement'.
		*/
		SELECT  s.*
			   ,CASE 
					WHEN s.eventstatus <> @eventstatus_completed -- cases 1, 2, 3 
							THEN CASE
									WHEN s.mainstatusid IN (111, 112, 113)  AND ISNULL(s.betdaqid,0) <> -2
										 AND EXISTS (SELECT TOP 1 1
													 FROM #InstantSettlementBettypes
													 WHERE bettype = s.bettype
													 )
											THEN s.OriginGroupName + ' (Instant Settlement)'
									ELSE s.OriginGroupName
								 END
					ELSE s.OriginGroupName -- case 4
				END AS SubGroupName
		FROM CTE_OriginResult s
	)
	, CTE_SettledTypeFiltering AS (
		SELECT s.*
		FROM CTE_InstantSettlementSubgrouping s
		WHERE CASE
					WHEN @SettledType = 'All' THEN 1
					WHEN @SettledType = 'Unsettled' 
							THEN CASE WHEN s.mainstatusid IN (0, 103) THEN 1
									ELSE 0
								 END
					WHEN @SettledType = 'Instantly' 
							THEN CASE WHEN s.SubGroupName LIKE '%(Instant Settlement)' THEN 1
									ELSE 0
								 END
					WHEN @SettledType = 'Settled' 
							THEN CASE WHEN s.mainstatusid IN (111, 112, 113)
										 AND s.SubGroupName NOT LIKE '%(Instant Settlement)' THEN 1
									ELSE 0
								 END
					ELSE 1
			  END = 1
	)	
	SELECT  s.transid 
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
		   ,s.IsCashOut
		   ,s.SubGroupName AS GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.RefCode
		   ,s.SettlementStatus 
		   ,s.WinLost
		   ,s.IsMarked
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
		   ,s.IsDeposit
		   ,ISNULL(si.IsChinaView,0) AS IsChinaView
		   ,CASE WHEN s.SubGroupName LIKE '%(Instant Settlement)' THEN 1 ELSE 0 END AS IsInstantSettlement
		   ,s.SiteDBGroupID
	FROM CTE_SettledTypeFiltering s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
		LEFT JOIN custDB.dbo.Site si WITH(NOLOCK) ON c.site = si.site
	WHERE 1 = CASE WHEN @IssueTypeId <> 13 THEN 1
				   WHEN @IssueTypeId = 13 AND  s.statusId IN (SELECT statusID FROM @Status_tmp)	 THEN 1 
				   ELSE 0 END
	ORDER BY CASE
				WHEN s.OriginGroupName = 'CN88' THEN 1
				WHEN s.OriginGroupName = 'Credit' THEN 2
				WHEN s.OriginGroupName = '8RM/BARM' THEN 3
				WHEN s.OriginGroupName = 'Deposit' THEN 4
				WHEN s.OriginGroupName = 'Betfair' THEN 5
				WHEN s.OriginGroupName = 'Credit (CO)' THEN 6
				WHEN s.OriginGroupName = 'Deposit (CO)' THEN 7
			 END
			, CASE WHEN s.SubGroupName NOT LIKE '%(Instant Settlement)' THEN 1
				ELSE 2
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
	
	DROP TABLE #TVSTicketBets
	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tmpTransInfo
END

GO

