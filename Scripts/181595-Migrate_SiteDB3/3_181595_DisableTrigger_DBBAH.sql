/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBBAH-bodb02

	Revisions:
		- 20230626@Louisa: Disable trigger DBBAH [Redmineid:#181595] 

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
