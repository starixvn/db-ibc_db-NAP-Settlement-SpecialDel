/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TemplateMessage_Select]
	  
AS
/*	Created by:: Alan
	Date 20181008
	Task: #101083 - Support Message Template
	DB: DBMSG.bodb_Message
	
	Revisions: 
		- 20181008@Alan: Select message template 
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	BEGIN
		SELECT Id, IssueType, English, ChineseTraditional, ChineseSimplified, ChineseNewSimplified
		FROM dbo.MessageTemplate
		ORDER BY Id
	END

	SET NOCOUNT OFF
END
GO
