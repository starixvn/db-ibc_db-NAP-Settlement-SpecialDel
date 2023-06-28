/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: Enable trigger on SiteDB3 [Redmineid:#181595] 

*/

----Note: Run on SITEDB03 only

USE bodb02
GO	
	ENABLE TRIGGER [dbo].[Bettrans_After_Insert] ON [dbo].[bettrans]
	GO
	ENABLE TRIGGER [dbo].[Bettrans_After_Update] ON [dbo].[bettrans]
	GO
	ENABLE TRIGGER [dbo].[bettransLC_After_Insert] ON [dbo].[bettransLC]
	GO
	ENABLE TRIGGER [dbo].[bettransLC_After_Update] ON [dbo].[bettransLC]
	GO
	ENABLE TRIGGER [dbo].[BettransRNG_After_Insert] ON [dbo].[bettransRnG]
	GO
	ENABLE TRIGGER [dbo].[BettransRNG_After_Update] ON [dbo].[bettransRnG]
	GO
	ENABLE TRIGGER [dbo].[TransLog_After_Insert] ON [dbo].[translog]
	GO
	ENABLE TRIGGER [dbo].[TransLog_After_Update] ON [dbo].[translog]
	GO
	ENABLE TRIGGER [dbo].[Transfer_After_Insert] ON [dbo].[Transfer]
	GO
	ENABLE TRIGGER [dbo].[Transfer_After_Update] ON [dbo].[Transfer]
	GO
