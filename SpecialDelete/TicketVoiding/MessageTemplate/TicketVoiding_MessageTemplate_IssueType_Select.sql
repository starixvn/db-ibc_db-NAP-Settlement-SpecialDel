/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MessageTemplate_IssueType_Select]
	  
AS
/*	Created by:: Alan
	Date 20181113
	Task: #101083 - Support Message Template
	DB: DBCTG.bodb02
	
	Revisions: 
		- 20181113@Alan: Select Issue Type [101083]
		- 20240829@July: Sort alphabet issuetype [Redmine: #208628]

	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	BEGIN
		SELECT 
			IssueTypeId, 
			IssueTypeName
		FROM [dbo].[TicketVoiding_IssueType] WITH(NOLOCK)
		ORDER BY IssueTypeName ASC 
	END
END
GO