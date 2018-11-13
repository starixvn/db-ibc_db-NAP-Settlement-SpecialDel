/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MessageTemplate_Settings_Select]
	  
AS
/*	Created by:: Alan
	Date 20181113
	Task: #101083 - Support Message Template
	DB: DBTXN.bodb02
	
	Revisions: 
		- 20181113@Alan: Select Settings [101083]
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	BEGIN
		SELECT 
			TemplateId, 
			SubIssueTypeId, 
			Sporttype
		FROM [dbo].[TicketVoiding_MessageTemplateSetting] WITH(NOLOCK)
	END
END
GO