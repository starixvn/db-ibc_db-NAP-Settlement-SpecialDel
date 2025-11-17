/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/    
/*	
	Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02 - ONLY SIT
	
	Revisions: 
		- 20251027@Max: Modify default constraint for only SIT [Redmine: #241652]
*/

USE [bodb02]
GO

ALTER TABLE [dbo].[BetBuilderLegOddsHistory] DROP CONSTRAINT [DF_BetBuilderLegOddsHistory_CreatedDate]
GO

ALTER TABLE [dbo].[BetBuilderLegOddsHistory] ADD CONSTRAINT [DF_BetBuilderLegOddsHistory_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
ALTER TABLE [dbo].[BetBuilderLegOddsHistory] ALTER COLUMN [Odds] [SMALLMONEY] NOT NULL
GO

--For DBCTG ONLY
IF OBJECT_ID ('BetBuilderHybridParlayLog', 'U') IS NOT NULL
BEGIN
	ALTER TABLE [dbo].[BetBuilderHybridParlayLog] ALTER COLUMN [Odds] [SMALLMONEY] NOT NULL
END









