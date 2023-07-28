/*<info serverAlias="DBSIC-bodb02"></info>*/
--sitedb3
USE bodb02
go
sp_rename 'Acc_BalanceNegativeSel_BySite','del_Acc_BalanceNegativeSel_BySite' 
GO
sp_rename 'Acc_BalanceNegativeUpd_StatusID','del_Acc_BalanceNegativeUpd_StatusID' 
GO
sp_rename 'DBA_SettleOutright_Undo_Trans','del_DBA_SettleOutright_Undo_Trans'
GO
sp_rename 'Dot_BalanceDelCredit','del_Dot_BalanceDelCredit' 
GO
sp_rename 'Dot_BalanceDelDebit','del_Dot_BalanceDelDebit' 
GO
sp_rename 'Dot_BalanceInsCredit','del_Dot_BalanceInsCredit'
GO
sp_rename 'Dot_BalanceInsDebit','del_Dot_BalanceInsDebit' 
GO
sp_rename 'Dot_BalanceUpdCredit','del_Dot_BalanceUpdCredit' 
GO
sp_rename 'Dot_BalanceUpdDebit','del_Dot_BalanceUpdDebit' 
GO
sp_rename 'NAP_Admin_Calculate_29','del_NAP_Admin_Calculate_29' 
GO
sp_rename 'NAP_Admin_Calculate_29_Summary','del_NAP_Admin_Calculate_29_Summary' 
GO
sp_rename 'NAP_Admin_Calculate_9_Cal','del_NAP_Admin_Calculate_9_Cal' 
GO
sp_rename 'NAP_Admin_Calculate_901','del_NAP_Admin_Calculate_901' 
GO
sp_rename 'NAP_Admin_Calculate_911','del_NAP_Admin_Calculate_911' 
GO
sp_rename 'NAP_Admin_Calculate_Refund_901','del_NAP_Admin_Calculate_Refund_901'
GO
sp_rename 'NAP_Admin_PreCalculate_s160','del_NAP_Admin_PreCalculate_s160' 
GO
sp_rename 'NAP_Admin_Settlement_135','del_NAP_Admin_Settlement_135'
GO
sp_rename 'NAP_Admin_Settlement_MetricGaming','del_NAP_Admin_Settlement_MetricGaming'
GO
sp_rename 'NAP_Admin_Settlement_Refund_FGLG','del_NAP_Admin_Settlement_Refund_FGLG'
GO
sp_rename 'NAP_Admin_Settlement_s160','del_NAP_Admin_Settlement_s160' 
GO
sp_rename 'NAP_Admin_Settlement_s162','del_NAP_Admin_Settlement_s162'
GO
sp_rename 'Nap_Set_MatchBetbuilderStatusSel','del_Nap_Set_MatchBetbuilderStatusSel'
GO
sp_rename 'NAP_Set_MatchSel_by_Vendor','del_NAP_Set_MatchSel_by_Vendor' 
GO
sp_rename 'NAP_Set_PerformanceReport','del_NAP_Set_PerformanceReport' 
GO
sp_rename 'NAP_Task_Calculate_Parlay','del_NAP_Task_Calculate_Parlay' 
GO
sp_rename 'Task_BalanceNegative','del_Task_BalanceNegative'
GO
sp_rename 'Task_BalanceUpdBonusCredit','del_Task_BalanceUpdBonusCredit'
GO
sp_rename 'Task_BalanceUpdCredit','del_Task_BalanceUpdCredit'
GO
sp_rename 'Task_BalanceUpdDebit','del_Task_BalanceUpdDebit'
GO
sp_rename 'Task_Calculate_Parlay','del_Task_Calculate_Parlay'
GO
sp_rename 'Admin_Settlement_VS_181','del_Admin_Settlement_VS_181' 
GO
sp_rename 'DBA_BettransDelBet_Parlay','del_DBA_BettransDelBet_Parlay' 
GO
sp_rename 'DBA_NAP_BettransRecoverBet_Parlay','del_DBA_NAP_BettransRecoverBet_Parlay'
GO
sp_rename 'NAP_Admin_Calculate_9_Cal','del_NAP_Admin_Calculate_9_Cal'
GO
sp_rename 'NAP_Admin_Calculate_Parlay', 'del_NAP_Admin_Calculate_Parlay'
GO
sp_rename 'NAP_Admin_Settlement_2b', 'del_NAP_Admin_Settlement_2b'
GO
sp_rename 'NAP_Admin_Settlement_Corner','del_NAP_Admin_Settlement_Corner'
GO
sp_rename 'NAP_Admin_Settlement_FGLG','del_NAP_Admin_Settlement_FGLG' 
GO
sp_rename 'NAP_Admin_Settlement_MetricGaming', 'del_NAP_Admin_Settlement_MetricGaming'
GO
sp_rename 'NAP_Admin_Settlement_MP','del_NAP_Admin_Settlement_MP' 
GO
sp_rename 'NAP_Admin_Settlement_MP_Push','del_NAP_Admin_Settlement_MP_Push' 
GO
sp_rename 'NAP_Admin_Settlement_Refund_FGLG', 'del_NAP_Admin_Settlement_Refund_FGLG' 
GO
sp_rename 'NAP_Admin_Settlement_Refund_MP','del_NAP_Admin_Settlement_Refund_MP' 
GO
sp_rename 'NAP_Admin_Settlement_Refund_MP_Push', 'del_NAP_Admin_Settlement_Refund_MP_Push'
GO
sp_rename 'NAP_Admin_Settlement_s160', 'del_NAP_Admin_Settlement_s160' 
GO
sp_rename 'NAP_Admin_Settlement_s162', 'del_NAP_Admin_Settlement_s162' 
GO

sp_rename 'Acc_Apl_ExecRep_00', 'del_Acc_Apl_ExecRep_00' 
GO
sp_rename 'Acc_Apl_ExecRep_01', 'del_Acc_Apl_ExecRep_01' 
GO
sp_rename 'Acc_Set_ConfirmedAction', 'del_Acc_Set_ConfirmedAction' 
GO
sp_rename 'Acc_Set_ConfirmedActionOutright', 'del_Acc_Set_ConfirmedActionOutright' 
GO
sp_rename 'Acc_Set_ConfirmedActionParlay', 'del_Acc_Set_ConfirmedActionParlay' 
GO
sp_rename 'Acc_Apl_ExecRep_02', 'del_Acc_Apl_ExecRep_02' 
GO
sp_rename 'Acc_Apl_ExecRep_00', 'del_Acc_Apl_ExecRep_00' 
GO
sp_rename 'Acc_Apl_ExecRep_01', 'del_Acc_Apl_ExecRep_01' 
GO
sp_rename 'Acc_Set_ConfirmedAction', 'del_Acc_Set_ConfirmedAction' 
GO
sp_rename 'Acc_Apl_ExecRep_00', 'del_Acc_Apl_ExecRep_00' 
GO
sp_rename 'Acc_Set_ConfirmedActionOutright', 'del_Acc_Set_ConfirmedActionOutright' 
GO
sp_rename 'Acc_Set_ConfirmedActionParlay', 'del_Acc_Set_ConfirmedActionParlay' 
GO
sp_rename 'NAP_Admin_Settlement_Parlay_Job', 'del_NAP_Admin_Settlement_Parlay_Job' 
GO
sp_rename 'NAP_Admin_Settlement_Refund_FGLG_Push', 'del_NAP_Admin_Settlement_Refund_FGLG_Push' 
GO