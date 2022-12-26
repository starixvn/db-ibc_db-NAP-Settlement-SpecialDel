/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created by: 20221229@July
    Task: Data Migration - Enable Trigger - PRO - ON SITEDB01
    DB: DBSIG-bodb02

	Revisions:
		- 20221229@July: Enable Trigger for bettransX tables [Redmineid:#181575] 

	Note: Run on SITEDB01
*/
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
ENABLE TRIGGER [dbo].[Transfer_After_Update] ON [[dbo].[Transfer]
GO
