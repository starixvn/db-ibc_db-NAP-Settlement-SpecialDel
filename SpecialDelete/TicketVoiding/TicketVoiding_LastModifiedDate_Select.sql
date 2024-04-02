/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LastModifiedDate_Select]
(	
	@RequestId	INT
)
AS
/*	
	Created by: Max
	Date 20210622
	Task: [TVS] Submit new allowance setting for Main Match [Redmine: #157226]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20210622@Max: Create new SP [Redmine: #157226]
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT r.LastModifiedDate
	FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
	WHERE r.RequestId = @RequestId

END
GO