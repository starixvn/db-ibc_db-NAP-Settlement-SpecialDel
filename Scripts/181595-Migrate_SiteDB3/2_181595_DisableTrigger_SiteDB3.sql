/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230626@Louisa: Disable trigger SiteDB3 [Redmineid:#181595] 

*/

----Note: Run on SITEDB03 only

USE bodb02
GO

	DISABLE TRIGGER [dbo].[Bettrans_After_Insert] ON [dbo].[bettrans]
	GO
	DISABLE TRIGGER [dbo].[Bettrans_After_Update] ON [dbo].[bettrans]
	GO
	DISABLE TRIGGER [dbo].[bettransLC_After_Insert] ON [dbo].[bettransLC]
	GO
	DISABLE TRIGGER [dbo].[bettransLC_After_Update] ON [dbo].[bettransLC]
	GO
	DISABLE TRIGGER [dbo].[BettransRNG_After_Insert] ON [dbo].[bettransRnG]
	GO
	DISABLE TRIGGER [dbo].[BettransRNG_After_Update] ON [dbo].[bettransRnG]
	GO
	DISABLE TRIGGER [dbo].[TransLog_After_Insert] ON [dbo].[translog]
	GO
	DISABLE TRIGGER [dbo].[TransLog_After_Update] ON [dbo].[translog]
	GO
	DISABLE TRIGGER [dbo].[Transfer_After_Insert] ON [dbo].[Transfer]
	GO
	DISABLE TRIGGER [dbo].[Transfer_After_Update] ON [dbo].[Transfer]
	GO
	DISABLE TRIGGER [dbo].[bettransG_After_Insert] ON [dbo].[bettransG]
	GO
	DISABLE TRIGGER [dbo].[bettransG_After_Update] ON [dbo].[bettransG]
	GO
