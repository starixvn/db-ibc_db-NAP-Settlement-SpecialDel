/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLastLog_Sel
AS
/*
	Created:20221020@Louisa
    Task: Tool support hold sync log service  [RedmineId:#178694]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20221020@Louisa: Get info  [RedmineId:#178694]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @LastLogId		BIGINT
			,@StatusId		TINYINT
			,@WaitingCount	INT

	SELECT TOP 1 @LastLogId = ll.LogId
				,@StatusId = ll.StatusId
	FROM dbo.SiteDB_SettlementService_LastLog ll WITH(NOLOCK)
	ORDER BY ll.LogId DESC

	IF ISNULL(@LastLogId,0) > 0
	BEGIN
		SELECT @WaitingCount = COUNT(l.LogID)
		FROM dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
		WHERE l.LogId > @LastLogID
	END

	SELECT @@SERVERNAME AS ServerName
		   ,@LastLogID  AS LastLogId
		   ,@StatusId	AS LastStatusId
		   ,@WaitingCount AS WaitingCount
	WHERE ISNULL(@LastLogId,0) > 0

END
GO