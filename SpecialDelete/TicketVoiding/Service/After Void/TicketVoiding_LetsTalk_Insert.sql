/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Letstalk_Insert]
(
	@RequestId				INT
   ,@BroadcastSessionID		VARCHAR(100)
   ,@StatusId				TINYINT
)
AS
/*	
	Created by: 20230103@July
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230103@July: Create new SP  [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM TicketVoiding_Letstalk WITH(NOLOCK) 
					WHERE RequestId = @RequestId AND BroadcastSessionId = @BroadcastSessionID
			)
	BEGIN
		INSERT INTO dbo.TicketVoiding_Letstalk (RequestId, BroadcastSessionID, StatusId)
		SELECT @RequestId, @BroadcastSessionID, @StatusId
	END

END
GO