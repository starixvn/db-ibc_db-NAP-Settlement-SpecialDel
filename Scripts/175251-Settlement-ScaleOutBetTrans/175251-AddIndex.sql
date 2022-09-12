/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

USE [bodb02]
GO

CREATE NONCLUSTERED INDEX [IX_SiteDB_SettlementService_CalculationLog_LogDate] ON [dbo].[SiteDB_SettlementService_CalculationLog]
(
	[LogDate] ASC
)ON [INDEX]
GO

CREATE NONCLUSTERED INDEX [IX_SiteDB_SettlementService_LastLog_EndTime] ON [dbo].[SiteDB_SettlementService_LastLog]
(
	[Endtime] ASC
)ON [INDEX]
GO

