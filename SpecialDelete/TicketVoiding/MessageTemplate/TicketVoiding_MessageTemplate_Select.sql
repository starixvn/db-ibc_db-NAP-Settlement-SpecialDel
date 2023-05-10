/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MessageTemplate_Select]
	  
AS
/*	Created by:: Alan
	Date 20181113
	Task: #101083 - Support Message Template
	DB: DBCTG.bodb02
	
	Revisions: 
		- 20181113@Alan: Select Message Template [101083]
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	BEGIN
		SELECT 
			TemplateId,
			MsgEnglish, 
			MsgChineseTraditional, 
			MsgChineseSimplified, 
			MsgChineseNewSimplified, 
			JsonValue
		FROM [dbo].[TicketVoiding_MessageTemplate] WITH(NOLOCK)
	END
END
GO