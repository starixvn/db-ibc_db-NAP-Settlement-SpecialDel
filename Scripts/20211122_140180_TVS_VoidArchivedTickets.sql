/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20211122@July 
	Task: [TVS] Void Archived Tickets - [Redmine: #140180]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

SET IDENTITY_INSERT TicketVoiding_IssueType ON
INSERT INTO TicketVoiding_IssueType (IssueTypeId,IssueTypeName)
VALUES (17,'Archived Ticket')
SET IDENTITY_INSERT TicketVoiding_IssueType OFF

SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId,SubIssueTypeName)
VALUES (93,17,'Archived Ticket')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF