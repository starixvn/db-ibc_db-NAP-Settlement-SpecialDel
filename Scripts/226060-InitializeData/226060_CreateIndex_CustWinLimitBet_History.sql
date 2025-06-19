/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250527@Helen
	Task: Create index in table CustWinLimitBet_History [Redmine: #226060]
	DB:DBSIC-bodb02
*/
USE bodb02
GO
CREATE NONCLUSTERED INDEX [IX_CustWinLimitBet_History_CustID_Transid_ActionType] ON [dbo].[CustWinLimitBet_History]
(
	[CustID] ASC,
	[Transid] ASC,
	[ActionType]
)
INCLUDE (Sporttype, Bettype)
WITH (ONLINE = ON) ON [winlimit_table]
GO
DROP INDEX CustWinLimitBet_History.IDX_CustWinLimitBet_History_CustID_TransId_Sporttype_Bettype;
GO
CREATE NONCLUSTERED INDEX [IX_CustWinLimitBet_History_TransID] ON [dbo].[CustWinLimitBet_History]
(
	[Transid] ASC
)
WITH (ONLINE = ON) ON [winlimit_table]
GO