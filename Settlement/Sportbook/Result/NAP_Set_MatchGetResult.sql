/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
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

	Param explanation:  
		@sporttype: show info of particular sport
		@LeagueID: = 0: show info of all leagues    	
		@statusid: 0: all, 1: running; 2: closed; 3: completed; 4: refund; 6: abandoned   
  
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @eventstatus NVARCHAR(50)
		,@isRefund BIT

	SELECT @eventstatus = CASE @statusid
			WHEN 1 THEN 'running'
			WHEN 2 THEN 'closed'
			WHEN 3 THEN 'completed'
			WHEN 6 THEN 'completed'
			ELSE ''
			END
		,@isRefund = CASE @statusid
			WHEN 4 THEN 1
			WHEN 6 THEN 1
			WHEN 0 THEN NULL
			ELSE 0
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
		,Foddsstatus VARCHAR(10)
		,sporttype TINYINT
		,IsNeutral BIT
		,eventdate DATETIME
		,goalrecord VARCHAR(50)
		,suspenderHalfTime NVARCHAR(50)
		,suspenderFullTime NVARCHAR(50)
		,IsHalfTimeCal BIT
		,calculate BIT
		,isPending BIT
		,isUndecided BIT
		,IsKeyscore BIT
		,IsExistFGLG BIT
		,IsExistHTFGLG BIT
		,WinOdds MONEY
		,PlaceOdds MONEY
		)

	DECLARE @matchid VARCHAR(MAX)
		,@betstatus VARCHAR(8000)
		,@intDocHandle INT
		,@rowcount INT
		,@max_matchid INT
	DECLARE @tmp_match TABLE (matchid INT)

	INSERT INTO #matchList
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
		,CASE 
			WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
			WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
			WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
			WHEN m.betstatus LIKE 'Abandoned 1H%' THEN 'Abandoned 1H'
			WHEN m.betstatus LIKE 'Abandoned 2H%' THEN 'Abandoned 2H'
			ELSE m.eventstatus
		END AS eventstatus
		,'' AS Foddsstatus
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
		,ISNULL(mr.isPending, 0) AS isPending
		,ISNULL(mr.isUndecided, 0) AS isUndecided 
		,CASE 
			WHEN hthomescore IS NOT NULL AND htawayscore IS NOT NULL AND finalhomescore IS NOT NULL AND finalawayscore IS NOT NULL THEN 1
			ELSE 0
			END IsKeyscore
		,0
		,0
		,0
		,0
	FROM dbo.match m WITH (NOLOCK)
		LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
		LEFT JOIN dbo.ResultDetail r WITH (NOLOCK) ON m.matchID = R.MatchId AND r.ResourceId='00'
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
				OR (m.sporttype = 5 AND @isRefund = 1 AND ISNULL(r.SettlementStatusID,0) BETWEEN 1 AND 3)
				OR (m.sporttype = 5 AND @isRefund = 0 AND ISNULL(r.SettlementStatusID,0) NOT BETWEEN 1 AND 3)
			)

	SELECT @rowcount = 0
		,@max_matchid = 0

	WHILE (1 = 1)
	BEGIN
		DELETE @tmp_match

		INSERT INTO @tmp_match (matchid)
		SELECT TOP 100 matchid
		FROM #matchList
		WHERE matchid > @max_matchid
		ORDER BY matchid ASC

		SELECT @rowcount = @@rowcount

		IF @rowcount = 0
			BREAK;

		SELECT @max_matchid = MAX(matchid)
		FROM @tmp_match

		SELECT @matchid = (
				SELECT matchid
				FROM @tmp_match
				FOR XML PATH('match')
					,ROOT('root')
				)

		-- FGLG
		EXEC DBTXN.bodb02.dbo.NAP_Set_MatchBetStatusSel @matchid = @matchid
			, @bettype = 14
			,@betstatus = @betstatus OUTPUT

		--Create an internal representation of the XML document.      
		EXEC sp_xml_preparedocument @intDocHandle OUTPUT
			,@betstatus

		UPDATE m
		SET IsExistFGLG = CASE 
				WHEN rs.cnt = 0 OR rs.cnt IS NULL THEN 0
				ELSE 1
				END
		FROM #matchList m
			INNER JOIN @tmp_match t ON m.matchid = t.matchid
			LEFT JOIN (
			SELECT matchid
				,cnt
			FROM OPENXML(@intDocHandle, '/root/match', 2) WITH (matchid INT, cnt INT)
			) rs ON m.matchid = rs.matchid

		-- 1H FGLG
		EXEC DBTXN.bodb02.dbo.NAP_Set_MatchBetStatusSel @matchid = @matchid
			, @bettype = 127
			,@betstatus = @betstatus OUTPUT

		--Create an internal representation of the XML document.      
		EXEC sp_xml_preparedocument @intDocHandle OUTPUT
			,@betstatus

		UPDATE m
		SET IsExistHTFGLG = CASE 
				WHEN rs.cnt = 0 OR rs.cnt IS NULL THEN 0
				ELSE 1
				END
		FROM #matchList m
			INNER JOIN @tmp_match t ON m.matchid = t.matchid
			LEFT JOIN (
			SELECT matchid
				,cnt
			FROM OPENXML(@intDocHandle, '/root/match', 2) WITH (matchid INT, cnt INT)
			) rs ON m.matchid = rs.matchid
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
		,o.Foddsstatus
		,l.sporttype
		,0 IsNeutral
		,o.eventdate
		,'' AS goalrecord 
		,'' AS suspenderHT
		,'' AS suspenderFT
		,0 AS IsHTCal
		,0 AS calculate
		,0 AS isPending
		,0 AS isUndecided
		,0 AS IsKeyscore
		,0 AS IsExistFGLG
		,0 AS IsExistHTFGLG
		,o.Odds
		,o.PlaceOdds
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
		--,o.eventstatus 
		,CASE 
			WHEN r.betstatus LIKE 'Refund%' THEN 'Refund'
			ELSE o.eventstatus
			END eventstatus
		,o.IsFavor Foddsstatus
		,r.sporttype
		,0 IsNeutral
		,o.eventdate
		,'' AS goalrecord
		,'' AS suspenderHT
		,'' AS suspenderFT
		,0 AS IsHTCal
		,0 AS calculate
		,0 AS isPending
		,0 AS isUndecided 
		,0 AS IsKeyscore
		,0 AS IsExistFGLG
		,0 AS IsExistHTFGLG
		,o.WinOdds
		,o.PlaceOdds
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
		,m.Foddsstatus
		,m.sporttype
		,m.IsNeutral
		,m.eventdate
		,m.goalrecord
		,m.suspenderHalfTime
		,m.suspenderFullTime
		,m.IsHalfTimeCal
		,m.calculate
		,m.isPending
		,m.isUndecided
		,m.IsKeyscore
		,m.IsExistFGLG
		,m.IsExistHTFGLG
		,m.WinOdds
		,m.PlaceOdds
	FROM #matchList m
	ORDER BY CASE eventstatus WHEN 'completed' THEN 1 WHEN 'Refund' THEN 1 ELSE 0 END
			,eventdate
			,kickofftime
			,sporttype
			,leagueid
			,matchid
			,betstatus
			,matchcode  

	-- Get TENNIS RESULT 
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
	FROM	dbo.[ResultDetail] WITH (NOLOCK) 
	WHERE	(@Sporttype IN (2, 5)
				OR( @Sporttype = 1 AND ResourceID NOT IN ('00','01','08')
			))
			AND MatchID IN (SELECT MatchID FROM #matchList)
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

	DROP TABLE #matchList
END
GO