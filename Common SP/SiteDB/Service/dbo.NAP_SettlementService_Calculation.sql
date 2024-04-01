/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_Calculation]
	@SiteDBGroupId		SMALLINT
	,@SessionId			BIGINT			= NULL
	,@MessageType		VARCHAR(200)
	,@TransInfo			XML				= NULL
	,@TransInfoJson		VARBINARY(MAX)	= NULL

	,@TableName			VARCHAR(128) 	= ''
	,@MatchId			INT				= 0
	,@Action			VARCHAR(1)		= 'U'
	,@SettlementAction	VARCHAR(20)		= NULL
	,@TicketType		VARCHAR(1)		= NULL
	,@TotalQueue		INT				= 0
	,@SettlementProcessingId BIGINT		= 0
	,@Is3rd				BIT				= 0
	,@SiteDB			SMALLINT		= 1
	,@EventTable		TINYINT			= 0
	,@AffectedTicket	INT 			= 0 OUTPUT
	,@ErrCode			INT				= 0	 OUTPUT
	,@ErrMsg			VARCHAR(300)	= '' OUTPUT
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221025@Louisa: Use Json log format for soccer [Redmine:#179449]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]
		- 20230111@Kathy: Skip validate ticket count [Redmine:#182763]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]	

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
			,@WarningDuration		INT
			,@LogDuration			INT
			,@WaringStartTime		DATETIME2
			,@Decompress_TransInfoJson	NVARCHAR(MAX)
			,@MessageBody			NVARCHAR(MAX)
			,@Message				VARCHAR(1024) 
			,@cnt_missingticket		INT
			,@IsSkip				BIT
			,@isFailedValidation	BIT 
			,@isWarningValidation	BIT

	DECLARE @tmpTransId TABLE (TransId BIGINT)
	CREATE TABLE #tmpMissingTransId (Id INT IDENTITY(1,1), TransId BIGINT)

	SELECT	@cnt_sitedb = 0
			,@cnt_central = 0
			,@IsPassed = 1
			,@cnt_missingticket = 0
			,@IsSkip = 0
			,@isFailedValidation = 0
			,@isWarningValidation = 0

	BEGIN TRY
		/* Sync for some tables when void bettrans14: bettrans14, Transfer, TicketVoiding_RoutineTasks */
		IF @TableName IN ('Transfer', 'TicketVoiding_RoutineTasks') AND @Action = 'I'
		BEGIN
			EXEC dbo.NAP_SyncService_NotExecRep
					@TransInfoJson = @TransInfoJson
					,@TableName = @TableName
					,@Action = @Action
		END
		ELSE IF @TableName = 'bettrans14'
		BEGIN
			EXEC dbo.Bet_ExecRep14_04
					@TransInfoJson = @TransInfoJson
					,@TableName = @TableName
					,@Action = @Action
					,@MessageType = @MessageType
		END
		ELSE IF @TableName = 'Transfer' AND @Action =  'U'
		BEGIN
			EXEC dbo.Transfer_ExecRep_04
					@TransInfoJson = @TransInfoJson
					,@TableName = @TableName
					,@Action = @Action
					,@MessageType = @MessageType
		END
		/*---------------------------------------------------------------------------------------------*/
		ELSE IF @TableName = 'SiteDB_SettlementLock'
			AND OBJECT_ID('SiteDB_SettlementLock', 'U') IS NOT NULL			
		BEGIN
			IF @Action = 'I'
			BEGIN
				EXEC dbo.Bet_ExecRep_NAP_Admin_01 
					@SiteDBGroupId = @SiteDBGroupId
					,@SessionId = @SessionId
					,@MessageType = @MessageType
					,@TableName = @TableName
					,@MatchId = @MatchId
					,@Action = @Action			
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
						EXEC dbo.Bet_ExecRep_NAP_Admin_01 
							@SiteDBGroupId = @SiteDBGroupId
							,@SessionId = @SessionId
							,@MessageType = @MessageType
							,@TableName = @TableName
							,@MatchId = @MatchId
							,@Action = @Action			
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
						,@WarningDuration = dbo.f_Set_GetDuration('CompareTicketCentralSiteDB_Warning')
						,@LogDuration = dbo.f_Set_GetDuration('CompareTicketCentralSiteDB_Log')
						,@StartTimeValidation = SYSDATETIME()
						,@WaringStartTime = SYSDATETIME()

				IF @TransInfoJson IS NOT NULL
				BEGIN
					SET @Decompress_TransInfoJson = DECOMPRESS(@TransInfoJson)
					SET @MessageBody = @Decompress_TransInfoJson
				END
				ELSE IF @TransInfo IS NOT NULL
				BEGIN
					SET @MessageBody = CAST(@TransInfo AS VARCHAR(MAX))
				END

				WHILE (@IsPassed = 0)
				BEGIN
					IF @TableName = 'bettrans'
					BEGIN
						IF @cnt_sitedb = 0
						BEGIN
							IF @TransInfoJson IS NOT NULL
							BEGIN
								INSERT INTO @tmpTransId (TransID)
								SELECT	t
								FROM	OPENJSON(@Decompress_TransInfoJson) WITH (t BIGINT)
								
								SET @cnt_sitedb = @@ROWCOUNT
							END
							ELSE
							BEGIN
								INSERT INTO @tmpTransId (TransID)
								SELECT	T.C.value('./@t', 'bigint') AS transid	
								FROM	@TransInfo.nodes('/root/r') AS T(C)
								OPTION (OPTIMIZE FOR (@TransInfo = NULL ))
									
								SET @cnt_sitedb = @@ROWCOUNT
							END							
						END 
						
						SELECT @cnt_central = COUNT(1)
						FROM	@tmpTransId t
						WHERE	EXISTS (SELECT TOP 1 1 
										FROM dbo.bettrans b WITH(NOLOCK) 
										WHERE b.transid = t.TransId
								)

						IF @isFailedValidation = 1 OR @isWarningValidation = 1
						BEGIN
							INSERT INTO #tmpMissingTransId (TransId)
							SELECT	t.TransId
							FROM	@tmpTransId t
							WHERE	NOT EXISTS (SELECT TOP 1 1 
											FROM dbo.bettrans b WITH(NOLOCK) 
											WHERE b.transid = t.TransId
									)
							SET @cnt_missingticket = @@ROWCOUNT
						END

					END
					ELSE IF @TableName = 'bettransm'
					BEGIN
						IF @cnt_sitedb = 0
						BEGIN
							IF @TransInfoJson IS NOT NULL
							BEGIN
								INSERT INTO @tmpTransId (TransID)
								SELECT	t
								FROM	OPENJSON(@Decompress_TransInfoJson) WITH (t BIGINT)
								
								SET @cnt_sitedb = @@ROWCOUNT
							END
							ELSE
							BEGIN
								INSERT INTO @tmpTransId (TransID)
								SELECT	T.C.value('./@t', 'bigint') AS transid	
								FROM	@TransInfo.nodes('/root/r') AS T(C)
								OPTION (OPTIMIZE FOR (@TransInfo = NULL ))
									
								SET @cnt_sitedb = @@ROWCOUNT
							END							
						END 

						SELECT @cnt_central = COUNT(1)
						FROM	@tmpTransId t
						WHERE	EXISTS (SELECT TOP 1 1 
										FROM dbo.bettransm b WITH(NOLOCK) 
										WHERE b.transid = t.TransId
								)

						IF @isFailedValidation = 1 OR @isWarningValidation = 1
						BEGIN
							INSERT INTO #tmpMissingTransId (TransId)
							SELECT	t.TransId
							FROM	@tmpTransId t
							WHERE	NOT EXISTS (SELECT TOP 1 1 
											FROM dbo.bettransm b WITH(NOLOCK) 
											WHERE b.transid = t.TransId
									)
							SET @cnt_missingticket = @@ROWCOUNT
						END
					END

					IF @cnt_sitedb = @cnt_central
					BEGIN
						SET @IsPassed = 1

						BREAK
					END
					ELSE IF DATEDIFF(SECOND,@StartTimeValidation,SYSDATETIME()) > @Duration
					BEGIN
						IF @isFailedValidation = 0
						BEGIN
							SET @isFailedValidation = 1

							CONTINUE
						END

						IF @isFailedValidation = 1
						BEGIN
							WHILE (@cnt_missingticket > 0) -- send msg with list missing transids
							BEGIN
								SET @Message = '(' + @TableName + ')' + 'Failed to validate ticket between CentralDB and SiteDB: '

								SET @Message = @Message + STUFF((SELECT ',' + CAST(transid AS VARCHAR(30)) 
																FROM	#tmpMissingTransId
																WHERE	id <= @cnt_missingticket AND id > @cnt_missingticket - 20
																FOR XML PATH ('')
																),1,1,'')

								EXEC dbo.SSB_Settlement_WriteLogs 
									@MessageId			= 1
									,@MessageType		= @MessageType
									,@MessageBody		= @MessageBody
									,@StartTime			= @StartTimeValidation
									,@EndTime			= @WaringStartTime
									,@SessionId			= @SessionId
									,@ErrorMessage		= @Message
									,@ConversationHandle= NULL
									,@QueueNo			= NULL
									,@SiteDBGroupId		= @SiteDBGroupId	

								SET @cnt_missingticket = @cnt_missingticket - 20
							END

							SET @IsSkip = 1

							BREAK
						END
					END
					ELSE
					BEGIN
						IF DATEDIFF(SECOND,@StartTimeValidation,SYSDATETIME()) > @WarningDuration
							IF DATEDIFF(SECOND,@WaringStartTime,SYSDATETIME()) > @LogDuration 
							BEGIN
								IF @isWarningValidation = 0
								BEGIN
									SET @isWarningValidation = 1

									CONTINUE
								END

								IF @isWarningValidation = 1
								BEGIN
									SET @WaringStartTime = SYSDATETIME()
									SET @isWarningValidation = 0

									WHILE (@cnt_missingticket > 0)
									BEGIN									
										SET @Message = '(' + @TableName + ')' + 'Warning: There are some tickets at SiteDB not exists on CentralDB: '
										
										SET @Message = @Message + STUFF((SELECT ',' + CAST(transid AS VARCHAR(30)) 
																FROM	#tmpMissingTransId
																WHERE	id <= @cnt_missingticket AND id > @cnt_missingticket - 20
																FOR XML PATH ('')
																),1,1,'')

										EXEC dbo.SSB_Settlement_WriteLogs 
											@MessageId			= 1
											,@MessageType		= @MessageType
											,@MessageBody		= @MessageBody
											,@StartTime			= @StartTimeValidation
											,@EndTime			= @WaringStartTime
											,@SessionId			= @SessionId
											,@ErrorMessage		= @Message
											,@ConversationHandle= NULL
											,@QueueNo			= NULL
											,@SiteDBGroupId		= @SiteDBGroupId

										SET @cnt_missingticket = @cnt_missingticket - 20
									END

									 TRUNCATE TABLE #tmpMissingTransId
								END
							END

						WAITFOR DELAY @DelayTime -- wait for comparing ticket between central and sitedb
						
						CONTINUE
					END
				END
			END

			IF @IsPassed = 1 OR @IsSkip = 1
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
					,@Is3rd = @Is3rd
					,@SiteDB = @SiteDB
					,@EventTable = @EventTable
					,@AffectedTicket = @AffectedTicket OUTPUT
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