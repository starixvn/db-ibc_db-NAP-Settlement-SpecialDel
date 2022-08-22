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
	
	CREATE TABLE #tmp_BroadcastSessionId (BroadcastSessionId VARCHAR(50), CreatedDate DATETIME)

	INSERT INTO #tmp_BroadcastSessionId
	SELECT DISTINCT sv.BroadcastSessionId
	FROM dbo.TicketVoiding_Void_Service sv WITH (NOLOCK)
	WHERE sv.StatusId = 12

	DELETE t
	FROM #tmp_BroadcastSessionId t
		CROSS APPLY (
			SELECT TOP(1) sv.BroadcastSessionId
			FROM dbo.TicketVoiding_Void_Service sv WITH (NOLOCK)
			WHERE sv.BroadcastSessionId = t.BroadcastSessionId
				AND sv.StatusId NOT IN (12)
		)s

	IF EXISTS (SELECT TOP(1) 1 FROM #tmp_BroadcastSessionId)
	BEGIN
		UPDATE t SET t.CreatedDate = s.CreatedDate
		FROM #tmp_BroadcastSessionId t
			CROSS APPLY (
				SELECT MAX(sv.CreatedDate) AS CreatedDate
				FROM dbo.TicketVoiding_Void_Service sv WITH (NOLOCK)
				WHERE sv.BroadcastSessionId = t.BroadcastSessionId
			)s
	END

	SELECT b.BroadcastSessionId, s.SiteDBGroupID, s.RequestId, s.VoidingHistoryId, s.StatusId, s.IsAutoVoid, s.MatchId, DATEDIFF(SECOND, b.CreatedDate, GETDATE()) AS CreatedTimeDuration
	FROM 
	(
		SELECT TOP(1) b.BroadcastSessionId, CreatedDate
		FROM #tmp_BroadcastSessionId b
		ORDER BY b.CreatedDate
	)b
	INNER JOIN dbo.TicketVoiding_Void_Service s WITH (NOLOCK) ON s.BroadcastSessionId = b.BroadcastSessionId
	
	DROP TABLE #tmp_BroadcastSessionId
END
GO

