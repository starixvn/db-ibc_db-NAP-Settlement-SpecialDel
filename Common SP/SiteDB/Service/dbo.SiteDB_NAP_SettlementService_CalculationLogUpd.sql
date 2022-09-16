/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLogUpd]
	@LogId BIGINT
	,@StatusId TINYINT
	,@ErrMsg VARCHAR(300) = NULL
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	IF @StatusId = 0 -- start validation
	BEGIN
		INSERT INTO dbo.SiteDB_SettlementService_LastLog(LogId, StatusId, StartTimeValidation) VALUES (@LogId, @StatusId, SYSDATETIME())
	END
	ELSE IF @StatusId = 1 -- start upd process
	BEGIN
		UPDATE dbo.SiteDB_SettlementService_LastLog WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
				,Starttime = SYSDATETIME()
		WHERE LogId = @LogId
	END
	ELSE IF @StatusId IN (2,3) -- done process
	BEGIN
		UPDATE dbo.SiteDB_SettlementService_LastLog WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
				,Endtime = SYSDATETIME()
				,ErrMsg = ISNULL(@ErrMsg,ErrMsg)
		WHERE LogId = @LogId
	END
				
END