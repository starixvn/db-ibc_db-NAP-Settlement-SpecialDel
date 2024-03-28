/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Email_CheckITUser]
	@VoidingHistoryId		INT = NULL
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

	SELECT ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (vh.UserId,2)),0) AS IsITSupport
		, ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (r.UserId,2)),0)  AS IsITSupportCreatedRequest
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK)
			ON r.RequestId =  vh.RequestId
	WHERE	vh.VoidingHistoryId = @VoidingHistoryId

END
GO
