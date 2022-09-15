/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_TotalVoidedTicket_Select]
( 
	@RequestInfo XML =''
)
AS;
/*	Created by: July
	Date 20220822
	Task: Change of TVS regarding to Scale out DBTrans [Redmine:#175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220822@July: Create new SP - get total voided ticket [Redmine:#175412]
		
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
		,TotalVoidedSingle	INT
		,TotalVoidedParlay	INT
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
		,TotalVoidedSingle	INT
		,TotalVoidedParlay	INT
	)

	INSERT INTO #tmpResult (RequestId, MatchId, IssueTypeId)
	SELECT DISTINCT RequestId, MatchId, IssueTypeId
	FROM @tmpMatchVoidingHistory

	-- single + cash out ticket	
	UPDATE vh 
		SET TotalVoidedSingle = t.TotalVoidedSingle
			,TotalVoidedParlay = CASE WHEN vh.IssueTypeId IN (11,13,17) THEN t.TotalVoidedParlay ELSE 0 END
	FROM @tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (11,13,17) THEN 1
							WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype NOT IN (9,29,2799) THEN 1
						ELSE 0 END
						) AS TotalVoidedSingle
					,SUM(CASE WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype IN (9,29,2799) THEN 1 ELSE 0 END) AS TotalVoidedParlay
					,CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END AS matchid
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON vh.VoidingHistoryId = z.VoidingHistoryId 
			WHERE z.SiteDBGroupID = @SiteDBGroupID AND (vh.MatchId = z.matchid OR vh.MatchId = 0)
			GROUP BY vh.VoidingHistoryId, CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END
	) t ON	vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid
			
	--parlay
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

	UPDATE t 
		SET TotalVoidedSingle = ISNULL(vh.TotalVoidedSingle,0)
			,TotalVoidedParlay = ISNULL(vh.TotalVoidedParlay,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	SUM(vh.TotalVoidedSingle) AS TotalVoidedSingle
					,SUM(vh.TotalVoidedParlay) AS TotalVoidedParlay
			FROM	@tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR vh.MatchId = 0)
		) vh

	SELECT  RequestId			
		   ,CASE WHEN IssueTypeId IN (13,17) THEN NULL ELSE matchid END AS matchid
		   ,TotalVoidedSingle	
		   ,TotalVoidedParlay	
	FROM #tmpResult

	DROP TABLE #tmpResult
	
END
GO
