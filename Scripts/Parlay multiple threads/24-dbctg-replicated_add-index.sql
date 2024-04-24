/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240422@Louisa
	Task	  : add index
	DB		  : DBCTG-bodb02,SBSETTLE-bodb02
*/

USE [bodb02]
GO

CREATE NONCLUSTERED INDEX [IX_SiteDB_ParlaySettlementProcessing_SiteDB_ParlaySettlementProcessingId] ON [dbo].[SiteDB_ParlaySettlementProcessing]
(
	[SiteDB_ParlaySettlementProcessingId] ASC
)ON [DATA]
GO