/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLogSel]
	
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
	
	DECLARE @LastLogId BIGINT
			,@LastStatusId TINYINT			
			,@LogId BIGINT
			,@TransInfo XML
			,@TableName VARCHAR(128)
			,@MatchId INT
			,@RowCount INT
			,@Action VARCHAR(1)
			,@SettlementAction VARCHAR(20)
			,@TicketType VARCHAR(1)

	SELECT TOP (1) @LastLogId = LogId 
			,@LastStatusId = StatusId		
	FROM	dbo.SiteDB_SettlementService_LastLog WITH(NOLOCK)
	ORDER BY LogId DESC
	
	IF @LastStatusId = 2 
	BEGIN
		SELECT	TOP 1 @LogId = LogId
				,@TransInfo = TransInfo
				,@TableName = TableName
				,@MatchId = MatchId
				,@Action = Action
				,@SettlementAction = SettlementAction
				,@TicketType = TicketType
		FROM	dbo.SiteDB_SettlementService_CalculationLog WITH(NOLOCK)
		WHERE	LogId > @LastLogId
		ORDER BY LogId
		
		SET @RowCount = @@ROWCOUNT
	END

	SELECT	@LogId AS LogId
			,@TransInfo AS TransInfo
			,@TableName AS TableName
			,@MatchId AS MatchId
			,@Action AS Action
			,@SettlementAction AS SettlementAction
			,@TicketType AS TicketType
	WHERE @RowCount = 1
END
GO