/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
 
/* 
	 Creator:20240222@Louisa  
	 Task: Archive data for ProviderExternalResultDetailXX [Redmine:#201196] 
	     
	 Revisions:  
		- 20240222@Louisa: Initial [Redmine:#201196]
    
*/  

--SITDB055

USE bodb_CustomerLog_Archive
GO

TRUNCATE TABLE ProviderExternalResultDetail_BK
GO
TRUNCATE TABLE ProviderExternalResultDetailES_BK
GO
TRUNCATE TABLE ProviderExternalResultDetailOS_BK
GO


--update all
UPDATE Settlement_ArchiveSetting WITH(ROWLOCK,UPDLOCK)
SET ArchiveValue =  '0'


