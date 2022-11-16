/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_PendingLog]
AS
/*
	Created by: 20221101@Louisa: allow run parallell [Redmine#]
	Task: Settlement  
	
	Revisions:
		- 20221101@Louisa: Get Pending Log [Redmine#]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON

		 SELECT l.LogId
				,l.TransInfo
				,l.TransInfoJson
				,l.TableName
				,l.MatchId
				,l.Action
				,l.SettlementAction
				,l.TicketType
				,l.SessionId
				,l.IsParallel
		FROM SiteDB_SettlementService_LastLog ll WITH(NOLOCK)
			INNER JOIN SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
				ON ll.LogId = l.LogId
		WHERE ll.StatusId = 1

END
GO
