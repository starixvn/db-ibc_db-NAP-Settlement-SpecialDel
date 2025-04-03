/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestList_UpdateStatus]
(
	 @RequestId			INT
	,@IsArchived		BIT	= 0
)
AS
/*	Created by: 20250403@July
	Task: Archived Request Function
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20250403@July: Create new SP [Redmine:#213398]
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE dbo.TicketVoiding_Request WITH (ROWLOCK,UPDLOCK)
	SET IsArchived = @IsArchived
	WHERE RequestId = @RequestId
END
