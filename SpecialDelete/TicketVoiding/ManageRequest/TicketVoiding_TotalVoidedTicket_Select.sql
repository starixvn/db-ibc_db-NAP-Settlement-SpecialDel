/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TotalVoidedTicket_Select]
( 
	@RequestInfo VARCHAR(MAX) = NULL
)
AS;
/*	Created by: 20220822@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine:#175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220822@July: Create new SP - get total voided ticket [Redmine:#175412]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		- 20230529@July: Support case Cricket main in table match -> child in table match14 [Redmine: #188153]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240319@July: [TVS] SP tuning for EC2024 [Redmine: #200840]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #tmpMatchVoidingHistory (
		 RequestId			INT
		,VoidingHistoryId	INT
		,MatchId			INT
		,IssueTypeId		TINYINT
		,TotalSingleProcessed	INT DEFAULT (0)
		,TotalParlayProcessed	INT DEFAULT (0)
		,TotalCancelCashOutProcessed INT DEFAULT (0)
	)
	CREATE NONCLUSTERED INDEX IX_tmpMatchVoidingHistory_VoidingHistoryId ON #tmpMatchVoidingHistory (VoidingHistoryId)

	DECLARE @tmpChildMatchCricket TABLE (
		RequestId		INT
	   ,MatchId			INT
	   ,ChildMatchId	INT
	)

	INSERT INTO #tmpMatchVoidingHistory( 
		 RequestId			
		,VoidingHistoryId	
		,IssueTypeId	
		,MatchId
	)
	SELECT req, vh, it, mid
	FROM STRING_SPLIT(@RequestInfo, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_RequestInfo) t
		CROSS APPLY (
				SELECT req, vh, it, mid
				FROM OPENJSON(t.Decompress_RequestInfo) 
				WITH( req INT, vh INT, it TINYINT, mid INT )
			)tbl
	WHERE f.value <> ''

	CREATE TABLE #tmpResult(
		 RequestId			INT
		,MatchId			INT
		,IssueTypeId		TINYINT
		,TotalSingleProcessed	INT DEFAULT (0)
		,TotalParlayProcessed	INT DEFAULT (0)
		,TotalCancelCashOutProcessed INT DEFAULT (0)
		,TotalResettleProcessed	INT DEFAULT (0)
	)
	INSERT INTO #tmpResult (RequestId, MatchId, IssueTypeId)
	SELECT DISTINCT RequestId, MatchId, IssueTypeId
	FROM #tmpMatchVoidingHistory

	IF EXISTS (SELECT TOP 1 1 FROM #tmpResult t
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.ParentID = t.MatchId AND m.sporttype = 50)
	BEGIN
		INSERT INTO @tmpChildMatchCricket (RequestId, MatchId, ChildMatchId)
		SELECT t.RequestId, t.MatchId, m.matchid
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
	
	-- single ticket	
	;WITH CTE_Single AS(
			SELECT	vh.VoidingHistoryId
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (1,10,3) AND z.bettype NOT IN (9,29,2799,10449) THEN 1
							WHEN vh.IssueTypeId IN (1,10,3) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
						ELSE 0 END
					) AS TotalSingleProcessed
					,SUM(CASE WHEN z.bettype IN (9,29,2799,10449) THEN 1 ELSE 0 END) AS TotalParlayProcessed
					,CASE WHEN vh.MatchId = 0 THEN 0 ELSE ISNULL(m.matchid, z.matchid) END AS matchid
					,SUM(CASE WHEN vh.IssueTypeId IN (1,10,3) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOutProcessed -- Apply for DA,RC,WC
			FROM #tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId
				LEFT JOIN @tmpChildMatchCricket m ON z.matchid = m.ChildMatchId
			WHERE vh.IssueTypeId NOT IN (22) --Recover Ticket
				 AND (vh.MatchId = CASE WHEN m.MatchId IS NOT NULL THEN m.MatchId ELSE z.matchid END
                        OR vh.MatchId = 0)
			GROUP BY vh.VoidingHistoryId
				   , CASE WHEN vh.MatchId = 0 THEN 0 ELSE ISNULL(m.matchid, z.matchid) END 
	)
	UPDATE vh 
		SET TotalSingleProcessed = t.TotalSingleProcessed
			,TotalParlayProcessed = t.TotalParlayProcessed
			,TotalCancelCashOutProcessed = t.TotalCancelCashOutProcessed
	FROM #tmpMatchVoidingHistory vh
		INNER JOIN CTE_Single t ON vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid
	
	--parlay ticket
	;WITH CTE_Parlay AS(
		SELECT	vh.VoidingHistoryId
					,COUNT(1) AS TotalParlayProcessed
					,ISNULL(m.matchid, zm.matchid) AS matchid
			FROM	#tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId
				LEFT JOIN @tmpChildMatchCricket m ON zm.matchid = m.ChildMatchId
			WHERE vh.IssueTypeId NOT IN (11,15,13,17,22) --Except AB,AB(real member),AC,ARC,RT
				AND vh.MatchId = CASE WHEN m.MatchId IS NOT NULL THEN m.MatchId ELSE zm.matchid END
			GROUP BY vh.VoidingHistoryId, ISNULL(m.matchid, zm.matchid)
	)
	UPDATE vh
		SET TotalParlayProcessed = t.TotalParlayProcessed
	FROM	#tmpMatchVoidingHistory vh
		INNER JOIN CTE_Parlay t ON vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid  

	UPDATE t 
		SET TotalSingleProcessed = ISNULL(vh.TotalSingleProcessed,0)
			,TotalParlayProcessed = ISNULL(vh.TotalParlayProcessed,0)
			,TotalCancelCashOutProcessed = ISNULL(vh.TotalCancelCashOutProcessed,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	SUM(vh.TotalSingleProcessed) AS TotalSingleProcessed
					,SUM(vh.TotalParlayProcessed) AS TotalParlayProcessed
					,SUM(vh.TotalCancelCashOutProcessed) AS TotalCancelCashOutProcessed
			FROM	#tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR vh.MatchId = 0)
		) vh
	
	IF EXISTS (SELECT TOP 1 1 FROM #tmpMatchVoidingHistory WHERE IssueTypeId = 22)
	BEGIN
		DECLARE @tmp_TransId AS TABLE (RequestId INT, TransId BIGINT, MatchId INT, IsProcessed TINYINT)

		INSERT INTO @tmp_TransId(RequestId, TransId, MatchId, IsProcessed)
		SELECT t.RequestId, s.TransId, s.MatchId, s.IsProcessed
		FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpResult t ON t.RequestId = s.Requestid
		WHERE s.IsProcessed IS NOT NULL
			AND s.SiteDBGroupID = @SiteDBGroupID

		DELETE t
		FROM @tmp_TransId t
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON t.TransId = z.transid AND z.comstatus <> 'CO'
		WHERE z.SiteDBGroupID = @SiteDBGroupID

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

	SELECT  RequestId			
		   ,CASE WHEN IssueTypeId IN (13,17,22) THEN NULL ELSE matchid END AS matchid
		   ,TotalSingleProcessed	
		   ,TotalParlayProcessed	
		   ,TotalCancelCashOutProcessed
		   ,TotalResettleProcessed
	FROM #tmpResult

	DROP TABLE #tmpResult
	DROP TABLE #tmpMatchVoidingHistory
END
GO
