/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Void14_Select] 
(
    @RequestId			INT = NULL
)
AS
/*	Created by: July
	Date 20211123
	Task: TVS - Void Archived Tickets [Redmine:#140180]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20211123@July: Create new SP - view voided ticket [Redmine:#140180]
		 
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	CREATE TABLE #SpecialDeleteBets (
		GroupID               BIGINT,
        transid               BIGINT,
        SubTransid            BIGINT,
        refno                 BIGINT,
        custid                INT,
        username              VARCHAR(30),
        odds                  MONEY,
        SubOdds               MONEY,
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
        ParlayType            SMALLINT DEFAULT(0),
        -- sub bettype of parlay 
        IsMixParlay           BIT DEFAULT(0),
        sporttype             SMALLINT,
        modds                 MONEY,
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
		winlostdate			  DATETIME,
		statusID			  TINYINT
    )
    CREATE TABLE #tmpRefCodeSummary
             (RefCode  BIGINT,
              custid   INT,
			  matchid  INT,
              bettype  SMALLINT,
              transid  BIGINT
             )

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	

	DECLARE @tmpMatchIDBatch TABLE (MatchID INT, bettype  SMALLINT)

	DECLARE @SettledType	VARCHAR(100) = 'All'
			,@MatchId		INT

	CREATE TABLE #TmpMatch( MatchId INT)

	INSERT INTO #TmpMatch( MatchId)
	SELECT DISTINCT rd.matchid
	FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
	WHERE rd.RequestId = @RequestId

	DECLARE @transIdTemp TABLE (transid BIGINT NULL);
				
	INSERT INTO @transIdTemp (transid)
	SELECT DISTINCT TransId
	FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
	WHERE RequestId = @RequestId
	
	-- search tickets : not metric gaming tickets, mix parlay tickets
	INSERT INTO #SpecialDeleteBets(
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
			,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS
				END AS STATUS
			,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS
				END AS SubStatus
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
	FROM	bettrans14 b WITH (NOLOCK)	
		INNER JOIN @transIdTemp t ON t.transid = b.transid
	WHERE  b.statusID NOT IN (101, 102, 103) -- reject, void, refund
		
	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #SpecialDeleteBets main
				INNER JOIN #SpecialDeleteBets sub
						ON main.RefCode = sub.RefCode
						AND main.transid <> sub.transid	
						AND main.custid = sub.custid
						AND main.bettype = sub.bettype
		WHERE main.WalletType = 1					
		  
		-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets  
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, matchid, bettype, transid)
		SELECT RefCode, custid, matchid, bettype
				, MAX(transid) AS transid
		FROM #SpecialDeleteBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, matchid, bettype
		HAVING COUNT(*) = 1

		IF @@ROWCOUNT > 0
		BEGIN	
			INSERT INTO #SpecialDeleteBets(
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
						,MainTransId
						,WinLost
						,LiveIndicator
						,mainstatusid
						,ActualStake
						,matchid
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
						,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								ELSE b.STATUS
							END AS STATUS
						,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								ELSE b.STATUS
							END AS SubStatus
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
						,t.transid AS MainTransId
						,b.winlost - b.actual_stake AS WinLost
						,b.liveindicator
						,b.statusID AS mainstatusid
						,b.actual_stake AS ActualStake
						,t.matchid
						,b.winlostdate
			FROM #tmpRefCodeSummary t
					INNER JOIN dbo.bettrans14 b WITH (NOLOCK)
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = t.matchid
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE b.statusID NOT IN (101, 102, 103)-- reject, void, refund	
		END  			    				    					    				    					    	
	END

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.match14 m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29, 2799)
	END
	
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (10)))
	BEGIN
		UPDATE d
		SET matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) 
			ON	d.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE d.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE d
			SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= r.leagueid
				,sporttype 	= r.sporttype
				,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
		FROM #SpecialDeleteBets d
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
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- UPDATE IsMixParlay = 1 [MixParlay bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (9, 29, 2799)))
	BEGIN
		UPDATE d
		SET IsMixParlay = 1
		FROM #SpecialDeleteBets d
		WHERE d.bettype IN (9, 29, 2799)
	END

	--- Remove invalid sporttype
	DELETE 
	FROM #SpecialDeleteBets
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
	FROM	#SpecialDeleteBets al
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
			ON al.custid = ci.custid
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK)
			ON al.creator = cr.custid
			
	-- update Isdeposit
	UPDATE al 
		SET IsDeposit = 1
	FROM	#SpecialDeleteBets al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)
	
	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(bettype	SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes(bettype)
		
		DECLARE @TempMatchID TABLE( MatchID INT, Bettype SMALLINT, IsFinish BIT)
		INSERT INTO @TempMatchID (MatchID,Bettype)
		SELECT m.MatchId, s.bettype
		FROM #TmpMatch m
		CROSS APPLY ( SELECT DISTINCT s.bettype
						FROM #SpecialDeleteBets s where m.matchid = s.matchid
					)s

		DECLARE @OldMatchID INT = 0
		WHILE (1=1) -- multiple match = 0
		BEGIN
			DELETE @tmpMatchIDBatch
			UPDATE TOP (1) m
				SET IsFinish = 1
					,@MatchId = m.MatchID
			OUTPUT DELETED.matchid
					,DELETED.bettype
			INTO @tmpMatchIDBatch (MatchID, bettype)
			FROM @TempMatchID m
				WHERE IsFinish IS NULL
				
			IF @@ROWCOUNT = 0 BREAK

			--> Get status of match
			SELECT @IsHTCal = ISNULL(IsHTCal, 0)		 
			FROM dbo.match_remark (NOLOCK)
			WHERE matchid = @MatchId
	
			SELECT @eventstatus = ISNULL(eventstatus, '')
			FROM dbo.match14 (NOLOCK)
			WHERE matchid = @MatchId
	
			--> Build bettype list supported for instant settlement based on settlement status of match
			IF @eventstatus <> @eventstatus_completed
			BEGIN
				IF @IsHTCal = 0 AND @MatchId <> @OldMatchID
					INSERT INTO #InstantSettlementBettypes(bettype)
					SELECT T.bettype
					FROM dbo.f_Set_Instant_GetBettypes() T
					WHERE T.InstantType IN (1, 3) -- 01, 11

				IF @IsHTCal = 1 AND @MatchId <> @OldMatchID
					INSERT INTO #InstantSettlementBettypes(bettype)
					SELECT T.bettype
					FROM dbo.f_Set_Instant_GetBettypes() T
					WHERE T.InstantType IN (2, 3) -- 10, 11				
			END	

			SET @OldMatchID = @MatchId
		END
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
		FROM	#SpecialDeleteBets s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #SpecialDeleteBets sub
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
			   ,b.transid AS followedId
			   ,b.Username AS followedUsername			   
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
		FROM	#SpecialDeleteBets s 
			LEFT JOIN dbo.bettrans14 b WITH(NOLOCK)
				ON	s.betid = b.transid
					AND b.matchid = s.matchid	
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
		FROM	#SpecialDeleteBets s 
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #SpecialDeleteBets sub
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
		FROM	#SpecialDeleteBets s WITH (NOLOCK)
			LEFT JOIN #SpecialDeleteBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
	)
	, CTE_CalculateMainBettype AS (
		SELECT s.*
			 , s.bettype AS MainBettype
		FROM CTE_OriginResult s
	)
	, CTE_InstantSettlementSubgrouping AS (
		/*
			Cases for dividing for instant settlement subgroup:
				1. Before match is kicked off : No ticketes in group 'Instant Settlement'.
				2. Before HT calculated : Ticketes that are settled ('WON', 'LOSE', 'DRAW')
										  and their bettype in list of HT instant settlement bettypes are in group 'Instant Settlement'
				3. After HT calculated : Ticketes that are settled  ('WON', 'LOSE', 'DRAW')
										 and bettype in list of FT instant settlement bettypes are in group 'Instant Settlement'
				4. After match is completed : No ticketes in group 'Instant Settlement'.
		*/
		SELECT  s.*
			   ,CASE 
					WHEN @eventstatus <> @eventstatus_completed -- cases 1, 2, 3 
							THEN CASE
									WHEN s.mainstatusid IN (111, 112, 113) AND s.betdaqid <> -2
										 AND EXISTS (SELECT TOP 1 1
													 FROM #InstantSettlementBettypes
													 WHERE bettype = s.MainBettype
													 )
											THEN s.OriginGroupName + ' (Instant Settlement)'
									ELSE s.OriginGroupName
								 END
					ELSE s.OriginGroupName -- case 4
				END AS SubGroupName
		FROM CTE_CalculateMainBettype s
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
	SELECT CASE WHEN s.bettype BETWEEN 801 AND 806 THEN s.refno ELSE s.transid END transid
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
		   ,s.SubGroupName AS GroupName
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
	FROM CTE_SettledTypeFiltering s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
	ORDER BY CASE
				WHEN s.OriginGroupName = 'CN88' THEN 1
				WHEN s.OriginGroupName = 'Credit' THEN 2
				WHEN s.OriginGroupName = '8RM/BARM' THEN 3
				WHEN s.OriginGroupName = 'Deposit' THEN 4
				WHEN s.OriginGroupName = 'Betfair' THEN 5 
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
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #TmpMatch
END

GO