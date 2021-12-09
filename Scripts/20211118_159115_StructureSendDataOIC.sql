/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211118@July
	Task: TVS - Send data to OIC instead of file - [Redmine: #159115]
	DB: DBLIC-bodb_Licensee 
*/

USE bodb_Licensee
GO

--- CREATING FILE GROUP AND DATA FILE
IF NOT EXISTS (SELECT TOP 1 1 FROM sys.filegroups where name='LicenseeResultAmendment_table')
BEGIN
	ALTER DATABASE bodb_Licensee
	ADD FILEGROUP LicenseeResultAmendment_table;
END
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.database_files where name='LicenseeResultAmendment_table_01')
BEGIN
ALTER DATABASE bodb_Licensee 
ADD FILE 
(
	NAME = LicenseeResultAmendment_table_01,
	FILENAME = 'D:\IBC_DB\bodb_Licensee\LicenseeResultAmendment_table_01.NDF'
	, SIZE = 32MB , MAXSIZE = UNLIMITED, FILEGROWTH = 32MB
)
TO FILEGROUP LicenseeResultAmendment_table;
END
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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [LicenseeResultAmendment_table]
) ON [LicenseeResultAmendment_table]

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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [LicenseeResultAmendment_table]
) ON [LicenseeResultAmendment_table]