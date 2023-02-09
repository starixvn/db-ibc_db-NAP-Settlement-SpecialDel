/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLastLog_Udp
	@LogIds			VARCHAR(500)
	,@QueueType		TINYINT
AS
/*
	Created:20221122@Louisa
    Task: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20221122@Louisa: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]
		- 20230208@Louisa: support queue 3rd [RedmineId:#179505]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @LogId TABLE ( LogId BIGINT )
	
	INSERT INTO @LogId ( LogId )
	SELECT DISTINCT Value from string_split(@LogIds, ',')


	IF @QueueType = 1
	BEGIN
		UPDATE ll
		SET StatusId = 2
		FROM dbo.SiteDB_SettlementService_LastLog ll WITH(ROWLOCK,UPDLOCK)
		INNER JOIN @LogId tmp
			ON ll.LogId = tmp.LogId
	END

	ELSE IF @QueueType = 3
	BEGIN
		UPDATE ll
		SET StatusId = 2
		FROM dbo.SiteDB_SettlementService_LastLog_3rd ll WITH(ROWLOCK,UPDLOCK)
		INNER JOIN @LogId tmp
			ON ll.LogId = tmp.LogId
	END


END
GO