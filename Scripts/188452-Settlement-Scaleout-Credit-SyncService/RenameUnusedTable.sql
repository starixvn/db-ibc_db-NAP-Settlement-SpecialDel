/*<info serverAlias="DBSIC-bodb02"></info>*/
--dbtrans
USE bodb02
go

sp_rename 'BalanceCredit','del_BalanceCredit'
GO
sp_rename 'BalanceDebit','del_BalanceDebit'
GO
sp_rename 'BalanceNegative','del_BalanceNegative'
GO
sp_rename 'BalanceNegativeHistory','del_BalanceNegativeHistory'
GO
sp_rename 'BalancePendingCredit','del_BalancePendingCredit'
GO
sp_rename 'BalancePendingDebit','del_BalancePendingDebit'
GO
sp_rename 'BetLucky3Result','del_BetLucky3Result'
GO
sp_rename 'BetParlayResultSummary','del_BetParlayResultSummary'
GO
sp_rename 'BettradeAPI','del_BettradeAPI'
GO
sp_rename 'BetTradeSelling','del_BetTradeSelling'
GO
sp_rename 'BetTradeSellingCancelled','del_BetTradeSellingCancelled'
GO

sp_rename 'Lucky3PrizeSettingDetail','del_Lucky3PrizeSettingDetail'
GO
sp_rename 'Lucky3RefCombination','del_Lucky3RefCombination'
GO
sp_rename 'Lucky3RefCombinationSet','del_Lucky3RefCombinationSet'
GO
sp_rename 'SettlementPerformanceLog','del_SettlementPerformanceLog'
GO
sp_rename 'TicketVoiding_VoidedTransaction','del_TicketVoiding_VoidedTransaction'