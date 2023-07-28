/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO
SP_RENAME 'NAP_Admin_Calculate_Undo_s213', 'del_NAP_Admin_Calculate_Undo_s213'
GO
SP_RENAME 'NAP_Admin_Calculate_Refund_s213', 'del_NAP_Admin_Calculate_Refund_s213'
GO
SP_RENAME 'NAP_Admin_Calculate_s213', 'del_NAP_Admin_Calculate_s213'
GO
SP_RENAME 'NAP_Admin_SendNotificationEmail_s213', 'del_NAP_Admin_SendNotificationEmail_s213'
GO
SP_RENAME 'NAP_Admin_Settlement_Refund_s213', 'del_NAP_Admin_Settlement_Refund_s213'
GO
SP_RENAME 'NAP_Admin_Settlement_s213', 'del_NAP_Admin_Settlement_s213'
GO
SP_RENAME 'NAP_Admin_Settlement_s213_Job', 'del_NAP_Admin_Settlement_s213_Job'
GO
SP_RENAME 'NAP_Admin_VoidBettrans_s213', 'del_NAP_Admin_VoidBettrans_s213'
GO
SP_RENAME 'NAP_Admin_DeleteBettrans_Staging_s213_Job', 'del_NAP_Admin_DeleteBettrans_Staging_s213_Job'
GO
SP_RENAME 'Nap_Admin_Settlement_Undo_s213', 'del_Nap_Admin_Settlement_Undo_s213'
GO

SP_RENAME 'Task_Archive_SelectNG2_Message', 'del_Task_Archive_SelectNG2_Message'
GO
SP_RENAME 'Task_Archive_bettrans_Staging', 'del_Task_Archive_bettrans_Staging'
GO
SP_RENAME 'SSIS_SettlementNG2_Message_Export', 'del_SSIS_SettlementNG2_Message_Export'
GO
SP_RENAME 'SSIS_bettrans_Staging_Export', 'del_SSIS_bettrans_Staging_Export'
GO
