/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SystemSettingsUpd
AS
/*
	Created:20210830@Louisa
    Task: Update dbo.SystemSettings [Redmineid:#160738]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210830@Louisa: Update dbo.SystemSettings [Redmineid:#160738]

	Param's Explanation: 



*/
BEGIN
	SET NOCOUNT ON

	UPDATE dbo.SystemSettings WITH(ROWLOCK, UPDLOCK)	
	SET VValue = '0'
	WHERE VName = 'isCalculatingParlay'
	AND VValue = '1'

END
GO