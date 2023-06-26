/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230602@Louisa
    Task: Migrate 12Bet from DBTrans to SiteDB2 [Redmineid:#188707] 
    DB: DBBAH.bodb02

	Revisions:
		- 20230602@Louisa: Enable trigger on SiteDB2 [Redmineid:#188707] 

*/
USE bodb02
GO

ENABLE TRIGGER [dbo].[Bettrans_After_Update] ON [dbo].[bettrans]
GO
ENABLE TRIGGER [dbo].[bettransLC_After_Update] ON [dbo].[bettransLC]
GO
ENABLE TRIGGER [dbo].[BettransRNG_After_Update] ON [dbo].[bettransRnG]
GO
ENABLE TRIGGER [dbo].[TransLog_After_Update] ON [dbo].[translog]
