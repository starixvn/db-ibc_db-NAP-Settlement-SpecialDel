/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Disable Trigger
    DB: DBSIG-bodb02

	 Revisions:
		- 20220926@Victoria: Disable Trigger for bettransX tables [Redmineid:#178142] 
*/

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