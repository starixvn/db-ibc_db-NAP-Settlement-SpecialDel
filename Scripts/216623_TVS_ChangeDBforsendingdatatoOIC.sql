/*<info serverAlias="DBOIC-bodb_OIC" executers="" isFunction="0"></info>*/
/*
    Created: 20250122@July
	Task: Integrate - Change DB for sending data to OIC - [Redmine: #216623]
	DB: DBOIC-bodb_OIC
*/

USE bodb_OIC
GO


IF OBJECT_ID (N'LicenseeResultAmendment', N'U') IS NOT NULL
	DROP TABLE dbo.LicenseeResultAmendment

IF OBJECT_ID (N'LicenseeResultAmendmentDetails', N'U') IS NOT NULL
	DROP TABLE dbo.LicenseeResultAmendmentDetails	

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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]

CREATE NONCLUSTERED INDEX [IX_LicenseeResultAmendment_EventDate_SiteName] ON [dbo].[LicenseeResultAmendment]
(
	EventDate ASC, SiteName ASC
) ON [bodb_OIC_Data]
GO

CREATE NONCLUSTERED INDEX [IX_LicenseeResultAmendment_SessionID] ON [dbo].[LicenseeResultAmendment]
(
	SessionID ASC
) ON [bodb_OIC_Data]
GO

CREATE NONCLUSTERED INDEX [IX_LicenseeResultAmendment_CreatedDate] ON [dbo].[LicenseeResultAmendment]
(
	CreatedDate ASC
) ON [bodb_OIC_Data]
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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bodb_OIC_Data]
) ON [bodb_OIC_Data]