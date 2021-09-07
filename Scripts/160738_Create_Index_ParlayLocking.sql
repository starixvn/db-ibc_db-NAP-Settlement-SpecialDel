/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20210907@Louisa
    Task: Create Index on table dbo.ParlayLocking  
    DB: DBTXN-bodb02

	 Revisions:
		- 20210907@Louisa: Create Index on table dbo.ParlayLocking [Redmineid:#160738]
*/

USE bodb02
GO


CREATE NONCLUSTERED INDEX [IX_ParlayLocking_Session]
ON [dbo].[ParlayLocking] ([Session])
ON [DATA]

GO
