/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestInfo_Select]
(
	@RequestId		INT				= NULL
)
AS
/*	Created by: Zane
	Date 20181212
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBTXN/bodb02
	
	Revisions: 		
		- 20201229@Zane: Create new SP [Redmine:#145719]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatchVoidingHistory TABLE (
		 RequestId			INT
		,VoidingHistoryId	INT
		,VoidedBy			INT
		,TotalSingle		INT
		,TotalParlay		INT
	)

	CREATE TABLE #tmpResult (
		 RequestId		INT
		,IssueTypeId	TINYINT
		,LastVoidedBy	INT
		,TotalSingle	INT
		,TotalParlay	INT
	)
	INSERT INTO #tmpResult(RequestId, IssueTypeId)
		SELECT DISTINCT r.RequestId
				,r.IssueTypeId
		FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
		WHERE	r.RequestId = @RequestId
		
	INSERT INTO @tmpMatchVoidingHistory (RequestId, VoidingHistoryId, VoidedBy)
	SELECT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
			FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
			WHERE	vh.RequestId = t.requestId AND vh.StatusId IN (2,3)
		) vh
		
	UPDATE	t 
		SET LastVoidedBy = vh.LastVoidedBy
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	TOP (1) vh.VoidedBy AS LastVoidedBy
			FROM	@tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId
			ORDER BY vh.VoidingHistoryId DESC
		) vh
		
	-- single
	UPDATE vh 
		SET TotalSingle =	t.TotalVoidedSingle
	FROM @tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,SUM(CASE 
							WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
							WHEN z.bettype = 911 THEN 1
							ELSE 0 END
						) AS TotalVoidedSingle
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId
	) t 
		ON	vh.VoidingHistoryId = t.VoidingHistoryId
		
	--parlay
	UPDATE vh
		SET TotalParlay = TotalVoidedParlay
	FROM	@tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,COUNT(1) AS TotalVoidedParlay
			FROM	@tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId
	) t
		ON	vh.VoidingHistoryId = t.VoidingHistoryId

	UPDATE t 
		SET TotalSingle = ISNULL(vh.TotalSingle,0)
			,TotalParlay = ISNULL(vh.TotalParlay,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	SUM(vh.TotalSingle) AS TotalSingle
					,SUM(vh.TotalParlay) AS TotalParlay
			FROM	@tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId
		) vh
	
	--Return Data
	SELECT	 t.RequestId
			,v.Username AS LastPerformedBy
			,t.TotalSingle AS TotalVoidedSingle
			,t.TotalParlay AS TotalVoidedParlay
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId

	DROP TABLE #tmpResult	
END
