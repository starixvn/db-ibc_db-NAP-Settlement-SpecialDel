/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201110@Max
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBTXN-bodb02 & Replicated Server for DBTrans_Sync_DB06
*/

USE bodb02
GO

ALTER TABLE [dbo].[TicketVoiding_VoidingHistory]
ADD
	MinWinlostDate	DATETIME NULL,
	MaxWinlostDate	DATETIME NULL
GO



