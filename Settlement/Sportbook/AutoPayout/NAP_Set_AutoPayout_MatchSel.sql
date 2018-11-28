/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_MatchSel
	  @FromDate 			DATETIME
	, @ToDate 			DATETIME
	, @SportType 			SMALLINT = 0
	, @LeagueID 			INT = 0 -- 0 for ALL Leagues
	, @MatchCode 			NVARCHAR(50) = ''
	, @StatusId 			TINYINT = 0
	, @FilterBy 			TINYINT = 0
	, @IsReLoad 			BIT = 0
	, @IsHTOverOnly 		BIT = 0
	, @IsOverOnly 			BIT = 0
	, @AutoSetting 		TINYINT = 0
AS
/*  
 Created by: 20160311@Patrick
 Task: Auto Payout - Match results for calculating settlement 
 DB: DBTXN/BODB02
 Original: Acc_Set_MatchSel
		 - NAP_Acc_Set_MatchSel
 Revisions:  
	- 20160801@Patrick: Auto Payout - User can cal MP before calculating FT FGLG [Redmine: #61767]
	- 20160713@Patrick: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
	- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
	- 20160930@Bobby: #65002 - Implement Auto CAL page info: update Instant match status & enable link FGLG when existing parlay tickets
	- 20161026@Bobby: #65002 - Do refactor code and move to DBTXN
	- 20161118@Kathy: Changes on Auto Settlement [Redmine:#67328]
	- 20160509@Patrick: Fast market integration [Redmine: #56367]
	- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
    - 20161223@Bobby: #69335 - Add filtering by Abandoned status
    - 20170313@Kathy: Check betstatus result for bettype 14,127 to notify user do CAL FGLG [Redmine:#73218]
	- 20170320@Bobby: Add filtering by abandoned status for Un-calculated multiple only option [Redmine:#73597]
	- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
	- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
	- 20180131@Benjamin: Add "SourceID = 100" to filter correct score from Suspender before confirm [Redmine:#86964]
	- 20180206@Kathy: Add new column IsFTCalculated to determine whether match calculated FT or not [Redmine:#86964]
	- 20180208@Benjamin: Implement to determine AutoIntant and ManualInstant [Redmine:#86964]
	- 20180528@Benjamin: Allow show button when Refund [Redmine:#86964]
	- 20180530@Benjamin: Convert HomeValue, AwayValue to number before comparing [Redmine:#86964]
	- 20180806@Kathy: Get waiting time for auto instant [Redmine:#86964]
	- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
	- 20181127@Vicky: Add MTD Hold status & Postponed [Redmine: #104948]
	
 Param explanation:  
	@MatchCode: match code
	@LeagueID: = 0: show info of all leagues     
	@StatusId: 0: all, 1: running; 2: closed; 3: completed; 4: refund; 5: Postponed, 6:Abandoned, 7: Result Pending, 8: Undecided, 9: Under Settlement, 10: MTD Hold
	@FilterBy: 0: none, 1: un-calculated game; 2: Un-calculated multiple only; 3: all
	@PenaltyShootoutOnly: 0: none; 1: running penalty shootout only
	@IsReLoad: 1: reload partial matches of a league, 0: not reload
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @UncalOnly BIT, @UncalMultiOnly BIT, @EventStatus NVARCHAR(50), @IsRefund BIT
		, @MatchId INT, @Today DATETIME
		,@SettlementStatus TINYINT

	SELECT @matchcode 	= ISNULL(@matchcode, '')
		, @LeagueID 	= ISNULL(@LeagueID, 0)
		, @filterBy 	= ISNULL(@filterBy, 0)
		, @Today 		= GETDATE()
		, @MatchId 	= 0

	-- if entering matcode, ignore other params (excep FromDate, ToDate, sport type)
	IF @matchcode <> ''
	BEGIN
		SELECT @eventstatus = '', @isRefund = NULL, @UncalOnly = NULL, @UncalMultiOnly = NULL
			, @LeagueID = CASE WHEN @isReLoad = 1 THEN @LeagueID 
							ELSE 0 END -- reload partial; search on LeagueID, not reload: get all leagues
			,@SettlementStatus = 0

		IF ISNUMERIC(@matchcode) = 1
		BEGIN
			SET @MatchId = CAST(@matchcode AS INT)
		END
		ELSE
		BEGIN
			SELECT @MatchId = matchid
			FROM dbo.match m WITH(NOLOCK) WHERE matchcode = @matchcode
		END
	END
	ELSE
	BEGIN
		SELECT @eventstatus = CASE 
								WHEN @statusid = 1 THEN 'running'
								WHEN @statusid = 2 THEN 'closed'
								WHEN @statusid IN (3,6) THEN 'completed'
								WHEN @statusid = 5 THEN 'postponed'
								ELSE ''	END
			, @isRefund = CASE 
							WHEN @statusid IN (4,6) THEN 1
							WHEN @statusid = 0 THEN NULL
							ELSE 0 
						END
			, @UncalOnly = CASE WHEN @filterBy IN (3, 1) THEN 1
							ELSE 0 END
			, @UncalMultiOnly = CASE WHEN @filterBy IN (3, 2) THEN 1
								ELSE 0 END
			,@SettlementStatus = CASE
				WHEN @StatusId = 7 THEN 1
				WHEN @StatusId = 8 THEN 2
				WHEN @StatusId = 9 THEN 4
				WHEN @StatusId = 10 THEN 16
				ELSE 0 
				END

		--ignore event status if selecting filterby
		IF (@UncalMultiOnly = 1 OR @UncalOnly = 1 OR @SettlementStatus <> 0 )
			SELECT @eventstatus = '', @isRefund = NULL
	END

	CREATE TABLE #matchList (HalfTimeHomeScore INT
		, HalfTimeAwayScore INT
		, IsCalculated BIT
		, IsFTCalculated BIT
		, IsMultiCaled BIT
		, IsRefund BIT
		, IsCalRefund BIT
		, matchid INT PRIMARY KEY
		, leagueid INT
		, homeid INT
		, awayid INT
		, matchcode NVARCHAR(50)
		, kickofftime DATETIME
		, finalhomescore INT
		, finalawayscore INT
		, betstatus NVARCHAR(50)
		, eventstatus NVARCHAR(50)
		, sporttype SMALLINT
		, IsNeutral BIT
		, eventdate DATETIME
		, goalrecord VARCHAR(50)
		, suspenderHalfTime NVARCHAR(50)
		, suspenderFullTime NVARCHAR(50)
		, IsHalfTimeCal BIT
		, SettlementStatus TINYINT
		, IsExistFGLG BIT -- is exist ticket of bettype 14
		, IsExistHTFGLG BIT -- is exist ticket of bettype 127
		
		, AutoSetting TINYINT
		, IsExistRunningCorner BIT
		, IsExistRunningHTCorner BIT
		, IsNeedToCalculateFGLG BIT
		, IsNeedToCalculateCorner BIT
		, AutoSettingForLeague TINYINT
		, BetCount INT
		, IsEnabledGoalRecordHT BIT
		, IsEnabledGoalRecordFT BIT
		, IsExistGoalRecordBettypeFT BIT
		, IsExistRunningUseGoalRecordHT BIT
		, IsExistRunningUseGoalRecordFT BIT
		, IsExistHTFGNG BIT
		, IsExistHTLG BIT
		, IsExistFTFGNG BIT
		, IsExistFTLG BIT
		, LivePeriod	TINYINT
		, IsHT			BIT
		, livehomescore	INT
		, liveawayscore	INT
	)
	--for instant match info
	CREATE TABLE #InstMatchInfo (
		MatchId 					INT
		, InstantHomeScore 			VARCHAR(50)
		, InstantAwayScore 			VARCHAR(50)
		, InstantStatusId 			TINYINT
		, InstantCalculationType 	TINYINT DEFAULT(0)
		, InstantPriority 			TINYINT
		, SettlementStatus			TINYINT
		, InstantKey				INT
		, InstantScoreDiff			TINYINT DEFAULT(0)
	)
	
	CREATE TABLE #tempBettrans (matchid INT, bettype SMALLINT, runningBet INT, betCount INT, IsParlay BIT DEFAULT(0), IsExistHTFGNG BIT, IsExistHTLG BIT, IsExistFTFGNG BIT, IsExistFTLG BIT)
	CREATE CLUSTERED INDEX IX_tempBettrans_bettype ON #tempBettrans (bettype)
	
	INSERT INTO #matchList (HalfTimeHomeScore, HalfTimeAwayScore, IsCalculated, IsFTCalculated, IsMultiCaled, IsRefund, IsCalRefund
		,matchid , leagueid, homeid, awayid, matchcode, kickofftime, finalhomescore, finalawayscore, betstatus, eventstatus
		,sporttype, IsNeutral, eventdate, goalrecord, suspenderHalfTime, suspenderFullTime, IsHalfTimeCal, SettlementStatus, IsExistFGLG , IsExistHTFGLG 
		,AutoSetting, IsExistRunningCorner, IsExistRunningHTCorner, IsNeedToCalculateFGLG, IsNeedToCalculateCorner, AutoSettingForLeague
		,BetCount, IsEnabledGoalRecordHT, IsEnabledGoalRecordFT, IsExistGoalRecordBettypeFT, IsExistRunningUseGoalRecordHT, IsExistRunningUseGoalRecordFT
		,IsExistHTFGNG, IsExistHTLG, IsExistFTFGNG, IsExistFTLG, LivePeriod, IsHT	, livehomescore, liveawayscore
	)
	SELECT m.hthomescore
		, m.htawayscore
		, ISNULL(mr.calculate, 0) IsCalculated
		, 0 AS IsFTCalculated
		, ISNULL(mr.multiple, 0) IsMultiCaled
		, ISNULL(mr.refund, 0) IsRefund
		, ISNULL(mr.calrefund, 0) IsCalRefund
		, m.matchid
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.matchcode
		, m.kickofftime
		, m.finalhomescore
		, m.finalawayscore
		, m.betstatus
		, m.eventstatus
		, m.sporttype
		, ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		, m.eventdate
		, m.goalrecord
		, ISNULL(ci.username, '') AS suspenderHT
		, ISNULL(cci.username, '') AS suspenderFT
		, ISNULL(mr.IsHTCal, 0) AS IsHTCal
		, ISNULL(m.SettlementStatus, 0) AS SettlementStatus
		, 0 AS IsExistFGLG
		, 0 AS IsExistHTFGLG		
		, ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AS AutoSetting
		, 0 AS IsExistRunningCorner
		, 0 AS IsExistRunningHTCorner
		, 0 AS IsNeedToCalculateFGLG
		, 0 AS IsNeedToCalculateCorner
		, ISNULL(l.AutoSetting, 0) AS AutoSettingForLeague
		, 0 AS BetCount
		, 0 AS IsEnabledGoalRecordHT
		, 0 AS IsEnabledGoalRecordFT
		, 0 AS IsExistGoalRecordBettypeFT
		, 0 AS IsExistRunningUseGoalRecordHT
		, 0 AS IsExistRunningUseGoalRecordFT
		, 0 AS IsExistHTFGNG 
		, 0 AS IsExistHTLG 
		, 0 AS IsExistFTFGNG 
		, 0 AS IsExistFTLG 
		, mr.LivePeriod
		, mr.IsHT
		, m.livehomescore
		, m.liveawayscore
	FROM dbo.match m WITH (NOLOCK)
		INNER JOIN dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
		INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
		LEFT JOIN CustDB.dbo.CustInfo ci WITH(NOLOCK) ON mr.ConfirmHT > 0 AND mr.ConfirmHT = ci.custid
		LEFT JOIN CustDB.dbo.CustInfo cci WITH(NOLOCK) ON mr.ConfirmFT > 0 AND mr.ConfirmFT = cci.custid
	WHERE m.eventdate BETWEEN @FromDate AND @ToDate
		AND m.sporttype = 1 --soccer only
		AND m.leagueID = CASE WHEN @LeagueID <> 0 THEN @LeagueID ELSE m.leagueID END 			
		AND CASE 
				WHEN @UncalMultiOnly = 0 THEN 1 
				WHEN @UncalMultiOnly = 1 THEN 
					CASE 
						WHEN (m.betstatus LIKE 'Abandoned 1H%') THEN m.hthomescore * m.htawayscore
						WHEN (m.betstatus LIKE 'Abandoned 2H%') THEN m.finalhomescore * m.finalawayscore
						ELSE m.hthomescore * m.htawayscore * m.finalhomescore * m.finalawayscore 
					END
				WHEN @UncalMultiOnly IS NULL OR @UncalOnly IS NULL THEN 1
			END IS NOT NULL 
		AND m.sporttype = CASE WHEN @sporttype = 0 THEN m.sporttype ELSE @sporttype END 
		AND (@MatchId = 0 OR (@MatchId <> 0 AND m.matchid = @matchid))
		AND (@eventstatus = '' OR eventstatus IN (@eventstatus, 'internal')) 
		AND (@isRefund IS NULL
				OR (@isRefund = 1 
					AND (1 = CASE 
								WHEN @statusid = 4 AND betstatus LIKE 'Refund%' THEN 1
								WHEN @statusid = 6 AND betstatus LIKE 'Abandoned%' THEN 1
								ELSE 0
							END
					)
				) 
				OR (@isRefund = 0 AND ISNULL(betstatus, '') NOT LIKE 'Refund%' AND ISNULL(betstatus, '') NOT LIKE 'Abandoned%')
			)
		AND 1 = CASE WHEN @IsHTOverOnly = 0 THEN 1
					WHEN @IsHTOverOnly = 1 
						AND m.eventstatus IN ('Closed', 'running', 'internal')
						AND mr.ishtcal = 0
						AND (mr.confirmHT <> 0 OR (DATEDIFF(MINUTE, m.kickofftime, @Today) > 40 
													AND DATEDIFF(MINUTE, m.kickofftime, @Today) < 100)) THEN 1
				ELSE 0 END
		AND 1 = CASE WHEN @IsOverOnly = 0 THEN 1
					WHEN @IsOverOnly = 1
						AND m.eventstatus <> N'Completed'
						AND (mr.ConfirmFT > 0 OR m.kickofftime < DATEADD(SS, - 6000, @Today)) THEN 1
				ELSE 0 END
		AND (@UncalOnly = 0 OR ISNULL(mr.calculate, 0) = 0 OR @UncalOnly IS NULL) 
		AND (@UncalMultiOnly = 0 OR ISNULL(mr.multiple, 0) = 0 OR @UncalMultiOnly IS NULL)
		AND (@SettlementStatus = 0 OR @SettlementStatus & m.SettlementStatus > 0)

	--check auto setting
	IF (@AutoSetting > 0)
	BEGIN
		DELETE m
		FROM #matchList m
		WHERE @AutoSetting & m.AutoSetting <> @AutoSetting
	END
	
	BEGIN --update status
		DECLARE @n INT = 2147483647
		
		
		--checking bettrans
		INSERT INTO #tempBettrans (matchid, bettype, runningBet, betCount)
		SELECT m.matchid
			,b.bettype
			,b.runningBet
			,b.betCount
		FROM (SELECT TOP (@n) MatchId FROM #matchList) AS m
			CROSS APPLY 
			(
				SELECT	b.bettype
						,SUM(CASE 
								WHEN b.statusID = 0 AND GETDATE() > '20160801' THEN 1 -- using hint to force Compute Scalar included in Aggregate Operator 
								ELSE 0 
							END) AS runningBet
						,COUNT(1) AS betCount
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE b.matchid = m.MatchId
					AND b.statusID NOT IN (101, 102)
				GROUP BY b.bettype
			) AS b
		OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	
		;WITH BetStatus AS (
			SELECT b.matchid
				, SUM(ISNULL(b.betCount, 0)) AS BetCount
				, SUM(CASE WHEN f.GroupId IN (2,4) AND f.IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistFGLG
				, SUM(CASE WHEN f.GroupId IN (1,3) AND f.IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistHTFGLG	
				, SUM(CASE WHEN f.GroupId = 2 AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) AS IsExistGoalRecordBettypeFT			
				, SUM(CASE WHEN f.GroupId = 6 AND b.runningBet > 0 THEN 1 ELSE 0 END) AS IsExistRunningCorner
				, SUM(CASE WHEN f.GroupId = 5 AND b.runningBet > 0 THEN 1 ELSE 0 END) AS IsExistRunningHTCorner
				, SUM(CASE WHEN f.GroupId = 3 AND f.IsUsedGoalRecordValue = 1 AND b.betCount > 0 THEN 1 ELSE 0 END) AS IsEnabledGoalRecordHT
				, SUM(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 AND b.betCount > 0 THEN 1 ELSE 0 END) AS IsEnabledGoalRecordFT
				, SUM(CASE WHEN f.GroupId = 3 AND f.IsUsedGoalRecordValue = 1 AND b.runningBet > 0 THEN 1 ELSE 0 END) AS IsExistRunningUseGoalRecordHT
				, SUM(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 AND b.runningBet > 0 THEN 1 ELSE 0 END) AS IsExistRunningUseGoalRecordFT
			from #tempBettrans b
				INNER JOIN dbo.f_Set_GetGroupBettypes() f 
				ON b.bettype = f.BetType			
			GROUP BY b.matchid
		)
		UPDATE t
		SET IsExistFGLG = CASE WHEN tt.IsExistFGLG > 0 THEN 1 ELSE 0 END
			, IsExistHTFGLG = CASE WHEN tt.IsExistHTFGLG > 0 THEN 1 ELSE 0 END		
			, IsExistGoalRecordBettypeFT = CASE WHEN tt.IsExistGoalRecordBettypeFT > 0 THEN 1 ELSE 0 END		
			, IsExistRunningCorner = CASE WHEN tt.IsExistRunningCorner > 0 THEN 1 ELSE 0 END
			, IsExistRunningHTCorner = CASE WHEN tt.IsExistRunningHTCorner > 0 THEN 1 ELSE 0 END
			, IsEnabledGoalRecordHT = CASE WHEN tt.IsEnabledGoalRecordHT > 0 THEN 1 ELSE 0 END
			, IsEnabledGoalRecordFT = CASE WHEN tt.IsEnabledGoalRecordFT > 0 THEN 1 ELSE 0 END
			, IsExistRunningUseGoalRecordHT = CASE WHEN tt.IsExistRunningUseGoalRecordHT > 0 THEN 1 ELSE 0 END
			, IsExistRunningUseGoalRecordFT = CASE WHEN tt.IsExistRunningUseGoalRecordFT > 0 THEN 1 ELSE 0 END
			
			, BetCount = tt.BetCount
		FROM #matchList t
			INNER JOIN BetStatus tt ON t.matchid = tt.matchid	
	
		--checking bettransm
		DECLARE @strBettypesParlay VARCHAR (MAX)
		
		SELECT  @strBettypesParlay = COALESCE(@strBettypesParlay + ',' + CAST(BetType AS VARCHAR),CAST(BetType AS VARCHAR))
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	GroupId IN (3,4,8)
				OR IsUsedGoalRecordValue = 1
		
		INSERT INTO #tempBettrans (matchid, bettype, runningBet, betCount, IsParlay, IsExistFTFGNG, IsExistFTLG, IsExistHTFGNG, IsExistHTLG)
		SELECT	m.matchid
			,b.bettype
			,b.runningBet
			,b.betCount
			,1 AS IsParlay
			,b.IsExistFTFGNG
			,b.IsExistFTLG
			,b.IsExistHTFGNG
			,b.IsExistHTLG
		FROM (
				SELECT TOP (@n) MatchId 
				FROM #matchList
			) AS m
			CROSS APPLY
			(
				SELECT	b.bettype
						,SUM(CASE 
								WHEN b.statusID = 0 AND GETDATE() > '20160801' THEN 1 -- using hint to force Compute Scalar included in Aggregate Operator 
								ELSE 0 
							END) AS runningBet
						,COUNT(1) AS betCount
						,MAX(CASE WHEN b.bettype = 14 AND betteam IN ('0:0', '1:1', '2:1') THEN 1 ELSE 0 END) AS IsExistFTFGNG
						,MAX(CASE WHEN b.bettype = 14 AND betteam IN ('1:2', '2:2') THEN 1 ELSE 0 END) AS IsExistFTLG
						,MAX(CASE WHEN b.bettype = 127 AND betteam IN ('0:0', '1:1', '2:1') THEN 1 ELSE 0 END) AS IsExistHTFGNG
						,MAX(CASE WHEN b.bettype = 127 AND betteam IN ('1:2', '2:2') THEN 1 ELSE 0 END) AS IsExistHTLG
				FROM	dbo.bettransm b WITH(NOLOCK)
				WHERE	b.matchid = m.MatchId 
						AND 1 = CASE
								WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',',',' + @strBettypesParlay + ',') > 0 THEN 1
								ELSE 0
							END
						AND b.statusID NOT IN (101, 102)
				GROUP BY b.bettype
			) AS b
		OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	
		;WITH BetStatusM AS (
			SELECT b.matchid
				, SUM(CASE WHEN  f.GroupId IN (2,4) AND f.IsFGLG = 1 AND (b.betCount > 0) THEN 1 ELSE 0 END) AS IsExistFGLG
				, SUM(CASE WHEN  f.GroupId IN (1,3) AND f.IsFGLG = 1 AND (b.betCount > 0) THEN 1 ELSE 0 END) AS IsExistHTFGLG
				, SUM(CASE WHEN f.GroupId = 2 AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) AS IsExistGoalRecordBettypeFT	
				, SUM(CASE WHEN f.GroupId = 3 AND f.IsUsedGoalRecordValue = 1 AND b.betCount > 0 THEN 1 ELSE 0 END) AS IsEnabledGoalRecordHT
				, SUM(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 AND b.betCount > 0 THEN 1 ELSE 0 END) AS IsEnabledGoalRecordFT
				, MAX(CASE WHEN b.IsExistFTFGNG > 0 THEN 1 ELSE 0 END) AS IsExistFTFGNG
				, MAX(CASE WHEN b.IsExistFTLG > 0 THEN 1 ELSE 0 END) AS IsExistFTLG
				, MAX(CASE WHEN b.IsExistHTFGNG > 0 THEN 1 ELSE 0 END) AS IsExistHTFGNG
				, MAX(CASE WHEN b.IsExistHTLG > 0 THEN 1 ELSE 0 END) AS IsExistHTLG
				
			FROM #tempBettrans b WITH(NOLOCK)
				INNER JOIN dbo.f_Set_GetGroupBettypes() f 
				ON b.bettype = f.BetType AND b.IsParlay = 1
				
			GROUP BY b.matchid
		)

		UPDATE t
		SET IsExistFGLG = CASE WHEN t.IsExistFGLG = 1 OR tt.IsExistFGLG > 0 THEN 1 ELSE 0 END
			, IsExistHTFGLG = CASE WHEN t.IsExistHTFGLG = 1 OR tt.IsExistHTFGLG > 0 THEN 1 ELSE 0 END
			, IsExistGoalRecordBettypeFT = CASE WHEN t.IsExistGoalRecordBettypeFT > 0 OR tt.IsExistGoalRecordBettypeFT > 0 THEN 1 ELSE 0 END		
			, IsEnabledGoalRecordHT = CASE WHEN t.IsEnabledGoalRecordHT > 0 OR  tt.IsEnabledGoalRecordHT > 0 THEN 1 ELSE 0 END
			, IsEnabledGoalRecordFT = CASE WHEN t.IsEnabledGoalRecordFT > 0 OR tt.IsEnabledGoalRecordFT > 0 THEN 1 ELSE 0 END
			, IsExistFTFGNG = tt.IsExistFTFGNG
			, IsExistFTLG = tt.IsExistFTLG
			, IsExistHTFGNG = tt.IsExistHTFGNG
			, IsExistHTLG = tt.IsExistHTLG
			
		FROM #matchList t
			INNER JOIN BetStatusM tt 
			ON t.matchid = tt.matchid
	END
	
	SET @Today = DATEADD(MINUTE, -10, GETDATE())

	;WITH SingleTicket AS (
		SELECT	matchid
				,MIN(IsCalculating) AS IsCalculating
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	Starttime > @Today 
				AND s.IsCalculating IN (0,1)
				AND SportType = 1
				AND s.LeagueID = CASE WHEN @LeagueId = 0 THEN s.LeagueID ELSE @LeagueId END
		GROUP BY matchid
	), ParlayTicket AS (
		SELECT p.matchid, min(IsCalculating)  IsCalculating
		FROM dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK)
			ON p.matchid = m.matchid
		WHERE p.Starttime > @Today
			AND p.IsCalculating IN (0,1)
			AND m.sporttype = 1
			AND m.leagueid = CASE WHEN @LeagueId = 0 THEN m.leagueid ELSE @LeagueId END
		GROUP BY p.matchid
	)	
	SELECT ISNULL(sg.matchid, pl.matchid) AS matchid
		, sg.IsCalculating AS IsCalculatingSingle
		, pl.IsCalculating AS IsCalculatingMP
	INTO #tempmatch
	FROM SingleTicket sg
		FULL OUTER JOIN ParlayTicket pl ON sg.matchid = pl.matchid 

	;WITH PayoutResult AS (
		SELECT t.MatchId
			, MAX(CASE WHEN rs.CalculationType = 1 THEN 1 ELSE 0 END) AS HTStatus
			, MAX(CASE WHEN rs.CalculationType = 2 THEN 1 ELSE 0 END) AS FTStatus
		FROM #matchList t 
			INNER JOIN DBPRO.bodb02.dbo.AutoPayoutResult rs WITH(NOLOCK) 
			ON t.matchId = rs.matchId
		WHERE t.eventstatus IN ('running', 'Completed')
			AND 1 & t.AutoSetting = 1
			AND rs.StatusId IN (1, 2)
			AND rs.CalculationType IN (1, 2)
		GROUP BY t.MatchId
		
	)
	--update status of match in order to can be calc FGLG & Corner bettype manually
	UPDATE t
	SET IsNeedToCalculateFGLG = CASE WHEN rs.HTStatus = 1 
										AND t.IsHalfTimeCal = 1 
										AND rs.FTStatus IN (0, 1) 
										AND (t.IsExistRunningUseGoalRecordHT = 1 
											OR (
												t.IsExistHTFGNG = 1
												AND ISNULL(rd.HTFGNGResultStatusId,0) = 0
											)
											OR (
												t.IsExistHTLG = 1
												AND ISNULL(rd.HTLGResultStatusId,0) = 0
											)
										)
										THEN 1 --can calc HT FGLG
									WHEN rs.FTStatus = 1
										AND t.IsHalfTimeCal = 1
										AND (t.IsExistRunningUseGoalRecordFT = 1 
											OR (t.IsExistGoalRecordBettypeFT = 1
												AND ISNULL(rd.GoalRecordFTResultStatusId,0) <> 5
											)
											OR (
												t.IsExistFTFGNG = 1
												AND ISNULL(rd.FTFGNGResultStatusId,0) = 0
											)
											OR (
												t.IsExistFTLG = 1
												AND ISNULL(rd.FTLGResultStatusId,0) = 0
											)
										)
										THEN 1 --can calc FT FGLG
								ELSE 0 END
		, IsNeedToCalculateCorner = CASE WHEN rs.HTStatus = 1
										AND t.IsHalfTimeCal = 1
										AND rs.FTStatus IN (0, 1) 
										AND t.IsExistRunningHTCorner = 1 THEN 1 --can calc HT Corner
									WHEN rs.FTStatus = 1
										AND t.IsHalfTimeCal = 1
										AND t.IsExistRunningCorner = 1 THEN 1 --can calc FT Corner
								ELSE 0 END
									
	FROM #matchList t
		INNER JOIN PayoutResult rs ON t.matchid = rs.MatchId
		OUTER APPLY (
			SELECT	MIN(CASE WHEN rd.ResourceId = '08' THEN rd.ResultStatusId END) AS GoalRecordFTResultStatusId
					,MIN(CASE WHEN rd.ResourceId = '127F' THEN rd.ResultStatusId END) AS HTFGNGResultStatusId
					,MIN(CASE WHEN rd.ResourceId = '14F' THEN rd.ResultStatusId END) AS FTFGNGResultStatusId

					,MIN(CASE WHEN rd.ResourceId = '127L' THEN rd.ResultStatusId END) AS HTLGResultStatusId
					,MIN(CASE WHEN rd.ResourceId = '14L' THEN rd.ResultStatusId END) AS FTLGResultStatusId
			FROM	DBPRO.bodb02.dbo.ResultDetail rd WITH(NOLOCK)
			WHERE	t.matchid = rd.matchid
					AND rd.ResourceId IN ('14F', '14L', '127F', '127L', '08')
		) rd
	
	--Checking for Inst match info
	IF (@AutoSetting = 0 OR 2 & @AutoSetting = 2)
	BEGIN 
		INSERT INTO #InstMatchInfo (MatchId, InstantHomeScore, InstantAwayScore, InstantStatusId,InstantCalculationType,InstantPriority, SettlementStatus, InstantKey)
		SELECT t.MatchId
			, 0 AS HomeValue
			, 0 AS AwayValue
			, 0 AS StatusId
			, 0 AS CalculationType
			, 4 AS Priority
			, t.SettlementStatus
			, 0  AS InstantKey
		FROM #matchList t 
		WHERE 2 & t.AutoSetting = 2
			AND (t.eventstatus IN ('running') OR t.eventstatus LIKE 'Refund%') --#86964
		
		;WITH InstantScores AS (
			SELECT *
			FROM (
				SELECT prd.MatchId
					, prd.HomeValue
					, prd.AwayValue
					, prd.TypeId AS CalculationType
					, prd.IsConfirmed
					, prd.SourceID
					, prd.ProviderResultDetailId AS InstantKey
					, ROW_NUMBER() OVER(
						PARTITION BY prd.matchID
						ORDER BY ProviderResultDetailId DESC
					) AS RowIdx
				FROM #InstMatchInfo m
					INNER JOIN DBPRO.bodb02.dbo.ProviderResultDetail prd WITH(NOLOCK)
					ON m.matchid = prd.matchID
				WHERE prd.TypeId IN (101, 102)
					AND m.SettlementStatus & 3 = 0
					AND prd.SourceID = 100 --#86964
			) AS t
			WHERE RowIdx IN (1, 2)
		)
		,InstMatchConfirm AS (
			SELECT temp.MatchId
				,temp.HomeValue
				,temp.AwayValue
				, 1 AS StatusId --to Confirm
				,temp.CalculationType
				,temp.InstantKey
				--,CASE WHEN (chk.matchID > 0 AND  (temp.HomeValue < chk.HomeValue OR temp.AwayValue < chk.AwayValue) ) THEN 1 ELSE 0 END AS InstantScoreDiff
				,CASE WHEN (chk.matchID > 0 AND  (CAST(ISNULL(temp.HomeValue, 0) AS INT)) < (CAST(ISNULL(chk.HomeValue, 0) AS INT)) OR (CAST(ISNULL(temp.AwayValue, 0) AS INT)) < (CAST(ISNULL(chk.AwayValue, 0) AS INT))) THEN 1 ELSE 0 END AS InstantScoreDiff
			FROM InstantScores AS temp
				LEFT JOIN InstantScores AS chk 
					ON temp.matchId = chk.matchId AND chk.RowIdx = 2
				LEFT JOIN DBPRO.bodb02.dbo.AutoPayoutResult aps WITH(NOLOCK)
					ON temp.matchid = aps.matchID
					AND temp.CalculationType = aps.CalculationType
					AND temp.HomeValue 	= aps.HomeValue
					AND temp.AwayValue 	= aps.AwayValue
					
			WHERE temp.RowIdx = 1
				AND (
					aps.StatusId IS NULL --not confirm yet
					OR (aps.StatusId = 3 --FAILED to re-confirm
						 
						 --#86964
						 AND (NOT EXISTS (SELECT 1 FROM DBPRO.bodb02.dbo.AutoPayoutResult a WITH(NOLOCK)  --SUCCESSS by Others (Auto/Manual)
									   WHERE a.matchid			  = aps.matchID
									   AND a.CalculationType	  = aps.CalculationType
									   AND a.HomeValue		  = aps.HomeValue
									   AND a.AwayValue		  = aps.AwayValue
									   AND a.StatusId		  = 2)
							 
							 OR EXISTS (SELECT 1 FROM (SELECT TOP 2 MatchID, ModifiedDate, StatusID, -- Not Calculate yet
												    ROW_NUMBER() OVER( PARTITION BY aps.matchid ORDER BY ModifiedDate DESC) AS RowIdx
												  FROM DBPRO.bodb02.dbo.AutoPayoutResult aps WITH(NOLOCK)
												  WHERE aps.matchid		   = temp.matchID
												    AND aps.CalculationType = temp.CalculationType
												    AND aps.HomeValue	   = temp.HomeValue
												    AND aps.AwayValue	   = temp.AwayValue
									  ) AS T1
									  LEFT JOIN (SELECT TOP 2 MatchID, ModifiedDate, StatusID, 
											     ROW_NUMBER() OVER( PARTITION BY aps.matchid ORDER BY ModifiedDate DESC) AS RowIdx
											   FROM DBPRO.bodb02.dbo.AutoPayoutResult aps WITH(NOLOCK)
											   WHERE aps.MatchID		 = temp.MatchID
												AND aps.CalculationType	 = temp.CalculationType
												AND aps.HomeValue		 = temp.HomeValue
												AND aps.AwayValue		 = temp.AwayValue
										  ) AS T2 ON T1.MatchID= T2.MatchID AND T2.RowIdx = 2
										  WHERE T1.RowIdx = 1
										  AND (T1.StatusID <> 2 AND T1.ModifiedDate > T2.ModifiedDate) --last update still calculate failed
									  )
							 )
					  )--#86964

					OR (aps.StatusId = 2 AND temp.IsConfirmed = 0)--abnormal case -> re-calculate
				    )
		)
		UPDATE d
		SET InstantHomeScore			= u.HomeValue
			, InstantAwayScore			= u.AwayValue
			, InstantStatusId			= u.StatusId
			, InstantCalculationType	     = u.CalculationType
			, InstantPriority			= 3
			, InstantKey				= u.InstantKey
			, InstantScoreDiff			= u.InstantScoreDiff
		FROM #InstMatchInfo d
			INNER JOIN InstMatchConfirm u 
			ON d.matchID = u.matchID
			
		;WITH InstMatchInProgress AS (
			SELECT m.MatchId
				, aps.HomeValue
				, aps.AwayValue
				, 2 AS StatusId -- has confirmed
				, aps.CalculationType
				, pr.InstantKey
			FROM #InstMatchInfo m
				INNER JOIN DBPRO.bodb02.dbo.AutoPayoutResult aps WITH(NOLOCK)
				ON m.matchid = aps.matchID
				OUTER APPLY (
					SELECT TOP(1) ProviderResultDetailId AS InstantKey
					FROM DBPRO.bodb02.dbo.ProviderResultDetail pr WITH(NOLOCK)
					WHERE matchID = m.matchID 
						AND TypeId = aps.CalculationType
						AND HomeValue = aps.HomeValue
						AND AwayValue = aps.AwayValue
						AND pr.SourceID = 100 --#86964
					ORDER BY ProviderResultDetailId DESC
				) AS pr

			WHERE aps.StatusId IN (1) --waiting & calculating
				AND aps.CalculationType IN (101, 102)	
		)
		UPDATE d
		SET InstantHomeScore			= u.HomeValue
			, InstantAwayScore			= u.AwayValue
			, InstantStatusId			= u.StatusId
			, InstantCalculationType	= u.CalculationType
			, InstantPriority			= 1
			, InstantKey				= u.InstantKey
		FROM #InstMatchInfo d
			INNER JOIN InstMatchInProgress u 
			ON d.matchID = u.matchID
	END
	
	-- match is calculated or not
	IF @SportType IN (0,1)
	BEGIN
		UPDATE	m
			SET IsFTCalculated = CASE WHEN ResultStatusID = 5 THEN 1 ELSE 0 END
		FROM	#matchList m
			INNER JOIN DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
				ON	m.matchid = r.MatchId
					AND r.ResourceId = '00'
	END

	SELECT m.HalfTimeHomeScore
		, m.HalfTimeAwayScore
		, m.IsCalculated
		, m.IsFTCalculated
		, m.IsMultiCaled
		, m.IsRefund
		, m.IsCalRefund
		, m.matchid
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.matchcode
		, m.kickofftime
		, m.finalhomescore
		, m.finalawayscore
		, m.betstatus
		, m.eventstatus
		, m.sporttype
		, m.IsNeutral
		, m.eventdate
		, m.goalrecord
		, m.suspenderHalfTime
		, m.suspenderFullTime
		, m.IsHalfTimeCal
		, m.SettlementStatus
		, m.IsExistFGLG
		, m.IsExistHTFGLG
		, t.IsCalculatingSingle
		, t.IsCalculatingMP
		, AutoSetting
		, IsNeedToCalculateFGLG
		, IsNeedToCalculateCorner
		, AutoSettingForLeague
		, IsEnabledGoalRecordHT
		, IsEnabledGoalRecordFT
		
		/*Instant match info*/
		, m.livehomescore
		, m.liveawayscore
		, m.IsHT
		, m.LivePeriod
		, ISNULL(im.InstantHomeScore, '') AS InstantHomeScore
		, ISNULL(im.InstantAwayScore,'') AS InstantAwayScore
		, ISNULL(im.InstantStatusId, 0) AS InstantStatusId
		, ISNULL(im.InstantCalculationType, 0) AS InstantCalculationType
		, ISNULL(im.InstantKey, 0) AS InstantKey
		, ISNULL(im.InstantScoreDiff, 0) AS InstantScoreDiff
		, ISNULL(ss.WaitingTime, 120) AS InstantWaitingTime
	FROM #matchList m
		LEFT JOIN #tempmatch t ON t.matchid = m.matchid
		LEFT JOIN #InstMatchInfo im ON m.matchid = im.matchid
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	DBPRO.bodb02.dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND AutoType = 2
		)ss
	WHERE 1 = CASE WHEN @IsHTOverOnly = 1 OR @IsOverOnly = 1 THEN CASE WHEN m.BetCount > 0 THEN 1 ELSE 0 END
				ELSE 1 END
	ORDER BY CASE m.eventstatus WHEN 'Completed' THEN 1 WHEN 'Refund' THEN 1 ELSE 0 END
		, m.eventdate
		, m.kickofftime
		, m.sporttype
		, m.leagueid
		, m.matchid
		, m.betstatus
		, m.matchcode
	
	
	DROP TABLE #tempmatch
	DROP TABLE #matchList
	DROP TABLE #InstMatchInfo
	DROP TABLE #tempBettrans
END
GO