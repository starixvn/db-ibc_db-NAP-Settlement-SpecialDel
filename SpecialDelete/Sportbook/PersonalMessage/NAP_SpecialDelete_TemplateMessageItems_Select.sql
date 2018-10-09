/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TemplateMessageItems_Select]
	
AS
/*	Created by:: Alan
	Date 20181008
	Task: #101083 - Support Message Template
	DB: DBMSG.bodb_Message
	
	Revisions: 
		- 20181008@Alan: Select message template item

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	SELECT TemplateId, InputType, Name, JsonValue, OrderBy
	FROM dbo.MessageTemplateItems

	SET NOCOUNT OFF
END
GO
