/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/

USE [bodb02]
GO
/*  Creator: 20210514@Kathy
	Task: Add new column
	DB: DBTXN/BODB02

*/
ALTER TABLE [dbo].[Parlay_Calculate_Queue] ADD sqlCommand NVARCHAR(MAX)
GO

ALTER TABLE [dbo].[Parlay_Calculate_Queue] ADD SportType SMALLINT
GO

