/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: mark table, type table no tin use not in-use are deleted [Redmineid:#181595]					
	
*/

---RUN ON SITEDB3 ONLY

USE bodb02
GO

--- tables
EXEC sp_rename 'bettrans_oldTransid'			,'DEL_bettrans_oldTransid'
GO
EXEC sp_rename 'bettransG_oldTransid'			,'DEL_bettransG_oldTransid'
GO
EXEC sp_rename 'bettransLC_oldTransid'			,'DEL_bettransLC_oldTransid'
GO
EXEC sp_rename 'bettransRnG_oldTransid'			,'DEL_bettransRnG_oldTransid'
GO
EXEC sp_rename 'SiteDB_SettlementLock'			,'DEL_SiteDB_SettlementLock'
GO
EXEC sp_rename 'SiteDB_SettlementProcessing'	,'DEL_SiteDB_SettlementProcessing'
GO
EXEC sp_rename 'SiteDB_SettlementService_CalculationLog_3rd_History'	,'DEL_SiteDB_SettlementService_CalculationLog_3rd_History'
GO
EXEC sp_rename 'SiteDB_SettlementService_CalculationLog_History'		,'DEL_SiteDB_SettlementService_CalculationLog_History'
GO
EXEC sp_rename 'Transfer_oldTransid'			,'DEL_Transfer_oldTransid'
GO
EXEC sp_rename 'translog_oldTransid'			,'DEL_translog_oldTransid'
GO

--- Type table
EXEC sp_rename 'TVP_SiteDB_CalculationLog'		,'DEL_TVP_SiteDB_CalculationLog'
GO
EXEC sp_rename 'TVP_SiteDB_CalculationLog_3rd'	,'DEL_TVP_SiteDB_CalculationLog_3rd'
GO



