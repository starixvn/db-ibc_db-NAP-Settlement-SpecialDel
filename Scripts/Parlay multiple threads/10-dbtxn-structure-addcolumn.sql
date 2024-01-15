/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240215@Kathy
	Task	  : add column
	DB		  : DBTXN/bodb02
*/
USE bodb02
GO

ALTER TABLE [dbo].[Parlay_Calculate_Queue] ADD SSBStatus TINYINT CONSTRAINT DF_Parlay_Calculate_Queue_SSBStatus DEFAULT 0
GO
ALTER TABLE [dbo].[Parlay_Calculate_Queue] ADD SSBCommand NVARCHAR(MAX)
