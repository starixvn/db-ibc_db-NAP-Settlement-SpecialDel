/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Disable Trigger - PRO - ON SITEDB02
    DB: DBSIG-bodb02

	 Revisions:
		- 20220926@Victoria: Disable Trigger for bettransX tables [Redmineid:#178145] 
*/
	---------------------hey pontus dep trai -> run on sitedb02 nhe------------------------------------
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