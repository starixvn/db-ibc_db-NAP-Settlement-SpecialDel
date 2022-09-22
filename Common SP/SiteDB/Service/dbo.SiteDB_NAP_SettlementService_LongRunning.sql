/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.SiteDB_NAP_SettlementService_LongRunning
AS
/*
	Created by: 20220912@Kathy
	Task: check process long running 

	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ErrorMessage varchar(400)
			,@LogId BIGINT
			,@StatusId TINYINT
			,@StartTime DATETIME2
			,@StartTimeValidation DATETIME2

	SET @ErrorMessage = ''

	SELECT	@LogId = LogId
			,@StatusId = StatusId
			,@StartTimeValidation = StartTimeValidation
			,@StartTime = Starttime
	FROM	dbo.SiteDB_SettlementService_LastLog WITH(NOLOCK)
	ORDER BY LogId DESC

	IF @StatusId = 2
		RETURN

	IF @StatusId = 3 
		SET @ErrorMessage = 'Hey guys, process sync data for SiteDB (' + @@SERVERNAME + ') got error (table SiteDB_SettlementService_LastLog). Please check!!!'
	ELSE IF @StatusId = 0 AND DATEDIFF(MINUTE,@StartTimeValidation, GETDATE()) > 3
		SET @ErrorMessage = 'Hey guys, process sync data for SiteDB (' + @@SERVERNAME + ') got validation failed (table SiteDB_SettlementService_LastLog). Please check!!!'
	ELSE IF @StatusId = 1 AND DATEDIFF(MINUTE,@StartTime, GETDATE()) > 1
		SET @ErrorMessage = 'Hey guys, the item on process sync data for SiteDB (' + @@SERVERNAME + ') has been running for too long (table SiteDB_SettlementService_LastLog). Please check!!!'

	IF @ErrorMessage <> ''
	BEGIN
		execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
			, @JobId = NULL, @JobName = N'vndba:Check slowly running or failed processes'
			, @Message = @ErrorMessage
			, @CaseId = 1;

		raiserror(@ErrorMessage, 16, 1)
	END

END

GO
