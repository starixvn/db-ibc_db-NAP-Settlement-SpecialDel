/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLog_Sel
AS
/*
	Created:20220913@Louisa
    Task: Tool support delete locking [RedmineId:#177711]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20220913@Louisa: Get log in waiting/running/fail from SiteDB_SettlementService_LastLog [RedmineId:#177711]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @CurrentTime DATETIME = GETDATE()

	SELECT @@SERVERNAME AS ServerName
		, ll.LogId
		, ll.StatusId
		, ll.Starttime
		, ll.Endtime
		, ll.StartTimeValidation
		, l.SystemName
		, l.FunctionName
		, l.TableName
		, l.Action
		, l.MatchId
		, l.TransInfo
		, l.LogDate
		, l.SettlementAction
		, l.TicketType
	FROM dbo.SiteDB_SettlementService_LastLog ll WITH(NOLOCK)
		INNER JOIN dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
			ON ll.LogId = l.LogId
	WHERE ll.StatusId IN ( 0,1,3)
		AND 1 = CASE WHEN ll.StatusId = 0 AND DATEDIFF( MINUTE, ll.StartTimeValidation, @CurrentTime) >= 5 THEN 1
					 WHEN ll.StatusId = 1 AND DATEDIFF( MINUTE, ll.StartTimeValidation, @CurrentTime) >=2 THEN 1
					 WHEN ll.StatusId = 3  THEN 1
					 ELSE 0
				END
END
GO