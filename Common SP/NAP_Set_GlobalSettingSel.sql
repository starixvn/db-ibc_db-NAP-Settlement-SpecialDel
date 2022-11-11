/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_GlobalSettingSel]
	@LockName VARCHAR(100)
	,@ThreadHold INT = 0 OUTPUT
	,@PrepareDataQueueSize SMALLINT = 0 OUTPUT
	,@ExecDataQueueSize SMALLINT = 0 OUTPUT
	,@RunPrepareDataBySSB BIT = 0 OUTPUT
	,@RunExecDataBySSB BIT = 0 OUTPUT
	,@MaxThreadHold INT = 0 OUTPUT
	,@MinThreadHold INT = 0 OUTPUT
	,@SiteDB_RunExecDataBySSB BIT = 0 OUTPUT
	,@SiteDB_ExecDataQueueSize SMALLINT = 0 OUTPUT
AS

/*
    Created: 20210514@Kathy
    Task: 
    DB: DBTXN/bodb02
    Revisions:       
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20211210@Kathy: Improve performance 
		- 20220606@Kathy: Adjust number of execution service from 6 to 8 [Redmine:#173205]
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

    Parameters Explanation:        
    
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpGlobalSetting TABLE (LockName VARCHAR(100) PRIMARY KEY
		,ThreadHold 			INT
		,RunPrepareDataBySSB 	BIT
		,RunExecDataBySSB 		BIT
		,PrepareDataQueueSize 	SMALLINT
		,ExecDataQueueSize 		SMALLINT
		,SiteDB_RunExecDataBySSB BIT
		,SiteDB_ExecDataQueueSize SMALLINT
	)
	
	INSERT INTO @tmpGlobalSetting(LockName, ThreadHold)
	VALUES ('ParlayRefno', 10000)

	INSERT INTO @tmpGlobalSetting(LockName, RunPrepareDataBySSB, RunExecDataBySSB, PrepareDataQueueSize, ExecDataQueueSize)
	VALUES ('SettlementSSB', 1, 1, 6, 8)

	INSERT INTO @tmpGlobalSetting(LockName, SiteDB_RunExecDataBySSB, SiteDB_ExecDataQueueSize)
	VALUES ('SiteDB_SettlementSSB', 1, 4)

	SET @ThreadHold = 0
	SET @PrepareDataQueueSize = 0
	SET @ExecDataQueueSize = 0
	SET @RunPrepareDataBySSB = 0
	SET @RunExecDataBySSB = 0
	SET @SiteDB_RunExecDataBySSB = 0
	SET @SiteDB_ExecDataQueueSize = 0

	IF @LockName = 'ParlayRefno'
		SELECT	@ThreadHold = ThreadHold
		FROM	@tmpGlobalSetting
		WHERE	LockName = @LockName
		
	IF @LockName = 'SettlementSSB'
	BEGIN
		SELECT	@PrepareDataQueueSize = PrepareDataQueueSize
				,@ExecDataQueueSize = ExecDataQueueSize
				,@RunPrepareDataBySSB = RunPrepareDataBySSB
				,@RunExecDataBySSB = RunExecDataBySSB
		FROM	@tmpGlobalSetting
		WHERE	LockName = @LockName
		
		IF @RunPrepareDataBySSB = 0
			SELECT @PrepareDataQueueSize = 1
		
		IF @RunExecDataBySSB = 0
			SELECT @ExecDataQueueSize = 1

		SET @MaxThreadHold = 20----50000   
		SET @MinThreadHold = 10----10000   
	END

	IF @LockName = 'SiteDB_SettlementSSB'
	BEGIN
		SELECT	@SiteDB_ExecDataQueueSize = SiteDB_ExecDataQueueSize
				,@SiteDB_RunExecDataBySSB = SiteDB_RunExecDataBySSB
		FROM	@tmpGlobalSetting
		WHERE	LockName = @LockName

		IF @SiteDB_RunExecDataBySSB = 0
			SELECT @SiteDB_ExecDataQueueSize = 1
	END
	
END
GO
