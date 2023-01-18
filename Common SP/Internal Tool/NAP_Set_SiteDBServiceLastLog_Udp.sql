/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLastLog_Udp
	@LogIds	VARCHAR(500)
AS
/*
	Created:20221122@Louisa
    Task: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20221122@Louisa: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	;WITH cte_LogId (LogId )
	AS 
	(
		SELECT DISTINCT Value from string_split(@LogIds, ',')
	)

	UPDATE ll
	SET StatusId = 2
	FROM dbo.SiteDB_SettlementService_LastLog ll WITH(ROWLOCK,UPDLOCK)
	INNER JOIN cte_LogId tmp
		ON ll.LogId = tmp.LogId


END
GO