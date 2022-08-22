/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void_Service_Select]
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmp_BroadcastSessionId (BroadcastSessionId VARCHAR(50), ID INT IDENTITY(1,1))

	DECLARE @CheckStatus_tmp AS TABLE (BroadcastSessionId VARCHAR(50))

	INSERT INTO #tmp_BroadcastSessionId
	SELECT DISTINCT sv.BroadcastSessionId
	FROM dbo.TicketVoiding_Void_Service sv WITH (NOLOCK)
	WHERE sv.StatusId = 12

	IF EXISTS (SELECT TOP(1) 1 FROM #tmp_BroadcastSessionId)
	BEGIN
		;WITH cte_BroadcastSessionId AS
		(
			SELECT BroadcastSessionId
			FROM #tmp_BroadcastSessionId 
		)
		, cte_CheckStatus AS
		(
			SELECT TOP(1) sv.BroadcastSessionId
			FROM dbo.TicketVoiding_Void_Service sv WITH (NOLOCK)
				INNER JOIN cte_BroadcastSessionId c ON c.BroadcastSessionId = sv.BroadcastSessionId
			WHERE sv.StatusId NOT IN (12)
		)
		INSERT INTO @CheckStatus_tmp (BroadcastSessionId)
		SELECT BroadcastSessionId FROM cte_CheckStatus
	END

	SELECT b.BroadcastSessionId, s.SiteDBGroupID, s.RequestId, s.VoidingHistoryId, s.StatusId, s.IsAutoVoid, s.MatchId
	FROM 
	(
		SELECT TOP(1) b.BroadcastSessionId
		FROM #tmp_BroadcastSessionId b
		WHERE NOT EXISTS (SELECT TOP(1) 1 FROM @CheckStatus_tmp t WHERE b.BroadcastSessionId = t.BroadcastSessionId)
	)b
	INNER JOIN dbo.TicketVoiding_Void_Service s WITH (NOLOCK) ON s.BroadcastSessionId = b.BroadcastSessionId
	
	DROP TABLE #tmp_BroadcastSessionId
END
GO

