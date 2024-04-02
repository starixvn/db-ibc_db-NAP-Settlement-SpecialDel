/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SubIssueTypeNote_Update]
(	
	@IssueTypeId	TINYINT
	,@GroupId	SMALLINT
	,@UserId	INT
	,@Note		NVARCHAR(MAX) = ''	
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

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_SubIssueType_Note WHERE GroupId = @GroupId AND UserId = @UserId)
	BEGIN
		INSERT INTO dbo.TicketVoiding_SubIssueType_Note (IssueTypeId, GroupId, UserId, Note)
		SELECT @IssueTypeId, @GroupId, @UserId, @Note
	END
	ELSE
	BEGIN
		UPDATE n SET n.Note = @Note, n.ModifiedDate = GETDATE()
		FROM dbo.TicketVoiding_SubIssueType_Note n WITH (ROWLOCK, UPDLOCK)
		WHERE n.GroupId = @GroupId
			AND n.UserId = @UserId
	END
END		
GO


