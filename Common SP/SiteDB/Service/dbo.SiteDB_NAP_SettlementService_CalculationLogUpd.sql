/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLogUpd]
	@LogId BIGINT
	,@StatusId TINYINT
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
	
	IF @StatusId = 1 -- running
	BEGIN
		INSERT INTO dbo.SiteDB_SettlementService_LastLog(LogId, StatusId, Starttime) VALUES (@LogId, @StatusId, SYSDATETIME())
	END
	ELSE	
	BEGIN
		UPDATE dbo.SiteDB_SettlementService_LastLog WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
				,Endtime = SYSDATETIME()
		WHERE LogId = @LogId
	END
				
END