/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestList_UpdateStatus]
(
	 @RequestId			INT
	,@IsStored			BIT	= 0
)
AS
/*	Created by: 20250403@July
	Task: Manage Request - Add new function and status "Stored" for request
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20250403@July: Create new SP [Redmine:#220451]
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE dbo.TicketVoiding_Request WITH (ROWLOCK,UPDLOCK)
	SET IsStored = @IsStored
	WHERE RequestId = @RequestId
END
