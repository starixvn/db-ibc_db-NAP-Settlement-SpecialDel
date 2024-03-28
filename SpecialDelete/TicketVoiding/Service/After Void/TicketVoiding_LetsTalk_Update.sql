/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Letstalk_Update]
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
	
	UPDATE dbo.TicketVoiding_Letstalk WITH (ROWLOCK,UPDLOCK)
	SET StatusId = @StatusId
	  , ModifiedDate = GETDATE()
	WHERE RequestId = @RequestId
		AND BroadcastSessionID = @BroadcastSessionID

END
GO