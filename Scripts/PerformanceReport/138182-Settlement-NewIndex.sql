/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20190506@Kathy
	Task : Create index [Redmine:#138182]
	DB: DBTXN/bodb02
	
*/

USE [bodb02]
GO

CREATE NONCLUSTERED INDEX [IX_Parlay_Calculate_Queue_bk_Starttime] ON [dbo].[Parlay_Calculate_Queue_bk]
(
	[Starttime] ASC
) ON [Event_table]
GO


CREATE NONCLUSTERED INDEX [IX_Single_Calculate_Queue_bk_Starttime] ON [dbo].[Single_Calculate_Queue_bk]
(
	[Starttime] ASC
) ON [Event_table]
GO

CREATE CLUSTERED INDEX [CIX_SettlementPerformanceLog_CreatedDate] ON [dbo].[SettlementPerformanceLog]
(
	[CreatedDate] ASC
)ON [DATA]
GO

