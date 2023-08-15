/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: object related inhouse replicator  [Redmineid:#181595]					
	
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

	---- Add index
		--bettrans.IX_RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettrans]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----BettransInfo.RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[BettransInfo]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----bettransLC.RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettransLC]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----bettransm.RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettransm]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----bettransRnG.IX_tstamp
	CREATE NONCLUSTERED INDEX [IX_tstamp] ON [dbo].[bettransRnG]
	(
		[tstamp] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO
	
	----CashOutSelling.IX_tstamp
	CREATE NONCLUSTERED INDEX [IX_tstamp] ON [dbo].[CashOutSelling]
	(
		[tstamp] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO
	
	----translog.IX_tstamp
	CREATE NONCLUSTERED INDEX [IX_tstamp] ON [dbo].[translog]
	(
		[tstamp] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO



