/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchDelSettled] 
	@date datetime  
AS  
/* 
	 Creator: Kathy  
	 Date: 20140318  
	 Task: Delete settled matches, messages in Single and Parlay's queue  
	 DB: DBTXN/BODB02  
	 Original: Admin_Settlement_1  
	   
	 Revisions:  
		- 20160115@Kathy: Delete service log in SettlementServicesLog, SettlementServicesLogDetail table [Redmine:#50375]
		- 20170906@Bobby: #82738 - VS Betradar - clean up command
		- 20180913@Kathy: Delete TempVariableNumberHistory data
		- 20181115@Kathy: backup data for 2 tables: Single_Calculate_Queue & Parlay_Calculate_Queue [Redmine:#104631]
		- 20200903@Kathy: backup data of single_calculate_queue & parlay_calculate_queue to DBLOG [Redmine:#138281]
		- 20210426@Kathy: Remove Old Command Logs of Settlement by Profile [Redmine:#153976]
	    - 20210706@Louisa: Letstalk message [Redmine:#157540]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20211028@Kathy: Remove log on table SSB_SettlementLogs [Redmine:#159486]
		- 20221026@Kathy: Remove log on table SiteDB_SettlementService_CalculationLog_History [178694]

	 Param's Explanation:  
    
    
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @SingleKeyIds VARCHAR(MAX)
			,@ParlayKeyIds VARCHAR(MAX)

	DECLARE @tmpKeyId TABLE (KeyId INT)
	DECLARE @tmpSingleKeyId TABLE (KeyId INT)
	DECLARE @tmpParlayKeyId TABLE (KeyId INT)

	SELECT	@SingleKeyIds = ''
			,@ParlayKeyIds = ''

	 -- Single commands   
	INSERT INTO @tmpSingleKeyId (KeyId)
	SELECT	KeyId
	FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)  
	WHERE	Starttime < @Date 
			AND IsCalculating NOT IN (0, 1)  

	IF @@ROWCOUNT > 0
		SELECT @SingleKeyIds = @SingleKeyIds + CAST(KeyId AS VARCHAR(20)) + ','
		FROM	@tmpSingleKeyId

	-- Parlay commands
	INSERT INTO @tmpParlayKeyId(KeyId)
	SELECT	KeyId
	FROM	dbo.Parlay_Calculate_Queue p WITH (NOLOCK)  
	WHERE	Starttime < @Date 
			AND IsCalculating NOT IN (0, 1)  

	IF @@ROWCOUNT > 0
		SELECT @ParlayKeyIds = @ParlayKeyIds + CAST(KeyId AS VARCHAR(20)) + ','
		FROM	@tmpParlayKeyId

	 -- backup data on DBLOG
	 EXEC DBLOG.bodb_CustomerLog.dbo.NAP_Set_QueueSBBackup
		  @SingleKeyIds = @SingleKeyIds
		  ,@ParlayKeyIds = @ParlayKeyIds

	-- delete data on DBTXN
	-- single commands
	WHILE (1 = 1)
	BEGIN
		DELETE FROM @tmpKeyId

		DELETE  TOP (2000)
		FROM	@tmpSingleKeyId 
		OUTPUT DELETED.KeyId
		INTO @tmpKeyId(KeyId)
			
		DELETE	s
		FROM	dbo.Single_calculate_queue s WITH(ROWLOCK, UPDLOCK) 
			INNER JOIN @tmpKeyId t
				ON	s.KeyId = t.KeyId

		IF @@ROWCOUNT < 2000
			BREAK
	END

	-- parlay commands
	WHILE (1 = 1)
	BEGIN
		DELETE FROM @tmpKeyId

		DELETE  TOP (2000)
		FROM	@tmpParlayKeyId 
		OUTPUT DELETED.KeyId
		INTO @tmpKeyId(KeyId)
			
		DELETE	p
		FROM	dbo.Parlay_Calculate_Queue p WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmpKeyId t
				ON	p.KeyId = t.KeyId

		IF @@ROWCOUNT < 2000
			BREAK
	END

	DELETE 
	FROM	dbo.Single_Calculate_Queue_VS WITH(UPDLOCK,ROWLOCK)  
	WHERE	Starttime < @Date 
		AND IsCalculating NOT IN (0, 1)  
	  
	-- VS Betradar - Parlay  
	DELETE		
	FROM	dbo.Parlay_Calculate_Queue_VS WITH (UPDLOCK,ROWLOCK)  
	WHERE	Starttime < @Date 
		AND IsCalculating NOT IN (0, 1)  

	-- Settled message  
	DELETE 
	FROM	dbo.Settled_Message WITH(UPDLOCK, ROWLOCK)  
	WHERE	Starttime < @Date   
		AND IsRead = 1  
 
	-- delete SettlementServiceLog/SettlementServicesLogDetail
	DECLARE @tblDeletedSession TABLE ([Session] NVARCHAR(50))
	 
	IF EXISTS (SELECT TOP 1 1 FROM dbo.SettlementServicesLog WITH(NOLOCK))
	BEGIN
		DELETE 
		FROM	dbo.SettlementServicesLog WITH(UPDLOCK, ROWLOCK)
		OUTPUT DELETED.Session
		INTO	@tblDeletedSession ([Session])
		WHERE	EndTime < @date
		
		IF @@ROWCOUNT <> 0
		DELETE 
		FROM	dbo.SettlementServicesLogDetail WITH(UPDLOCK, ROWLOCK)
		WHERE	[Session] IN (SELECT [Session] FROM @tblDeletedSession)
	END

	WHILE (1=1)
	BEGIN
		DELETE TOP (1000)
		FROM	dbo.TempVariableNumberHistory WITH(ROWLOCK, UPDLOCK)
		WHERE	CreatedDateTime < @date

		IF @@rowcount < 1000
			BREAK
	END
 
	-- Remove Old Command Logs of Settlement by Profile
	WHILE (1=1)
	BEGIN
		DELETE TOP (1000)
		FROM	dbo.SingleSettlementTrace WITH(ROWLOCK, UPDLOCK)
		WHERE	CreatedDate < @Date

		IF @@ROWCOUNT < 1000
			BREAK
	END

	WHILE (1=1)
	BEGIN
		DELETE TOP (1000)
		FROM	dbo.ParlayLockingHistory WITH(ROWLOCK, UPDLOCK)
		WHERE	CreatedDate <= DATEADD (DD, -7, GETDATE())

		IF @@rowcount < 1000
			BREAK
	END

	-- Remove old data from TVS_UserActionLog
	WHILE (1=1)
	BEGIN
		DELETE TOP (1000)
		FROM	dbo.TVS_UserActionLog WITH(ROWLOCK, UPDLOCK)
		WHERE	 CreatedDate <= DATEADD (DD, -14, GETDATE())

		IF @@ROWCOUNT < 1000
			BREAK
	END

	-- Remove old data from table store Letstalk Message
	WHILE (1=1)
	BEGIN
		DELETE TOP (1000)
		FROM	dbo.Settlement_LetstalkMessage WITH(ROWLOCK, UPDLOCK)
		WHERE	 CreatedDate <= DATEADD (DD, -14, GETDATE())

		IF @@ROWCOUNT < 1000
			BREAK
	END

	DECLARE @8DaysBefore DATETIME = DATEADD (DD, -8, GETDATE())	
	WHILE(1=1)
	BEGIN
		DELETE TOP(2000) FROM dbo.SSB_SettlementLogs WITH(ROWLOCK)
		WHERE StartTime <= @8DaysBefore

		IF @@ROWCOUNT = 0
			BREAK
	END

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog_History','U') IS NOT NULL
	BEGIN
		WHILE(1=1)
		BEGIN
			DELETE TOP(2000) FROM dbo.SiteDB_SettlementService_CalculationLog_History WITH(ROWLOCK)
			WHERE LogDate <= @8DaysBefore

			IF @@ROWCOUNT = 0
				BREAK
		END
	END
END  
GO