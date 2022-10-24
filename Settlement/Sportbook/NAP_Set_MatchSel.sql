/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel] 
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@SportType		SMALLINT		= 1
	,@LeagueIDs		NVARCHAR(200)	= '0'
	,@MatchCode		NVARCHAR(50)	= ''
	,@MatchStatus	VARCHAR(50)		= '0'	 
	,@FilterOver	TINYINT			= 0		 
	,@HoldStatus	VARCHAR(50)		= '0'	 
	,@MatchType		TINYINT			= 0		 
	,@IsReLoad		BIT				= 0
	,@IsIncludeTest BIT				= 0
--WITH RECOMPILE  
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
		- 20220924@Kathy: Scale Out BetTrans - wrong order when chosing @FilterOver [Redmine:#175251]
		- 20221012@Louisa: Enhancement [Redmine:#178551]
		
 Param explanation: 
	@LeagueIDs  : '0' :all  
	@MatchStatus: 0:all/none,  1:close, 2:running 3:internal, 4:posponed, 5:IrregularTime 1H, 6:IrregularTime, 7:Wrong TeamName, 8:Suspended,	9:Completed, 10:refund 11-Abandoned
	@FilterOver : 0:all, 1: Early over, 2: HT over, 3:FT over, 4:settled with running ticket
	@HoldStatus :  '0': none/all
					87 - Not on hold 
					1 - Result Pending
					2 - Undecided
					4 - Under Settlement
					16- MTD Hold
					64- Hold Key
				ex: '1,2'
	@MatchType  : 0: all, 1: normal/real, 2:Virtual, 3: FastMarket
	@IsReLoad   : 1: reload partial matches of a league, 0: not reload
	@IsIncludeTest: 1: include test matches, 0: exclude test matches
*/
BEGIN
	SET NOCOUNT ON

	DECLARE 
		@matchid INT
		,@StartTime DATETIME
		,@EndTime	DATETIME
		,@SqlCommand VARCHAR(MAX)
		,@IsCentral			BIT = 0
		,@Matchid_tmp		INT = 1
		,@IsMergedParlay	BIT = 0
		,@ProcName			SYSNAME = OBJECT_NAME(@@procid)		
		,@n					INT = 2147483647
		,@minbettype SMALLINT	
		,@maxbettype SMALLINT


	DECLARE @tmpLeagueID	 TABLE ( LeagueId INT )
	DECLARE @tmpMatchStatus  TABLE ( MatchStatus TINYINT )
	DECLARE @tmpHoldStatus	 TABLE ( HoldStatus TINYINT )

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsExistMarkedTicketParlay BIT DEFAULT(0))
	
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)
	
	CREATE TABLE #tempmatch (matchid INT, IsCalculatingSingle INT, IsCalculatingMP INT)
	
	CREATE TABLE #tmpBettypes (bettype SMALLINT, groupid SMALLINT, IsFGLG BIT, IsEarly BIT)

	CREATE TABLE #BettypeExtraStatus(matchid INT, bettype SMALLINT, betid NVARCHAR(50), Bet_cnt INT, isRunning BIT,Waiting_cnt INT, IsParLay BIT DEFAULT(0), GroupId TINYINT, IsFGLG BIT, IsEarly BIT, IsVoidReject	BIT)

	CREATE TABLE #matchList (
		HalfTimeHomeScore INT
		,HalfTimeAwayScore INT
		,IsCalculated BIT
		,IsMultiCaled BIT
		,IsRefund BIT
		,IsCalRefund BIT
		,matchid INT
		,leagueid INT
		,LeagueGroupID SMALLINT
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
		,IsExistEarlyResultConfirmed BIT
		,IsExistEarlyBettypes BIT
		,IsRunningEarlyBettypes BIT
		,IsWaitingEarlyBettypes BIT
		,IsExistRunningTicket BIT
		,IsExistRunningTicketParlay BIT
		,IsExistMarkedTicket BIT
		,IsExistMarkedTicketParlay BIT
		,ChildMatchType TINYINT
		,IsMergedParlay BIT DEFAULT(0)
		,EventStatusReason TINYINT
		,IsExistTicket BIT DEFAULT(0)
		,IsRunningSingle	BIT
		,IsRunningParlay	BIT
		,IsVoidReject		BIT
		)

	SET @StartTime = GETDATE()
	
	SELECT @matchcode	= ISNULL(@matchcode, '')
	
	SELECT @IsMergedParlay =  ( SELECT IsMergedParlay FROM dbo.SettlementResultTableSetting ss WITH(NOLOCK) WHERE ss.Sporttype = @SportType)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
		
	-- if entering matcode, ignore other params (excep FromDate, ToDate, sport type)
	IF (@matchcode <> '')
	BEGIN
		SELECT @FilterOver = 0	 

		BEGIN TRY
			SET @matchid = CASE 
					WHEN ISNUMERIC(@matchcode) = 1 THEN CAST(@matchcode AS INT)
					ELSE NULL
					END
		END TRY

		BEGIN CATCH
			SET @matchid = NULL
		END CATCH

		INSERT INTO #matchList (HalfTimeHomeScore,HalfTimeAwayScore ,IsCalculated ,IsMultiCaled ,IsRefund ,IsCalRefund ,matchid ,leagueid , LeagueGroupID, homeid ,awayid ,matchcode ,kickofftime ,finalhomescore ,finalawayscore 
			,betstatus 	,eventstatus,sporttype ,IsNeutral ,eventdate ,goalrecord ,suspenderHalfTime,suspenderFullTime 	,IsHalfTimeCal ,calculate 
			,SettlementStatus 
			,IsExistFGLG ,IsExistHTFGLG ,AutoSetting 
			,IsExistFastMarket,IsRunningFastMarket 
			,IsExistFastMarketResult
			,IsExistEarlyResultConfirmed
			,IsExistEarlyBettypes,IsRunningEarlyBettypes, IsWaitingEarlyBettypes
			,IsExistRunningTicket, IsExistRunningTicketParlay, IsExistMarkedTicket, IsExistMarkedTicketParlay
			,ChildMatchType, IsMergedParlay, EventStatusReason
		)
		SELECT 
			m.hthomescore
			,m.htawayscore
			,ISNULL(mr.calculate, 0) IsCalculated
			,ISNULL(mr.multiple, 0) IsMultiCaled
			,ISNULL(mr.refund, 0) IsRefund
			,ISNULL(mr.calrefund, 0) IsCalRefund
			,m.matchid
			,l.leagueid
			,ISNULL(l.LeagueGroupID,0) AS LeagueGroupID
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
			,ISNULL(m.SettlementStatus, 0) AS SettlementStatus
			,0 AS IsExistFGLG
			,0 AS IsExistHTFGLG
			,ISNULL(m.AutoSetting, 0) AS AutoSetting
			,0 AS IsExistFastMarket
			,0 AS IsRunningFastMarket
			,0 AS IsExistFastMarketResult
			,0 AS IsExistEarlyResultConfirmed
			,0 AS IsExistEarlyBettypes
			,0 AS IsRunningEarlyBettypes
			,0 AS IsWaitingEarlyBettype
			,0 AS IsExistRunningTicket
			,0 AS IsExistRunningTicketParlay
			,0 AS IsExistMarkedTicket
			,0 AS IsExistMarkedTicketParlay
			,m.ChildMatchType
			,@IsMergedParlay AS IsMergedParlay
			,m.EventStatusReason
		FROM dbo.match m WITH (NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
			WHERE m.eventdate BETWEEN @FromDate AND @ToDate
				AND m.sporttype = @sporttype 
				AND (m.matchid = @matchid OR m.matchcode LIKE + '%' + @matchcode + '%')
				AND ISNULL(m.IsDeleted,0) = 0

	END
	
	ELSE
	BEGIN
		INSERT INTO @tmpMatchStatus ( MatchStatus )
		SELECT Value FROM string_split(@MatchStatus, ',' )

		INSERT INTO @tmpHoldStatus ( HoldStatus )
		SELECT Value FROM string_split(@HoldStatus, ',' )

		INSERT INTO @tmpLeagueID ( LeagueId )
		SELECT Value FROM string_split(@LeagueIDs, ',' )
	
		INSERT INTO #matchList (HalfTimeHomeScore,HalfTimeAwayScore ,IsCalculated ,IsMultiCaled ,IsRefund ,IsCalRefund ,matchid ,leagueid , LeagueGroupID, homeid ,awayid ,matchcode ,kickofftime ,finalhomescore ,finalawayscore 
			,betstatus 	,eventstatus,sporttype ,IsNeutral ,eventdate ,goalrecord ,suspenderHalfTime,suspenderFullTime 	,IsHalfTimeCal ,calculate 
			,SettlementStatus 
			,IsExistFGLG ,IsExistHTFGLG ,AutoSetting 
			,IsExistFastMarket,IsRunningFastMarket 
			,IsExistFastMarketResult
			,IsExistEarlyResultConfirmed
			,IsExistEarlyBettypes,IsRunningEarlyBettypes, IsWaitingEarlyBettypes
			,IsExistRunningTicket, IsExistRunningTicketParlay, IsExistMarkedTicket, IsExistMarkedTicketParlay
			,ChildMatchType, IsMergedParlay, EventStatusReason
		)
		SELECT 
			m.hthomescore
			,m.htawayscore
			,ISNULL(mr.calculate, 0) IsCalculated
			,ISNULL(mr.multiple, 0) IsMultiCaled
			,ISNULL(mr.refund, 0) IsRefund
			,ISNULL(mr.calrefund, 0) IsCalRefund
			,m.matchid
			,m.leagueid
			,ISNULL(l.LeagueGroupID,0) AS LeagueGroupID
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
			,ISNULL(m.SettlementStatus, 0) AS SettlementStatus
			,0 AS IsExistFGLG
			,0 AS IsExistHTFGLG
			,ISNULL(ISNULL(m.AutoSetting,l.AutoSetting), 0) AS AutoSetting
			,0 AS IsExistFastMarket
			,0 AS IsRunningFastMarket
			,0 AS IsExistFastMarketResult
			,0 AS IsExistEarlyResultConfirmed
			,0 AS IsExistEarlyBettypes
			,0 AS IsRunningEarlyBettypes
			,0 AS IsWaitingEarlyBettype
			,0 AS IsExistRunningTicket
			,0 AS IsExistRunningTicketParlay
			,0 AS IsExistMarkedTicket
			,0 AS IsExistMarkedTicketParlay
			,m.ChildMatchType
			,@IsMergedParlay AS IsMergedParlay
			,m.EventStatusReason			
			FROM dbo.match m WITH (NOLOCK)
				INNER JOIN dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
				INNER JOIN  dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
				CROSS APPLY (	SELECT TOP 1 l.LeagueID FROM @tmpLeagueID tmp 
								WHERE @LeagueIDs = '0' OR tmp.LeagueId = l.leagueid 
							 ) tmp
			WHERE m.eventdate BETWEEN @FromDate AND @ToDate	
				AND m.sporttype = @sporttype
				AND l.isTest = CASE WHEN @IsIncludeTest = 1 THEN l.isTest ELSE 0 END
				AND l.LeagueGroupID <> 113 --if not query by matchcode, exclude Pingoal
				AND 1 = CASE WHEN @MatchType = 0 THEN 1 --all type or FM
								WHEN @MatchType IN (1, 3) AND l.LeagueGroupID NOT IN (42,74,108) THEN 1 --normal match or FM
								WHEN @MatchType = 2 AND l.LeagueGroupID IN (42,74,108) THEN 1 --Virtual
								ELSE 0 
						END
				AND 1 = CASE WHEN @FilterOver IN (0,1) THEN 1
							 WHEN @FilterOver = 2 --HT Over
									AND m.eventstatus IN ('Closed', 'running', 'internal')
									AND ((DATEDIFF(MINUTE, m.kickofftime, GETDATE()) > 40
											AND DATEDIFF(MINUTE, m.kickofftime, GETDATE()) < 100)
										OR  mr.ConfirmHT > 0
									)
									AND mr.IsHTCal = 0
							 THEN 1
							 WHEN @FilterOver = 3 --FT Over
									AND m.eventstatus <> 'Completed'
									AND (m.kickofftime < CASE 
																WHEN l.LeagueGroupID NOT IN (42,74,108) THEN DATEADD(s, - 6000, GETDATE())
																ELSE DATEADD(s, -1800, GETDATE())
															END
											OR mr.ConfirmFT > 0
										)
							 THEN 1
							 WHEN @FilterOver = 4 AND m.eventstatus = 'Completed' THEN 1
							 ELSE 0
						 END
				AND EXISTS (	SELECT TOP 1 1 
								FROM @tmpHoldStatus h
								WHERE  CASE WHEN h.HoldStatus = 0 THEN 1
										WHEN h.HoldStatus = 87 THEN CASE WHEN h.HoldStatus &  m.SettlementStatus = 0 THEN 1
																		 ELSE 0 
																		 END
										ELSE h.HoldStatus & m.SettlementStatus
										END > 0 
								)
				AND EXISTS (	SELECT TOP 1 1 
								FROM @tmpMatchStatus ms
								WHERE  CASE WHEN ms.MatchStatus	= 0 THEN 1
											WHEN ms.MatchStatus = 1 AND m.eventstatus = 'closed' THEN 1
											WHEN ms.MatchStatus = 2 AND m.eventstatus = 'running' THEN 1
											WHEN ms.MatchStatus = 3 AND m.eventstatus = 'Internal' THEN 1
											WHEN ms.MatchStatus = 4 AND m.eventstatus = 'Postponed' THEN 1
											WHEN ms.MatchStatus = 9 AND m.eventstatus = 'Completed' THEN 1
											WHEN ms.MatchStatus = 10 AND m.betstatus LIKE 'Refund%' THEN 1
											WHEN ms.MatchStatus = 11 AND m.eventstatus ='Completed' AND m.betstatus LIKE 'Abandoned%' THEN 1
											WHEN ms.MatchStatus = 5 AND ISNULL(m.eventstatusreason,0) = 1 THEN 1 --Irregular Time 1H
											WHEN ms.MatchStatus = 6 AND ISNULL(m.eventstatusreason,0) = 2 THEN 1 --Irregular Time
											WHEN ms.MatchStatus = 7 AND ISNULL(m.eventstatusreason,0) = 3 THEN 1 --Wrong Team Name
											WHEN ms.MatchStatus = 8 AND ISNULL(m.eventstatusreason,0) = 4 THEN 1 --Suspended
											ELSE 0
										END > 0
								)
	END
  
	;WITH cteTicketSingle
	AS (
		SELECT b.matchid
		FROM dbo.bettrans b WITH (NOLOCK, INDEX = CIX_matchid_bettype) 
			INNER JOIN #matchList m
				ON b.matchid = m.matchid
		WHERE b.bettype <> 38
			AND b.bettype NOT BETWEEN 911 AND 920 --cashout tickets
		GROUP BY  b.matchid
	)
	UPDATE m 
		SET IsExistTicket = 1 
	FROM	#matchList m
		INNER JOIN cteTicketSingle t
			ON m.matchid = t.matchid

	;WITH cteTicketParlay
	AS (
		SELECT b.matchid
		FROM dbo.bettransm b WITH (NOLOCK) 
			INNER JOIN #matchList m
				ON b.matchid = m.matchid
		WHERE b.bettype <> 38
			AND b.bettype NOT BETWEEN 911 AND 920 --cashout tickets
			AND ISNULL(IsExistTicket,0) = 0
		GROUP BY  b.matchid
	)
	UPDATE m 
		SET IsExistTicket = 1 
	FROM	#matchList m
		INNER JOIN cteTicketParlay t
			ON m.matchid = t.matchid

	IF @FilterOver > 0 OR @MatchType = 3
	BEGIN
		DELETE FROM	#matchList WHERE IsExistTicket = 0
	END
	
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
 
	INSERT INTO #BettypeExtraStatus (matchid, bettype, betid, Bet_cnt, isRunning,Waiting_cnt, GroupId,IsFGLG, IsEarly)
	SELECT m.matchid, chk.bettype, chk.betid, chk.Bet_cnt, chk.IsRunning,chk.Waiting_cnt, chk.GroupId,chk.IsFGLG, chk.IsEarly
	FROM (
		SELECT TOP (@n) MatchId FROM #matchList
		WHERE IsExistTicket = 1
	) AS m
		CROSS APPLY 
		(
			SELECT b.bettype
				, b.betid
				, MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) AS IsRunning
				, SUM(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS Waiting_cnt
				, COUNT(Transid) AS Bet_cnt
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
			GROUP BY b.bettype, b.betid
		) AS chk
	 OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	-- check bettransm
	INSERT INTO #BettypeExtraStatus (matchid, bettype, betid, Bet_cnt, isRunning, Waiting_cnt, IsParLay, GroupId, IsEarly)
	SELECT m.matchid, chk.bettype, chk.betcheck, chk.Bet_cnt, chk.IsRunning,chk.Waiting_cnt, 1, chk.GroupId, chk.IsEarly
	FROM (
		SELECT TOP (@n) MatchId FROM #matchList
		WHERE IsExistTicket = 1
	) AS m
		CROSS APPLY 
		(
			SELECT	bm.bettype
					, bm.betcheck
					, MAX(CASE WHEN bm.statusID = 0 THEN 1 ELSE 0 END) AS IsRunning
					, SUM(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) AS Waiting_cnt
					, COUNT(TransId) AS Bet_cnt
					, MAX(t.groupid) AS GroupId
					, MAX(CASE WHEN t.IsEarly = 1 THEN 1 ELSE 0 END) AS IsEarly
			FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN	#tmpBettypes t
					ON	bm.bettype = t.bettype
			WHERE	bm.matchid = m.MatchId	
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND	t.groupid <> 9
				AND bm.statusID NOT IN (101, 102)
				AND bm.bettype BETWEEN @minbettype AND @maxbettype
			GROUP BY bm.bettype, bm.betcheck
		) AS chk
	OPTION (OPTIMIZE FOR (@n = 1))	-- using hint to force Optimize execute temp table first
	 
	;WITH cte_tmpBetcount AS 
	(	SELECT matchid
			,MAX(CASE WHEN GroupId = 4 THEN 1 ELSE 0 END ) AS cntFGLG
			,MAX(CASE WHEN GroupId = 3 THEN 1 ELSE 0 END ) AS cntHTFGLG
			,MAX(CASE WHEN IsEarly = 1 THEN 1 ELSE 0 END) AS cntEarlyBettypes
			,MAX(CASE WHEN GroupId = 9 THEN 1 ELSE 0 END ) AS cntFastMarket
			,MAX(CASE WHEN GroupId = 9 AND isRunning = 1 THEN 1 ELSE 0 END) IsRunningFastMarket
			,MAX(CASE WHEN IsEarly = 1 AND isRunning = 1 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypes
			,MAX(CASE WHEN IsEarly = 1 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWaitingEarlyBettypes
			,MAX(CASE WHEN  isRunning = 1 THEN 1 ELSE 0 END ) AS isRunning
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
		,IsWaitingEarlyBettypes = CASE WHEN ext.IsWaitingEarlyBettypes = 1 THEN 1 ELSE 0 END
		,IsRunningSingle		= ext.isRunning
	FROM #matchList m
		INNER JOIN cte_tmpBetcount ext
		ON m.matchid = ext.matchid
	
	;WITH cte_tmpBetcount AS 
	(	SELECT matchid
			,MAX(CASE WHEN GroupId = 4 THEN 1 ELSE 0 END ) AS cntFGLG
			,MAX(CASE WHEN GroupId = 3 THEN 1 ELSE 0 END ) AS cntHTFGLG
			,MAX(CASE WHEN IsEarly = 1 THEN 1 ELSE 0 END) AS cntEarlyBettypes
			,MAX(CASE WHEN IsEarly = 1 AND isRunning = 1 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypes
			,MAX(CASE WHEN IsEarly = 1 AND Waiting_cnt = Bet_cnt THEN 1 ELSE 0 END) IsWaitingEarlyBettypes
			,MAX(CASE WHEN  isRunning = 1 THEN 1 ELSE 0 END ) AS isRunning
		FROM #BettypeExtraStatus 
		WHERE IsParLay = 1
		GROUP BY matchid
	)
	UPDATE m
	SET IsExistFGLG 			= CASE WHEN m.IsExistFGLG = 1 OR ext.cntFGLG > 0 THEN 1 ELSE 0 END
		,IsExistHTFGLG 			= CASE WHEN m.IsExistFGLG = 1 OR ext.cntHTFGLG > 0 THEN 1 ELSE 0 END
		,IsExistEarlyBettypes	= CASE WHEN m.IsExistEarlyBettypes = 1 OR ext.cntEarlyBettypes > 0 THEN 1 ELSE 0 END
		,IsRunningEarlyBettypes = CASE WHEN m.IsRunningEarlyBettypes = 0 THEN ext.IsRunningEarlyBettypes ELSE m.IsRunningEarlyBettypes END
		,IsWaitingEarlyBettypes = CASE WHEN m.IsWaitingEarlyBettypes = 0 THEN ext.IsWaitingEarlyBettypes ELSE m.IsWaitingEarlyBettypes END
		,IsRunningParlay		= ext.isRunning
	FROM #matchList m
		INNER JOIN cte_tmpBetcount ext
		ON m.matchid = ext.matchid
 
	;WITH cteFMResultDetail 
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
			SELECT	TOP 1 r.MatchId
			FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
				INNER JOIN cteFMResultDetail c
					ON	r.ResourceId LIKE c.ResourceId
			WHERE	r.MatchId = m.matchid
			) fm
 
	IF @MatchType = 3
	BEGIN
		DELETE FROM	#matchList WHERE ISNULL(IsExistFastMarket,0) = 0 AND ISNULL(IsExistFastMarketResult,0) = 0
	END

	IF @FilterOver = 1
	BEGIN
		DELETE FROM	#matchList WHERE ISNULL(IsRunningEarlyBettypes,0) = 0

		;WITH cteEarlyResourceIds
		AS (
			SELECT	b.matchid, s.ResourceID
			FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				CROSS APPLY (
					SELECT b.matchid
					FROM #BettypeExtraStatus b
					WHERE	b.bettype = s.bettype
							AND (s.betid = 0 OR s.betid = b.betid)
							AND b.isRunning = 1
				)b
			WHERE	s.SportType = 1
					AND s.SettleType = 'EAR'
			GROUP BY b.matchid, s.ResourceID
		)
		UPDATE	m
			SET	IsExistEarlyResultConfirmed = 1
		FROM	#matchList m
			CROSS APPLY (
				SELECT	TOP 1 r.matchid
				FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
					INNER JOIN cteEarlyResourceIds c
						ON	r.ResourceId = c.ResourceId
							AND r.MatchId = c.matchid
							AND r.ResultStatusID = 3
				WHERE	r.MatchId = m.matchid
				GROUP BY r.MatchId
			)r

		DELETE m
		FROM	#matchList m
		WHERE	ISNULL(m.IsExistEarlyResultConfirmed,0) = 0
		
	END

	;WITH cteTicket
	AS (
		SELECT b.matchid
		FROM dbo.bettrans b WITH (NOLOCK, INDEX = CIX_matchid_bettype) 
			INNER JOIN #matchList m
				ON b.matchid = m.matchid
		WHERE b.bettype <> 38
			AND b.bettype NOT BETWEEN 911 AND 920--cashout tickets
			AND b.statusID = 0
			AND m.IsRunningSingle = 0
		GROUP BY  b.matchid
	)
	UPDATE m 
		SET IsRunningSingle = 1
	FROM	#matchList m
		INNER JOIN cteTicket t
			ON m.matchid = t.matchid

	;WITH cteTicket
	AS (
		SELECT b.matchid
		FROM dbo.bettransm b WITH (NOLOCK) 
			INNER JOIN #matchList m
				ON b.matchid = m.matchid
		WHERE b.bettype <> 38
			AND b.bettype NOT BETWEEN 911 AND 920 --cashout tickets
			AND b.statusID = 0
			AND m.IsRunningParlay = 0
		GROUP BY  b.matchid
	)
	UPDATE m 
		SET IsRunningParlay = 1
	FROM	#matchList m
		INNER JOIN cteTicket t
			ON m.matchid = t.matchid
	
	IF @FilterOver = 4 --settled but exists running ticket
	BEGIN
		DELETE	m
		FROM	#matchList m
		WHERE ISNULL(m.isRunningSingle,0) = 0 AND ISNULL(m.isRunningParlay,0) = 0
	END
	
	;WITH SingleTicket AS
	(
		SELECT	matchid, min(IsCalculating)  IsCalculating
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	s.IsCalculating IN (0,1)
			AND s.Sporttype = @sporttype
		group by matchid 
	),
	ParlayTicket AS
	(
		SELECT	p.matchid, MAX(IsCalculating)  IsCalculating
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE	p.IsCalculating IN (0,1)
			AND p.Sporttype = @sporttype
		group by matchid 
	)	
	INSERT INTO #tempmatch(matchid, IsCalculatingSingle, IsCalculatingMP)
	select isnull(sg.matchid, pl.matchid) matchid
		, sg.IsCalculating IsCalculatingSingle
		, pl.IsCalculating IsCalculatingMP
	from SingleTicket sg
		full outer join ParlayTicket pl on sg.matchid = pl.matchid 

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, m.matchid
	FROM	#matchList m
		CROSS APPLY (
			SELECT	mt.TransId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt
	WHERE m.IsRunningSingle = 1

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket		= m.HasMarkedSingle
				,IsExistMarkedTicketParlay	= m.HasMarkedParlay
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

	IF EXISTS (SELECT TOP 1 1 FROM #matchList WHERE eventstatus = 'Completed')
	BEGIN
		UPDATE #matchList
		SET IsExistRunningTicket = 1
		WHERE eventstatus = 'Completed' 
			AND ISNULL(IsRunningSingle,0) = 1
			AND ISNULL(IsExistMarkedTicket,0) = 0

		UPDATE	#matchList
		SET IsExistRunningTicket = CASE WHEN IsExistRunningTicket = 0 AND @IsMergedParlay = 1 THEN 1 
										ELSE IsExistRunningTicket 
										END
			,IsExistRunningTicketParlay = IsExistRunningTicketParlay
		WHERE eventstatus = 'Completed'
			AND ISNULL(IsExistMarkedTicketParlay,0) = 0
			AND ISNULL(IsRunningParlay,0) = 1
	END
	
	IF @FilterOver > 0
	BEGIN
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
				,m.IsRunningEarlyBettypes
				,m.IsWaitingEarlyBettypes
				,m.IsExistRunningTicket
				,m.IsExistRunningTicketParlay
				,m.IsExistMarkedTicket
				,m.IsExistMarkedTicketParlay
				,m.EventStatusReason
		FROM	#matchList m
				LEFT JOIN #tempmatch t 
					ON	t.matchid = m.matchid				
		ORDER BY m.eventstatus
			, m.matchcode			
	END
	ELSE
	BEGIN
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
				,m.IsRunningEarlyBettypes
				,m.IsWaitingEarlyBettypes
				,m.IsExistRunningTicket
				,m.IsExistRunningTicketParlay
				,m.IsExistMarkedTicket
				,m.IsExistMarkedTicketParlay
				,m.EventStatusReason
		FROM	#matchList m
				LEFT JOIN #tempmatch t 
					ON	t.matchid = m.matchid				
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
	END

	SET @EndTime = GETDATE()
	
	IF DATEDIFF(MILLISECOND,@StartTime, @EndTime) > 10000
	BEGIN
		SET @SqlCommand = 'EXEC '+@ProcName+ ' @FromDate =''' + CONVERT(VARCHAR(20), @FromDate) + ''''
										   + ', @ToDate = ''' + CONVERT(VARCHAR(20), @ToDate) + ''''
										   + ', @SportType =' + CONVERT(VARCHAR(10), @SportType) 
										   + ', @LeagueIDs =' + CONVERT(VARCHAR(10), @LeagueIDs)  
										   + ', @MatchCode =''' + ISNULL(@MatchCode, '') + '''' 
										   + ', @MatchStatus	 = '''+ CONVERT(VARCHAR(50), @MatchStatus	)+ ''''	 
										   + ', @FilterOver	 = '+ CONVERT(VARCHAR(50), @FilterOver) 
										   + ', @HoldStatus	 = '''+ CONVERT(VARCHAR(50), @HoldStatus	)+ ''''	 
										   + ', @MatchType		 = '+ CONVERT(VARCHAR(50), @MatchType)			 
										   + ', @IsReLoad		 = '+ CONVERT(VARCHAR(10), @IsReLoad	)	
										   + ', @IsIncludeTest  = '+ CONVERT(VARCHAR(10), @IsIncludeTest )
	
		INSERT INTO SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END

	DROP TABLE #BettypeExtraStatus
	DROP TABLE #matchList
	DROP TABLE #tempmatch
	DROP TABLE #tmpBettypes
	DROP TABLE #tmpMarkedTransaction
END
GO