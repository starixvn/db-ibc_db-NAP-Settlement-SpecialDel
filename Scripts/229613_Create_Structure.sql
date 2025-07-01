/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250606@Louisa
	Task: Archive data for ProviderExternalResultDetailXX [Redmine:#229613]
	DB: DBARC/bodb_Archive

	Revision:
		20240222@Louisa: Create structure, init data [Redmine:#229613]

*/

USE bodb_Archive
GO

--DROP TABLE Settlement_ArchiveSetting

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects WHERE name = 'Settlement_ArchiveSetting')
BEGIN
	CREATE TABLE Settlement_ArchiveSetting
	(
		ArchiveName		VARCHAR(100) NOT NULL,
		ArchiveValue	VARCHAR(100),		 
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
INSERT INTO Settlement_ArchiveSetting ( ArchiveName, ArchiveValue, ArchiveTime )
VALUES   ('ProviderExternalResultDetail'	, '0'	, GETDATE() )
		,('ProviderExternalResultDetailES'	, '0'	, GETDATE() )
		,('ProviderExternalResultDetailOS'	, '0'	, GETDATE() )


