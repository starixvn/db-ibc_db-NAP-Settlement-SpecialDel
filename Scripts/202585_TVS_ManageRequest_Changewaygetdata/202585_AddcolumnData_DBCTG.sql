/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240627@July
	Task: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail]
ADD
    Sporttype SMALLINT NULL
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'Sporttype' AND Object_ID = Object_ID(N'TicketVoiding_Request'))
BEGIN
	ALTER TABLE TicketVoiding_Request DROP COLUMN Sporttype
END
GO
