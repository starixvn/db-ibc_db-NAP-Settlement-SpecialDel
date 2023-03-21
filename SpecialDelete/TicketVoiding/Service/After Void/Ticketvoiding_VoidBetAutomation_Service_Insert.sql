/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Ticketvoiding_VoidBetAutomation_Service_Insert]
(
	@IsAutoVoid BIT = 0
	,@RequestId  INT = NULL
	,@VoidingHistoryId INT = NULL
	,@MatchId INT = NULL
	,@NegativeBalanceUsers NVARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @sessionID	INT = 0

	SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1
	
	IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
							WHERE s.RequestId = @RequestId AND s.VoidingHistoryId = @VoidingHistoryId)
	BEGIN
		INSERT INTO dbo.Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistoryId,statusID,matchID,SessionID, IsAutoVoid, NegativeBalanceUsers)
		SELECT @RequestId, @VoidingHistoryId, 1, @MatchId, @sessionID, @IsAutoVoid, @NegativeBalanceUsers
		WHERE NOT EXISTS(SELECT TOP(1) 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
					WHERE s.RequestId = @RequestId AND s.VoidingHistoryId = @VoidingHistoryId)
	END
	
	SELECT s.SessionID, s.matchID, s.RequestID, s.VoidingHistoryId, s.statusID, s.NegativeBalanceUsers
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
	WHERE s.SessionID = @sessionID

END
GO

