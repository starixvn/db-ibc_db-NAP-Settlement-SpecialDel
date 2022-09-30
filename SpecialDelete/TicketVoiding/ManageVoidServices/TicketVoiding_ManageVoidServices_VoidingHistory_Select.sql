/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ManageVoidServices_VoidingHistory_Select]
(
	@RequestId	INT
)
AS
/*	
	Created by: 20220927@July
	Task: [TVS] Manage Void Service - Support web [Redmine: #178172]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220927@July: Create new SP [Redmine:#178172]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	SELECT VoidingHistoryId
		   ,RequestId
		   ,MessageId
		   ,StatusId
		   ,ReasonId
		   ,UserId
		   ,CreatedDate
		   ,ModifiedDate
		   ,TransIds
		   ,VoidData
		   ,MinWinlostdate
		   ,MaxWinlostdate
	FROM dbo.TicketVoiding_VoidingHistory WITH(NOLOCK)
	WHERE RequestId = @RequestId

END		
GO


