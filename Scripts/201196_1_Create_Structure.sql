/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240222@Louisa
	Task: Archive data for ProviderExternalResultDetailXX [Redmine:#201196]
	DB: DBLOG/bodb_CustomerLog_Archive

	Revision:
		20240222@Louisa: Create structure, init data [Redmine:#201196]

*/

USE bodb_CustomerLog_Archive
GO

---1. ProviderExternalResultDetail_BK -------------------------------------------------------------------------------

CREATE TABLE ProviderExternalResultDetail_BK 
(	ProviderExternalId INT NOT NULL
	,MatchId INT NOT NULL
	,SourceId SMALLINT NOT NULL
	,ResourceId VARCHAR(20) NOT NULL
	,HomeValue VARCHAR(50) NULL 
	,AwayValue VARCHAR(50) NULL
	,CreateDate DATETIME NULL
) 
ON ps_SETTLE_monthly (CreateDate) WITH (DATA_COMPRESSION = PAGE) 
GO

CREATE CLUSTERED INDEX CIX_ProviderExternalResultDetail_BK ON ProviderExternalResultDetail_BK(ProviderExternalId)
WITH (DATA_COMPRESSION = PAGE) ON ps_SETTLE_monthly (CreateDate) 
GO

CREATE NONCLUSTERED INDEX IDX_ProviderExternalResultDetail_BK_SourceIdMatchIdResourceId ON ProviderExternalResultDetail_BK
(
	SourceId ASC,
	MatchId ASC,
	ResourceId ASC
) WITH (DATA_COMPRESSION = PAGE)  ON ps_SETTLE_monthly (CreateDate) 
GO

CREATE NONCLUSTERED INDEX IDX_ProviderExternalResultDetail_BK_CreateDate ON ProviderExternalResultDetail_BK(CreateDate ASC)
WITH (DATA_COMPRESSION = PAGE)  ON ps_SETTLE_monthly (CreateDate) 
GO

--------2. ProviderExternalResultDetailES_BK--------------------------------------------------------------------------

CREATE TABLE ProviderExternalResultDetailES_BK 
(	ProviderExternalId INT NOT NULL
	,MatchId INT NOT NULL
	,SourceId SMALLINT NOT NULL
	,ResourceId VARCHAR(20) NOT NULL
	,HomeValue VARCHAR(50) NULL 
	,AwayValue VARCHAR(50) NULL
	,CreateDate DATETIME NULL
) 
ON ps_SETTLE_monthly (CreateDate)  WITH (DATA_COMPRESSION = PAGE) 
GO

CREATE CLUSTERED INDEX CIX_ProviderExternalResultDetailES_BK ON ProviderExternalResultDetailES_BK(ProviderExternalId)
WITH (DATA_COMPRESSION = PAGE) ON ps_SETTLE_monthly (CreateDate) 
GO

CREATE NONCLUSTERED INDEX IDX_ProviderExternalResultDetailES_BK_SourceIdMatchIdResourceId ON ProviderExternalResultDetailES_BK
(
	SourceId ASC,
	MatchId ASC,
	ResourceId ASC
)WITH (DATA_COMPRESSION = PAGE) ON ps_SETTLE_monthly (CreateDate)
GO

CREATE NONCLUSTERED INDEX IDX_ProviderExternalResultDetailES_BK_CreateDate ON ProviderExternalResultDetailES_BK(CreateDate ASC)
WITH (DATA_COMPRESSION = PAGE) ON ps_SETTLE_monthly (CreateDate)
GO

-------3.ProviderExternalResultDetailOS_BK---------------------------------------------------------------------------

CREATE TABLE ProviderExternalResultDetailOS_BK 
(	ProviderExternalId INT NOT NULL
	,MatchId INT NOT NULL
	,SourceId SMALLINT NOT NULL
	,ResourceId VARCHAR(20) NOT NULL
	,HomeValue VARCHAR(50) NULL 
	,AwayValue VARCHAR(50) NULL
	,CreateDate DATETIME NULL
) 
ON ps_SETTLE_monthly (CreateDate) WITH (DATA_COMPRESSION = PAGE) 
GO

CREATE CLUSTERED INDEX CIX_ProviderExternalResultDetailOS_BK ON ProviderExternalResultDetailOS_BK(ProviderExternalId)
WITH (DATA_COMPRESSION = PAGE) ON ps_SETTLE_monthly (CreateDate) 
GO

CREATE NONCLUSTERED INDEX IDX_ProviderExternalResultDetailOS_BK_SourceIdMatchIdResourceId ON ProviderExternalResultDetailOS_BK
(
	SourceId ASC,
	MatchId ASC,
	ResourceId ASC
)WITH (DATA_COMPRESSION = PAGE) ON ps_SETTLE_monthly (CreateDate)
GO

CREATE NONCLUSTERED INDEX IDX_ProviderExternalResultDetailOS_BK_CreateDate ON ProviderExternalResultDetailOS_BK(CreateDate ASC)
WITH (DATA_COMPRESSION = PAGE) ON ps_SETTLE_monthly (CreateDate)
GO

------4. Settlement_ArchiveSetting----------------------------------------------------------------------------

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects WHERE name = 'Settlement_ArchiveSetting')
BEGIN
	CREATE TABLE Settlement_ArchiveSetting
	(
		ArchiveName		VARCHAR(100) NOT NULL,
		ArchiveValue	VARCHAR(100),
		CutOffValue		INT NULL,		 
		ArchiveTime		DATETIME
	)
END
GO

IF NOT EXISTS ( SELECT TOP 1 1 FROM sys.key_constraints ctr
				WHERE ctr.parent_object_id = OBJECT_ID('Settlement_ArchiveSetting')
					AND ctr.type = 'PK'
				)
BEGIN
	ALTER TABLE Settlement_ArchiveSetting
	ADD CONSTRAINT PK_Settlement_ArchiveSetting 
	PRIMARY KEY CLUSTERED (	ArchiveName ASC) 
END
GO

------ INITIAL DATA ------------------------------------------------------------------------
INSERT INTO Settlement_ArchiveSetting ( ArchiveName, ArchiveValue, CutOffValue, ArchiveTime )
VALUES   ('ProviderExternalResultDetail'	, '0'	,30	, GETDATE() )
		,('ProviderExternalResultDetailES'	, '0'	,30	, GETDATE() )
		,('ProviderExternalResultDetailOS'	, '0'	,30	, GETDATE() )

