/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBBAH.bodb02

	Revisions:
		- 20230602@Louisa: Enable trigger on DBBAH [Redmineid:#181595] 

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
