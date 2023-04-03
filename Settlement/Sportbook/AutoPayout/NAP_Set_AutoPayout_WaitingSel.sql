/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_WaitingSel] 
	@SportType SMALLINT = 0
	, @LeagueId INT = 0 -- 0 for ALL Leagues
AS
/*
	Created: 20160314@Patrick
	Task: Autop payout - Get status for a match
	DB: DBTXN/BODB02
	Original:
		NAP_Set_WaitingSel
	
	Revision:
		- 20160713@Patrick: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160824@Kathy: Rearrange code [Redmine:#62290]
							- Using TOP (@n) and OPTION (OPTIMIZE FOR (@n = 1))
							- GETDATE() > '20160801'	
		- 20161003@Bobby: #65002 - Implement Auto CAL page info: update Instant match status
		- 20161118@Kathy: Changes on Auto Settlement [Redmine:#67328]
		- 20160509@Kathy: Fast Market integration [Remine:#56367]
		- 20170118@Kathy: Check match in queue in 10mins instead of 1 hour [Redmine:49143]
		- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170313@Kathy: Check betstatus result for bettype 14,127 to notify user do CAL FGLG [Redmine:#73218]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180206@Kathy: Add new column IsFTCalculated to determine whether match calculated FT or not [Redmine:#86964]
		- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
		- 20181218@Vicky: Add New Undecided Option for MTD team [Redmine:#104948]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190610@Kathy: Exclude checking running BetBuilder tickets [Redmine:#114877]
		- 20190620@Kathy: Remove corner betradar, auto betradar bettypes [Redmine:#109584]
		- 20190801@Sol: Removed unused code IsNeedToCalculateFGLG [Redmine:#115232]
		- 20200227@Sol: Show Result of SBO on Main Calculate & Main Popup for Soccer - [Redmine:#129780]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200619@Kathy: Duplicate transid on table MarkedTransaction [Redmine:#136146]
		- 20200827@Louisa: Get external score [Redmine:#139979]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220509@Kathy: Change to use STRING_SPLIT [Redmine:#172461]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]

	Param's explanation: 
		
*/
BEGIN

	SET NOCOUNT ON 
	
	DECLARE @Today			  DATETIME
		 , @MatchIds		  VARCHAR(MAX)
		 , @n			  INT = 2147483647
		 , @MinBettype		  SMALLINT
		 , @MaxBettype		  SMALLINT
		 , @IsCentral		  BIT

	SELECT	@LeagueID	   = ISNULL(@LeagueID, 0)
		   , @SportType   = ISNULL(@SportType, 0)
		   , @Today	   = GETDATE()

	SET @Today = DATEADD(MINUTE, -10, @Today)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	CREATE TABLE #tblMatchInQueue(
		MatchId						INT PRIMARY KEY
		,SingleStatus					INT
		,ParlayStatus					INT
		,IsExistHTFGLG					BIT
		,IsExistFGLG					BIT
		,IsExistGoalRecordBettypeFT		BIT
		,IsEnabledGoalRecordHT			BIT
		,IsEnabledGoalRecordFT			BIT
		,IsExistRunningUseGoalRecordHT	BIT
		,IsExistRunningUseGoalRecordFT	BIT
		,IsExistHTFGNG					BIT
		,IsExistHTLG					BIT
		,IsExistFTFGNG					BIT
		,IsExistFTLG					BIT
		,IsExistMarkedTicket			BIT
		,IsExistRunningTicket			BIT
	)
	
	CREATE TABLE #tblBetStatus(
		  MatchId			  INT	
		, bettype			  SMALLINT
		, IsRunning		  BIT
		, IsParlay		  BIT
		, IsExistHTFGNG	  BIT
		, IsExistHTLG		  BIT
		, IsExistFTFGNG	  BIT
		, IsExistFTLG		  BIT
	)
	
	CREATE TABLE #tblBettype (bettype SMALLINT PRIMARY KEY, GroupId SMALLINT, IsUsedGoalRecordValue BIT, IsFGLG BIT)
	
	DECLARE @tblMatchInfo TABLE (matchid INT, leagueId INT, HalfTimeHomeScore INT, HalfTimeAwayScore INT, IsCalculated BIT, IsFTCalculated BIT, IsMultiCaled BIT
		, IsRefund BIT, IsCalRefund BIT, homeid INT, awayid INT, matchcode NVARCHAR(50), finalhomescore INT, finalawayscore INT
		, betstatus NVARCHAR(50), eventstatus NVARCHAR(50), IsNeutral BIT, goalrecord VARCHAR(50)
		, IsHalfTimeCal BIT, SettlementStatus TINYINT, IsCalculatingSingle INT  
		, HTStatus BIT, FTStatus BIT, suspenderHalfTime NVARCHAR(50), suspenderFullTime NVARCHAR(50), AutoSetting TINYINT, IsHTCal BIT
		, livehomescore			    INT
		, liveawayscore			    INT
		, IsHT					    BIT
		, LivePeriod				    TINYINT
		, InstantHomeScore			    VARCHAR(50)
		, InstantAwayScore			    VARCHAR(50)
		, InstantStatusId			    TINYINT DEFAULT(0)
		, InstantCalculationType		    TINYINT DEFAULT(0)
		, InstantKey				    INT
		, InstantScoreDiff			    TINYINT DEFAULT(0)
		, GoalRecordFTResultStatusId	    TINYINT
		, FTFGNGResultStatusId		    TINYINT
		, FTLGResultStatusId		    TINYINT
		, HTFGNGResultStatusId		    TINYINT		
		, HTLGResultStatusId		    TINYINT
		, EventStatusReason				TINYINT
		, autoSettingForLeague			TINYINT
		, InstantWaitingTime			INT
		, DirectWaitingTime				INT
		, InstantHomeScoreBefore		INT
		, InstantAwayScoreBefore		INT
		, InstantGoalRecordBefore		VARCHAR(50)
	)
	
	DECLARE @strBettypesParlay VARCHAR (MAX)
		
	SELECT  @strBettypesParlay = COALESCE(@strBettypesParlay + ',' + CAST(BetType AS VARCHAR),CAST(BetType AS VARCHAR))
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId IN (3,4,8) OR IsUsedGoalRecordValue = 1
	
	;WITH cteSingleTicket AS (
		SELECT	matchid
				,MIN(IsCalculating) AS IsCalculating
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	Starttime > @Today 
				AND SportType = 1
				AND s.LeagueID = CASE WHEN @LeagueId = 0 THEN s.LeagueID ELSE @LeagueId END
		GROUP BY matchid
	), cteParlayTicket AS (
		SELECT	p.matchid
				,MIN(IsCalculating) AS IsCalculating
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK)
				ON p.matchid = m.matchid
		WHERE	Starttime > @Today
				AND m.sporttype = 1
				AND m.leagueid = CASE WHEN @LeagueId = 0 THEN m.leagueid ELSE @LeagueId END
		GROUP BY p.matchid 
	)
	INSERT INTO #tblMatchInQueue(MatchId, SingleStatus, ParlayStatus)
	SELECT	ISNULL(sg.matchid, pl.matchid) AS MatchId
			,sg.IsCalculating AS SingleStatus
			,pl.IsCalculating AS ParlayStatus
	FROM	cteSingleTicket sg
		FULL OUTER JOIN cteParlayTicket pl 
			ON	sg.matchid = pl.matchid
	
	SELECT @MatchIds = COALESCE(@MatchIds + ',' + CAST(MatchId AS VARCHAR(20)),CAST(MatchId AS VARCHAR(20)))
	FROM	#tblMatchInQueue

	INSERT INTO @tblMatchInfo
	EXEC DBPRO.bodb02.dbo.NAP_Set_AutoPayout_MatchInfo 
	@MatchIds = @MatchIds
	
	-- get more match of Auto Payout & Instant
	INSERT INTO #tblMatchInQueue (MatchId, SingleStatus, ParlayStatus)
	SELECT	MatchId
			,MIN(IsCalculatingSingle) AS SingleStatus
			,NULL AS ParlayStatus
	FROM @tblMatchInfo
	WHERE	matchid NOT IN (SELECT MatchId FROM #tblMatchInQueue)
	GROUP BY MatchId
	
	BEGIN
		INSERT INTO #tblBettype (bettype, GroupId,IsUsedGoalRecordValue, IsFGLG)
		SELECT	BetType
				,GroupId
				,IsUsedGoalRecordValue
				,IsFGLG
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	IsUsedGoalRecordValue = 1
		
		SELECT @MinBettype = MIN(bettype)
			,@MaxBettype = MAX(bettype)
		FROM #tblBettype
		
		INSERT INTO #tblBetStatus (MatchId, bettype, IsRunning, IsParlay)
		SELECT	b.matchid
				,b.bettype
				,b.IsRunning
				
				,0 AS IsParlay
		FROM	(SELECT TOP (@n) MatchId FROM #tblMatchInQueue ) m
			CROSS APPLY 
				(
					SELECT	b.matchid
							,b.bettype
							,MAX(CASE 
									WHEN b.statusID = 0 AND GETDATE() > '20160801' THEN 1 -- using hint to force Compute Scalar included in Aggregate Operator 
									ELSE 0 
								END) AS IsRunning
							
					FROM	dbo.bettrans b WITH(NOLOCK)
					WHERE	b.matchid = m.MatchId
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
						AND b.bettype BETWEEN @MinBettype AND @MaxBettype
						AND b.statusID NOT IN (101, 102)
					GROUP BY b.matchid, b.bettype
			)b
		OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
		
		INSERT INTO #tblBetStatus (MatchId, bettype, IsRunning, IsParlay, IsExistFTFGNG, IsExistFTLG, IsExistHTFGNG, IsExistHTLG)
		SELECT	bm.matchid
				,bm.bettype
				,bm.IsRunning
				
				,1 AS IsParlay
				,bm.IsExistFTFGNG
				,bm.IsExistFTLG
				,bm.IsExistHTFGNG
				,bm.IsExistHTLG
		FROM	#tblMatchInQueue m
			CROSS APPLY (
					SELECT	bm.matchid
							,bm.bettype
							,MAX(CASE WHEN bm.statusID = 0 AND GETDATE() > '20160801' THEN 1 ELSE 0 END) AS IsRunning
							,MAX(CASE WHEN bm.bettype = 14 AND betteam IN ('0:0', '1:1', '2:1') THEN 1 ELSE 0 END) AS IsExistFTFGNG
							,MAX(CASE WHEN bm.bettype = 14 AND betteam IN ('1:2', '2:2') THEN 1 ELSE 0 END) AS IsExistFTLG
							,MAX(CASE WHEN bm.bettype = 127 AND betteam IN ('0:0', '1:1', '2:1') THEN 1 ELSE 0 END) AS IsExistHTFGNG
							,MAX(CASE WHEN bm.bettype = 127 AND betteam IN ('1:2', '2:2') THEN 1 ELSE 0 END) AS IsExistHTLG
					FROM	dbo.bettransm bm WITH(NOLOCK)
					WHERE	bm.matchid = m.matchid
							AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
							AND bm.bettype BETWEEN @MinBettype AND @MaxBettype
							AND 1 = CASE
									WHEN CHARINDEX(',' + CAST(bm.bettype AS VARCHAR) + ',',',' + @strBettypesParlay + ',') > 0 THEN 1
									ELSE 0
								END
							AND bm.statusID NOT IN (101, 102)
					GROUP BY bm.matchid, bm.bettype
		) bm
		
		;WITH cteBetStatus
		AS
		(
			SELECT	b.matchid
					,MAX(CASE WHEN f.GroupId IN (1,3) AND f.IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistHTFGLG
					,MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistFGLG
					,MAX(CASE WHEN f.GroupId = 2 AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) AS IsExistGoalRecordBettypeFT	
					,MAX(CASE WHEN f.GroupId = 3 AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) AS IsEnabledGoalRecordHT
					,MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) AS IsEnabledGoalRecordFT
					,MAX(CASE WHEN f.GroupId = 3 AND f.IsUsedGoalRecordValue = 1 AND IsRunning = 1 AND b.IsParlay = 0 THEN 1 ELSE 0 END) AS IsExistRunningUseGoalRecordHT
					,MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 AND IsRunning = 1 AND b.IsParlay = 0 THEN 1 ELSE 0 END) AS IsExistRunningUseGoalRecordFT
					,MAX(CASE WHEN b.IsExistFTFGNG > 0 THEN 1 ELSE 0 END) AS IsExistFTFGNG
					,MAX(CASE WHEN b.IsExistFTLG > 0 THEN 1 ELSE 0 END) AS IsExistFTLG
					,MAX(CASE WHEN b.IsExistHTFGNG > 0 THEN 1 ELSE 0 END) AS IsExistHTFGNG
					,MAX(CASE WHEN b.IsExistHTLG > 0 THEN 1 ELSE 0 END) AS IsExistHTLG
			FROM	#tblBetStatus b
				INNER JOIN #tblBettype f
					ON	b.bettype = f.BetType
			GROUP BY b.matchid
		)
		UPDATE	m
			SET IsExistHTFGLG = b.IsExistHTFGLG
				,IsExistFGLG = b.IsExistFGLG
				,IsExistGoalRecordBettypeFT = b.IsExistGoalRecordBettypeFT
				,IsEnabledGoalRecordHT = b.IsEnabledGoalRecordHT
				,IsEnabledGoalRecordFT = b.IsEnabledGoalRecordFT
				,IsExistRunningUseGoalRecordHT = b.IsExistRunningUseGoalRecordHT
				,IsExistRunningUseGoalRecordFT = b.IsExistRunningUseGoalRecordFT
				,IsExistFTFGNG = b.IsExistFTFGNG
				,IsExistFTLG = b.IsExistFTLG
				,IsExistHTFGNG = b.IsExistHTFGNG
				,IsExistHTLG = b.IsExistHTLG
				
		FROM #tblMatchInQueue m	
			INNER JOIN cteBetStatus b
				ON m.MatchId = b.matchid
	END
	
	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, mt.matchid
	FROM	#tblMatchInQueue m
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
			SET  IsExistMarkedTicket = CASE WHEN m.HasMarkedSingle = 1 OR m.HasMarkedParlay = 1 THEN 1 ELSE 0 END
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
			SET IsExistMarkedTicket = t.IsExistMarkedTicket
		FROM	#tblMatchInQueue m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId

	END

	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0))
	CREATE TABLE #temp_match_parlay (transid BIGINT, matchid INT, refno BIGINT)

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	mq.matchid
	FROM	#tblMatchInQueue mq
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON m.matchid = mq.MatchId
	WHERE	m.eventstatus = 'completed'

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
		WHERE	bm.statusID = 0
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
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
		FROM	#tblMatchInQueue m
			INNER JOIN @tmpMatchCompleted t
				ON m.matchid = t.MatchId
	END

	-- get score from external source and return to web for result comparing
	DECLARE @tmp_ExternalSourceResult TABLE (Matchid INT, SourceId TINYINT, ExHTHomeScore INT, ExHTAwayScore INT, ExFTHomeScore INT, ExFTAwayScore INT)
	DECLARE @queryMatch NVARCHAR(MAX) = ''
	DECLARE @execSql NVARCHAR(MAX) = ''

	SET @queryMatch = '	
						SELECT 
							matchid, SourceId 
							, MAX(CASE WHEN TypeId = 1 THEN HomeValue END) AS HTHomeScore
							, MAX(CASE WHEN TypeId = 1 THEN AwayValue END) AS HTAwayScore
							, MAX(CASE WHEN TypeId = 2 THEN HomeValue END) AS FTHomeScore
							, MAX(CASE WHEN TypeId = 2 THEN AwayValue END) AS FTAwayScore
						FROM 
						(
							SELECT 
								rd.matchid, SourceId, TypeId, HomeValue, AwayValue, CreatedDate
								, RANK()OVER(PARTITION BY rd.matchid, SourceId, TypeId ORDER BY createddate DESC) maxDate
							FROM bodb02.dbo.ProviderResultDetail rd WITH(NOLOCK)
								INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , '','')) tm
														ON rd.matchid = tm.value
							WHERE TypeId IN (1,2) AND SourceId = 1
						) t
						WHERE maxDate = 1
						GROUP BY t.MatchId, SourceId
						
					'
	SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryMatch, N''@MatchIds VARCHAR(MAX)'', @matchids'

	INSERT INTO @tmp_ExternalSourceResult(Matchid, SourceId, ExHTHomeScore, ExHTAwayScore, ExFTHomeScore, ExFTAwayScore)
	EXECUTE	sys.sp_executesql @execSql, N'@queryMatch NVARCHAR(MAX), @MatchIds VARCHAR(MAX)', @queryMatch, @matchids
			
	SELECT	i.MatchId
			,i.leagueId
			,i.HalfTimeHomeScore
			,i.HalfTimeAwayScore
			,i.IsCalculated
			,i.IsFTCalculated
			,i.IsMultiCaled
			,i.IsRefund
			,i.IsCalRefund
			,i.homeid
			,i.awayid
			,i.matchcode
			,i.finalhomescore
			,i.finalawayscore
			,i.betstatus
			,i.eventstatus
			,CAST(1 AS TINYINT) AS sporttype
			,i.IsNeutral
			,i.goalrecord
			,i.IsHalfTimeCal
			,i.SettlementStatus
			,ISNULL(m.IsExistFGLG,0) AS IsExistFGLG
			,ISNULL(m.IsExistHTFGLG,0) AS IsExistHTFGLG
			,ISNULL(m.SingleStatus, i.IsCalculatingSingle) AS IsCalculatingSingle
			,m.ParlayStatus AS IsCalculatingMP
			,i.suspenderHalfTime
			,i.suspenderFullTime
			,i.AutoSetting
			,ISNULL(m.IsEnabledGoalRecordHT, 0) AS IsEnabledGoalRecordHT
			,ISNULL(m.IsEnabledGoalRecordFT, 0) AS IsEnabledGoalRecordFT
			/*Instant match info*/
			, i.livehomescore
			, i.liveawayscore
			, i.IsHT
			, i.LivePeriod
			, i.InstantHomeScore
			, i.InstantAwayScore
			, i.InstantStatusId
			, i.InstantCalculationType
			, i.InstantKey
			, i.InstantScoreDiff

			,m.IsExistMarkedTicket
			,m.IsExistRunningTicket
			,i.EventStatusReason
			,i.autoSettingForLeague
			,i.InstantWaitingTime
			,i.DirectWaitingTime	
			,i.InstantHomeScoreBefore
			,i.InstantAwayScoreBefore
			,i.InstantGoalRecordBefore
	FROM	@tblMatchInfo i
		LEFT JOIN #tblMatchInQueue m
			ON i.matchid = m.MatchId
		LEFT JOIN @tmp_ExternalSourceResult exSource 
			ON m.matchid = exSource.Matchid
		
	DROP TABLE #tblMatchInQueue
	DROP TABLE #tblBetStatus

END

GO