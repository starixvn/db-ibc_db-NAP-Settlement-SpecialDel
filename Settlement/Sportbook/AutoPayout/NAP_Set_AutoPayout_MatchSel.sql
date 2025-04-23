/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_MatchSel
	  @FromDate 			DATETIME
	, @ToDate 				DATETIME
	, @SportType 			SMALLINT = 0
	, @LeagueID 			INT = 0 -- 0 for ALL Leagues
	, @MatchCode 			NVARCHAR(50) = ''
	, @StatusId 			TINYINT = 0
	, @FilterBy 			TINYINT = 0
	, @IsReLoad 			BIT = 0
	, @IsHTOverOnly 		BIT = 0
	, @IsOverOnly 			BIT = 0
	, @AutoSetting 			VARCHAR(10) = ''
	, @IsMarkedTicket		BIT = 0
	, @IsInstant			BIT = 0
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
	- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
	- 20190610@Kathy: Exclude checking running BetBuilder tickets [Redmine:#114877]
	- 20190528@Sol: Auto payout phase 3 - Removed unused field IsNeedToCalculateFGLG [Redmine:#116073]
	- 20190620@Kathy: Remove corner betradar bettypes [Redmine:#109584]
	- 20200227@Sol: Sort Completed Matches With Running Tickets - [Redmine:#128968]
	- 20200225@Sol: Direct Settlement Action for Soccer - [Redmine:#103568]
	- 20200227@Sol: Show Result of SBO on Main Calculate & Main Popup for Soccer - [Redmine:#129780]
	- 20200410@Sol: Set Timeout for Direct Settlement - [Redmine:#132138]
	- 20200505@Kathy: - Add New Filter Option allowing user to exclude/include test matches 
					  - Not display matches that have been calculate/refund mix parlay when check Un-Calculated Parlay Only filter [Redmine:#133518]
	- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
	- 20200617@Kathy: Allow to search like on MatchCode [Redmine:#135991]
	- 20200904@Louisa: Get external score [Redmine:#139979]
	- 20201027@Louisa: Add new settlement status - Hold Key bit[7] - [Redmine:#143441]
	- 20210326@Louisa: New filter for auto payput [Redmine:#148241]
	- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192]
	- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
	- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
	- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
	- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
	- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
	- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
	- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
	- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
	- 20231025@Aries: Cannot insert duplicate key in object 'dbo.#matchList' [Redmine:#196002]
	- 20240621@Aries: Enhance Auto Refund to add waiting time [Redmine:#206153]
	- 20241205@Louisa: fix issue convert matchcode [Redmine:#214853]
	- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

 Param explanation:  
	@MatchCode: match code
	@LeagueID: = 0: show info of all leagues     
	@StatusId: 0: all, 1: running; 2: closed; 3: completed; 4: refund; 5: Postponed, 6:Abandoned, 7: Result Pending, 8: Undecided, 9: Under Settlement, 10: MTD Hold, 11: Hold Key
				12: Irregular Time 1H	13:Irregular Time	14:Wrong Team Name	15:Suspended
	@FilterBy: 0: none, 1: un-calculated game; 2: Un-calculated multiple only; 3: all
	@PenaltyShootoutOnly: 0: none; 1: running penalty shootout only
	@IsReLoad: 1: reload partial matches of a league, 0: not reload
	@AutoSetting : '': not select or select All; 1-Auto Payout (bit[1]); 16: Direct (bit[5]); 0: Turn off Autopayout  | Ex: @AutoSetting = '16,0'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @UncalOnly BIT, @UncalMultiOnly BIT, @EventStatus NVARCHAR(50), @IsRefund BIT
		,@MatchId INT, @Today DATETIME
		,@SettlementStatus TINYINT
		,@EventStatusReason TINYINT = 0
		,@IsCentral BIT

	SELECT @matchcode 	= ISNULL(@matchcode, '')
		, @LeagueID 	= ISNULL(@LeagueID, 0)
		, @filterBy 	= ISNULL(@filterBy, 0)
		, @Today 		= GETDATE()
		, @MatchId 	= 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	-- if entering matcode, ignore other params (excep FromDate, ToDate, sport type)
	IF @matchcode <> ''
	BEGIN
		SELECT @eventstatus = '', @isRefund = NULL, @UncalOnly = NULL, @UncalMultiOnly = NULL
			, @LeagueID = CASE WHEN @isReLoad = 1 THEN @LeagueID 
							ELSE 0 END -- reload partial; search on LeagueID, not reload: get all leagues
			,@SettlementStatus = 0
			,@SportType = 0
			,@FilterBy = 3
			,@IsMarkedTicket = 0
			,@IsHTOverOnly = 0
			,@IsOverOnly   = 0
			,@AutoSetting = ''
			,@IsInstant =0
			,@StatusId = 0
			,@IsMarkedTicket =0

		IF TRY_CONVERT(INT, @matchcode) IS NOT NULL
		BEGIN
			SET @MatchId = CAST(@matchcode AS INT)
		END
		--ELSE
		--BEGIN
		--	SELECT @MatchId = matchid
		--	FROM dbo.match m WITH(NOLOCK) WHERE matchcode = @matchcode
		--END
	END
	ELSE
	BEGIN
		SELECT @eventstatus = CASE 
								WHEN @statusid IN (1, 12, 13, 14, 15) THEN 'running'
								WHEN @statusid = 2 THEN 'closed'
								WHEN @statusid IN (3,6) THEN 'completed'
								WHEN @statusid = 5 THEN 'postponed'
								ELSE ''	END
			,@EventStatusReason = CASE @StatusId
									WHEN 12 THEN 1
									WHEN 13 THEN 2
									WHEN 14 THEN 3
									WHEN 15 THEN 4
									ELSE 0	END
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
				WHEN @StatusId = 11 THEN 64
				ELSE 0 
				END

		--ignore event status if selecting filterby
		IF (@UncalMultiOnly = 1 OR @UncalOnly = 1 OR @SettlementStatus <> 0 OR @IsMarkedTicket = 1 )
			SELECT @eventstatus = '', @isRefund = NULL
	END

	CREATE TABLE #matchList (HalfTimeHomeScore INT
		, HalfTimeAwayScore INT
		, IsCalculated BIT
		, IsFTCalculated BIT
		, IsMultiCaled BIT
		, IsRefund BIT
		, IsCalRefund BIT
		, matchid INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON)
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
		, ChildMatchType	TINYINT
		, IsExistFGLG BIT -- is exist ticket of bettype 14
		, IsExistHTFGLG BIT -- is exist ticket of bettype 127
		
		, AutoSetting TINYINT
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

		,IsExistRunningTicket BIT
		--,IsExistRunningTicketParlay BIT
		,IsExistMarkedTicket BIT
		--,IsExistMarkedTicketParlay BIT
		,EventStatusReason TINYINT
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
	CREATE TABLE #tempmatch(MatchId INT, IsCalculatingSingle  INT, IsCalculatingMP INT)
	CREATE TABLE #tempBettrans (matchid INT, bettype SMALLINT, runningBet INT, betCount INT, IsParlay BIT DEFAULT(0), IsExistHTFGNG BIT, IsExistHTLG BIT, IsExistFTFGNG BIT, IsExistFTLG BIT)
	CREATE CLUSTERED INDEX IX_tempBettrans_bettype ON #tempBettrans (bettype)
	
	INSERT INTO #matchList (HalfTimeHomeScore, HalfTimeAwayScore, IsCalculated, IsFTCalculated, IsMultiCaled, IsRefund, IsCalRefund
		,matchid , leagueid, homeid, awayid, matchcode, kickofftime, finalhomescore, finalawayscore, betstatus, eventstatus
		,sporttype, IsNeutral, eventdate, goalrecord, suspenderHalfTime, suspenderFullTime, IsHalfTimeCal, SettlementStatus, ChildMatchType, IsExistFGLG , IsExistHTFGLG 
		,AutoSetting, AutoSettingForLeague
		,BetCount, IsEnabledGoalRecordHT, IsEnabledGoalRecordFT, IsExistGoalRecordBettypeFT, IsExistRunningUseGoalRecordHT, IsExistRunningUseGoalRecordFT
		,IsExistHTFGNG, IsExistHTLG, IsExistFTFGNG, IsExistFTLG, LivePeriod, IsHT	, livehomescore, liveawayscore, IsExistRunningTicket, IsExistMarkedTicket,EventStatusReason
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
		, m.ChildMatchType
		, 0 AS IsExistFGLG
		, 0 AS IsExistHTFGLG		
		, ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AS AutoSetting
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
		,0 AS IsExistRunningTicket
		,0 AS IsExistMarkedTicket
		,m.EventStatusReason
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
		AND (@MatchCode = '' OR (m.matchid = @matchid OR m.matchcode LIKE '%'+ @MatchCode +'%'))
		AND 1 = CASE WHEN @eventstatus = '' THEN 1
						 WHEN @EventStatusReason = 0 AND eventstatus IN (@eventstatus, 'internal') THEN 1
						 WHEN @SportType = 1 AND ISNULL(m.EventStatusReason,0) = @EventStatusReason AND m.eventstatus = @eventstatus THEN 1
						 ELSE 0
					END				 
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
		AND 1 = CASE
					WHEN @UncalMultiOnly = 1 
						THEN CASE
								WHEN m.sporttype = 1 AND l.LeagueGroupID IN (113, 252) THEN 0 --PinGoal
								WHEN (ISNULL(mr.calculate,0) = 1 OR ISNULL(mr.calrefund,0) = 1) -- match completed (cal/refund)
									AND ISNULL(mr.multiple,0) = 0 AND ISNULL(mr.refund,0) = 0 THEN 1 -- not cal/refund parlay yet
								ELSE 0
							END
					ELSE 1
				END
		AND (@SettlementStatus = 0 OR @SettlementStatus & m.SettlementStatus > 0)
		AND ISNULL(m.IsDeleted,0) = 0

	IF (@IsInstant = 1)
	BEGIN
		DELETE m
		FROM #matchList m
		WHERE m.AutoSetting & 2  = 0
	END
		
	--check auto setting
	IF ( ISNULL(@AutoSetting,'') <> '')
	BEGIN
		DECLARE @AutoValue TINYINT
				,@minValue TINYINT

		DECLARE @tmpAutoSetting TABLE (AutoSetting TINYINT)

		INSERT INTO @tmpAutoSetting ( AutoSetting ) 
		SELECT CAST([value] AS TINYINT) FROM STRING_SPLIT(@AutoSetting, ',')

		SELECT  @AutoValue = SUM(AutoSetting) 
				,@minValue = MIN(AutoSetting)
		FROM @tmpAutoSetting

		DELETE m
		FROM #matchList m
		WHERE 1 =  CASE WHEN @AutoValue = 0 THEN CASE when  m.AutoSetting & 17 > 0 THEN 1 
				   										 ELSE 0 END
				   		WHEN @minValue = 0 
				   			AND m.AutoSetting & (@AutoValue ^17) > 0  
				   			AND m.AutoSetting & @AutoValue = 0
				   			THEN 1
				   		WHEN @minValue > 0 AND m.AutoSetting & @AutoValue = 0 THEN 1
				   		ELSE 0
				   		END
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
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
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
		WHERE	IsUsedGoalRecordValue = 1
		
		INSERT INTO #tempBettrans (matchid, bettype, runningBet, betCount, IsParlay, IsExistFTFGNG, IsExistFTLG, IsExistHTFGNG, IsExistHTLG)
		SELECT	m.matchid
			,bm.bettype
			,bm.runningBet
			,bm.betCount
			,1 AS IsParlay
			,bm.IsExistFTFGNG
			,bm.IsExistFTLG
			,bm.IsExistHTFGNG
			,bm.IsExistHTLG
		FROM (
				SELECT TOP (@n) MatchId 
				FROM #matchList
			) AS m
			CROSS APPLY
			(
				SELECT	bm.bettype
						,SUM(CASE 
								WHEN bm.statusID = 0 AND GETDATE() > '20160801' THEN 1 -- using hint to force Compute Scalar included in Aggregate Operator 
								ELSE 0 
							END) AS runningBet
						,COUNT(1) AS betCount
						,MAX(CASE WHEN bm.bettype = 14 AND betteam IN ('0:0', '1:1', '2:1') THEN 1 ELSE 0 END) AS IsExistFTFGNG
						,MAX(CASE WHEN bm.bettype = 14 AND betteam IN ('1:2', '2:2') THEN 1 ELSE 0 END) AS IsExistFTLG
						,MAX(CASE WHEN bm.bettype = 127 AND betteam IN ('0:0', '1:1', '2:1') THEN 1 ELSE 0 END) AS IsExistHTFGNG
						,MAX(CASE WHEN bm.bettype = 127 AND betteam IN ('1:2', '2:2') THEN 1 ELSE 0 END) AS IsExistHTLG
				FROM	dbo.bettransm bm WITH(NOLOCK)
				WHERE	bm.matchid = m.MatchId 
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND 1 = CASE
								WHEN CHARINDEX(',' + CAST(bm.bettype AS VARCHAR) + ',',',' + @strBettypesParlay + ',') > 0 THEN 1
								ELSE 0
							END
						AND bm.statusID NOT IN (101, 102)
				GROUP BY bm.bettype
			) AS bm
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
	INSERT INTO #tempmatch(MatchId, IsCalculatingSingle, IsCalculatingMP)
	SELECT ISNULL(sg.matchid, pl.matchid) AS matchid
		, sg.IsCalculating AS IsCalculatingSingle
		, pl.IsCalculating AS IsCalculatingMP
	FROM SingleTicket sg
		FULL OUTER JOIN ParlayTicket pl ON sg.matchid = pl.matchid 

	--Inst match info
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
				AND m.SettlementStatus & 87 = 0 ----bit 1,2,3,5,7
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
	----/END Inst match info
		
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

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsExistMarkedTicketParlay BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, mt.matchid
	FROM	#matchList m
		CROSS APPLY (
			SELECT	mt.TransId, mt.MatchId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = m.HasMarkedSingle
				,IsExistMarkedTicketParlay = m.HasMarkedParlay
		FROM	@tmpMatchMarked mk
			INNER JOIN (
				SELECT	mt.matchId
						,CASE WHEN MIN(ISNULL(bm.IsParlay,0)) = 0 THEN 1 ELSE 0 END AS HasMarkedSingle
						,CASE WHEN MAX(ISNULL(bm.IsParlay,0)) = 1 THEN 1 ELSE 0 END AS HasMarkedParlay
				FROM	#tmpMarkedTransaction mt
					CROSS APPLY (
						SELECT	TOP (1) b.transid
								,b.refno
								,b.matchid
								,b.statusID
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	mt.transid = b.transid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					) b
					OUTER APPLY (
						SELECT TOP 1 1 IsParlay
						FROM	dbo.bettransm bm WITH(NOLOCK)
						WHERE	bm.refno = b.refno
								AND bm.statusid = 0
								AND b.matchid = 29
								AND bm.matchid = mt.matchid
					)bm
				WHERE	1 = CASE
								WHEN b.matchid <> 29 AND b.statusID = 0 THEN 1
								WHEN b.matchid = 29 AND bm.IsParlay = 1 THEN 1
								ELSE 0
							END
				GROUP BY mt.matchid
			) m
				ON m.matchid = mk.MatchId

		UPDATE m 
			SET IsExistMarkedTicket = CASE WHEN t.IsExistMarkedTicket = 1 OR t.IsExistMarkedTicketParlay = 1 THEN 1 ELSE 0 END
		FROM	#matchList m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId

	END

	IF @IsMarkedTicket = 1
	BEGIN
		DELETE	m
		FROM	#matchList m 
		WHERE	IsExistMarkedTicket = 0 
	END

	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0))
	CREATE TABLE #temp_match_parlay (transid BIGINT, matchid INT, refno BIGINT)

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	matchid
	FROM	#matchList
	WHERE	eventstatus = 'completed'

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE m 
			SET IsExistRunningTicket = 1
		FROM	@tmpMatchCompleted m
			CROSS APPLY (
				SELECT	b.matchid
				FROM	dbo.bettrans b WITH(NOLOCK)
					OUTER APPLY (
						SELECT TOP 1 mt.transId
						FROM	#tmpMarkedTransaction mt 
						WHERE b.transid = mt.TransId
					)mt
				WHERE	b.matchid = m.matchid
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
						AND b.statusID = 0
						AND b.bettype NOT BETWEEN 801 AND 806 -- Metric Gaming
						AND b.bettype <> 38 -- BetBuilder
						AND mt.transId IS NULL
				GROUP BY b.matchid
			)b

		-- parlay
		INSERT INTO #temp_match_parlay (transid, matchid, refno)
		SELECT	0, m.MatchId, bm.refno
		FROM @tmpMatchCompleted m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.MatchId = bm.matchid
		WHERE	bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND bm.statusID = 0
				AND m.IsExistRunningTicket = 0
				
		IF EXISTS (SELECT TOP 1 1 FROM #temp_match_parlay)
		BEGIN
			UPDATE   t
				SET transid = b.transid
			FROM   #temp_match_parlay  t
				INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
			
			UPDATE	m 
				SET IsExistRunningTicket = t.IsExistRunningTicketParlay
			FROM	@tmpMatchCompleted m
					CROSS APPLY (
								SELECT 1 AS IsExistRunningTicketParlay										
								FROM (
										SELECT	transid, MatchId
										FROM	#temp_match_parlay p
										WHERE p.matchid = m.MatchId
									) b
									OUTER APPLY (
										SELECT TOP 1 mt.transId
										FROM	#tmpMarkedTransaction mt 
										WHERE	b.transid = mt.TransId
												AND b.MatchId = mt.matchId
									)mt
									WHERE	mt.transId IS NULL
									GROUP BY b.matchid
								) t							
		END

		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	#matchList m
			INNER JOIN @tmpMatchCompleted t
				ON m.matchid = t.MatchId
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
		, m.IsExistRunningTicket
		, m.IsExistMarkedTicket
		, m.EventStatusReason
		, m.ChildMatchType

		, ssRefund.EnabledAutoRefund  
		, ISNULL(ssDirect.WaitingTime, 1) AS DirectWaitingTime
		, ISNULL(ssRefund.WaitingTime, 0) AS RefundWaitingTime

		, mRefund.EnabledAutoRefundMatch 
		, mDirect.WaitingTime AS DirectWaitingTimeMatch
		, mRefund.WaitingTime AS RefundWaitingTimeMatch
		
	FROM #matchList m
		LEFT JOIN #tempmatch t ON t.matchid = m.matchid
		LEFT JOIN #InstMatchInfo im ON m.matchid = im.matchid
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	DBPRO.bodb02.dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND AutoType = 2
		)ss
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	DBPRO.bodb02.dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND AutoType = 5
		)ssDirect
		OUTER APPLY (
			SELECT TOP 1 s1.WaitingTime,s1.[Enable] AS EnabledAutoRefund
			FROM	DBPRO.bodb02.dbo.SettlementSetting s1 WITH (NOLOCK)
			WHERE	s1.LeagueId = m.leagueid
					AND AutoType = 7
		)ssRefund
		OUTER APPLY (
			SELECT TOP 1 m1.WaitingTime, m1.[Enable] AS EnabledAutoRefundMatch
			FROM	DBPRO.bodb02.dbo.AutoPayoutSetting AS m1 WITH (NOLOCK)
			WHERE	m.matchid = m1.matchid
					AND AutoType = 7
		) mRefund
		OUTER APPLY (
			SELECT TOP 1 m1.WaitingTime 
			FROM	DBPRO.bodb02.dbo.AutoPayoutSetting AS m1 WITH (NOLOCK)
			WHERE	m.matchid = m1.matchid
					AND AutoType = 5
		) mDirect
	WHERE 1 = CASE WHEN @IsHTOverOnly = 1 OR @IsOverOnly = 1 THEN CASE WHEN m.BetCount > 0 THEN 1 ELSE 0 END
				ELSE 1 END
	ORDER BY CASE 
				WHEN m.eventstatus = 'completed' AND m.IsExistMarkedTicket = 0 AND m.IsExistRunningTicket = 0 THEN 1 
				WHEN m.eventstatus = 'refund' THEN 1 
				ELSE 0 
			END
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