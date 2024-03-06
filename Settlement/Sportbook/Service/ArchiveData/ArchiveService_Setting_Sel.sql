/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE ArchiveService_Setting_Sel   
AS  
/*
	Created by: 20240222@Louisa
	Task: Archive data for ProviderExternalResultDetailXX [Redmine:#201196]
	DB: DBACC/bodb_archive

	Revision:
		20240222@Louisa: Get Setting [Redmine:#201196]

*/  
BEGIN  
	SET NOCOUNT ON
	
	SELECT s.ArchiveName,ArchiveValue
	FROM Settlement_ArchiveSetting s WITH(NOLOCK)

END
GO