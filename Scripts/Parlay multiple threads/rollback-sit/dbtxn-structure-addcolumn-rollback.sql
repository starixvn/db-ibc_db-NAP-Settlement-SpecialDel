/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240215@Kathy
	Task	  : rollback column
	DB		  : DBTXN/bodb02
*/

USE [bodb02]
GO

alter table Parlay_Calculate_Queue drop constraint DF_Parlay_Calculate_Queue_SSBStatus
alter table Parlay_Calculate_Queue drop column SSBStatus
alter table Parlay_Calculate_Queue drop column SSBCommand

