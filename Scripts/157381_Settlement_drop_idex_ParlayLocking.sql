/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20210910@Louisa
    Task: Drop Index on table [dbo].[ParlayLocking] 
    DB: DBTXN-bodb02

	 Revisions:
		- 20210910@Louisa: Drop Index on table [dbo].[ParlayLocking] [Redmine:#157381]
*/

USE bodb02
GO

IF EXISTS ( SELECT TOP 1 1 FROM sys.indexes s where s.name  = 'IX_ParlayLocking_MatchId' )
BEGIN

	DROP INDEX [IX_ParlayLocking_MatchId]	ON [dbo].[ParlayLocking]

END

GO