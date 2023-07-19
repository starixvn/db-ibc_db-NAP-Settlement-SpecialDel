/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: Drop SPs not in-use [Redmineid:#181595]					
	
*/

---RUN ON SITEDB3 ONLY

USE bodb02
GO

DROP PROCEDURE DEL_NAP_Set_SiteDB_SettlementLockDel 
GO
DROP PROCEDURE DEL_NAP_Set_SiteDB_SettlementLockSel 
GO
DROP PROCEDURE DEL_NAP_Set_SiteDB_SettlementProcessingDel 
GO
DROP PROCEDURE DEL_NAP_Set_SiteDB_SettlementProcessingDetailSel 
GO
DROP PROCEDURE DEL_NAP_Set_SiteDB_SettlementProcessingSel 
GO
DROP PROCEDURE DEL_NAP_Set_SiteDB_SSBErrSel 
GO
DROP PROCEDURE DEL_NAP_SettlementService_Calculation 
GO
DROP PROCEDURE DEL_NAP_SettlementService_CalculationLog_3rdIns 
GO
DROP PROCEDURE DEL_NAP_SettlementService_CalculationLogIns 
GO
DROP PROCEDURE DEL_NAP_SettlementService_PendingLog_3rdIns 
GO
DROP PROCEDURE DEL_NAP_SettlementService_PendingLogIns 
GO
DROP PROCEDURE DEL_NAP_SettlementService_Validation 
GO
DROP PROCEDURE DEL_NAP_SyncService_NotExecRep 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB_Execute_Message 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB_Execute_Message_3rd 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB_UpdateData 
GO
DROP PROCEDURE SSB_Settlement_SiteDB1_Process_Message 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB1_Process_Message_01 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB1_Process_Message_02 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB1_Process_Message_03 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB1_Process_Message_04 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB1_Process_Message_3rd 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB1_Process_Message_parlay 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB2_Process_Message 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB2_Process_Message_01 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB2_Process_Message_02 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB2_Process_Message_03 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB2_Process_Message_04 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB2_Process_Message_3rd 
GO
DROP PROCEDURE DEL_SSB_Settlement_SiteDB2_Process_Message_parlay 
GO

 
 
	

