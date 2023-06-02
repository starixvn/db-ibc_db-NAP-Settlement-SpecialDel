/*<info serverAlias="DBSIC-bodb02"></info>*/
--dbtrans
USE bodb02
go

sp_rename 'BalanceCredit','del_BalanceCredit'
sp_rename 'BalanceDebit','del_BalanceDebit'
sp_rename 'BalanceNegative','del_BalanceNegative'
sp_rename 'BalanceNegativeHistory','del_BalanceNegativeHistory'
sp_rename 'BalancePendingCredit','del_BalancePendingCredit'
sp_rename 'BalancePendingDebit','del_BalancePendingDebit'
sp_rename 'BetLucky3Result','del_BetLucky3Result'
sp_rename 'BetParlayResultSummary','del_BetParlayResultSummary'
sp_rename 'BettradeAPI','del_BettradeAPI'
sp_rename 'BetTradeSelling','del_BetTradeSelling'
sp_rename 'BetTradeSellingCancelled','del_BetTradeSellingCancelled'
sp_rename 'BonusAdjustmentTransfer','del_BonusAdjustmentTransfer'
sp_rename 'BonusWalletCredit','del_BonusWalletCredit'
sp_rename 'BonusWalletDebit','del_BonusWalletDebit'
sp_rename 'BonusWalletPending','del_BonusWalletPending'
sp_rename 'Lucky3PrizeSettingDetail','del_Lucky3PrizeSettingDetail'
sp_rename 'Lucky3RefCombination','del_Lucky3RefCombination'
sp_rename 'Lucky3RefCombinationSet','del_Lucky3RefCombinationSet'
sp_rename 'SettlementPerformanceLog','del_SettlementPerformanceLog'
sp_rename 'TicketVoiding_VoidedTransaction','del_TicketVoiding_VoidedTransaction'