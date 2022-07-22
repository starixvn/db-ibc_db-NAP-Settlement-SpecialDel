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
	,@IsIncludeTest BIT = 0
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
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200212@Sol: Show all bet option for Early of Esport based on OddsES table - [Redmine:#128069]
		- 20200227@Sol: Sort Completed Matches With Running Tickets - [Redmine:#128968]
		- 20200227@Sol: Show Result of SBO on Main Calculate & Main Popup for Soccer - [Redmine:#129780]
		- 20200505@Kathy: - Add New Filter Option allowing user to exclude/include test matches 
						  - Not display matches that have been calculate/refund mix parlay when check Un-Calculated Parlay Only filter [Redmine:#133518]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200617@Kathy: Allow to search like on MatchCode [Redmine:#135991]
		- 20200827@Louisa: Get external score [Redmine:#139979]
		- 20201027@Louisa: Add new settlement status - Hold Key bit[7] + remove unused code - [Redmine:#143441]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20210312@Louisa: Ignore filter  "Include Test Matches" when user input Match Code/ID [Readmine:#150425]
		- 20210324@Louisa: Enhancement [Redmine:#151545]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192] 
		- 20210906@Louisa: Get configuration from table SettlementResultTableSetting [Redmine:#160478]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#163733]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220331@Kathy: Wrong display early match incase of no ticket [Redmine:#166072]
		- 20220404@Louisa: Wrong display early status [Redmine:#171037]
		- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
		- 20220620@Louisa: Extend Best Of Map Esports from M9 up to M30 [Redmine:#174252]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

      
 Param explanation:  
	@MatchCode: match code
	@LeagueID: = 0: show info of all leagues     
	@StatusId:  0: all, 1: running; 2: closed; 3: completed; 4: refund, 5: Postponed, 6: Abandoned, 7: Result Pending, 8: Undecided, 9: Under Settlement, 10: MTD Hold, 11: Hold Key
				12: Irregular Time 1H	13:Irregular Time	14:Wrong Team Name	15:Suspended
	@FilterBy: 0: none, 1: un-calculated game; 2: Un-calculated multiple only; 3: all
	@PenaltyShootoutOnly: 0: none; 1: running penalty shootout only
	@IsReLoad: 1: reload partial matches of a league, 0: not reload
	@IsIncludeTest: 1: include test matches, 0: exclude test matches
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
		,@matchidList VARCHAR(MAX) = ''
		,@EventStatusReason TINYINT = 0
		,@IsCentral	BIT
	
	CREATE TABLE #temp_match_parlay (ParentID INT, transid BIGINT, matchid INT, refno BIGINT, IsMergedParlay BIT DEFAULT(0))
	CREATE TABLE #tempmatch (matchid INT, IsCalculatingSingle INT, IsCalculatingMP INT)

	SET @StartTime = GETDATE()
	
	SELECT @matchcode = ISNULL(@matchcode, '')
		,@LeagueID = ISNULL(@LeagueID, 0)
		,@filterBy = ISNULL(@filterBy, 0)
		,@IsCentral = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	SELECT  @isSettingByProfile = 1
	FROM	dbo.f_Set_SettingByProfile(@sporttype)

	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
	BEGIN
		SET @isSettingByProfile = 1
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
			@UncalOnly			= NULL
			,@UncalMultiOnly	= NULL
			,@AutoSettlementOnly = 0
			,@FastMarketsOnly	= 0
			,@SettlementStatus	= 0
			,@IsMarkedTicket	= 0
			,@IsIncludeTest		= 1

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
				WHEN @statusid IN (1, 12, 13, 14, 15) THEN 'running'
				WHEN @statusid = 2 THEN 'closed'
				WHEN @statusid IN (3, 6) THEN 'completed'
				WHEN @statusid = 5 THEN 'postponed'
				ELSE ''
				END
			,@EventStatusReason = CASE @StatusId
				WHEN 12 THEN 1
				WHEN 13 THEN 2
				WHEN 14 THEN 3
				WHEN 15 THEN 4
				ELSE 0
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
				WHEN @StatusId = 11 THEN 64
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
		--,IsExistEarlyBettypesParlay BIT
		,IsRunningEarlyBettypes BIT
		--,IsRunningEarlyBettypesParlay BIT
		,IsWaitingEarlyBettypes BIT
		--,IsWaitingEarlyBettypesParlay BIT
		,IsExistRunningTicket BIT
		,IsExistRunningTicketParlay BIT
		,IsExistMarkedTicket BIT
		,IsExistMarkedTicketParlay BIT
		,ChildMatchType TINYINT
		,IsMergedParlay BIT DEFAULT(0)
		,EventStatusReason TINYINT
		,BestOfMap TINYINT
		)

	CREATE TABLE #tmpAllParentChildMatch (MatchId INT, ParentId INT, IsMergedParlay BIT DEFAULT(0))

	DECLARE @strmatchid VARCHAR(MAX)
		,@betstatus VARCHAR(8000)
		,@intDocHandle INT
		,@rowcount INT
		,@max_matchid INT
	DECLARE @tmp_ESportMatch TABLE (matchid INT)
	
	INSERT INTO #matchList (HalfTimeHomeScore,HalfTimeAwayScore ,IsCalculated ,IsMultiCaled ,IsRefund ,IsCalRefund ,matchid ,leagueid ,homeid ,awayid ,matchcode ,kickofftime ,finalhomescore ,finalawayscore 
		,betstatus 	,eventstatus,sporttype ,IsNeutral ,eventdate ,goalrecord ,suspenderHalfTime,suspenderFullTime 	,IsHalfTimeCal ,calculate 
		,SettlementStatus 
		,IsExistFGLG ,IsExistHTFGLG ,AutoSetting 
		,IsExistFastMarket,IsRunningFastMarket 
		,IsExistFastMarketResult
		,IsExistEarlyBettypes,IsRunningEarlyBettypes, IsWaitingEarlyBettypes
		,IsExistRunningTicket, IsExistRunningTicketParlay, IsExistMarkedTicket, IsExistMarkedTicketParlay
		,ChildMatchType, IsMergedParlay, EventStatusReason, BestOfMap
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
		,0 AS IsRunningEarlyBettypes
		,0 AS IsWaitingEarlyBettype
		,0 AS IsExistRunningTicket
		,0 AS IsExistRunningTicketParlay
		,0 AS IsExistMarkedTicket
		,0 AS IsExistMarkedTicketParlay
		,tmp.ChildMatchType
		,ISNULL(f.IsMergedParlay,0) AS IsMergedParlay
		,tmp.EventStatusReason
		,mr.BestOfMap
	FROM (
		SELECT hthomescore
			,htawayscore			
			,m.matchid
			,m.leagueid
			,l.LeagueGroupID
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
			,m.ChildMatchType
			,m.EventStatusReason			
		FROM	dbo.match m WITH (NOLOCK)
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail r WITH (NOLOCK) ON m.matchID = r.MatchId AND r.ResourceId ='00'
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
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
			AND (@matchcode = '' OR (m.matchid = @matchid OR m.matchcode LIKE + '%' + @matchcode + '%')) 
			AND 1 = CASE WHEN @eventstatus = '' THEN 1
						 WHEN @EventStatusReason = 0 AND eventstatus IN (@eventstatus, 'internal') THEN 1
						 WHEN @SportType = 1 AND ISNULL(m.EventStatusReason,0) = @EventStatusReason AND m.eventstatus = @eventstatus THEN 1
						 ELSE 0
					END
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
			AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END -- dont get the child match of cricket
			AND l.isTest = CASE WHEN @IsIncludeTest = 0 THEN 0 ELSE l.isTest END
			AND ISNULL(m.IsDeleted,0) = 0
	) tmp
	LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON tmp.matchid = mr.matchid
	OUTER APPLY (
			SELECT	IsMergedParlay
			FROM	dbo.SettlementResultTableSetting ss WITH(NOLOCK) 
			WHERE ss.Sporttype = tmp.sporttype
		)f
	WHERE	(@UncalOnly = 0 OR ISNULL(mr.calculate, 0) = 0 OR @UncalOnly IS NULL) 
			AND 1 = CASE
						WHEN @UncalMultiOnly = 1 AND ISNULL(f.IsMergedParlay,0) = 0
							THEN CASE
									WHEN tmp.sporttype = 1 AND tmp.LeagueGroupID = 113 THEN 0 --PinGoal
									WHEN (ISNULL(mr.calculate,0) = 1 OR ISNULL(mr.calrefund,0) = 1) -- match completed (cal/refund)
										AND ISNULL(mr.multiple,0) = 0 AND ISNULL(mr.refund,0) = 0 THEN 1 -- not cal/refund parlay yet
									ELSE 0
								END
						ELSE 1
					END
	
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
	
	CREATE TABLE #BettypeExtraStatus(matchid INT, ParentId INT, bettype SMALLINT,Bet_cnt INT, isRunning BIT,Waiting_cnt INT, IsParLay BIT DEFAULT(0), GroupId TINYINT, IsFGLG BIT, IsEarly BIT)
		
	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, IsMergedParlay)
	SELECT	m.matchid, m.ParentId, t.IsMergedParlay
	FROM	#matchList t
		CROSS APPLY (
			SELECT	m.matchid, m.ParentId
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.sporttype = 50
					AND m.ChildMatchType = 200
					AND m.ParentID = t.matchid
		)m
	UNION ALL SELECT m.matchid, m.matchid, m.IsMergedParlay FROM #matchList m

	INSERT INTO #BettypeExtraStatus (matchid, ParentId, bettype, Bet_cnt, isRunning,Waiting_cnt, GroupId,IsFGLG, IsEarly)
	SELECT m.matchid, m.ParentId, chk.bettype,chk.Bet_cnt, chk.IsRunning,chk.Waiting_cnt, chk.GroupId,chk.IsFGLG, chk.IsEarly
	FROM (
		SELECT TOP (@n) MatchId, ParentId FROM #tmpAllParentChildMatch
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
				AND b.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupId END
				AND b.bettype BETWEEN @minbettype AND @maxbettype
				AND b.statusID NOT IN (101, 102)
			GROUP BY b.bettype
		) AS chk
	OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	
	;WITH MatchExtraStatus AS (
		SELECT ParentId
			,SUM(CASE WHEN GroupId IN (2,4) AND IsFGLG = 1 THEN 1 ELSE 0 END ) AS cntFGLG
			,SUM(CASE WHEN GroupId IN (1,3) AND IsFGLG = 1  THEN 1 ELSE 0 END ) AS cntHTFGLG
			,SUM(CASE WHEN GroupId = 9 THEN 1 ELSE 0 END ) AS cntFastMarket
			,MAX(CASE WHEN GroupId = 9 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningFastMarket
			,SUM(CASE WHEN IsEarly = 1 THEN 1 ELSE 0 END ) AS cntEarlyBettypes
			,MAX(CASE WHEN IsEarly = 1 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningEarlyBettypes
			,MAX(CASE WHEN IsEarly = 1 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWatingEarlyBettypes
			,MAX(CASE WHEN  isRunning = 1 THEN 1 ELSE 0 END ) AS	IsExistRunningTicket
		FROM #BettypeExtraStatus
		GROUP BY ParentId
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
		ON m.matchid = ext.ParentId
	
	-- check bettransm
	INSERT INTO #BettypeExtraStatus (matchid, ParentId, bettype, Bet_cnt, isRunning, Waiting_cnt, IsParLay, GroupId, IsEarly)
	SELECT m.matchid, m.ParentId, chk.bettype,chk.Bet_cnt, chk.IsRunning,chk.Waiting_cnt, 1, chk.GroupId, chk.IsEarly
	FROM (
		SELECT TOP (@n) MatchId, ParentId FROM #tmpAllParentChildMatch
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
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND	t.groupid <> 9
				AND bm.bettype BETWEEN @minbettype AND @maxbettype		
				AND bm.statusID NOT IN (101, 102)
			GROUP BY bm.bettype
		) AS chk
	OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	
	;WITH MatchExtraStatusParlay AS (
		SELECT ParentId
			,SUM(CASE WHEN GroupId = 4 THEN 1 ELSE 0 END ) AS cntFGLG
			,SUM(CASE WHEN GroupId = 3 THEN 1 ELSE 0 END ) AS cntHTFGLG
			,SUM(CASE WHEN IsEarly = 1 THEN 1 ELSE 0 END) AS cntEarlyBettypeParlay
			,MAX(CASE WHEN IsEarly = 1 AND isRunning = 1 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypesParlay
			,MAX(CASE WHEN IsEarly = 1 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWaitingEarlyBettypesParlay
		FROM #BettypeExtraStatus
		WHERE IsParLay = 1
		GROUP BY ParentId
	)
	UPDATE m
	SET IsExistFGLG 			= CASE WHEN m.IsExistFGLG = 1 OR ext.cntFGLG > 0 THEN 1 ELSE 0 END
		,IsExistHTFGLG 			= CASE WHEN m.IsExistFGLG = 1 OR ext.cntHTFGLG > 0 THEN 1 ELSE 0 END
		,IsExistEarlyBettypes	= CASE WHEN m.IsExistEarlyBettypes = 1 OR ext.cntEarlyBettypeParlay > 0 THEN 1 ELSE 0 END
		,IsRunningEarlyBettypes = CASE WHEN m.IsRunningEarlyBettypes = 1 OR ext.IsRunningEarlyBettypesParlay = 1 THEN 1 ELSE 0 END
		,IsWaitingEarlyBettypes = CASE WHEN m.IsWaitingEarlyBettypes = 1 OR ext.IsWaitingEarlyBettypesParlay = 1 THEN 1 ELSE 0 END
	FROM #matchList m
		INNER JOIN MatchExtraStatusParlay ext 
		ON m.matchid = ext.ParentId
	
	;WITH SingleTicket AS
	(
		SELECT	matchid, min(IsCalculating)  IsCalculating
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	s.IsCalculating IN (0,1)
		group by matchid 
	),
	ParlayTicket AS
	(
		SELECT	p.matchid, MAX(IsCalculating)  IsCalculating
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE	p.IsCalculating IN (0,1)
		group by matchid 
	)	
	INSERT INTO #tempmatch(matchid, IsCalculatingSingle, IsCalculatingMP)
	select isnull(sg.matchid, pl.matchid) matchid
		, sg.IsCalculating IsCalculatingSingle
		, pl.IsCalculating IsCalculatingMP
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
			WHERE IsRunningEarlyBettypes = 0
		END			
		
	END

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsExistMarkedTicketParlay BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, m.matchid
	FROM	#matchList m
		CROSS APPLY (
			SELECT	mt.TransId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt
	WHERE m.sporttype <> 50

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
								AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
								AND bm.statusid = 0
								AND b.matchid = 29
								AND bm.matchid = mt.matchId
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
				,IsExistMarkedTicketParlay = t.IsExistMarkedTicketParlay
		FROM	#matchList m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId

	END

	IF @IsMarkedTicket = 1
	BEGIN
		DELETE m
		FROM #matchList m 
		WHERE	IsExistMarkedTicket = 0 AND m.IsExistMarkedTicketParlay = 0
	END

	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0), IsExistRunningTicketParlay BIT DEFAULT (0))

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	m.matchid
	FROM	#matchList m
	WHERE	eventstatus = 'completed' 
	
	IF @@ROWCOUNT <> 0
	BEGIN
		-- single 
		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	@tmpMatchCompleted m
			CROSS APPLY (
				SELECT 1 AS IsExistRunningTicket
				FROM (
						SELECT	tmp.ParentId, b.transid, tmp.MatchId
						FROM	dbo.bettrans b WITH(NOLOCK)
							INNER JOIN #tmpAllParentChildMatch tmp 
								ON	b.MatchId = tmp.MatchId
						WHERE	b.matchid = m.MatchId
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusID = 0
								AND b.bettype NOT BETWEEN 801 AND 806 -- Metric Gaming
								AND b.bettype <> 38 -- BetBuilder
					) b
					OUTER APPLY (
						SELECT TOP 1 mt.transId
						FROM	#tmpMarkedTransaction mt 
						WHERE	b.transid = mt.TransId
								AND b.MatchId = mt.matchId
					)mt
				WHERE	mt.transId IS NULL
				GROUP BY b.ParentId
			) t
		
		-- parlay
		INSERT INTO #temp_match_parlay (ParentID, transid, matchid, refno, IsMergedParlay)
		SELECT	tmp.ParentId, 0, tmp.MatchId, bm.refno, tmp.IsMergedParlay
		FROM @tmpMatchCompleted m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.MatchId = bm.matchid
			INNER JOIN #tmpAllParentChildMatch tmp	ON	bm.matchid = tmp.MatchId
		WHERE	bm.statusID = 0
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND 1 = CASE 
							WHEN m.IsExistRunningTicket = 0
									AND tmp.IsMergedParlay = 1 THEN 1
							WHEN tmp.IsMergedParlay = 0 THEN 1
						END
						
		IF EXISTS (SELECT TOP 1 1 FROM #temp_match_parlay)
		BEGIN
			UPDATE   t
				SET transid = b.transid
			FROM   #temp_match_parlay  t
				INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
			
			UPDATE	m 
				SET IsExistRunningTicket = CASE WHEN m.IsExistRunningTicket = 0 AND t.IsMergedParlay = 1 THEN t.IsExistRunningTicketParlay ELSE m.IsExistRunningTicket END
					,IsExistRunningTicketParlay = t.IsExistRunningTicketParlay
			FROM	@tmpMatchCompleted m
					CROSS APPLY (
								SELECT	1 AS IsExistRunningTicketParlay
										,MAX(CASE WHEN b.IsMergedParlay = 1 THEN 1 ELSE 0 END) AS IsMergedParlay
								FROM (
										SELECT	ParentId, transid, MatchId, p.IsMergedParlay
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
									GROUP BY b.ParentId
								) t
			--WHERE m.IsExistRunningTicket = 0
		END
		
		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
				,IsExistRunningTicketParlay = t.IsExistRunningTicketParlay
		FROM	#matchList m
			INNER JOIN @tmpMatchCompleted t
				ON m.matchid = t.MatchId
	END

	IF (@SportType = 43)
	BEGIN

		INSERT INTO @tmp_ESportMatch(MatchId)
		SELECT DISTINCT m.MatchId
		FROM DBPRO.BODB02.dbo.oddsES o WITH (NOLOCK)
				INNER JOIN f_Set_GetEarlyBettypes() f
					ON o.bettype = f.bettype
				INNER JOIN #matchList m 
					ON m.matchid = o.matchid 
		WHERE m.sporttype = 43
			AND ISNULL(o.IsDeleted,0) = 0

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
			,m.IsExistFastMarket
			,m.IsExistFastMarketResult
			,m.IsRunningFastMarket
			,m.IsExistEarlyBettypes
			,m.ChildMatchType
			,CASE WHEN te.matchid IS NOT NULL THEN 1 ELSE 0 END AS IsOpenOdds 
			,m.IsRunningEarlyBettypes
			,m.IsWaitingEarlyBettypes
			,m.IsExistRunningTicket
			,m.IsExistRunningTicketParlay
			,m.IsExistMarkedTicket
			,m.IsExistMarkedTicketParlay
			,m.EventStatusReason
			,m.BestOfMap
	FROM	#matchList m
			LEFT JOIN #tempmatch t 
				ON	t.matchid = m.matchid
			LEFT JOIN @tmp_ESportMatch te
				ON te.matchid = m.matchid
				
	ORDER BY CASE 
				WHEN m.eventstatus = 'completed' AND m.IsExistMarkedTicket = 0 AND m.IsExistRunningTicket = 0 THEN 1 
				ELSE 0 
			END
		, m.eventdate
		, m.kickofftime
		, m.sporttype
		, m.leagueid
		, m.matchid
		, m.betstatus
		, m.matchcode			
	
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