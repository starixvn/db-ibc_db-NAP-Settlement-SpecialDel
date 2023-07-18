/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Init configuration for SiteDB3 [Redmineid:#181595]

*/

--- run on DB05/DB05BK1  

USE bodb02
GO

---- insert flag to on/off service
BEGIN
	SET NOCOUNT ON
	
	INSERT INTO bodb02.dbo.SystemSettings ( VName, VValue )
	VALUES   ('BT_SiteDB03_InsStatus' 		,'2' )	
			,('BT_SiteDB03_ServiceStatus' 	,'0' ) ---not allow service pro running
			,('BT_SiteDB03_Sync' 	 		,'0' ) ---last row is 0 for the first time synchronize
		
			,('BT_SiteDB03_InsStatus_UAT' 		,'2' )
			,('BT_SiteDB03_ServiceStatus_UAT'	,'0' ) ---not allow service uat running
			,('BT_SiteDB03_Sync_UAT'			,'0' ) 
	

END
GO