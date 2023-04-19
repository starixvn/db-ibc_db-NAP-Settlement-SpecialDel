/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Outright]
	 @MatchID		INT
	,@Status		NVARCHAR(10)	= NULL 
	,@Action		VARCHAR(10)		='CAL'	
	,@Deadheat		FLOAT			= 1 
	,@IsDeadheat	BIT				= 0 
	,@EventDate		DATETIME		= NULL
	,@AdminID		INT				= 5838421 

	,@ErrCode		INT				= 0  OUTPUT
	,@ErrMsg		VARCHAR(300)	= '' OUTPUT
AS
/*
	Created by: Jamie
	Date: 2014-08-11
	Task: Settlement Outright 
	DB: DBTXN/bodb02 
	Original: Dot_Admin_SettleOutright_Event & Dot_Admin_SettleOutright_Trans
	
	Revision: 
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20180702@Helen: Using Bet Publication for outright settlement [Redmine:#97670]
		- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20230109@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]
		- 20230419@Aries: Fix STRING_AGG  error [Redmine:#187152]
		- 20230317@Aries: Enhance Outright Settlement as User Feedback [Redmine:#185129]

	Param's Explanation:
		+ @Action	= CAL | UNDO 
		+ @Status	= WON | LOSE | REFUND 
		+ @Deadheat = fraction of deadheat to divide (1,2,3  etc)	
*/
BEGIN
	SET NOCOUNT ON 
	

	DECLARE  @Remark 			VARCHAR(500) = ''
			,@ActionID 			INT
			,@LeagueID			INT
			,@IsCentral			BIT = 0
			,@AvaiableProcess	BIT
			,@BatchSize			INT = 2000
			,@StrTranIDs		VARCHAR(MAX)

	DECLARE @TransIDs TABLE(transid BIGINT PRIMARY KEY)

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblTransID(transid BIGINT PRIMARY KEY)
	

	-- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@MatchID AS matchid
		   ,2 AS KeyId
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		 @IsExistOutright	= 1
		,@AvaiableProcess 	= @AvaiableProcess OUTPUT
		,@ErrCode			= @ErrCode OUTPUT
		,@ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @AvaiableProcess = 0)
		RETURN

	SET @ActionID = CASE WHEN @Action = 'CAL' AND @Status IN ('WON','LOSE') THEN 137
						 WHEN @Action = 'CAL' AND @Status IN ('REFUND') THEN 139
						 WHEN @Action = 'UNDO'	THEN 145
					 END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	SET @EventDate =  CONVERT(DATE, ISNULL(@EventDate,GETDATE()))

	SELECT	@LeagueID	= LeagueID
	FROM	Outright WITH (NOLOCK)
	WHERE	ORID = @MatchID
	
	-------------------------------------------------------------
	---						START Settlement				  ---
	-------------------------------------------------------------
	INSERT INTO #tblTransID(transid)
	SELECT transid		
	FROM dbo.bettrans WITH(NOLOCK)	
	WHERE matchid = @Matchid 
		AND bettype = 10
		AND statusID NOT IN (101, 102)
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END

	WHILE (1 = 1)
	BEGIN
		DELETE @TransIDs

		DELETE TOP (@BatchSize) #tblTransID
		OUTPUT deleted.transid
		INTO @TransIDs(transid)	

		IF @@ROWCOUNT = 0 BREAK

		SELECT @strTranIDs = STRING_AGG(CAST(transid AS VARCHAR(MAX)), ',')
		FROM @TransIDs;

		EXEC dbo.NAP_Admin_Calculate_Main 
			 @StrTransIds = @StrTranIDs
			,@Matchid = @MatchID
			,@Status = @Status
			,@Action = @Action
			,@Deadheat = @Deadheat
			,@EventDate  = @EventDate
			,@IsSettingByProfile = 1
			,@Mode = 'Outright'

			,@ErrCode = @ErrCode OUTPUT
			,@ErrMessage = @ErrMsg OUTPUT

		IF @ErrCode > 0  BREAK
	END

	-------------------------------------------------------------
	---						END Settlement				      ---
	-------------------------------------------------------------
	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		 @IsExistOutright	= 1
		,@IsReleased		= 1

	--add log to outright_log to notify for Apollo
	EXEC dbo.[Acc_Set_ConfirmedActionOutright] 
		 @matchid = @matchid
		,@actionid = 31
		,@status = @status
		,@deadheat = @deadheat

	-- WRITE LOG	
	IF @IsCentral = 1
	BEGIN
		BEGIN TRY
			SET @deadheat = IIF(@deadheat = 1,0, @deadheat)
			SET @Remark = CAST(@deadheat AS VARCHAR(5))

			IF @ErrCode > 0
			BEGIN
				SET @Remark = @Remark + ',ErrCode= ' + CAST(@ErrCode AS VARCHAR(5)) + ' ,ErrMsg=' + @ErrMsg;
			END

			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
				 @UserID = @AdminID
				,@MatchID = @MatchID
				,@ActionID = @ActionID
				,@LeagueID = @LeagueID
				,@EventDate = @EventDate
				,@Result = @Status
				,@Remark = @Remark
		END TRY
		BEGIN CATCH
			SET @Remark = 'ErrCode= ' + CAST(@ErrCode AS VARCHAR(5)) + ' ,ErrMsg= ' + @ErrMsg + ' ,InsLogErrMsg=' + LEFT(ERROR_MESSAGE(), 100)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
				@UserID = @AdminID
				,@MatchID = @MatchID
				,@ActionID = @ActionID
				,@LeagueID = @LeagueID
				,@EventDate = @EventDate
				,@Result = @Status
				,@Remark = @Remark
		END CATCH
	END
END

GO