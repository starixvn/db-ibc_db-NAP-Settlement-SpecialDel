/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Ticketvoiding_VoidBetAutomation_Service_Insert]
(
	@IsAutoVoid BIT = 0
	,@AfterVoidDataXml  XML = NULL
)
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

	DECLARE @sessionID	INT = 0
	
	CREATE TABLE #AfterVoidData (RequestId INT, VoidingHistoryId INT, MatchId INT, NegativeBalanceUsers VARCHAR(1000))
	INSERT INTO #AfterVoidData (RequestId, VoidingHistoryId, MatchId, NegativeBalanceUsers)
	SELECT t.c.value('@RequestId','INT') AS TransId
		,t.c.value('@VoidingHistoryId','INT') AS VoidingHistoryId
		,t.c.value('@MatchId','INT') AS MatchId
		,t.c.value('@NegativeBalanceUsers','VARCHAR(1000)') AS NegativeBalanceUsers
	FROM @AfterVoidDataXml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AfterVoidDataXml = NULL)) 


	SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1
	
	IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
							INNER JOIN #AfterVoidData t ON t.RequestId = s.RequestID AND t.VoidingHistoryId = s.VoidingHistoryId)
	BEGIN
		INSERT INTO dbo.Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistoryId,statusID,matchID,SessionID, IsAutoVoid, NegativeBalanceUsers)
		SELECT v.RequestId, v.VoidingHistoryId, 1, v.MatchId , @sessionID, @IsAutoVoid, v.NegativeBalanceUsers
		FROM #AfterVoidData v
			LEFT JOIN dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK) ON s.RequestID = v.RequestId AND s.VoidingHistoryId = v.VoidingHistoryId
		WHERE s.RequestID IS NULL
	END
	
	SELECT s.SessionID, s.matchID, s.RequestID, s.VoidingHistoryId, s.statusID, s.NegativeBalanceUsers
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
	WHERE s.SessionID = @sessionID

END
GO

