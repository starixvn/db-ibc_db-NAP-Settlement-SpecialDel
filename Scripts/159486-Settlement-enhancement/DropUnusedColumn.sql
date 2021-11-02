/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20210928@Kathy
	Task	  : Delete unused column in log table
	DB		  : DBTXN/bodb02
*/
USE bodb02
GO

ALTER TABLE [dbo].[SSB_SettlementLogs] DROP COLUMN MatchId
