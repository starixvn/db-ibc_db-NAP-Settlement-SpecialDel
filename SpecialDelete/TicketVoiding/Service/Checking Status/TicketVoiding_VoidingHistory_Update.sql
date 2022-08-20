/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Update]
(
	@BroadcastSessionId	VARCHAR(50)
	,@VoidingHistoryId	INT
	,@StatusId			TINYINT
	,@SiteDBGroupId		TINYINT
	,@RequestId			INT
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

	UPDATE dbo.TicketVoiding_Void_Service WITH (ROWLOCK, UPDLOCK)
		SET StatusId = @StatusId
			,ModifiedDate = GETDATE()
	WHERE VoidingHistoryId = @VoidingHistoryId 
		AND RequestId = @RequestId
		AND SiteDBGroupID = @SiteDBGroupId
		AND BroadcastSessionId = @BroadcastSessionId
END
GO

