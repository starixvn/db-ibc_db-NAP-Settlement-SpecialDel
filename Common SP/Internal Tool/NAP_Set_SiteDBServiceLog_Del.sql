/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLog_Del
	@LogId	BIGINT
	,@Action VARCHAR(10)
AS
/*
	Created:20220913@Louisa
    Task: Tool support delete locking [RedmineId:#177711]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20220913@Louisa: Delete/Update log in waiting/running/fail from SiteDB_SettlementService_LastLog [RedmineId:#177711]

	Param's Explanation:
		@Action:
			Delete: delete to let service re-run that @LogId again
			Update: update status is successfull to skip that @LogId
*/
BEGIN
	SET NOCOUNT ON
		
		IF @Action = 'Delete'
		BEGIN
			DELETE FROM dbo.SiteDB_SettlementService_LastLog
			WHERE LogId = @LogId
		END

		IF @Action = 'Update'
		BEGIN
			UPDATE dbo.SiteDB_SettlementService_LastLog WITH(ROWLOCK,UPDLOCK)
			SET StatusId = 2
			WHERE LogId = @LogId
		END

END
GO