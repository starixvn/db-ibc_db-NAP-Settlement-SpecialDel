/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void_Service_Update]
(
	@BroadcastSessionId	VARCHAR(50) = NULL
	,@VoidingHistoryId	INT = NULL
	,@StatusId			TINYINT = NULL
	,@SiteDBGroupId		TINYINT = NULL
	,@RequestId			INT = NULL
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
	
	IF @BroadcastSessionId IS NOT NULL
	BEGIN

		UPDATE dbo.TicketVoiding_Void_Service WITH (ROWLOCK, UPDLOCK)
		SET StatusId = @StatusId
			,ModifiedDate = GETDATE()
		WHERE BroadcastSessionId = @BroadcastSessionId
	END
	ELSE
	BEGIN
		UPDATE dbo.TicketVoiding_Void_Service WITH (ROWLOCK, UPDLOCK)
		SET StatusId = @StatusId
			,ModifiedDate = GETDATE()
	WHERE VoidingHistoryId = @VoidingHistoryId 
		AND RequestId = @RequestId
		AND SiteDBGroupID = @SiteDBGroupId
	END
END
GO

