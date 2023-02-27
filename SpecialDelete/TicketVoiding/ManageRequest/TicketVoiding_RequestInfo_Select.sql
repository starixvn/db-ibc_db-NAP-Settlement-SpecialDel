/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (
		 RequestId		INT
		,MatchId		INT
		,IssueTypeId	TINYINT
		,LastVoidedBy	INT
		,TotalVoidedSingle	INT
		,TotalVoidedParlay	INT
		,TotalCancelCashOut INT
		,VoidingHistoryId	INT
	)
	INSERT INTO #tmpResult(RequestId, IssueTypeId, VoidingHistoryId, LastVoidedBy)
	SELECT r.RequestId
			,vh.VoidingHistoryId
			,r.IssueTypeId
			,vh.UserId
	FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON r.RequestId = vh.RequestId	
	WHERE	r.RequestId = @RequestId
	
	-- single
	UPDATE vh 
		SET TotalVoidedSingle = t.TotalVoidedSingle
			,TotalVoidedParlay = t.TotalVoidedParlay
			,TotalCancelCashOut = t.TotalCancelCashOut
			,MatchId = t.matchid
	FROM #tmpResult vh
		CROSS APPLY (
                              SELECT CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END AS matchid
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (11,13,17,1,10,3) THEN 1
							WHEN vh.IssueTypeId IN (1,10,3) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
							WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype NOT IN (9,29,2799) THEN 1
						ELSE 0 END
					) AS TotalVoidedSingle
					,SUM(CASE WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype IN(9,29,2799) THEN 1 ELSE 0 END) AS TotalVoidedParlay
					,SUM(CASE WHEN vh.IssueTypeId IN (1,10,3) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOut
			FROM dbo.zzzbettrans z WITH(NOLOCK)
			WHERE	vh.VoidingHistoryId = z.VoidingHistoryId
			AND 1 = CASE WHEN @MatchId IN (0,29) THEN 1 
				         WHEN @MatchId NOT IN (0,29) AND z.matchid = @MatchId THEN 1
						 ELSE 0 END
			GROUP BY CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END
	) t 
		
	--parlay
	UPDATE vh
		SET TotalVoidedParlay = t.TotalVoidedParlay
		,MatchId = t.MatchId
	FROM	#tmpResult vh
		CROSS APPLY (
			SELECT COUNT(1) AS TotalVoidedParlay, zm.matchid
			FROM dbo.zzzbettransm zm WITH(NOLOCK)
			WHERE zm.VoidingHistoryId = vh.VoidingHistoryId
			AND 1 = CASE WHEN @MatchId IN (0,29) THEN 1 
				         WHEN @MatchId NOT IN (0,29) AND zm.matchid = @MatchId THEN 1
						 ELSE 0 END
			GROUP BY zm.matchid
	) t
	
	--Return Data
	SELECT TOP(1)
			t.RequestId
			,MatchId
			,v.Username AS LastPerformedBy
			,tmp.TotalVoidedSingle
			,tmp.TotalVoidedParlay
			,tmp.TotalCancelCashOut
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		CROSS APPLY (
		    SELECT SUM(ISNULL(tmp.TotalVoidedSingle,0)) AS TotalVoidedSingle 
				  ,SUM(ISNULL(tmp.TotalVoidedParlay,0)) AS TotalVoidedParlay
				  ,SUM(ISNULL(tmp.TotalCancelCashOut,0)) AS TotalCancelCashOut
			FROM #tmpResult tmp
			WHERE t.RequestId = tmp.RequestId
		)tmp
	ORDER BY t.VoidingHistoryId DESC
	
	DROP TABLE #tmpResult	
END
