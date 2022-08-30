/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_Instant] 
    @creator			INT
    ,@matchid			INT
    ,@fth            	SMALLINT        = NULL
    ,@fta            	SMALLINT        = NULL
    ,@hth            	SMALLINT
    ,@hta            	SMALLINT
    ,@goalrecord        VARCHAR(50)     = NULL
    ,@betstatus        	NVARCHAR(50)    = NULL     
    
    ,@action            VARCHAR(10)    	= 'CAL'
    ,@IP                VARCHAR(50)    	= ''
	,@IsReSettledTickets BIT			= 1
	,@ChildMatchIds		VARCHAR(500)	= NULL
	,@KeyId				INT				= 0
	,@RefResultStatus	TINYINT			= 0
	,@BroadcastSessionId VARCHAR(50)	= NULL
    ,@ErrCode			INT            	= 0		OUTPUT
    ,@ErrMsg            NVARCHAR(200)	= ''    OUTPUT
AS
/*    
	Creator: 20220419@Kathy
    Task: SP for instant settlement
    DB: DBTXN/BODB02
    
    Revisions:
		- 20220419@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
	
*/
BEGIN
    SET NOCOUNT ON
		
	DECLARE @starttime	DATETIME
			,@SessionId BIGINT
			,@ActionId INT
			,@LogActionId INT
			,@TicketCount INT
			,@LogDataSoccer	XML
			,@CommandMonitor NVARCHAR(MAX)
			,@SSBStatus	TINYINT
			,@avaiableProcess BIT
			,@IsCentral	BIT

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	SELECT	@starttime = GETDATE()
			,@ActionId = CASE @Action WHEN 'CAL-HT' THEN 102 END
			,@LogActionId = 81037

	 -- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT    @ErrCode = 1000000
                ,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
	END
		
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO dbo.Settlement_SettledSession (MatchId)
	SELECT @matchid
	SET @SessionId = SCOPE_IDENTITY()
		
	BEGIN TRY
		EXEC dbo.NAP_Admin_Settlement_3_Profile_Instant
			@matchId	= @matchid
			,@hth = @hth
			,@hta = @hta
			,@action	= @action
			,@ActionId = @ActionId
			,@SessionId = @SessionId
			,@BroadcastSessionId = @BroadcastSessionId
			,@creator = @creator
			,@TicketCount = @TicketCount OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END TRY
	BEGIN CATCH
			SELECT  @ErrCode = 1001017 
					,@ErrMsg = ERROR_MESSAGE()   
	END CATCH

	SELECT @LogDataSoccer = (					
			SELECT	@action AS '@Action'
					,@LogActionId AS '@ActionID'
					,@hth AS '@hth'
					,@hta AS '@hta'
					,@creator AS '@AdminId'
					,@IP AS '@IP'
					,@TicketCount AS '@TicketCount'
					,2 AS '@DeterminedFTStatus'
					,@starttime AS '@Starttime'
					,@ErrMsg AS '@ErrMsg'
			FOR XML PATH('r'), ROOT('root'), TYPE)

	SET @CommandMonitor = 'EXEC dbo.NAP_Admin_MonitorProcess @SessionId = ' + CAST(@SessionId AS VARCHAR(50))
					+ ', @MatchId = ' + CAST(@MatchId AS VARCHAR)
					+ ', @HasError = ' + CAST(@ErrCode AS VARCHAR)
					+ ', @LogData = ' + '''' + CAST(@LogDataSoccer AS VARCHAR(MAX)) + ''''
					+ ', @IsCentral = ' + CAST(@IsCentral AS VARCHAR)
					+ CASE WHEN @BroadcastSessionId IS NOT NULL 
							THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
							ELSE '' END
					+ ', @ErrCode = @ErrCode OUTPUT' 
                    + ', @ErrMsg = @ErrMsg OUTPUT'
					+ ', @SSBStatus = @SSBStatus OUTPUT'

	UPDATE dbo.Single_Calculate_Queue 
		SET SSBCommand = @CommandMonitor
	WHERE	keyid = @KeyId

	IF @@ROWCOUNT = 0
	BEGIN
		SET @CommandMonitor = @CommandMonitor + ', @NeedWaiting = 1' 

		EXEC sys.sp_executesql @CommandMonitor
			, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT, @SSBStatus TINYINT OUTPUT'
			, @ErrMsg	= @ErrMsg	OUTPUT
			, @ErrCode	= @ErrCode	OUTPUT
			, @SSBStatus = @SSBStatus OUTPUT
	END
END
