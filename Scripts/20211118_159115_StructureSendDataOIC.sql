/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211118@July
	Task: TVS - Send data to OIC instead of file - [Redmine: #159115]
	DB: DBLIC-bodb_Licensee 
*/

USE bodb_Licensee
GO
CREATE TABLE dbo.LicenseeResultAmendment
(
	ResultID	 BIGINT IDENTITY(1,1),
	SessionID	 UNIQUEIDENTIFIER,
	SiteName	 NVARCHAR(50),
	MatchID		 INT,
	EventDate	 DATETIME,
	CreatedDate  DATETIME,
	ModifiedDate DATETIME
 CONSTRAINT [PK_LicenseeResultAmendment_ResultID] PRIMARY KEY CLUSTERED 
(
	ResultID ASC
))

CREATE NONCLUSTERED INDEX [IX_LicenseeResultAmendment_EventDate_SiteName] ON [dbo].[LicenseeResultAmendment]
(
	EventDate ASC, SiteName ASC
)
GO

CREATE NONCLUSTERED INDEX [IX_LicenseeResultAmendment_SessionID] ON [dbo].[LicenseeResultAmendment]
(
	SessionID ASC
)
GO

ALTER TABLE dbo.LicenseeResultAmendment ADD  CONSTRAINT [DF_LicenseeResultAmendment_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

ALTER TABLE dbo.LicenseeResultAmendment ADD  CONSTRAINT [DF_LicenseeResultAmendment_ModifiedDate]  DEFAULT (getdate()) FOR [ModifiedDate]
GO

CREATE TABLE dbo.LicenseeResultAmendmentDetails
(
	ResultID	BIGINT,
	TransID		BIGINT,
	CustID		INT,
	Recommend	INT
CONSTRAINT [PK_LicenseeResultAmendmentDetails_ResultID_TransID] PRIMARY KEY CLUSTERED 
(
	ResultID ASC, TransID ASC
))