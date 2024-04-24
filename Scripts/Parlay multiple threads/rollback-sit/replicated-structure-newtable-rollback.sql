/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240215@Kathy
	Task	  : create new table
	DB		  : 
*/
USE [bodb02]
GO

IF OBJECT_ID('ParlaySettlementProcessing') IS NOT NULL
	DROP TABLE dbo.ParlaySettlementProcessing

IF OBJECT_ID('ParlaySettlementLock') IS NOT NULL
	DROP TABLE dbo.ParlaySettlementLock

IF OBJECT_ID('SiteDB_ParlaySettlementProcessing') IS NOT NULL
	DROP TABLE dbo.SiteDB_ParlaySettlementProcessing

IF OBJECT_ID('SiteDB_ParlaySettlementLock') IS NOT NULL
	DROP TABLE dbo.SiteDB_ParlaySettlementLock
