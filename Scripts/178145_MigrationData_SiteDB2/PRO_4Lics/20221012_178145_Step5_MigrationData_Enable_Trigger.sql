/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Enable Trigger - PRO - ON SITEDB02
    DB: DBSIG-bodb02

	 Revisions:
		- 20220926@Victoria: Enable Trigger for bettransX tables [Redmineid:#178142] 
*/
	---------------------hey pontus dep trai -> run on sitedb02 nhe------------------------------------
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

