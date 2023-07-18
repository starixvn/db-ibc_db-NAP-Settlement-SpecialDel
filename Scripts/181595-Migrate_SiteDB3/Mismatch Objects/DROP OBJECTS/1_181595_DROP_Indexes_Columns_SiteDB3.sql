/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: DROP index, column  [Redmineid:#181595]					
	
*/

--- run on SiteDB3  only

USE bodb02
GO

	---- DROP index
	DROP INDEX IX_zzzbettrans_source_keyid ON dbo.zzzbettrans 
	GO
	DROP INDEX IX_zzzbettransm_source_keyid ON dbo.zzzbettransm 
	GO
	ALTER TABLE dbo.zzzbettransm DROP  CONSTRAINT  DF_zzzbettransm_source_keyid
	GO
	ALTER TABLE dbo.zzzbettrans DROP  CONSTRAINT  DF_zzzbettrans_source_keyid

	---- DROP column
	ALTER TABLE dbo.bettrans DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.bettransG DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.bettransLC DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.bettransRnG DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.translog DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.zzzbettrans DROP COLUMN source_keyid
	GO
	ALTER TABLE dbo.zzzbettransm DROP COLUMN source_keyid
	GO





