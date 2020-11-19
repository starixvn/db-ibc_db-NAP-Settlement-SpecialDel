/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201110@Max
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBTXN-bodb02 & Replicated Server for DBTrans_API_Data
*/

USE bodb02
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail]
ADD
    Usernames		NVARCHAR(MAX)	NULL,
	ProductIds		VARCHAR(50)	NULL,
	TicketStatusIds			VARCHAR(50)		NULL,
	FromWinlostDate			DATETIME		NULL,
	ToWinlostDate		DATETIME			NULL
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetailTicket_Single] ADD RequestDetailId INT NULL
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetailTicket_SubParlay]
ADD
	RequestDetailId INT NULL,
	MainTransId	BIGINT	NULL
GO



