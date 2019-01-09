/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchGetResult] 
	@Date DATETIME
	,@LeagueID INT = 0
	,@sporttype SMALLINT = 0
	,@statusid TINYINT = 0
AS
/*  
	Created by: Kathy  
	Date:   
	Task: Match results  
	DB: DBPRO/BODB02  

	Revisions:  
		- 20140428@Kathy: get 1H FGLG ticket info [Redmine:#14449]
		- 20141008@Jamie: Sportting Solution settlement [Redmine: #23034]
		- 20150403@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20170209@Bobby: Add filtering Abandoned status [Redmine: #71284]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170525@Kathy: Show all results of Basketball  [Redmine:#77046]
		- 20170920@Kathy: Allow user to view result of matches stored in match14 [Redmine:#83261]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181127@Vicky: Add MTD Hold status & Postponed [Redmine: #104948]
		
	Param explanation:  
		@sporttype: show info of particular sport
		@LeagueID: = 0: show info of all leagues    	
		@statusid: 0: all, 1: running; 2: closed; 3: completed; 4: refund; 5: Postponed, 6: abandoned, 7: Result Pending, 8: Undecided, 9: Under Settlement, 10: MTD Hold
  
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @eventstatus	NVARCHAR(50)
		,@isRefund			BIT
		,@strMatchIds		VARCHAR(8000)
		,@strBettypes		VARCHAR(8000)
		,@strResults		VARCHAR(8000)
		,@xmlResults		XML
		,@MaxMatchId		INT
		,@SettlementStatus	TINYINT
		,@isSettingByProfile BIT = 0

	DECLARE @tmpMatchId TABLE (matchid INT, isMove BIT)
		
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
		,sporttype TINYINT
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
		,isMove BIT
		)
	
	CREATE TABLE #BettypeFGLG  (bettype SMALLINT, GroupID SMALLINT)
	
	INSERT INTO #BettypeFGLG (bettype,GroupID)
	SELECT BetType,GroupID
	FROM dbo.f_Set_GetGroupBettypes()
	WHERE IsFGLG = 1
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
	BEGIN
		SELECT @isSettingByProfile = 1
	END
	
	SELECT @eventstatus = CASE @statusid
			WHEN 1 THEN 'running'
			WHEN 2 THEN 'closed'
			WHEN 3 THEN 'completed'
			WHEN 6 THEN 'completed'
			WHEN 5 THEN 'postponed'
			ELSE ''
			END
		,@isRefund = CASE @statusid
			WHEN 4 THEN 1
			WHEN 6 THEN 1
			WHEN 0 THEN NULL
			ELSE 0
			END
		,@MaxMatchId = 0
		,@SettlementStatus = CASE
			WHEN @StatusId = 7 THEN 1
			WHEN @StatusId = 8 THEN 2
			WHEN @StatusId = 9 THEN 4
			WHEN @StatusId = 10 THEN 16
			ELSE 0 
			END
	IF @SettlementStatus <> 0
		SELECT @eventstatus = ''
				,@isRefund = NULL
		
	INSERT INTO #matchList (HalfTimeHomeScore,HalfTimeAwayScore,IsCalculated,IsMultiCaled,IsRefund,IsCalRefund,matchid,leagueid,homeid,awayid,matchcode,kickofftime,finalhomescore,finalawayscore 
		,betstatus, eventstatus, sporttype, IsNeutral, eventdate, goalrecord, suspenderHalfTime, suspenderFullTime,IsHalfTimeCal,calculate,SettlementStatus 
		,IsExistFGLG,IsExistHTFGLG,isMove)
	SELECT hthomescore
		,htawayscore
		,ISNULL(mr.calculate, 0) IsCalculated
		,ISNULL(mr.multiple, 0) IsMultiCaled
		,ISNULL(mr.refund, 0) IsRefund
		,ISNULL(mr.calrefund, 0) IsCalRefund
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
		,CASE mr.ConfirmHT
			WHEN 0 THEN ''
			ELSE (
					SELECT username
					FROM dbo.custinfo WITH (NOLOCK)
					WHERE custid = mr.ConfirmHT
					)
			END suspenderHT
		,CASE mr.ConfirmFT
			WHEN 0 THEN ''
			ELSE (
					SELECT username
					FROM dbo.custinfo WITH (NOLOCK)
					WHERE custid = mr.ConfirmFT
					)
			END suspenderFT
		,ISNULL(mr.IsHTCal, 0) AS IsHTCal
		,ISNULL(mr.calculate, 0) AS calculate
		,ISNULL(m.SettlementStatus, 0) AS SettlementStatus
		,0 AS IsExistFGLG
		,0 AS IsExistHTFGLG
		,m.IsMove
	FROM(
		 SELECT m.matchid, m.leagueid, m.sporttype, m.betstatus, m.eventstatus, m.eventdate, r.SettlementStatusID
				,m.hthomescore, m.htawayscore, m.homeid, m.awayid, m.matchcode, m.kickofftime
				,m.finalhomescore, m.finalawayscore, m.IsNeutral, m.GoalRecord, 0 AS IsMove, m.SettlementStatus
		 FROM	dbo.match m WITH (NOLOCK)
			LEFT JOIN dbo.ResultDetail r WITH(NOLOCK)
				ON m.matchid = r.MatchId AND r.ResourceId = '00'
				
		UNION ALL
		SELECT  m.matchid, m.leagueid, m.sporttype, m.betstatus, m.eventstatus, m.eventdate, r.SettlementStatusID
				,m.hthomescore, m.htawayscore, m.homeid, m.awayid, m.matchcode, m.kickofftime
				,m.finalhomescore, m.finalawayscore, m.IsNeutral, m.GoalRecord, 1 AS IsMove, 0 AS SettlementStatus
		 FROM	dbo.match14 m WITH (NOLOCK)
			LEFT JOIN dbo.ResultDetail14 r WITH(NOLOCK)
				ON m.matchid = r.MatchId AND r.ResourceId = '00'
	) m
		LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
	WHERE	m.eventdate = @Date 
			AND m.leagueID = CASE WHEN @LeagueID <> 0 THEN @LeagueID ELSE m.leagueID END 
			AND m.sporttype = CASE WHEN @sporttype = 0 THEN m.sporttype ELSE @sporttype END 
			AND (@eventstatus = '' OR eventstatus IN (@eventstatus, 'internal')) 
			AND (@isRefund IS NULL 
				OR (
					m.sporttype <> 5 AND @isRefund = 1 
					AND ( 
						1 = CASE 
								WHEN @statusid = 4 AND betstatus LIKE 'Refund%' THEN 1
								WHEN @statusid = 6 AND betstatus LIKE 'Abandoned%' THEN 1
								ELSE 0
							END
					)
				) 
				OR (m.sporttype <> 5 AND @isRefund = 0 AND ISNULL(betstatus, '') NOT LIKE 'Refund%' AND ISNULL(betstatus, '') NOT LIKE 'Abandoned%')
				OR (m.sporttype = 5 AND @isRefund = 1 AND ISNULL(m.SettlementStatusID,0) BETWEEN 1 AND 3)
				OR (m.sporttype = 5 AND @isRefund = 0 AND ISNULL(m.SettlementStatusID,0) NOT BETWEEN 1 AND 3)
			)
			AND (@SettlementStatus = 0 OR @SettlementStatus & m.SettlementStatus > 0)
	
	SET @strBettypes = CAST((SELECT t.bettype '@b'
								FROM (VALUES(14),(127)) AS t(bettype)
								FOR XML PATH ('bettype'), ROOT('root'), TYPE
							) AS VARCHAR(8000)
						)
	
	WHILE (1 = 1)
	BEGIN
		DELETE @tmpMatchId
		SET @strResults = NULL

		INSERT INTO @tmpMatchId (matchid)
		SELECT TOP 200 matchid
		FROM #matchList
		WHERE matchid > @MaxMatchId
		ORDER BY matchid ASC

		IF @@rowcount = 0
			BREAK

		SELECT @strMatchIds = CAST((
									SELECT	matchid '@m'
											,isMove '@im'
									FROM	@tmpMatchId
									FOR XML PATH('match'), ROOT('root'), TYPE
									) AS VARCHAR(8000) )

		EXEC DBTXN.bodb02.dbo.NAP_Set_TicketInfo 
			@strMatchIds = @strMatchIds
			,@strBettypes = @strBettypes
			,@strResults = @strResults OUTPUT
		
		SET @xmlResults = CAST(@strResults AS XML)
		
		;WITH cteResults
		AS(
			SELECT	T.C.value('@m', 'INT') AS MatchId
					,T.C.value('@b', 'INT') AS Bettype
					,T.C.value('@e', 'BIT') AS IsExist
			FROM	@xmlResults.nodes('/root/result') AS T(C)
		)
		UPDATE m 
			SET IsExistFGLG = CASE WHEN fglg.GroupID IN (2,4) AND c.IsExist = 1 THEN 1 ELSE 0 END
				,IsExistHTFGLG = CASE WHEN fglg.GroupID IN (1,3) AND c.IsExist = 1 THEN 1 ELSE 0 END
		FROM	#matchList m
			INNER JOIN cteResults c	ON m.matchid = c.MatchId
			LEFT JOIN #BettypeFGLG fglg WITH (NOLOCK) ON fglg.bettype = c.Bettype
		OPTION ( OPTIMIZE FOR ( @xmlResults = NULL ) )
		
		SELECT @MaxMatchId = MAX(matchid)
		FROM	@tmpMatchId
	END
	
	-- outright table
	INSERT INTO #matchList
	SELECT o.IsFavor hthomescore --TF  
		,o.IsSCR htawayscore --SCR  
		,0 IsCalculated
		,0 IsMultiCaled
		,0 IsRefund
		,0 IsCalRefund
		,o.groupmatch matchid --Race   
		,o.leagueid
		,o.teamid homeid
		,0 awayid
		,o.matchcode --Horse   
		,o.kickofftime
		,0 finalhomescore
		,0 finalawayscore
		,CASE 
			WHEN o.placing = 0 THEN '5'
			ELSE ISNULL(CONVERT(VARCHAR(2), placing), 5)
			END betstatus --Placing  
		,o.oddsstatus eventstatus
		,l.sporttype
		,0 IsNeutral
		,o.eventdate
		,'' AS goalrecord 
		,'' AS suspenderHT
		,'' AS suspenderFT
		,0 AS IsHTCal
		,0 AS calculate
		,0 AS SettlementStatus
		,0 AS IsExistFGLG
		,0 AS IsExistHTFGLG
		,0 as isMove
	FROM dbo.outright o WITH (NOLOCK)
		INNER JOIN league l WITH (NOLOCK) ON o.leagueid = l.leagueid
	WHERE o.eventdate = @Date AND l.sporttype BETWEEN (CASE 
					WHEN @sporttype = 0 THEN 151
					ELSE @sporttype END
					) AND (CASE 
					WHEN @sporttype = 0 THEN 153
					ELSE @sporttype END
					) AND @sporttype IN (0, 151, 152, 153) AND o.leagueid = CASE 
			WHEN @leagueid = 0 THEN o.leagueid
			ELSE @leagueid
			END 
			AND (@eventstatus='' or o.oddsstatus in (@eventstatus,'internal') ) 
			AND o.oddsstatus <> 'Closed'

	--Virtual HR, Virtual Grey Hounds, Motor Racing
	INSERT INTO #matchList
	SELECT 0 hthomescore --TF  
		,0 htawayscore --SCR  
		,0 IsCalculated
		,0 IsMultiCaled
		,0 IsRefund
		,0 IsCalRefund
		,o.EventID matchid --Race   
		,r.leagueid
		,o.RacerID homeid
		,0 awayid
		,o.RacerNum matchcode --Horse   
		,r.EventTime kickofftime
		,0 finalhomescore
		,0 finalawayscore
		,o.placing betstatus --Placing  
		,o.eventstatus
		,r.sporttype
		,0 IsNeutral
		,o.eventdate
		,'' AS goalrecord
		,'' AS suspenderHT
		,'' AS suspenderFT
		,0 AS IsHTCal
		,0 AS calculate
		,0 AS SettlementStatus
		,0 AS IsExistFGLG
		,0 AS IsExistHTFGLG
		,0 AS IsMove
	FROM VSOutright o WITH (NOLOCK)
		INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN league l WITH (NOLOCK) ON r.leagueid = l.leagueid
	WHERE o.eventdate = @Date AND l.sporttype = CASE 
			WHEN @sporttype = 0 THEN l.sporttype
			ELSE @sporttype
			END AND @sporttype IN (0, 181, 182, 184, 183, 185) AND r.leagueid = CASE 
			WHEN @leagueid = 0 THEN r.leagueid
			ELSE @leagueid
			END AND (@eventstatus='' or o.eventstatus in (@eventstatus,'internal')) 
			AND (@isRefund is null or 
					(@isRefund =1 and r.betstatus like 'Refund%') or
					(@isRefund =0 and ISNULL(r.betstatus,'') not like 'Refund%') 
				)

	SELECT m.HalfTimeHomeScore
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
	FROM #matchList m
	ORDER BY CASE eventstatus WHEN 'completed' THEN 1 WHEN 'Refund' THEN 1 ELSE 0 END
			,eventdate
			,kickofftime
			,sporttype
			,leagueid
			,matchid
			,betstatus
			,matchcode  

	
	-- Get TENNIS, ESport RESULT 
	IF @isSettingByProfile = 1
	BEGIN
		IF @sporttype = 43
		BEGIN
			SELECT    rs.MatchId
	                , rs.ResourceId
	                , rs.HomeValue
	                , rs.AwayValue
	                , CASE WHEN (@Sporttype = 43 AND LEN(ResourceId) = 2 AND SettlementStatusID = 0) THEN 4 
					   ELSE SettlementStatusID END AS SettlementStatusID
	        FROM    (
	        			SELECT  MatchId, ResourceId, HomeValue, AwayValue, SettlementStatusID, ResultStatusID
						FROM	dbo.[ResultDetailES] rs WITH (NOLOCK) 
						WHERE	MatchID IN (SELECT MatchID FROM #matchList WHERE isMove = 0)
														
						UNION ALL
						SELECT	MatchId, ResourceId, HomeValue, AwayValue, SettlementStatusID, ResultStatusID
						FROM	dbo.ResultDetailES14 rs WITH(NOLOCK)
						WHERE	MatchID IN (SELECT MatchID FROM #matchList WHERE isMove = 1)
							 
	        		)rs 
	        WHERE
	        	1 = CASE
						WHEN @Sporttype = 43 THEN CASE
													WHEN LEN(ResourceId) = 2 THEN 1
													WHEN SettlementStatusID > 0 THEN 1
													WHEN HomeValue IS NOT NULL OR AwayValue IS NOT NULL THEN 1
													ELSE 0
												END
						ELSE CASE WHEN ResultStatusID > 0 THEN 1 ELSE 0 END
					END	
		END
	END
	ELSE
	BEGIN
		
		SELECT	DISTINCT MatchId
				, CASE WHEN @Sporttype = 1 THEN '04'
					   WHEN @Sporttype = 5 AND LEN(ResourceId) > 2 THEN '0101' 
					   ELSE ResourceID END AS ResourceID 
				, CASE WHEN @Sporttype = 1 THEN '0'
					   WHEN @sporttype = 5 AND LEN(ResourceID) > 2 THEN '0' 
					   ELSE HomeValue END AS HomeValue 
				, CASE WHEN @Sporttype = 1 THEN '0'
					   WHEN @Sporttype = 5 AND LEN(ResourceID) > 2 THEN '0' 
					   ELSE AwayValue END AS AwayValue 
				, CASE WHEN @Sporttype = 1 
							OR (@Sporttype = 5 AND LEN(ResourceID) > 2)
							OR (@Sporttype = 2 AND LEN(ResourceId) = 2 AND SettlementStatusID = 0)
								THEN 4 
					   ELSE SettlementStatusID END AS SettlementStatusID
		FROM(
				SELECT  MatchId, ResourceId, HomeValue, AwayValue, SettlementStatusID, ResultStatusID
				FROM	dbo.[ResultDetail] WITH (NOLOCK) 
				WHERE	MatchID IN (SELECT MatchID FROM #matchList WHERE isMove = 0)
				UNION ALL
				SELECT	MatchId, ResourceId, HomeValue, AwayValue, SettlementStatusID, ResultStatusID
				FROM	dbo.ResultDetail14 WITH(NOLOCK)
				WHERE	MatchID IN (SELECT MatchID FROM #matchList WHERE isMove = 1)
			) r
		WHERE	(@Sporttype IN (2, 5)
					OR( @Sporttype = 1 AND ResourceID NOT IN ('00','01','08')
				))
				AND 1 = CASE
							WHEN @Sporttype = 2 THEN CASE
														WHEN LEN(ResourceId) = 2 THEN 1
														WHEN SettlementStatusID > 0 THEN 1
														WHEN HomeValue IS NOT NULL OR AwayValue IS NOT NULL THEN 1
														ELSE 0
													END
							ELSE CASE WHEN ResultStatusID > 0 THEN 1 ELSE 0 END
						END								
				
		ORDER BY MatchID, ResourceID
	END
	 
	DROP TABLE #matchList
END
GO