/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLog_3rdIns] 	
	@SystemName			VARCHAR(50) = NULL
	,@FunctionName		VARCHAR(50) = NULL
	,@TableName		VARCHAR(128)
	,@Action VARCHAR(1) = 'U'
	,@MatchId INT = 0
	,@TransInfoJson NVARCHAR(MAX) = NULL
	,@SettlementAction VARCHAR(20) = NULL
	,@TicketType VARCHAR(1) = NULL
	,@EventTable TINYINT = 1
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
	
	INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, SettlementAction, TicketType, EventTable)
	VALUES (@SystemName, @FunctionName, @TableName, @Action, @matchid, COMPRESS(@TransInfoJson), @SettlementAction, @TicketType, @EventTable)	

END
GO