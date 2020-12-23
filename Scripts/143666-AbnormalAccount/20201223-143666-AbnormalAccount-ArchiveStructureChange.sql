/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201223@July
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBARC/bodb_Archive
*/

USE bodb_Archive
GO

ALTER TABLE [dbo].[TicketVoiding_VoidingHistory_bk]
ADD
	[VoidData] [xml] NULL
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail_bk]
ADD
    Usernames		NVARCHAR(MAX) NULL,
	ProductIds		VARCHAR(50)	NULL,
	TicketStatusIds	VARCHAR(50)	NULL,
	FromWinlostDate	DATETIME	NULL,
	ToWinlostDate	DATETIME	NULL
GO


ALTER TABLE [dbo].[TicketVoiding_RequestDetailTicket_Single_bk] ADD RequestDetailId INT NULL
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetailTicket_SubParlay_bk]
ADD
	RequestDetailId INT NULL,
	MainTransId	BIGINT	NULL
GO
