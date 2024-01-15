/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.SiteDB_NAP_SettlementService_CalculationLogIns
	@SystemName			VARCHAR(50) = NULL
	,@FunctionName		VARCHAR(50) = NULL
	,@TableName		VARCHAR(128)
	,@Action VARCHAR(1) = 'U'
	,@MatchId INT = 0
	,@TransInfo XML = NULL
	,@TransInfoJson NVARCHAR(MAX) = NULL
	,@SettlementAction VARCHAR(20) = NULL
	,@TicketType VARCHAR(1) = NULL
	,@SessionId BIGINT = 0
	,@IsParallel BIT = 0
	,@BroadcastSessionId	VARCHAR(50)	= NULL
	,@ParlaySettlementProcessingId BIGINT = NULL
AS
/*
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]
		- 20220130@Louisa: Copy code from SiteDB1 to SiteDB3 [Redmineid:#181595]
		- 20231214@Aries: Result Amendment [Redmine: #196401]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	IF @ParlaySettlementProcessingId IS NOT NULL
		SET @TransInfo = (SELECT @ParlaySettlementProcessingId AS '@pid' FOR XML PATH ('r'), ROOT('parlay'))
		
	INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo, TransInfoJson, SettlementAction, TicketType, SessionId, IsParallel,BroadcastSessionId)
	VALUES (@SystemName, @FunctionName, @TableName, @Action, @matchid, @transInfo, COMPRESS(@TransInfoJson), @SettlementAction, @TicketType, @SessionId, @IsParallel,@BroadcastSessionId)	


END
GO
