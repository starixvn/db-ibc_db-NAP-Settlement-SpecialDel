/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MessageTemplate_SubIssueType_Select]	  
AS
/*	Created by:: Alan
	Date 20181113
	Task: #101083 - Support Message Template
	DB: DBCTG.bodb02
	
	Revisions: 
		- 20181113@Alan: Select Sub Issue Type [101083]
		- 20191122@Raymond.Le: Ticket Voiding System - Abnormal Bet Issue Type [Redmine: #111541]
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	BEGIN
		SELECT 
			SubIssueTypeId, 
			SubIssueTypeName,
			SubIssueTypeNameCS,
			IssueTypeId
		FROM [dbo].[TicketVoiding_SubIssueType] WITH(NOLOCK)
		ORDER BY SubIssueTypeId
	END
END
GO