/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_PendingLog_3rdIns]
	@SiteDBGroupId SMALLINT
	,@SiteDBCalculationLog_3rd TVP_SiteDB_CalculationLog READONLY
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
	
	DECLARE @SiteDBPendingCalculationLog_3rd TVP_SiteDB_CalculationLog

	INSERT INTO @SiteDBPendingCalculationLog_3rd 
	(	LogId
		,TransInfoJson
		,TableName
		,MatchId
		,Action
		,SettlementAction
		,TicketType
	)
	SELECT l.LogId
		,l.TransInfoJson
		,l.TableName
		,l.MatchId
		,l.Action
		,l.SettlementAction
		,l.TicketType
	FROM @SiteDBCalculationLog_3rd l
		LEFT JOIN dbo.SiteDB_SettlementService_CalculationLog_3rd_History h WITH(NOLOCK)
			ON l.LogId = h.LogId
				AND h.SiteDBGroupId = @SiteDBGroupId
	WHERE h.LogId IS NULL

	IF @@ROWCOUNT = 0
		RETURN

	EXEC dbo.NAP_SettlementService_CalculationLog_3rdIns
		@SiteDBGroupId = @SiteDBGroupId
		,@SiteDBCalculationLog_3rd = @SiteDBPendingCalculationLog_3rd
END
GO
