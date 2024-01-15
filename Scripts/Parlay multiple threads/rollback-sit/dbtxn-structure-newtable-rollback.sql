/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240215@Kathy
	Task	  : drop table
	DB		  : DBTXN/bodb02
*/

USE [bodb02]
GO

IF OBJECT_ID('ParlaySettlementProcessing') IS NOT NULL
	DROP TABLE dbo.ParlaySettlementProcessing
