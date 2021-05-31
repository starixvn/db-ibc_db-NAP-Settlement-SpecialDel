/*<info serverAlias="DBARC-bodb_archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210531@Max
	Task: TVS - Danger Accept Enhancement - Phase 9 - [Redmine: #153216]
	DB: DBARC-bodb_archive
*/

USE bodb_Archive
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail_bk]
ADD
    SubIssueTypeId SMALLINT NULL
GO

