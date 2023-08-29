/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SubIssueTypeNote_Select]
(
	@IssueTypeId TINYINT
	,@UserId	 INT
)
AS
/*	
	Created by:20230828@Max
	Task: [TVS] Edit description of subtypes by each user [Redmine: #185498]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230828@Max: Create new SP [Redmine:#185498]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT n.GroupId
		, n.Note
	FROM dbo.TicketVoiding_SubIssueType_Note n WITH (NOLOCK)
	WHERE n.IssueTypeId = @IssueTypeId
		AND n.UserId = @UserId
	ORDER BY n.GroupId
END		
GO


