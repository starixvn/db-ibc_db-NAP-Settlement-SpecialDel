/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel] 
	@FromDate DATETIME
	,@ToDate DATETIME
	,@SportType SMALLINT = 0
	,@LeagueID INT = 0 -- 0 for ALL Leagues
	,@MatchCode NVARCHAR(50) = ''
	,@StatusId TINYINT = 0
	,@FilterBy TINYINT = 0
	,@AutoSettlementOnly BIT = 0 
	,@FastMarketsOnly BIT = 0 
	,@IsReLoad BIT = 0
	,@IsMarkedTicket BIT = 0
AS
/*  
 Created by: Kathy
 Date: 20131223
 Task: Match results for calculating settlement 
 DB: DBTXN/BODB02
 Original: Acc_Set_MatchSel
 Revisions:  
		- 20140417@Kathy: re-arrange order list (follow by old system)
		- 20140421@Kathy: get match status in queue
		- 20140428@Kathy: get 1H FGLG ticket info [Redmine:#14449]
		- 20140714@Kathy: filter by running penalty shootout only [Redmine:#17142]
		- 20141006@Jamie: Get ResultDetail for Tennis [Redmine:#23034]
		- 20150130@Jamie: Betradar phase II [Readmine:#27212]
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20151207@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160805@Kathy: Write log duration
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20161118@Kathy: Changes on Auto Settlement - Move sp to DBTXN [Redmine:#67328]
		- 20160509@Kathy: Fast Market integration [Remine:#56367]
		- 20161223@Bobby: #69335 - Add filtering by Abandoned status
		- 20170320@Bobby: Add filtering by abandoned status for Un-calculated multiple only option [Redmine:#73597]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170613@Kathy: Early Settlement [Redmine:#77835]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180611@Kaden: Add Blinking Color for Disabled Auto Cal FM Matches [Redmine:#96018]
		- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
		- 20180731@Vicky: e-sport 2.0 [Redmine: #95874]
		- 20181127@Vicky: Add MTD Hold status & Postponed [Redmine: #104948]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190610@Kathy: Exclude checking running BetBuilder tickets [Redmine:#114877]
		- 20190620@Kathy: PH AIO Phase 4 [Redmine:#109584]
      
 Param explanation:  
	@MatchCode: match code
	@LeagueID: = 0: show info of all leagues     
	@StatusId: 0: all, 1: running; 2: closed; 3: completed; 4: refund, 5: Postponed, 6: Abandoned, 7: Result Pending, 8: Undecided, 9: Under Settlement, 10: MTD Hold
	@FilterBy: 0: none, 1: un-calculated game; 2: Un-calculated multiple only; 3: all
	@PenaltyShootoutOnly: 0: none; 1: running penalty shootout only
	@IsReLoad: 1: reload partial matches of a league, 0: not reload
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @UncalOnly BIT
		,@UncalMultiOnly BIT
		,@eventstatus NVARCHAR(50)
		,@isRefund BIT
		,@matchid INT
		,@StartTime DATETIME
		,@EndTime	DATETIME
		,@SqlCommand VARCHAR(MAX)
		,@SettlementStatus TINYINT
		,@isSettingByProfile BIT = 0
		,@existSettingEarly BIT = 0
	
	SET @StartTime = GETDATE()
	
	SELECT @matchcode = ISNULL(@matchcode, '')
		,@LeagueID = ISNULL(@LeagueID, 0)
		,@filterBy = ISNULL(@filterBy, 0)

	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
	BEGIN
		SELECT @isSettingByProfile = 1
		IF EXISTS (SELECT TOP 1 1 FROM SettlementSpecialBettypeProfile WITH (NOLOCK) WHERE sporttype = @sporttype AND SettleType = 'EAR')
		BEGIN
			SET @existSettingEarly = 1
		END
	END
	
	
	-- if entering matcode, ignore other params (excep FromDate, ToDate, sport type)
	IF (@matchcode <> '')
	BEGIN
		SELECT @eventstatus = ''
			,@isRefund = NULL
			,@LeagueID = CASE 
				WHEN @isReLoad = 1 THEN @LeagueID
				ELSE 0
				END
			,-- reload partial; search on LeagueID, not reload: get all leagues	
			@UncalOnly = NULL
			,@UncalMultiOnly = NULL
			,@AutoSettlementOnly = 0
			,@FastMarketsOnly =0
			,@SettlementStatus = 0
			,@IsMarkedTicket = 0

		BEGIN TRY
			SET @matchid = CASE 
					WHEN ISNUMERIC(@matchcode) = 1 THEN CAST(@matchcode AS INT)
					ELSE NULL
					END
		END TRY

		BEGIN CATCH
			SET @matchid = NULL
		END CATCH
	END
	ELSE
	BEGIN
		SELECT @eventstatus = CASE 
				WHEN @statusid = 1 THEN 'running'
				WHEN @statusid = 2 THEN 'closed'
				WHEN @statusid IN (3, 6) THEN 'completed'
				WHEN @statusid = 5 THEN 'postponed'
				ELSE ''
				END
			,@isRefund = CASE 
				WHEN @statusid IN (4, 6) THEN 1
				WHEN @statusid = 0 THEN NULL
				ELSE 0
				END
			,@UncalOnly = CASE 
				WHEN @filterBy IN (3, 1) THEN 1
				ELSE 0
				END
			,@UncalMultiOnly = CASE 
				WHEN @filterBy IN (3, 2) THEN 1
				ELSE 0
				END
			,@SettlementStatus = CASE
				WHEN @StatusId = 7 THEN 1
				WHEN @StatusId = 8 THEN 2
				WHEN @StatusId = 9 THEN 4
				WHEN @StatusId = 10 THEN 16
				ELSE 0 
				END

		--ignore event status if selecting filterby
		IF (@UncalMultiOnly = 1 OR @UncalOnly = 1 OR @AutoSettlementOnly = 1 OR @FastMarketsOnly = 1 OR @SettlementStatus <> 0 OR @IsMarkedTicket <> 0)
			SELECT @eventstatus = ''
				,@isRefund = NULL
	END

	CREATE TABLE #matchList (
		HalfTimeHomeScore INT
		,HalfTimeAwayScore INT
		,IsCalculated BIT
		,IsMultiCaled BIT
		,IsRefund BIT
		,IsCalRefund BIT
		,matchid INT
		,leagueid INT
		,homeid INT
		,awayid INT
		,matchcode NVARCHAR(50)
		,kickofftime DATETIME
		,finalhomescore INT
		,finalawayscore INT
		,betstatus NVARCHAR(50)
		,eventstatus NVARCHAR(50)
		,sporttype SMALLINT
		,IsNeutral BIT
		,eventdate DATETIME
		,goalrecord VARCHAR(50)
		,suspenderHalfTime NVARCHAR(50)
		,suspenderFullTime NVARCHAR(50)
		,IsHalfTimeCal BIT
		,calculate BIT
		,SettlementStatus TINYINT
		,IsExistFGLG BIT
		,IsExistHTFGLG BIT
		,AutoSetting TINYINT		
		,IsExistFastMarket BIT
		,IsRunningFastMarket BIT		
		,IsExistFastMarketResult BIT
		,IsExistEarlyBettypes BIT
		,IsExistEarlyBettypesParlay BIT
		,IsRunningEarlyBettypes BIT
		,IsRunningEarlyBettypesParlay BIT
		,IsWaitingEarlyBettypes BIT
		,IsWaitingEarlyBettypesParlay BIT
		,IsExistRunningTicket BIT
		,IsExistMarkedTicket BIT
		)

	DECLARE @strmatchid VARCHAR(MAX)
		,@betstatus VARCHAR(8000)
		,@intDocHandle INT
		,@rowcount INT
		,@max_matchid INT
	DECLARE @tmp_match TABLE (matchid INT)

	INSERT INTO #matchList (HalfTimeHomeScore,HalfTimeAwayScore ,IsCalculated ,IsMultiCaled ,IsRefund ,IsCalRefund ,matchid ,leagueid ,homeid ,awayid ,matchcode ,kickofftime ,finalhomescore ,finalawayscore 
		,betstatus 	,eventstatus,sporttype ,IsNeutral ,eventdate ,goalrecord ,suspenderHalfTime,suspenderFullTime 	,IsHalfTimeCal ,calculate 
		,SettlementStatus 
		,IsExistFGLG ,IsExistHTFGLG ,AutoSetting 
		,IsExistFastMarket,IsRunningFastMarket 
		,IsExistFastMarketResult
		,IsExistEarlyBettypes,IsExistEarlyBettypesParlay,IsRunningEarlyBettypes,IsRunningEarlyBettypesParlay, IsWaitingEarlyBettypes, IsWaitingEarlyBettypesParlay
		,IsExistRunningTicket, IsExistMarkedTicket
	)
	SELECT 
		tmp.hthomescore
		,tmp.htawayscore
		,ISNULL(mr.calculate, 0) IsCalculated
		,ISNULL(mr.multiple, 0) IsMultiCaled
		,ISNULL(mr.refund, 0) IsRefund
		,ISNULL(mr.calrefund, 0) IsCalRefund
		,tmp.matchid
		,tmp.leagueid
		,tmp.homeid
		,tmp.awayid
		,tmp.matchcode
		,tmp.kickofftime
		,tmp.finalhomescore
		,tmp.finalawayscore
		,tmp.betstatus
		,tmp.eventstatus
		,tmp.sporttype
		,tmp.IsNeutral
		,tmp.eventdate
		,tmp.goalrecord
		,CASE mr.ConfirmHT
		WHEN 0 THEN ''
		ELSE (
				SELECT username
				FROM CustDB.dbo.custinfo WITH (NOLOCK)
				WHERE custid = mr.ConfirmHT
				)
		END suspenderHT
		,CASE mr.ConfirmFT
			WHEN 0 THEN ''
			ELSE (
					SELECT username
					FROM CustDB.dbo.custinfo WITH (NOLOCK)
					WHERE custid = mr.ConfirmFT
					)
		END suspenderFT
		,ISNULL(mr.IsHTCal, 0) AS IsHTCal
		,ISNULL(mr.calculate, 0) AS calculate
		,tmp.SettlementStatus
		,tmp.IsExistFGLG
		,tmp.IsExistHTFGLG
		,tmp.AutoSetting
		,0 AS IsExistFastMarket
		,0 AS IsRunningFastMarket
		,0 AS IsExistFastMarketResult
		,0 AS IsExistEarlyBettypes
		,0 AS IsExistEarlyBettypesParlay
		,0 AS IsRunningEarlyBettypes
		,0 AS IsRunningEarlyBettypesParlay
		,0 AS IsWaitingEarlyBettype
		,0 AS IsWaitingEarlyBettypeParlay 
		,0 AS IsExistRunningTicket
		,0 AS IsExistMarkedTicket
	FROM (
		SELECT hthomescore
			,htawayscore			
			,m.matchid
			,m.leagueid
			,m.homeid
			,m.awayid
			,m.matchcode
			,m.kickofftime
			,m.finalhomescore
			,m.finalawayscore
			,m.betstatus
			,m.eventstatus
			,m.sporttype
			,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
			,m.eventdate
			,m.goalrecord						
			,0 as IsExistFGLG
			,0 as IsExistHTFGLG
			,ISNULL(m.AutoSetting, 0) AS AutoSetting
			,ISNULL(m.SettlementStatus, 0) AS SettlementStatus
		FROM	dbo.match m WITH (NOLOCK)
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail r WITH (NOLOCK) ON m.matchID = r.MatchId AND r.ResourceId ='00'
		WHERE m.eventdate BETWEEN @FromDate AND @ToDate 
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
			AND m.sporttype = @sporttype 
			AND (@matchcode = '' OR (m.matchid = @matchid OR m.matchcode = @matchcode)) 
			AND (@eventstatus = '' OR eventstatus IN (@eventstatus, 'internal')) 
			AND (@isRefund IS NULL 
						OR (
							m.sporttype <> 5 AND @isRefund = 1 
							AND 1 = CASE 
										WHEN @statusid = 4 AND betstatus LIKE 'Refund%' THEN 1
										WHEN @statusid = 6 AND betstatus LIKE 'Abandoned%' THEN 1
										ELSE 0
									END
						) 
					OR (m.sporttype <> 5 AND @isRefund = 0 AND ISNULL(betstatus, '') NOT LIKE 'Refund%' AND ISNULL(betstatus, '') NOT LIKE 'Abandoned%')
					OR (m.sporttype = 5 AND @isRefund = 1 AND ISNULL(r.SettlementStatusID,0) BETWEEN 1 AND 3)
					OR (m.sporttype = 5 AND @isRefund = 0 AND ISNULL(r.SettlementStatusID,0) NOT BETWEEN 1 AND 3)
				)
			AND (@SettlementStatus = 0 OR @SettlementStatus & m.SettlementStatus > 0)
	) tmp
	LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON tmp.matchid = mr.matchid
	WHERE	(@UncalOnly = 0 OR ISNULL(mr.calculate, 0) = 0 OR @UncalOnly IS NULL) 
			AND (@UncalMultiOnly = 0 OR (ISNULL(mr.multiple, 0) = 0 AND (ISNULL(mr.calculate, 0) = 1 OR ISNULL(mr.calrefund, 0) = 1)) OR @UncalMultiOnly IS NULL)	
	
	--check FGLG & BetRadar
	DECLARE @strBettypesParlay	VARCHAR (MAX)		
		,@n						INT = 2147483647

	
	CREATE TABLE #tmpBettypes (bettype SMALLINT, groupid SMALLINT, IsFGLG BIT, IsEarly BIT)
	
	DECLARE @minbettype SMALLINT	
			,@maxbettype SMALLINT
	
	INSERT INTO #tmpBettypes (bettype, groupid, IsFGLG, IsEarly)
	SELECT	BetType, f.GroupId, f.IsFGLG, ISNULL(e.IsEarly, 0)
	FROM	dbo.f_Set_GetGroupBettypes() f
		OUTER APPLY (
			SELECT 1 AS IsEarly
			FROM dbo.f_Set_GetEarlyBettypes() e
			WHERE f.BetType = e.bettype
		) e
	WHERE	f.IsUsedGoalRecordValue = 1 
			OR f.GroupId = 9 
			OR e.IsEarly = 1
	
	SELECT @minbettype = MIN(bettype)
		,@maxbettype = MAX(bettype)
	FROM	#tmpBettypes
	
	CREATE TABLE #BettypeExtraStatus(matchid INT, bettype SMALLINT,Bet_cnt INT, isRunning BIT,Waiting_cnt INT, IsParLay BIT DEFAULT(0), GroupId TINYINT, IsFGLG BIT, IsEarly BIT)
		
	INSERT INTO #BettypeExtraStatus (matchid, bettype, Bet_cnt, isRunning,Waiting_cnt, GroupId,IsFGLG, IsEarly)
	SELECT m.matchid, chk.bettype,chk.Bet_cnt, chk.IsRunning,chk.Waiting_cnt, chk.GroupId,chk.IsFGLG, chk.IsEarly
	FROM (
		SELECT TOP (@n) MatchId FROM #matchList
	) AS m
		CROSS APPLY 
		(
			SELECT b.bettype
				, MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) AS IsRunning
				, SUM(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS Waiting_cnt
				, SUM(CASE WHEN b.StatusID BETWEEN 101 AND 102 THEN 0	ELSE 1 END) AS Bet_cnt
				, MAX(t.GroupId) AS GroupId
				, MAX(CASE WHEN t.IsFGLG = 1 THEN 1 ELSE 0 END) AS IsFGLG
				, MAX(CASE WHEN t.IsEarly = 1 THEN 1 ELSE 0 END) AS IsEarly
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN #tmpBettypes t
					ON b.bettype = t.bettype
			WHERE b.matchid = m.MatchId
				AND b.bettype BETWEEN @minbettype AND @maxbettype
				AND b.statusID NOT IN (101, 102)
			GROUP BY b.bettype
		) AS chk
	OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	
	;WITH MatchExtraStatus AS (
		SELECT matchid
			,SUM(CASE WHEN GroupId IN (2,4) AND IsFGLG = 1 THEN 1 ELSE 0 END ) AS cntFGLG
			,SUM(CASE WHEN GroupId IN (1,3) AND IsFGLG = 1  THEN 1 ELSE 0 END ) AS cntHTFGLG
			,SUM(CASE WHEN GroupId = 9 THEN 1 ELSE 0 END ) AS cntFastMarket
			,MAX(CASE WHEN GroupId = 9 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningFastMarket
			,SUM(CASE WHEN IsEarly = 1 THEN 1 ELSE 0 END ) AS cntEarlyBettypes
			,MAX(CASE WHEN IsEarly = 1 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningEarlyBettypes
			,MAX(CASE WHEN IsEarly = 1 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWatingEarlyBettypes
		FROM #BettypeExtraStatus
		GROUP BY matchid
	)
	UPDATE m
	SET IsExistFGLG 			= CASE WHEN ext.cntFGLG > 0 THEN 1 ELSE 0 END
		,IsExistHTFGLG 			= CASE WHEN ext.cntHTFGLG > 0 THEN 1 ELSE 0 END
		,IsExistFastMarket 	= CASE WHEN ext.cntFastMarket > 0 THEN 1 ELSE 0 END
		,IsRunningFastMarket = CASE WHEN ext.IsRunningFastMarket = 1 THEN 1 ELSE 0 END
		,IsExistEarlyBettypes = CASE WHEN ext.cntEarlyBettypes > 0 THEN 1 ELSE 0 END
		,IsRunningEarlyBettypes = CASE WHEN ext.IsRunningEarlyBettypes = 1 THEN 1 ELSE 0 END
		,IsWaitingEarlyBettypes = CASE WHEN ext.IsWatingEarlyBettypes = 1 THEN 1 ELSE 0 END
	FROM #matchList m
		INNER JOIN MatchExtraStatus ext 
		ON m.matchid = ext.matchid
	
	-- check bettransm
	INSERT INTO #BettypeExtraStatus (matchid, bettype, Bet_cnt, isRunning, Waiting_cnt, IsParLay, GroupId)
	SELECT m.matchid, chk.bettype,chk.Bet_cnt, chk.IsRunning,chk.Waiting_cnt, 1, chk.GroupId
	FROM (
		SELECT TOP (@n) MatchId FROM #matchList
	) AS m
		CROSS APPLY 
		(
			SELECT	bm.bettype
					, MAX(CASE WHEN bm.statusID = 0 THEN 1 ELSE 0 END) AS IsRunning
					, SUM(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) AS Waiting_cnt
					, SUM(CASE WHEN bm.StatusID BETWEEN 101 AND 102 THEN 0	ELSE 1 END) AS Bet_cnt
					, MAX(t.groupid) AS GroupId
					, MAX(CASE WHEN t.IsEarly = 1 THEN 1 ELSE 0 END) AS IsEarly
			FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN	#tmpBettypes t
					ON	bm.bettype = t.bettype
			WHERE	bm.matchid = m.MatchId	
				AND	t.groupid <> 9
				AND bm.bettype BETWEEN @minbettype AND @maxbettype		
				AND bm.statusID NOT IN (101, 102)
			GROUP BY bm.bettype
		) AS chk
	OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	
	;WITH MatchExtraStatusParlay AS (
		SELECT matchid
			,SUM(CASE WHEN GroupId = 4 THEN 1 ELSE 0 END ) AS cntFGLG
			,SUM(CASE WHEN GroupId = 3 THEN 1 ELSE 0 END ) AS cntHTFGLG
			,SUM(CASE WHEN IsEarly = 1 THEN 1 ELSE 0 END) AS cntEarlyBettypeParlay
			,MAX(CASE WHEN IsEarly = 1 AND isRunning = 1 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypesParlay
			,MAX(CASE WHEN IsEarly = 1 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWaitingEarlyBettypesParlay
		FROM #BettypeExtraStatus
		WHERE IsParLay = 1
		GROUP BY matchid
	)
	UPDATE m
	SET IsExistFGLG 			= CASE WHEN  m.IsExistFGLG = 1 OR ext.cntFGLG > 0 THEN 1 ELSE 0 END
		,IsExistHTFGLG 			= CASE WHEN  m.IsExistFGLG = 1 OR ext.cntHTFGLG > 0 THEN 1 ELSE 0 END
		,IsExistEarlyBettypesParlay	= CASE WHEN ext.cntEarlyBettypeParlay > 0 THEN 1 ELSE 0 END
		,IsRunningEarlyBettypesParlay = CASE WHEN ext.IsRunningEarlyBettypesParlay = 1 THEN 1 ELSE 0 END
		,IsWaitingEarlyBettypesParlay = CASE WHEN ext.IsWaitingEarlyBettypesParlay = 1 THEN 1 ELSE 0 END
	FROM #matchList m
		INNER JOIN MatchExtraStatusParlay ext 
		ON m.matchid = ext.matchid

	;WITH SingleTicket AS
	(
		SELECT matchid, min(IsCalculating)  IsCalculating
		FROM dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE Starttime > DATEADD(HH,-1,GETDATE())
		AND s.IsCalculating IN (0,1)
		group by matchid 
	),
	ParlayTicket AS
	(
		SELECT p.matchid, min(IsCalculating)  IsCalculating
		FROM dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE Starttime > DATEADD(HH,-1,GETDATE())
		AND p.IsCalculating IN (0,1)
		group by matchid 
	)	

	select isnull(sg.matchid, pl.matchid) matchid, sg.IsCalculating IsCalculatingSingle, pl.IsCalculating IsCalculatingMP
	into #tempmatch
	from SingleTicket sg
		full outer join ParlayTicket pl on sg.matchid = pl.matchid 

	;WITH cteAutoResultDetail 
	AS(
		SELECT	CAST(BetType AS VARCHAR(20)) + '__' AS ResourceId
				,GroupId
		FROM	#tmpBettypes
		WHERE	groupid = 9
	)	
	UPDATE	m
		SET	IsExistFastMarketResult = 1
	FROM	#matchList m
		CROSS APPLY (
			SELECT	TOP 1 r.matchid
			FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
				INNER JOIN cteAutoResultDetail c
					ON	r.ResourceId LIKE c.ResourceId
			WHERE	r.MatchId = m.matchid
					AND @sporttype IN (0,1)
			GROUP BY r.MatchId
		)r
	
	IF (@FastMarketsOnly = 1 AND @sporttype = 1)
	BEGIN
		DELETE FROM	#matchList WHERE IsExistFastMarket = 0 AND IsExistFastMarketResult = 0
	END
	
	IF (@AutoSettlementOnly = 1) --Running Auto bettypes ONLY (BAIO, BETRADAR)
	BEGIN
		IF (@sporttype IN (1,2) OR @existSettingEarly = 1)
		BEGIN
			DELETE FROM #matchList
			WHERE 1 = CASE
							WHEN IsExistEarlyBettypes > 0 AND IsRunningEarlyBettypes = 0 THEN 1
							WHEN IsExistEarlyBettypes = 0 AND IsRunningEarlyBettypesParlay = 0 THEN 1
							ELSE 0
					  END
		END			
		
	END

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT PRIMARY KEY, matchId INT)

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, m.matchid
	FROM	#matchList m
		CROSS APPLY (
			SELECT	mt.TransId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = 1
		FROM	@tmpMatchMarked mk
			INNER JOIN (
				SELECT	mt.matchId
				FROM	#tmpMarkedTransaction mt
					CROSS APPLY (
						SELECT	TOP (1) b.transid
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	mt.transid = b.transid
								AND b.statusID = 0
					) b
				GROUP BY mt.matchid
			) m
				ON m.matchid = mk.MatchId

		UPDATE m 
			SET IsExistMarkedTicket = t.IsExistMarkedTicket
		FROM	#matchList m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId

	END

	IF @IsMarkedTicket = 1
	BEGIN
		DELETE m
		FROM #matchList m 
		WHERE	IsExistMarkedTicket = 0
	END

	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0))

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
						AND b.statusID = 0
						AND b.bettype NOT BETWEEN 801 AND 806 -- Metric Gaming
						AND b.bettype <> 38 -- BetBuilder
						AND mt.transId IS NULL
				GROUP BY b.matchid
			)b

		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	#matchList m
			INNER JOIN @tmpMatchCompleted t
				ON m.matchid = t.MatchId
	END

	SELECT	m.HalfTimeHomeScore
			,m.HalfTimeAwayScore
			,m.IsCalculated
			,m.IsMultiCaled
			,m.IsRefund
			,m.IsCalRefund
			,m.matchid
			,m.leagueid
			,m.homeid
			,m.awayid
			,m.matchcode
			,m.kickofftime
			,m.finalhomescore
			,m.finalawayscore
			,m.betstatus
			,m.eventstatus
			,m.sporttype
			,m.IsNeutral
			,m.eventdate
			,m.goalrecord
			,m.suspenderHalfTime
			,m.suspenderFullTime
			,m.IsHalfTimeCal
			,m.calculate
			,m.SettlementStatus
			,m.IsExistFGLG
			,m.IsExistHTFGLG
			,m.AutoSetting
			,t.IsCalculatingSingle
			,t.IsCalculatingMP
			,CASE 
				WHEN m.IsExistFastMarket = 0 AND m.IsExistFastMarketResult = 0 THEN 'N/A'
				WHEN m.IsExistFastMarket = 0 AND m.IsExistFastMarketResult = 1 THEN 'No Ticket'
				WHEN m.IsRunningFastMarket > 0 THEN 'Running'	
				ELSE 'Completed'		
			END AS AutoSettleFastMarket
			
			,CASE
				WHEN m.IsExistEarlyBettypes = 0 AND m.IsExistEarlyBettypesParlay = 0 THEN 'N/A' 
				WHEN m.IsRunningEarlyBettypes > 0 THEN 'Running'
				WHEN m.IsWaitingEarlyBettypes > 0 THEN 'Waiting'
				WHEN m.IsExistEarlyBettypes = 0 AND m.IsRunningEarlyBettypesParlay > 0 THEN 'Parlay Running'
				WHEN m.IsExistEarlyBettypes = 0 AND m.IsWaitingEarlyBettypesParlay > 0 THEN 'Parlay Waiting'
				ELSE 'Completed'
			END AS EarlySettleStatus
			
			,m.IsExistRunningTicket
			,m.IsExistMarkedTicket
	FROM	#matchList m
		LEFT JOIN #tempmatch t 
			ON	t.matchid = m.matchid
	ORDER BY case m.eventstatus when 'completed' then 1 when 'refund' then 1 else 0 END
		, m.eventdate
		, m.kickofftime
		, m.sporttype
		, m.leagueid
		, m.matchid
		, m.betstatus
		, m.matchcode			

	-- Get TENNIS, BASKETBALL RESULT 
	

	IF @isSettingByProfile = 1
    BEGIN
	    DECLARE @matchidList VARCHAR(MAX) = ''
	    
	    SELECT @matchidList =  @matchidList + ',' + CAST(matchid AS VARCHAR(20))
	    FROM #matchList
	    SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))
	    
		EXEC DBPRO.bodb02.dbo.NAP_Set_MatchSel_ResultDetail 
					@matchidList = @matchidList
					,@Sporttype = @Sporttype   
    END
    ELSE
    BEGIN
		SELECT	MatchId
				, ResourceId
				, HomeValue
				, AwayValue
				, ResultStatusID
				, SettlementStatusID
		FROM	DBPRO.bodb02.dbo.[ResultDetail] WITH (NOLOCK) 
		WHERE	@Sporttype IN (0,2,5)
				AND (ResourceId LIKE '0[0-5]' -- Tennis
					OR ResourceId LIKE 'Q[1-4]' OR ResourceId = 'OT' -- Basketball: 00, 01, Q1, Q2, Q3, Q4, OT
				)
				AND MatchID IN (SELECT MatchID FROM #matchList)
	END
	DROP TABLE #matchList
	
	SET @EndTime = GETDATE()
	
	IF DATEDIFF(MILLISECOND,@StartTime, @EndTime) > 10000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_MatchSel @FromDate =''' + CONVERT(VARCHAR(20), @FromDate) + ''''
						+ ', @ToDate = ''' + CONVERT(VARCHAR(20), @ToDate) + ''''
						+ ', @SportType =' + CONVERT(VARCHAR(10), @SportType) 
						+ ', @LeagueID =' + CONVERT(VARCHAR(10), @LeagueID)  
						+ ', @MatchCode =''' + ISNULL(@MatchCode, '') + ''''
						+ ', @StatusId = '+ CONVERT(VARCHAR(10), @StatusId)  
						+ ', @FilterBy = '+ CONVERT(VARCHAR(10), @FilterBy)  
						+ ', @AutoSettlementOnly = '+ CONVERT(VARCHAR(10), @AutoSettlementOnly)
						+ ', @FastMarketsOnly = ' + CONVERT(VARCHAR(10), @FastMarketsOnly)	
						+ ', @IsReLoad = '+ CONVERT(VARCHAR(10), @IsReLoad)  
						
	
		INSERT INTO SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END
END
GO
