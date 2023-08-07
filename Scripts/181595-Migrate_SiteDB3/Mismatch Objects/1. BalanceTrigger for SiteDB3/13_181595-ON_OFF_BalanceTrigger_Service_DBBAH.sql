/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: ON/OFF Service status for SiteDB3 [Redmineid:#181595]

*/

--- run on DB05/DB05BK1  

USE bodb02
GO

BEGIN
	SET NOCOUNT ON

	UPDATE dbo.SystemSettings WITH(ROWLOCK, UPDLOCK)
	SET VValue = '1'
	WHERE VName  = ('BT_SiteDB03_ServiceStatus' ) 

END