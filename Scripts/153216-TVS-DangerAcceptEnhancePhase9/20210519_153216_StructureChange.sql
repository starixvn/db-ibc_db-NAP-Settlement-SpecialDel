/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210519@Max
	Task: [TVS] Danger Accept Enhancement - Phase 9 - [Redmine: #153216]
	DB: DBTXN-bodb02 & Replicated Server for DBTrans_Sync_DB06
*/

USE bodb02
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail]
ADD
    SubIssueTypeId SMALLINT NULL
GO




