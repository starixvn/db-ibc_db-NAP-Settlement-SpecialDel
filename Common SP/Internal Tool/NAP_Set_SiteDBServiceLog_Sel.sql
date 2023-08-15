/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLog_Sel
	@SessionId	BIGINT
AS
/*
	Created:20220913@Louisa
    Task: Tool support delete locking [RedmineId:#177711]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20220913@Louisa: Get log in waiting/running/fail from SiteDB_SettlementService_LastLog [RedmineId:#177711]
		- 20221122@Louisa: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]
		- 20230208@Louisa: support queue 3rd [RedmineId:#179505]
		- 20220130@Louisa: Copy code from SiteDB1 to SiteDB3 [Redmineid:#181595]
	
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT l.FunctionName	 
		, l.TableName
		, l.SettlementAction  
		, l.TicketType
	FROM dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
	WHERE  l.SessionId =  @SessionId
		AND l.tickettype is not null ---not get command lock match

END
GO
