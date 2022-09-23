/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SystemSettingsSel
AS
/*
	Created:20210830@Louisa
    Task: Get data from dbo.SystemSettings [Redmineid:#160738]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210830@Louisa: Get data from dbo.SystemSettings [Redmineid:#160738]
		- 20220913@Louisa: Get more info [RedmineId:#177711]

	Param's Explanation: 

*/
BEGIN
	SET NOCOUNT ON

	SELECT	@@SERVERNAME AS ServerName
		, ss.VID
		 , ss.VName
		 , ss.VValue
	FROM dbo.SystemSettings ss WITH(NOLOCK)
	WHERE ss.VName = 'isCalculatingParlay'

END
GO