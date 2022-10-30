/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLogIns] 	
	@SystemName			VARCHAR(50) = NULL
	,@FunctionName		VARCHAR(50) = NULL
	,@TableName		VARCHAR(128)
	,@Action VARCHAR(1) = 'U'
	,@MatchId INT = 0
	,@TransInfo XML = NULL
	,@TransInfoJson VARCHAR(MAX) = NULL
	,@SettlementAction VARCHAR(20) = NULL
	,@TicketType VARCHAR(1) = NULL
	,@SessionId BIGINT = 0
	,@IsParallel BIT = 0
AS
/*
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo, TransInfoJson, SettlementAction, TicketType, SessionId, IsParallel)
	VALUES (@SystemName, @FunctionName, @TableName, @Action, @matchid, @transInfo, @TransInfoJson, @SettlementAction, 's', @SessionId, @IsParallel)	

END
GO