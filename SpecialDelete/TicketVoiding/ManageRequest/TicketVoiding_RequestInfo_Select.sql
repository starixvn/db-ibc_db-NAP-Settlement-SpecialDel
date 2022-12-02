/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestInfo_Select]
(
	@RequestId		INT	= NULL
   ,@MatchId		INT = 0
)
AS
/*	Created by: 20181212@Zane
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBTXN/bodb02
	
	Revisions: 		
		- 20201229@Zane: Create new SP [Redmine:#145719]
		- 20210607@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20220113@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220413@July: TVS - New issue type Wrong OU and Wrong 1H OU [Redmine: #170220]
		- 20221201@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (
		 RequestId		INT
		,MatchId		INT
		,IssueTypeId	TINYINT
		,LastVoidedBy	INT
		,TotalSingle	INT
		,TotalParlay	INT
		,VoidingHistoryId	INT
	)
	INSERT INTO #tmpResult(RequestId, IssueTypeId, VoidingHistoryId, LastVoidedBy)
	SELECT r.RequestId
			,r.IssueTypeId
			,vh.VoidingHistoryId
			,vh.UserId
	FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON r.RequestId = vh.RequestId	
	WHERE	r.RequestId = @RequestId
	
	-- single
	UPDATE vh 
		SET TotalSingle =	ISNULL(t.TotalVoidedSingle,0)
		    ,MatchId = t.MatchId
	FROM #tmpResult vh
		CROSS APPLY (
			SELECT	COUNT(1) AS TotalVoidedSingle, z.matchid
			FROM dbo.zzzbettrans z WITH(NOLOCK)
			WHERE	vh.VoidingHistoryId = z.VoidingHistoryId
			AND 1 = CASE WHEN @MatchId IN (0,29) THEN 1 
				         WHEN @MatchId NOT IN (0,29) AND z.matchid = @MatchId THEN 1
						 ELSE 0 END
			GROUP BY z.matchid
	) t 
		
	--parlay
	UPDATE vh
		SET TotalParlay = ISNULL(TotalVoidedParlay,0)
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
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		CROSS APPLY (
		    SELECT SUM(ISNULL(tmp.TotalSingle,0)) AS TotalVoidedSingle 
				  ,SUM(ISNULL(tmp.TotalParlay,0)) AS TotalVoidedParlay
			FROM #tmpResult tmp
			WHERE t.RequestId = tmp.RequestId
		)tmp
	ORDER BY t.VoidingHistoryId DESC
	
	
	DROP TABLE #tmpResult	
END
