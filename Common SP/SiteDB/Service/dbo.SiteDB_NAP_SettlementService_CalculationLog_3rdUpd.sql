/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLog_3rdUpd]
	@LogId BIGINT
	,@StatusId TINYINT
	,@ErrMsg VARCHAR(300) = NULL
AS
/*
	Created by: 20221011@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	IF @StatusId = 0 -- start validation
	BEGIN
		INSERT INTO dbo.SiteDB_SettlementService_LastLog_3rd(LogId, StatusId, StartTimeValidation) VALUES (@LogId, @StatusId, SYSDATETIME())
	END
	ELSE IF @StatusId = 1 -- start upd process
	BEGIN
		UPDATE dbo.SiteDB_SettlementService_LastLog_3rd WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
				,Starttime = SYSDATETIME()
		WHERE LogId = @LogId
	END
	ELSE IF @StatusId IN (2,3) -- done process
	BEGIN
		UPDATE dbo.SiteDB_SettlementService_LastLog_3rd WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
				,Endtime = SYSDATETIME()
				,ErrMsg = CASE WHEN ISNULL(@ErrMsg,'') = '' THEN ErrMsg ELSE @ErrMsg END
		WHERE LogId = @LogId
	END
				
END