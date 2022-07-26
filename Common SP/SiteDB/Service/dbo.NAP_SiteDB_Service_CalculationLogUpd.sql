/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SiteDB_Service_CalculationLogUpd]
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
		UPDATE dbo.Service_SiteDB_LastLog WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
	ELSE	
		UPDATE dbo.Service_SiteDB_LastLog WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
				,LastLogId = @LogId
				,LastStatusId = @StatusId
END