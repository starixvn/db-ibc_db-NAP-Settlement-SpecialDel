/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel] 
	@FromDate				DATETIME
	,@ToDate				DATETIME
	,@SportType				SMALLINT = 0
	,@LeagueID				INT = 0 -- 0 for ALL Leagues
	,@MatchCode				NVARCHAR(50) = ''
	,@StatusId				TINYINT = 0
	,@FilterBy				TINYINT = 0
	,@AutoSettlementOnly	BIT = 0 
	,@FastMarketsOnly		BIT = 0 
	,@IsReLoad				BIT = 0
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
      
 Param explanation:  
	@MatchCode: match code
	@LeagueID: = 0: show info of all leagues     
	@StatusId: 0: all, 1: running; 2: closed; 3: completed; 4: refund; 6: Abandoned, 7: Result Pending, 8: Under Settlement
	@FilterBy: 0: none, 1: un-calculated game; 2: Un-calculated multiple only; 3: all
	@PenaltyShootoutOnly: 0: none; 1: running penalty shootout only
	@IsReLoad: 1: reload partial matches of a league, 0: not reload
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@UncalOnly			BIT
			,@UncalMultiOnly	BIT
			,@eventstatus		NVARCHAR(50)
			,@isRefund			BIT
			,@matchid			INT
			,@StartTime			DATETIME
			,@EndTime			DATETIME
			,@SqlCommand		VARCHAR(MAX)
	
	SET @StartTime = GETDATE()
	
	SELECT	@matchcode = ISNULL(@matchcode, '')
			,@LeagueID = ISNULL(@LeagueID, 0)
			,@filterBy = ISNULL(@filterBy, 0)

	-- if entering matcode, ignore other params (excep FromDate, ToDate, sport type)
	IF (@matchcode <> '')
	BEGIN
		SELECT	@eventstatus = ''
				,@isRefund = NULL
				,@LeagueID = CASE 
								WHEN @isReLoad = 1 THEN @LeagueID
								ELSE 0
							END
			-- reload partial; search on LeagueID, not reload: get all leagues	
				,@UncalOnly = NULL
				,@UncalMultiOnly = NULL
				,@AutoSettlementOnly = 0
				,@FastMarketsOnly =0

		BEGIN TRY
			SET @matchid = CASE 
								WHEN ISNUMERIC(@matchcode) = 1 THEN CAST(@matchcode AS INT)
								ELSE NULL
							END
		END TRY

		BEGIN CATCH
			SET		@matchid = NULL
		END CATCH
	END
	ELSE
	BEGIN
		SELECT @eventstatus = CASE 
								WHEN @statusid = 1 THEN 'running'
								WHEN @statusid = 2 THEN 'closed'
								WHEN @statusid IN (3, 6) THEN 'completed'
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

		--ignore event status if selecting filterby
		IF (@UncalMultiOnly = 1 OR @UncalOnly = 1 OR @AutoSettlementOnly = 1 OR @FastMarketsOnly = 1)
			SELECT @eventstatus = ''
				,@isRefund = NULL
	END

	CREATE TABLE #matchList (
		HalfTimeHomeScore				INT
		,HalfTimeAwayScore				INT
		,IsCalculated					BIT
		,IsMultiCaled					BIT
		,IsRefund						BIT
		,IsCalRefund					BIT
		,matchid						INT
		,leagueid						INT
		,homeid							INT
		,awayid							INT
		,matchcode						NVARCHAR(50)
		,kickofftime					DATETIME
		,finalhomescore					INT
		,finalawayscore					INT
		,betstatus						NVARCHAR(50)
		,eventstatus					NVARCHAR(50)
		,sporttype						SMALLINT
		,IsNeutral						BIT
		,eventdate						DATETIME
		,goalrecord						VARCHAR(50)
		,suspenderHalfTime				NVARCHAR(50)
		,suspenderFullTime				NVARCHAR(50)
		,IsHalfTimeCal					BIT
		,calculate						BIT
		,IsPending						BIT
		,IsUndecided					BIT
		,IsExistFGLG					BIT
		,IsExistHTFGLG					BIT
		,AutoSetting					TINYINT
		,IsExistAutoBettypes			BIT
		,IsExistAutoBettypesParlay		BIT
		
		,IsRunningAutoBettypes			BIT
		,IsRunningAutoBettypesParlay	BIT
		
		,IsWaitingAutoBettypes			BIT
		,IsWaitingAutoBettypesParlay	BIT
		
		,IsMissingAutoResult			BIT
		,IsExistFastMarket				BIT
		,IsRunningFastMarket			BIT
		,SettlementStatusID				TINYINT
		,IsExistFastMarketResult		BIT
		,IsExistEarlyBettypes			BIT
		,IsExistEarlyBettypesParlay		BIT
		,IsRunningEarlyBettypes			BIT
		,IsRunningEarlyBettypesParlay	BIT
	)

	INSERT INTO #matchList (HalfTimeHomeScore,HalfTimeAwayScore ,IsCalculated ,IsMultiCaled ,IsRefund ,IsCalRefund ,matchid ,leagueid ,homeid ,awayid ,matchcode ,kickofftime ,finalhomescore ,finalawayscore 
		,betstatus 	,eventstatus ,sporttype ,IsNeutral ,eventdate ,goalrecord 	,suspenderHalfTime 	,suspenderFullTime 	,IsHalfTimeCal ,calculate, IsPending, IsUndecided
		,IsExistFGLG ,IsExistHTFGLG ,AutoSetting ,IsExistAutoBettypes ,IsExistAutoBettypesParlay ,IsRunningAutoBettypes ,IsRunningAutoBettypesParlay 
		,IsWaitingAutoBettypes ,IsWaitingAutoBettypesParlay ,IsMissingAutoResult ,IsExistFastMarket ,IsRunningFastMarket ,SettlementStatusID,IsExistFastMarketResult ,IsExistEarlyBettypes	,IsExistEarlyBettypesParlay 
		,IsRunningEarlyBettypes ,IsRunningEarlyBettypesParlay)
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
		,ISNULL(mr.isPending, 0) AS isPending
		,ISNULL(mr.isUndecided, 0) AS isUndecided
		,tmp.IsExistFGLG
		,tmp.IsExistHTFGLG
		,tmp.AutoSetting
		,0 AS IsExistAutoBettypes
		,0 AS IsExistAutoBettypesParlay
		,0 AS IsRunningAutoBettypes
		,0 AS IsRunningAutoBettypesParlay
		,0 AS IsWaitingAutoBettypes 
		,0 AS IsWaitingAutoBettypesParlay 
		,0 AS IsMissingAutoResult
		,0 AS IsExistFastMarket
		,0 AS IsRunningFastMarket
		,NULL AS SettlementStatusID
		,0 AS IsExistFastMarketResult
		,0 AS IsExistEarlyBettypes
		,0 AS IsExistEarlyBettypesParlay
		,0 AS IsRunningEarlyBettypes
		,0 AS IsRunningEarlyBettypesParlay
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
		FROM	dbo.match m WITH (NOLOCK)
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail r WITH (NOLOCK) ON m.matchID = r.MatchId AND r.ResourceId ='00'
		WHERE	m.eventdate BETWEEN @FromDate AND @ToDate 
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
		) tmp
		LEFT JOIN	dbo.match_remark mr WITH (NOLOCK) 
			ON	tmp.matchid = mr.matchid
		WHERE	(@UncalOnly = 0 OR ISNULL(mr.calculate, 0) = 0 OR @UncalOnly IS NULL) 
				AND (@UncalMultiOnly = 0 OR (ISNULL(mr.multiple, 0) = 0 AND (ISNULL(mr.calculate, 0) = 1 OR ISNULL(mr.calrefund, 0) = 1)) OR @UncalMultiOnly IS NULL)	
				AND 1 = CASE
							WHEN @StatusId = 0 THEN 1
							WHEN @matchcode <> '' THEN 1
							WHEN @StatusId = 7 AND ISNULL(mr.SettlementStatus,0) & 1 > 0 THEN 1
							WHEN @StatusId = 8 AND ISNULL(mr.SettlementStatus,0) & 1 = 0 AND ISNULL(mr.SettlementStatus,0) & 2 > 0 AND tmp.eventstatus <> 'Completed' THEN 1
							WHEN @StatusId NOT IN (7,8) AND ISNULL(mr.SettlementStatus,0) & 3 = 0 THEN 1
							ELSE 0
						END
			
				
	--check FGLG & BetRadar
	DECLARE @strBettypesParlay	VARCHAR (MAX)		
		,@n						INT = 2147483647
	
	CREATE TABLE #tmpBettypes (bettype SMALLINT, groupid SMALLINT, IsFGLG BIT)
	
	DECLARE @minbettype SMALLINT	
			,@maxbettype SMALLINT
	
	INSERT INTO #tmpBettypes (bettype, groupid, IsFGLG)
	SELECT BetType, GroupId,IsFGLG
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId IN (3,4,8,9) OR IsUsedGoalRecordValue = 1
	UNION ALL
	SELECT	bettype, 10, 0 AS IsFGLG
	FROM	dbo.f_Set_GetEarlyBettypes()
	
	SELECT @minbettype = MIN(bettype)
		,@maxbettype = MAX(bettype)
	FROM	#tmpBettypes
	
	CREATE TABLE #BettypeExtraStatus(matchid INT, bettype SMALLINT,Bet_cnt INT, isRunning BIT,Waiting_cnt INT, IsParLay BIT DEFAULT(0), GroupId TINYINT, IsFGLG BIT )
		
	INSERT INTO #BettypeExtraStatus (matchid, bettype, Bet_cnt, isRunning,Waiting_cnt, GroupId,IsFGLG)
	SELECT m.matchid, chk.bettype,chk.Bet_cnt, chk.IsRunning,chk.Waiting_cnt, chk.GroupId,chk.IsFGLG
	FROM (
		SELECT TOP (@n) MatchId FROM #matchList
	) AS m
		CROSS APPLY 
		(
			SELECT b.bettype
				, MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) AS IsRunning
				, SUM(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS Waiting_cnt
				, SUM(CASE WHEN b.StatusID BETWEEN 101 AND 102 THEN 0	ELSE 1 END) AS Bet_cnt
				, MAX(t.GroupId) AS GroupId, t.IsFGLG
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN #tmpBettypes t
					ON b.bettype = t.bettype
			WHERE b.matchid = m.MatchId
				AND b.bettype BETWEEN @minbettype AND @maxbettype
				AND b.statusID NOT IN (101, 102)
			GROUP BY b.bettype,t.IsFGLG
		) AS chk
	OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	
	;WITH MatchExtraStatus AS (
		SELECT matchid
			,SUM(CASE WHEN GroupId IN (2,4) AND IsFGLG = 1 THEN 1 ELSE 0 END ) AS cntFGLG
			,SUM(CASE WHEN GroupId IN (1,3) AND IsFGLG = 1  THEN 1 ELSE 0 END ) AS cntHTFGLG
			
			,SUM(CASE WHEN GroupId = 8 THEN 1 ELSE 0 END ) AS cntAutoBettypes
			
			,MAX(CASE WHEN GroupId = 8 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningAutoBettypes
			
			--For Waiting Status: Only 'waiting' single ticket of "early settled" bet types 
			,MAX(CASE WHEN GroupId = 8 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWatingAutoBettypes
			
			,SUM(CASE WHEN GroupId = 9 THEN 1 ELSE 0 END ) AS cntFastMarket
			,MAX(CASE WHEN GroupId = 9 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningFastMarket
			,SUM(CASE WHEN GroupId = 10 THEN 1 ELSE 0 END ) AS cntEarlyBettypes
			,MAX(CASE WHEN GroupId = 10 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningEarlyBettypes
		FROM #BettypeExtraStatus
		GROUP BY matchid
	)
	UPDATE m
	SET IsExistFGLG 			= CASE WHEN ext.cntFGLG > 0 THEN 1 ELSE 0 END
		,IsExistHTFGLG 			= CASE WHEN ext.cntHTFGLG > 0 THEN 1 ELSE 0 END
		,IsExistAutoBettypes 	= CASE WHEN ext.cntAutoBettypes > 0 THEN 1 ELSE 0 END
		,IsRunningAutoBettypes 	= CASE WHEN ext.IsRunningAutoBettypes = 1 THEN 1 ELSE 0 END
		,IsWaitingAutoBettypes = CASE WHEN ext.IsWatingAutoBettypes = 1 THEN 1 ELSE 0 END
		,IsExistFastMarket 	= CASE WHEN ext.cntFastMarket > 0 THEN 1 ELSE 0 END
		,IsRunningFastMarket = CASE WHEN ext.IsRunningFastMarket = 1 THEN 1 ELSE 0 END
		,IsExistEarlyBettypes = CASE WHEN ext.cntEarlyBettypes > 0 THEN 1 ELSE 0 END
		,IsRunningEarlyBettypes = CASE WHEN ext.IsRunningEarlyBettypes = 1 THEN 1 ELSE 0 END
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
			
			,SUM(CASE WHEN GroupId = 8 THEN 1 ELSE 0 END ) AS cntAutoBettypesParlay
			
			,MAX(CASE WHEN GroupId = 8 AND isRunning = 1 THEN 1 ELSE 0 END) AS IsRunningAutoBettypesParlay
			--For Waiting Status: Only 'waiting' parlay ticket of "early settled" bet types 
			,MAX(CASE WHEN GroupId = 8 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWaitingAutoBettypesParlay
			
			,SUM(CASE WHEN GroupId = 10 THEN 1 ELSE 0 END) AS cntEarlyBettypeParlay
			,MAX(CASE WHEN GroupId = 10 AND isRunning = 1 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypesParlay
		FROM #BettypeExtraStatus
		WHERE IsParLay = 1
		GROUP BY matchid
	)
	UPDATE m
	SET IsExistFGLG 			= CASE WHEN  m.IsExistFGLG = 1 OR ext.cntFGLG > 0 THEN 1 ELSE 0 END
		,IsExistHTFGLG 			= CASE WHEN  m.IsExistFGLG = 1 OR ext.cntHTFGLG > 0 THEN 1 ELSE 0 END
		,IsExistAutoBettypesParlay 	= CASE WHEN ext.cntAutoBettypesParlay > 0 THEN 1 ELSE 0 END
		,IsRunningAutoBettypesParlay = CASE WHEN ext.IsRunningAutoBettypesParlay = 1 THEN 1 ELSE 0 END
		,IsWaitingAutoBettypesParlay = CASE WHEN ext.IsWaitingAutoBettypesParlay = 1 THEN 1 ELSE 0 END
		,IsExistEarlyBettypesParlay	= CASE WHEN ext.cntEarlyBettypeParlay > 0 THEN 1 ELSE 0 END
		,IsRunningEarlyBettypesParlay = CASE WHEN ext.IsRunningEarlyBettypesParlay = 1 THEN 1 ELSE 0 END
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
		SELECT	CASE 
					WHEN Bettype = 22 THEN '160__'
					WHEN BetType IN (160,164,169,180,216) OR GroupId = 9 THEN CAST(BetType AS VARCHAR(20)) + '__'
					ELSE CAST(BetType AS VARCHAR(20))
				END AS ResourceId
				,GroupId
		FROM	#tmpBettypes
		WHERE	groupid IN (8,9)
	)	
	UPDATE	m
		SET	SettlementStatusID = r.SettlementStatusID
			,IsExistFastMarketResult = r.IsExistFastMarketResult
	FROM	#matchList m
		CROSS APPLY (
			SELECT	TOP 1 r.matchid
					,MIN(CASE WHEN c.groupId = 8 THEN ISNULL(r.SettlementStatusID,0) ELSE NULL END) AS SettlementStatusID
					,MAX(CASE WHEN c.groupId = 9 THEN 1 ELSE 0 END) AS IsExistFastMarketResult
			FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
				INNER JOIN cteAutoResultDetail c
					ON	r.ResourceId LIKE c.ResourceId
			WHERE	r.MatchId = m.matchid
					AND @sporttype IN (0,1)
			GROUP BY r.MatchId
		)r
	
	;WITH cteAutoBettypes
	AS(
		SELECT	CASE 
					WHEN Bettype = 22 THEN '160__'
					WHEN BetType IN (160,164,169,180,216) THEN CAST(BetType AS VARCHAR(20)) + '__'
					ELSE CAST(BetType AS VARCHAR(20))
				END AS ResourceId
				,BetType
		FROM	#tmpBettypes
		WHERE	GroupId = 8
	)	
	UPDATE m
		SET IsMissingAutoResult = CASE WHEN t.MissingAutoResult > 0 THEN 1 ELSE 0 END
	FROM #matchList m
		INNER JOIN (
			SELECT  b.matchid, COUNT(1) MissingAutoResult
			FROM	#BettypeExtraStatus b
				INNER JOIN cteAutoBettypes c
					ON b.bettype = c.bettype
			WHERE	IsParLay = 1		
					AND NOT EXISTS (SELECT TOP 1 1 FROM DBPRO.bodb02.dbo.ResultDetail WITH(NOLOCK) WHERE b.matchid = MatchId AND ResourceId LIKE c.ResourceId)
			GROUP BY b.matchid
	) t
		ON m.matchid = t.matchid
	
	IF (@FastMarketsOnly = 1 AND @sporttype = 1)
	BEGIN
		DELETE FROM	#matchList WHERE IsExistFastMarket = 0 AND IsExistFastMarketResult = 0
	END
	
	IF (@AutoSettlementOnly = 1) --Running Auto bettypes ONLY (BAIO, BETRADAR)
	BEGIN
		IF (@sporttype = 1)
		BEGIN
			DELETE FROM	#matchList WHERE IsRunningAutoBettypes = 0 AND IsRunningAutoBettypesParlay = 0 
		END
		
		ELSE IF (@sporttype = 2)
		BEGIN
			DELETE FROM #matchList
			WHERE 1 = CASE
							WHEN IsExistEarlyBettypes > 0 AND IsRunningEarlyBettypes = 0 THEN 1
							WHEN IsExistEarlyBettypes = 0 AND IsRunningEarlyBettypesParlay = 0 THEN 1
							ELSE 0
					  END
		END			
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
			,m.IsPending
			,m.IsUndecided
			,m.IsExistFGLG
			,m.IsExistHTFGLG
			,m.AutoSetting
			,t.IsCalculatingSingle
			,t.IsCalculatingMP			
			,CASE	
				WHEN m.IsExistAutoBettypes = 0 AND m.IsExistAutoBettypesParlay = 0 THEN 'N/A'
				WHEN m.IsRunningAutoBettypes = 1 THEN 'Running'
				WHEN m.IsWaitingAutoBettypes = 1 THEN 'Waiting'
				WHEN m.IsExistAutoBettypes = 0  AND m.IsRunningAutoBettypesParlay = 1 THEN 'Parlay Running'
				WHEN m.IsExistAutoBettypes = 0  AND m.IsWaitingAutoBettypesParlay = 1 THEN 'Parlay Waiting'
				WHEN (m.IsExistAutoBettypes > 0 AND m.IsRunningAutoBettypes = 0)
					OR (m.IsExistAutoBettypes = 0 AND m.IsExistAutoBettypesParlay > 0 AND m.IsRunningAutoBettypesParlay = 0) THEN 'Completed'				
				ELSE '' 
				
			END AS AutoSettleResultStatus
			
			,CASE 
				WHEN m.IsExistFastMarket = 0 AND m.IsExistFastMarketResult = 0 THEN 'N/A'
				WHEN m.IsExistFastMarket = 0 AND m.IsExistFastMarketResult = 1 THEN 'No Ticket'
				WHEN m.IsRunningFastMarket > 0 THEN 'Running'	
				ELSE 'Completed'		
			END AS AutoSettleFastMarket
			
			,CASE
				WHEN m.IsExistEarlyBettypes = 0 AND m.IsExistEarlyBettypesParlay = 0 THEN 'N/A' 
				WHEN m.IsRunningEarlyBettypes > 0 THEN 'Running'
				WHEN m.IsExistEarlyBettypes = 0 AND m.IsRunningEarlyBettypesParlay > 0 THEN 'Parlay Running'
				ELSE 'Completed'
			END AS EarlySettleStatus
			
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