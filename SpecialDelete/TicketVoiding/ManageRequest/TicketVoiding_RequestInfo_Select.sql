/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet,wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestInfo_Select]
(
	@RequestId		INT	= NULL
   ,@MatchId		INT = 0
)
AS
/*	Created by: 20181212@Zane
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBCTG/bodb02
	
	Revisions: 		
		- 20201229@Zane: Create new SP [Redmine:#145719]
		- 20210607@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20220113@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220413@July: TVS - New issue type Wrong OU and Wrong 1H OU [Redmine: #170220]
		- 20221201@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230529@July: Support case Cricket main in table match -> child in table match14 [Redmine: #188153]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (
		 RequestId		INT
		,MatchId		INT
		,IssueTypeId	TINYINT
		,LastVoidedBy	INT
		,TotalSingleProcessed	INT DEFAULT (0)
		,TotalParlayProcessed	INT DEFAULT (0)
		,TotalCancelCashOutProcessed INT
		,TotalResettleProcessed	INT DEFAULT (0)
		,VoidingHistoryId	INT
	)
	DECLARE @tmpChildMatchCricket TABLE (
		RequestId	INT
		,MatchId			INT
		,ChildMatchId			INT
	)

	INSERT INTO #tmpResult(RequestId, IssueTypeId, VoidingHistoryId, LastVoidedBy, MatchId)
	SELECT r.RequestId
			,r.IssueTypeId
			,vh.VoidingHistoryId
			,vh.UserId
			,@MatchId
	FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON r.RequestId = vh.RequestId	
	WHERE	r.RequestId = @RequestId
	
	-- single
	UPDATE vh 
		SET TotalSingleProcessed = t.TotalVoidedSingle
			,TotalParlayProcessed = t.TotalVoidedParlay
			,TotalCancelCashOutProcessed = t.TotalCancelCashOut
			,MatchId = t.matchid
	FROM #tmpResult vh
		CROSS APPLY (
            SELECT CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END AS matchid
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (11,13,17,1,10,3,2,19,20,21) THEN 1
							WHEN vh.IssueTypeId IN (1,10,3,2,19,21) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
							WHEN vh.IssueTypeId IN (11,13,17,20) AND z.bettype NOT IN (9,29,2799,10449) THEN 1
						ELSE 0 END
					) AS TotalVoidedSingle
					,SUM(CASE WHEN vh.IssueTypeId IN (11,13,17,20) AND z.bettype IN(9,29,2799,10449) THEN 1 ELSE 0 END) AS TotalVoidedParlay
					,SUM(CASE WHEN vh.IssueTypeId IN (1,10,3,2,19,21) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOut
			FROM #tmpResult vh
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON vh.VoidingHistoryId = z.VoidingHistoryId
			WHERE 1 = CASE WHEN @MatchId IN (0,29) THEN 1 
				           WHEN @MatchId NOT IN (0,29) AND z.matchid = @MatchId THEN 1
						 ELSE 0 END
			GROUP BY CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END
	) t 
		
	--parlay
	UPDATE vh
		SET TotalParlayProcessed = t.TotalVoidedParlay
		,MatchId = t.MatchId
	FROM	#tmpResult vh
		CROSS APPLY (
			SELECT COUNT(1) AS TotalVoidedParlay, zm.matchid
			FROM #tmpResult vh
			INNER JOIN  dbo.zzzbettransm zm WITH(NOLOCK) ON zm.VoidingHistoryId = vh.VoidingHistoryId
			WHERE 1 = CASE WHEN @MatchId IN (0,29) THEN 1 
				         WHEN @MatchId NOT IN (0,29) AND zm.matchid = @MatchId THEN 1
						 ELSE 0 END
			GROUP BY zm.matchid
	) t

	IF EXISTS (SELECT TOP 1 1 FROM #tmpResult t
						INNER JOIN dbo.match m WITH (NOLOCK) ON m.ParentID = t.MatchId AND m.sporttype = 50)
	BEGIN
		INSERT INTO @tmpChildMatchCricket (RequestId, MatchId, ChildMatchId)
		SELECT DISTINCT t.RequestId, t.MatchId, m.matchid
		FROM #tmpResult t 
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.ParentID = t.MatchId
		WHERE m.sporttype = 50 
			AND m.ChildMatchType = 200
	END

	-- Support case Cricket main in table match -> child in table match14
	IF EXISTS (SELECT TOP 1 1 FROM #tmpResult t
						INNER JOIN dbo.match14 m WITH (NOLOCK) ON m.ParentID = t.MatchId AND m.sporttype = 50)
	BEGIN
		INSERT INTO @tmpChildMatchCricket (RequestId, MatchId, ChildMatchId)
		SELECT t.RequestId, t.MatchId, m.matchid
		FROM #tmpResult t 
			INNER JOIN dbo.match14 m WITH (NOLOCK) ON m.ParentID = t.MatchId
		WHERE m.sporttype = 50 
			AND m.ChildMatchType = 200
	END

	--Child match cricket
	IF EXISTS (SELECT TOP 1 1 FROM @tmpChildMatchCricket)
	BEGIN
		-- single
		UPDATE vh 
			SET TotalSingleProcessed += t.TotalVoidedSingle
				,TotalCancelCashOutProcessed += t.TotalCancelCashOut
				,MatchId = t.matchid
		FROM #tmpResult vh
			CROSS APPLY (
				SELECT CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE cm.matchid END AS matchid
						,SUM( CASE 
								WHEN vh.IssueTypeId NOT IN (11,13,17,1,10,3,2,19,20,21) THEN 1
								WHEN vh.IssueTypeId IN (1,10,3,2,19,21) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
								WHEN vh.IssueTypeId IN (11,13,17,20) AND z.bettype NOT IN (9,29,2799,10449) THEN 1
							ELSE 0 END
						) AS TotalVoidedSingle
						,SUM(CASE WHEN vh.IssueTypeId IN (1,10,3,2) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOut
				FROM #tmpResult vh
					INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON vh.VoidingHistoryId = z.VoidingHistoryId
					INNER JOIN @tmpChildMatchCricket cm ON cm.ChildMatchId = z.matchid
				WHERE 1 = CASE WHEN @MatchId IN (0,29) THEN 1 
							   WHEN @MatchId NOT IN (0,29) AND cm.matchid = @MatchId THEN 1
							 ELSE 0 END
					AND cm.RequestId = vh.RequestId
				GROUP BY CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE cm.matchid END
		) t 
		
		--parlay
		UPDATE vh
			SET TotalParlayProcessed = t.TotalVoidedParlay
			,MatchId = t.MatchId
		FROM	#tmpResult vh
			CROSS APPLY (
				SELECT COUNT(1) AS TotalVoidedParlay, cm.matchid
				FROM #tmpResult vh
					INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK) ON zm.VoidingHistoryId = vh.VoidingHistoryId
					INNER JOIN @tmpChildMatchCricket cm ON cm.ChildMatchId = zm.matchid
				WHERE 1 = CASE WHEN @MatchId IN (0,29) THEN 1 
							 WHEN @MatchId NOT IN (0,29) AND cm.matchid = @MatchId THEN 1
							 ELSE 0 END
				AND cm.RequestId = vh.RequestId
				GROUP BY cm.matchid
		) t
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpResult WHERE IssueTypeId = 22)
	BEGIN
		DECLARE @tmp_TransId AS TABLE (RequestId INT, TransId BIGINT, MatchId INT, IsProcessed TINYINT)

		INSERT INTO @tmp_TransId(RequestId, TransId, MatchId, IsProcessed)
		SELECT t.RequestId, s.TransId, s.MatchId, s.IsProcessed
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpResult t ON t.RequestId = s.Requestid
		WHERE s.IsProcessed IS NOT NULL

		DELETE t
		FROM @tmp_TransId t
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON t.TransId = z.transid AND z.comstatus <> 'CO'

		UPDATE t 
		SET TotalSingleProcessed = ISNULL(rt.TotalSingleProcessed,0)
			,TotalParlayProcessed = ISNULL(rt.TotalParlayProcessed,0)
			,TotalResettleProcessed= ISNULL(rt.TotalResettleProcessed,0) 
		FROM	#tmpResult t
		CROSS APPLY (SELECT 
						SUM(CASE WHEN s.MatchId NOT IN (9,29,2799,10449) THEN 1 ELSE 0 END) AS TotalSingleProcessed
						,SUM(CASE WHEN s.MatchId IN (9,29,2799,10449) THEN 1 ELSE 0 END) AS TotalParlayProcessed
						,SUM(CASE WHEN s.IsProcessed = 2 THEN 1 ELSE 0 END) AS TotalResettleProcessed
					FROM @tmp_TransId s
					WHERE s.RequestId = t.RequestId
				)rt	
		WHERE t.IssueTypeId = 22 --Recover Ticket
	END
	
	--Return Data
	SELECT TOP(1)
			t.RequestId
			,MatchId
			,v.Username AS LastPerformedBy
			,tmp.TotalSingleProcessed
			,tmp.TotalParlayProcessed
			,tmp.TotalCancelCashOutProcessed
			,tmp.TotalResettleProcessed
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		CROSS APPLY (
		    SELECT ISNULL(tmp.TotalSingleProcessed,0) AS TotalSingleProcessed 
				  ,ISNULL(tmp.TotalParlayProcessed,0) AS TotalParlayProcessed
				  ,ISNULL(tmp.TotalCancelCashOutProcessed,0) AS TotalCancelCashOutProcessed
				  ,ISNULL(tmp.TotalResettleProcessed,0) AS TotalResettleProcessed
			FROM #tmpResult tmp
			WHERE t.RequestId = tmp.RequestId
		)tmp
	ORDER BY t.VoidingHistoryId DESC
	
	DROP TABLE #tmpResult	
END
