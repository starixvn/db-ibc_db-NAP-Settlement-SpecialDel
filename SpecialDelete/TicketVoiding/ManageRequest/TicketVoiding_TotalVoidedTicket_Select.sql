/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TotalVoidedTicket_Select]
( 
	@RequestInfo XML =''
)
AS;
/*	Created by: 20220822@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine:#175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220822@July: Create new SP - get total voided ticket [Redmine:#175412]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		
	Param's explanation:	
		@RequestInfo: <root><r req ="" vh="0" i="1" mid = ""/></root>
			
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpMatchVoidingHistory TABLE (
		 RequestId			INT
		,VoidingHistoryId	INT
		,MatchId			INT
		,IssueTypeId		TINYINT
		,TotalVoidedSingle	INT DEFAULT (0)
		,TotalVoidedParlay	INT DEFAULT (0)
		,TotalCancelCashOut INT
	)

	DECLARE @tmpChildMatchCricket TABLE (
		RequestId	INT
		,MatchId			INT
		,ChildMatchId			INT
	)

	INSERT INTO @tmpMatchVoidingHistory( 
		 RequestId			
		,VoidingHistoryId	
		,IssueTypeId	
		,MatchId
	)
	SELECT t.c.value('@req','INT') AS RequestId	
		  ,t.c.value('@vh','INT') AS VoidingHistoryId
		  ,t.c.value('@i','TINYINT') AS IssueTypeId
		  ,t.c.value('@mid','INT') AS MatchId
	FROM @RequestInfo.nodes('root/r') t(c)	
	OPTION (OPTIMIZE FOR (@RequestInfo = NULL))

	CREATE TABLE #tmpResult(
		 RequestId			INT
		,MatchId			INT
		,IssueTypeId		TINYINT
		,TotalVoidedSingle	INT DEFAULT (0)
		,TotalVoidedParlay	INT DEFAULT (0)
		,TotalCancelCashOut INT
	)

	INSERT INTO #tmpResult (RequestId, MatchId, IssueTypeId)
	SELECT DISTINCT RequestId, MatchId, IssueTypeId
	FROM @tmpMatchVoidingHistory

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

	-- single + cash out ticket	and exclude child match cricket
	UPDATE vh 
		SET TotalVoidedSingle = t.TotalVoidedSingle
			,TotalVoidedParlay = t.TotalVoidedParlay
			,TotalCancelCashOut = t.TotalCancelCashOut
	FROM @tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (11,13,17,1,10,3) THEN 1
							WHEN vh.IssueTypeId IN (1,10,3) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
							WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype NOT IN (9,29,2799) THEN 1
						ELSE 0 END
						) AS TotalVoidedSingle
					,SUM(CASE WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype IN (9,29,2799) THEN 1 ELSE 0 END) AS TotalVoidedParlay
					,SUM(CASE WHEN vh.IssueTypeId IN (1,10,3) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOut
					,CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END AS matchid
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON vh.VoidingHistoryId = z.VoidingHistoryId 
			WHERE z.SiteDBGroupID = @SiteDBGroupID AND (vh.MatchId = z.matchid OR vh.MatchId = 0)
			GROUP BY vh.VoidingHistoryId, CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END
	) t ON	vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid
			
	--parlay and exclude child match cricket
	UPDATE vh
		SET TotalVoidedParlay = t.TotalVoidedParlay
	FROM	@tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,COUNT(1) AS TotalVoidedParlay
					,CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE zm.matchid END AS matchid
			FROM	@tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId 
			WHERE zm.SiteDBGroupID = @SiteDBGroupID AND (vh.MatchId = zm.matchid OR vh.MatchId = 0)
			GROUP BY vh.VoidingHistoryId, CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE zm.matchid END
	) t ON	vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid

	--Child match cricket
	IF EXISTS (SELECT TOP 1 1 FROM @tmpChildMatchCricket)
	BEGIN
		UPDATE vh 
			SET TotalVoidedSingle += t.TotalVoidedSingle
		FROM @tmpMatchVoidingHistory vh
			INNER JOIN (
				SELECT	vh.VoidingHistoryId
						,SUM( CASE 
								WHEN vh.IssueTypeId NOT IN (11,13,17) THEN 1
								WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype NOT IN (9,29,2799) THEN 1
							ELSE 0 END
							) AS TotalVoidedSingle
						,CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE cm.matchid END AS matchid
				FROM @tmpMatchVoidingHistory vh
					INNER JOIN @tmpChildMatchCricket cm ON cm.MatchId = vh.MatchId AND cm.RequestId = vh.RequestId
					INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
						ON vh.VoidingHistoryId = z.VoidingHistoryId 					
				WHERE z.SiteDBGroupID = @SiteDBGroupID AND (cm.ChildMatchId = z.matchid OR vh.MatchId = 0)
				GROUP BY vh.VoidingHistoryId, CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE cm.matchid END
		) t ON	vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid

		UPDATE vh
			SET TotalVoidedParlay += t.TotalVoidedParlay
		FROM	@tmpMatchVoidingHistory vh
			INNER JOIN (
				SELECT	vh.VoidingHistoryId
						,COUNT(1) AS TotalVoidedParlay
						,CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE cm.matchid END AS matchid
				FROM	@tmpMatchVoidingHistory vh
					INNER JOIN @tmpChildMatchCricket cm ON cm.MatchId = vh.MatchId AND cm.RequestId = vh.RequestId
					INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK)
						ON	zm.VoidingHistoryId = vh.VoidingHistoryId 
				WHERE zm.SiteDBGroupID = @SiteDBGroupID AND (cm.ChildMatchId = zm.matchid OR vh.MatchId = 0)
				GROUP BY vh.VoidingHistoryId, CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE cm.matchid END
		) t ON	vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid
	END

	UPDATE t 
		SET TotalVoidedSingle = ISNULL(vh.TotalVoidedSingle,0)
			,TotalVoidedParlay = ISNULL(vh.TotalVoidedParlay,0)
			,TotalCancelCashOut = ISNULL(vh.TotalCancelCashOut,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	SUM(vh.TotalVoidedSingle) AS TotalVoidedSingle
					,SUM(vh.TotalVoidedParlay) AS TotalVoidedParlay
					,SUM(vh.TotalCancelCashOut) AS TotalCancelCashOut
			FROM	@tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR vh.MatchId = 0)
		) vh

	SELECT  RequestId			
		   ,CASE WHEN IssueTypeId IN (13,17) THEN NULL ELSE matchid END AS matchid
		   ,TotalVoidedSingle	
		   ,TotalVoidedParlay	
		   ,TotalCancelCashOut
	FROM #tmpResult

	DROP TABLE #tmpResult
	
END
GO
