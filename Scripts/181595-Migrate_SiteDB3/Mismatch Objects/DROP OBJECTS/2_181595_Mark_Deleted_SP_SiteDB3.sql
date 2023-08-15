/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: mark SP not in-use is deleted [Redmineid:#181595]					
	
*/

---RUN ON SITEDB3 ONLY

USE bodb02
GO

EXEC sp_rename 'NAP_Set_SiteDB_SettlementLockDel'				,'DEL_NAP_Set_SiteDB_SettlementLockDel'
GO
EXEC sp_rename 'NAP_Set_SiteDB_SettlementLockSel'				,'DEL_NAP_Set_SiteDB_SettlementLockSel'
GO
EXEC sp_rename 'NAP_Set_SiteDB_SettlementProcessingDel'			,'DEL_NAP_Set_SiteDB_SettlementProcessingDel'
GO
EXEC sp_rename 'NAP_Set_SiteDB_SettlementProcessingDetailSel'	,'DEL_NAP_Set_SiteDB_SettlementProcessingDetailSel'
GO
EXEC sp_rename 'NAP_Set_SiteDB_SettlementProcessingSel'			,'DEL_NAP_Set_SiteDB_SettlementProcessingSel'
GO
EXEC sp_rename 'NAP_Set_SiteDB_SSBErrSel'						,'DEL_NAP_Set_SiteDB_SSBErrSel'
GO
EXEC sp_rename 'NAP_SettlementService_Calculation'				,'DEL_NAP_SettlementService_Calculation'
GO
EXEC sp_rename 'NAP_SettlementService_CalculationLog_3rdIns'	,'DEL_NAP_SettlementService_CalculationLog_3rdIns'
GO
EXEC sp_rename 'NAP_SettlementService_CalculationLogIns'		,'DEL_NAP_SettlementService_CalculationLogIns'
GO
EXEC sp_rename 'NAP_SettlementService_PendingLog_3rdIns'		,'DEL_NAP_SettlementService_PendingLog_3rdIns'
GO
EXEC sp_rename 'NAP_SettlementService_PendingLogIns'			,'DEL_NAP_SettlementService_PendingLogIns'
GO
EXEC sp_rename 'NAP_SettlementService_Validation'				,'DEL_NAP_SettlementService_Validation'
GO
EXEC sp_rename 'NAP_SyncService_NotExecRep'						,'DEL_NAP_SyncService_NotExecRep'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB_Execute_Message'			,'DEL_SSB_Settlement_SiteDB_Execute_Message'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB_Execute_Message_3rd'		,'DEL_SSB_Settlement_SiteDB_Execute_Message_3rd'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB_UpdateData'				,'DEL_SSB_Settlement_SiteDB_UpdateData'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB1_Process_Message'			,'SSB_Settlement_SiteDB1_Process_Message'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB1_Process_Message_01'		,'DEL_SSB_Settlement_SiteDB1_Process_Message_01'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB1_Process_Message_02'		,'DEL_SSB_Settlement_SiteDB1_Process_Message_02'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB1_Process_Message_03'		,'DEL_SSB_Settlement_SiteDB1_Process_Message_03'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB1_Process_Message_04'		,'DEL_SSB_Settlement_SiteDB1_Process_Message_04'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB1_Process_Message_3rd'		,'DEL_SSB_Settlement_SiteDB1_Process_Message_3rd'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB1_Process_Message_parlay'	,'DEL_SSB_Settlement_SiteDB1_Process_Message_parlay'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB2_Process_Message'			,'DEL_SSB_Settlement_SiteDB2_Process_Message'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB2_Process_Message_01'		,'DEL_SSB_Settlement_SiteDB2_Process_Message_01'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB2_Process_Message_02'		,'DEL_SSB_Settlement_SiteDB2_Process_Message_02'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB2_Process_Message_03'		,'DEL_SSB_Settlement_SiteDB2_Process_Message_03'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB2_Process_Message_04'		,'DEL_SSB_Settlement_SiteDB2_Process_Message_04'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB2_Process_Message_3rd'		,'DEL_SSB_Settlement_SiteDB2_Process_Message_3rd'
GO
EXEC sp_rename 'SSB_Settlement_SiteDB2_Process_Message_parlay'	,'DEL_SSB_Settlement_SiteDB2_Process_Message_parlay'
GO

