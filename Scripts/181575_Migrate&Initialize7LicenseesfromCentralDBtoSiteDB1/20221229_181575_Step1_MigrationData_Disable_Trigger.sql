/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221229@July
    Task: Data Migration - Disable Trigger - PRO - ON SITEDB01
    DB: DBSIG-bodb02

	Revisions:
		- 20221229@July: Disable Trigger for bettransX tables [Redmineid:#181575] 

	Note: Run on SITEDB01

*/
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