/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Letstalk_Update]
(
	@RequestId				INT
   ,@BroadcastSessionID		VARCHAR(100)
   ,@StatusId				TINYINT
   ,@Mode					TINYINT
)
AS
/*	
	Created by: 20230103@July
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230103@July: Create new SP  [Redmine: #180625]

	Param's explanation:
		@Mode: 1 - Insert, 2 - Update
*/
BEGIN
	SET NOCOUNT ON
	IF @Mode = 1
	BEGIN
		INSERT INTO dbo.TicketVoiding_Letstalk (RequestId, BroadcastSessionID, StatusId)
		SELECT @RequestId, @BroadcastSessionID, @StatusId
	END
	ELSE IF @Mode = 2
	BEGIN
		UPDATE dbo.TicketVoiding_Letstalk 
		SET StatusId = @StatusId, ModifiedDate = GETDATE()
		WHERE RequestId = @RequestId AND BroadcastSessionID = @BroadcastSessionID
	END
END
GO