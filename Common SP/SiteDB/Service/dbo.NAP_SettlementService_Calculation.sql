/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_Calculation]
	@SiteDBGroupId		SMALLINT
	,@SessionId			BIGINT			= NULL
	,@MessageType		VARCHAR(200)
	,@TransInfo			XML				= NULL
	,@TransInfoJson		VARBINARY(MAX)	= NULL

	,@TableName			VARCHAR(128) 
	,@MatchId			INT				= 0
	,@Action			VARCHAR(1)		= 'U'
	,@SettlementAction	VARCHAR(20)		= NULL
	,@TicketType		VARCHAR(1)		= NULL
	,@TotalQueue		INT				= 0
	,@SettlementProcessingId BIGINT		= 0
	,@ErrCode			INT				= 0	 OUTPUT
	,@ErrMsg			VARCHAR(300)	= '' OUTPUT
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221025@Louisa: Use Json log format for soccer [Redmine:#179449]
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @cnt_sitedb				INT
			,@cnt_central			INT
			,@IsPassed				BIT 
			,@StartTimeValidation	DATETIME2
			,@DelayTime				VARCHAR(50)
			,@Duration				INT

	DECLARE @tmpTransId TABLE (TransId BIGINT)

	SELECT	@cnt_sitedb = 0
			,@cnt_central = 0
			,@IsPassed = 1

	BEGIN TRY
		/* Sync for some tables when void bettrans14: bettrans14, Transfer, TicketVoiding_RoutineTasks */
		IF @TableName IN ('Transfer', 'TicketVoiding_RoutineTasks') AND @Action = 'I'
		BEGIN
			EXEC dbo.NAP_SyncService_NotExecRep
					@TransInfo = @TransInfo
					,@TableName = @TableName
					,@Action = @Action
		END
		ELSE IF @TableName = 'bettrans14'
		BEGIN
			EXEC dbo.Bet_ExecRep14_04
					@TransInfo = @TransInfo
					,@TableName = @TableName
					,@Action = @Action
		END
		ELSE IF @TableName = 'Transfer' AND @Action =  'U'
		BEGIN
			EXEC dbo.Transfer_ExecRep_04
					@TransInfo = @TransInfo
					,@TableName = @TableName
					,@Action = @Action
		END
		/*---------------------------------------------------------------------------------------------*/
		ELSE IF @TableName = 'SiteDB_SettlementLock'
			AND OBJECT_ID('SiteDB_SettlementLock', 'U') IS NOT NULL			
		BEGIN
			IF @Action = 'I'
			BEGIN
				EXEC dbo.ExecRep_NAP_Admin_04 @Action = @Action
					,@SiteDBGroupId = @SiteDBGroupId
					,@MatchId = @MatchId
					,@SessionId = @SessionId
					,@TotalQueue = @TotalQueue
			END
			ELSE IF @Action = 'D'
			BEGIN
				WHILE 1=1
				BEGIN
					IF EXISTS (SELECT	TOP 1 1 
								FROM	dbo.SiteDB_SettlementProcessing 
								WHERE	SiteDBGroupId = @SiteDBGroupId
										AND SessionId = @SessionId
					)
						WAITFOR DELAY '00:00:00.005' -- wait for release match
					ELSE
					BEGIN
						EXEC dbo.ExecRep_NAP_Admin_04 @Action = @Action
							,@SiteDBGroupId = @SiteDBGroupId
							,@MatchId = @MatchId
							,@SessionId = @SessionId
							,@TotalQueue = @TotalQueue

						BREAK
					END
				END
			END
		END
		ELSE
		BEGIN
			IF @TableName IN ('bettrans', 'bettransm')
			BEGIN
				SELECT	@IsPassed = 0 
						,@DelayTime = dbo.f_Settlement_GetDelayTime('Wait_CompareTicket')
						,@Duration = dbo.f_Set_GetDuration('CompareTicketCentralSiteDB')
						,@StartTimeValidation = SYSDATETIME()

				WHILE (@IsPassed = 0)
				BEGIN
					IF @TableName = 'bettrans'
					BEGIN
						IF @cnt_sitedb = 0
						BEGIN
							INSERT INTO @tmpTransId (TransID)
							SELECT	t
							FROM	OPENJSON(DECOMPRESS(@TransInfoJson)) WITH (t BIGINT)

							SET @cnt_sitedb = @@ROWCOUNT
						END 

						SELECT @cnt_central = COUNT(1)
						FROM	@tmpTransId t
						WHERE	EXISTS (SELECT TOP 1 1 
										FROM dbo.bettrans b WITH(NOLOCK) 
										WHERE b.transid = t.TransId
								)
					END
					ELSE IF @TableName = 'bettransm'
					BEGIN
						IF @cnt_sitedb = 0
						BEGIN
							INSERT INTO @tmpTransId (TransID)
							SELECT	T.C.value('./@t', 'bigint') AS transid
							FROM	@TransInfo.nodes('/root/r') AS T(C)

							SET @cnt_sitedb = @@ROWCOUNT
						END

						SELECT @cnt_central = COUNT(1)
						FROM	@tmpTransId t
						WHERE	EXISTS (SELECT TOP 1 1 
										FROM dbo.bettransm b WITH(NOLOCK) 
										WHERE b.transid = t.TransId
								)
					END

					IF @cnt_sitedb = @cnt_central
					BEGIN
						SET @IsPassed = 1

						BREAK
					END
					ELSE IF DATEDIFF(SECOND,@StartTimeValidation,SYSDATETIME()) > @Duration
					BEGIN
						SELECT	@errcode = 100
								,@errmsg = 'Failed to validate ticket between CentralDB and SiteDB'

						BREAK
					END
					ELSE
					BEGIN
						WAITFOR DELAY @DelayTime -- wait for comparing ticket between central and sitedb
						
						CONTINUE
					END
				END
			END

			IF @IsPassed = 1
				EXEC dbo.Bet_ExecRep_NAP_Admin_01 
					@SiteDBGroupId = @SiteDBGroupId
					,@SessionId = @SessionId
					,@MessageType = @MessageType
					,@TransInfo = @TransInfo
					,@TransInfoJson = @TransInfoJson
					,@TableName = @TableName
					,@MatchId = @MatchId
					,@Action = @Action					
					,@SettlementAction = @SettlementAction
					,@TicketType = @TicketType
					,@TotalQueue = @TotalQueue
					,@SettlementProcessingId = @SettlementProcessingId
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	IF @IsPassed = 0 AND ISNULL(@SettlementProcessingId,0) <> 0 AND OBJECT_ID('SiteDB_SettlementProcessing', 'U') IS NOT NULL
		UPDATE s
			SET StatusId = 3
		FROM	dbo.SiteDB_SettlementProcessing s
		WHERE	Id = @SettlementProcessingid 
END