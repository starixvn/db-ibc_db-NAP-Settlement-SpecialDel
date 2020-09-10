/*<info serverAlias="DBLOG-bodb_Customerlog" executers="" viewers="" isFunction="0"></info>*/
/* 
	 Creator: Kathy  
	 Date: 20200903  
	 Task: move table from DBTXN to DBLOG [Redmine:#138281]  
	 DB: DBLOG/bodb_CustomerLog  
	   

*/ 
USE bodb_CustomerLog
GO

/* move these tables from DBTXN to DBLOG (filegroup MATCH)
1. Single_Calculate_Queue_bk
2. Parlay_Calculate_Queue_bk
3. SettlementPerformanceLog
*/

-- Create index

CREATE CLUSTERED INDEX [CIX_Single_Calculate_Queue_bk_MatchId] ON [dbo].[Single_Calculate_Queue_bk]
(
	[matchid] ASC
)ON [MATCH]
GO
CREATE NONCLUSTERED INDEX [IX_Single_Calculate_Queue_bk_Starttime] ON [dbo].[Single_Calculate_Queue_bk]
(
	[Starttime] ASC
)ON [MATCH]
GO

CREATE CLUSTERED INDEX [CIX_Parlay_Calculate_Queue_bk_MatchId] ON [dbo].[Parlay_Calculate_Queue_bk]
(
	[matchid] ASC
)ON [MATCH]
GO
CREATE NONCLUSTERED INDEX [IX_Parlay_Calculate_Queue_bk_Starttime] ON [dbo].[Parlay_Calculate_Queue_bk]
(
	[Starttime] ASC
)ON [MATCH]
GO

CREATE CLUSTERED INDEX [CIX_SettlementPerformanceLog_CreatedDate] ON [dbo].[SettlementPerformanceLog]
(
	[CreatedDate] ASC
)ON [MATCH]
GO
