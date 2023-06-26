/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230602@Louisa
    Task: Migrate 12Bet from DBTrans to SiteDB2 [Redmineid:#188707] 
    DB: DBBAH-bodb02

	Revisions:
		- 20230602@Louisa: Disable trigger on DBBAH [Redmineid:#188707] 

*/

USE bodb02
GO

DISABLE TRIGGER [dbo].[Bettrans_After_Update] ON [dbo].[bettrans]
GO
DISABLE TRIGGER [dbo].[bettransLC_After_Update] ON [dbo].[bettransLC]
GO
DISABLE TRIGGER [dbo].[BettransRNG_After_Update] ON [dbo].[bettransRnG]
GO
DISABLE TRIGGER [dbo].[TransLog_After_Update] ON [dbo].[translog]
