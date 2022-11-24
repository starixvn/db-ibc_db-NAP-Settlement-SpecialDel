/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_PendingLog_3rd]
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

		 SELECT l.LogId
				,l.TransInfoJson
				,l.TableName
				,l.MatchId
				,l.Action
				,l.SettlementAction
				,l.TicketType
		FROM SiteDB_SettlementService_LastLog_3rd ll WITH(NOLOCK)
			INNER JOIN SiteDB_SettlementService_CalculationLog_3rd l WITH(NOLOCK)
				ON ll.LogId = l.LogId
		WHERE ll.StatusId = 1

END
GO
