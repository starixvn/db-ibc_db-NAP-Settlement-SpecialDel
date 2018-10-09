/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TemplateMessage_Insert]
	@IssueType				NVARCHAR(100),
	@ParentId				INT = NULL,
	@Creator				NVARCHAR(50) = NULL,
	@English				NVARCHAR(4000) = NULL,
	@ChineseTraditional		NVARCHAR(4000) = NULL,
	@ChineseSimplified		NVARCHAR(4000) = NULL,
	@ChineseNewSimplified	NVARCHAR(4000) = NULL,

	@ErrorMsg				NVARCHAR(200)	= ''	OUTPUT,
    @ErrorCode				INT				= 0		OUTPUT   
AS
/*	Created by:: Alan
	Date 20181008
	Task: #101083 - Support Message Template
	DB: DBMSG.bodb_Message
	
	Revisions: 
		- 20181008@Alan: Insert message template into new table MessageTemplate
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	IF EXISTS (SELECT IssueType FROM dbo.MessageTemplate WHERE IssueType = @IssueType) 
	BEGIN
		SELECT 
			@ErrorMsg = 'This template has already existed!',
			@ErrorCode  = 1
		RETURN
	END
	ELSE 
	BEGIN
		INSERT dbo.MessageTemplate(IssueType, ParentId, English, ChineseTraditional, ChineseSimplified, ChineseNewSimplified,
			Creator, CreatedTime, LastUpdatedTime)
		VALUES (@IssueType, @ParentId, @English, @ChineseTraditional, @ChineseSimplified, @ChineseNewSimplified,
			@Creator, getdate(), getdate())

		SELECT SCOPE_IDENTITY() AS TemplateId;
	END

	SET NOCOUNT OFF
END
GO
