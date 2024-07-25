/*<info serverAlias="DBARC-bodb_archive" executers="" isFunction="0"></info>*/
/*
    Created: 20240627@July
	Task: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
	DB: DBARC-bodb_archive
*/

USE bodb_Archive
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail_bk]
ADD
    Sporttype SMALLINT NULL,
	Eventdate DATETIME NULL
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_RequestDetail_bk_Eventdate] ON [dbo].[TicketVoiding_RequestDetail_bk]
(
	[Eventdate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO


IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'Sporttype' AND Object_ID = Object_ID(N'TicketVoiding_Request_bk'))
BEGIN
	ALTER TABLE TicketVoiding_Request_bk DROP COLUMN Sporttype
END
GO


