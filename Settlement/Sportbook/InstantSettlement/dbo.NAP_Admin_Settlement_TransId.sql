/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_TransId]
	@MatchId				INT
	,@Action				VARCHAR(20)
	,@ActionId				INT
	,@SessionId				BIGINT
	,@SettlementProcessingId BIGINT
	,@hth					INT
	,@hta					INT
	,@fth					INT
	,@fta					INT
	,@AffectedTicket		INT = 0 OUTPUT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				VARCHAR(300) = '' OUTPUT
AS
/*
	Created by: 20230404@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20231006@Aries: Enhance instant Settlement [Redmine:#195162]
		- 20240901@Kathy: missing @matchid when sending data to SSB [Redmine:210264]
	Param's Explanation:  
		@Params: <Params><Params/>
		   
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @IsCentral	BIT
			,@MinRowId INT
			,@MaxRowId INT
			,@strTransIds VARCHAR(MAX)
			,@ExecDataQueueSize SMALLINT
			,@QueueExecNo SMALLINT
			,@batchNo INT
			,@batchSize INT			
			,@messageBody VARCHAR(MAX)
			,@oddstype SMALLINT 
			,@IsMarked TINYINT
			,@modds MONEY
			,@RunningTotal INT
			,@CurrentFilter INT
			,@PreviousFilter INT
			,@MessageTypePattern VARCHAR(200)
			,@MessageType VARCHAR(200)
			,@TotalBatch INT
			,@SPName NVARCHAR(128)
			,@RunExecDataBySSB BIT
			,@i INT

	DECLARE @tmpBatchNo TABLE (
		BatchNo INT
		,oddstype SMALLINT 
		,IsMarked TINYINT
		,modds MONEY
	)

	DECLARE @tmpResultDetailCorner TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(2000))

	CREATE TABLE #tmpFinalResult (
		transid BIGINT
		,modds MONEY
		,oddstype SMALLINT
		,IsMarked TINYINT 
		,BatchNo INT DEFAULT (0)
		,filter INT
		,runningtotal INT
		,RowId INT IDENTITY (1,1) PRIMARY KEY
	)
	
	SELECT	@strTransIds = ''
			,@QueueExecNo = 0
			,@batchSize = 2000  
			,@messageBody = ''
			,@IsMarked = 0
			,@oddstype = 0
			,@batchNo = 0
			,@RunningTotal = 0
			,@CurrentFilter = 0
			,@PreviousFilter = 0
			,@MessageTypePattern = 'bet_settle_msg_type_0'
			,@MessageType = ''
			,@TotalBatch = 0
			,@SPName = OBJECT_NAME(@@procId)
			,@ExecDataQueueSize = 0
			,@RunExecDataBySSB = 0
			,@isCentral = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	BEGIN TRY
		IF @Action LIKE 'CAL-INST%'
		BEGIN
			INSERT INTO #tmpFinalResult (transid, filter, modds, IsMarked, oddstype)
			SELECT	b.transid
					,CASE 					
						WHEN m.modds > 0.25 THEN POWER(2,0)
						WHEN m.modds = 0.25 THEN power (2,1)
						WHEN m.modds = 0 THEN power(2,2)
						WHEN m.modds = -0.25 THEN power (2,3)
						ELSE power(2,4) END
					+ CASE WHEN mt.IsMarked IS NOT NULL THEN POWER(2,5) ELSE 0 END
					+ CASE WHEN s.oddstype = 1 THEN POWER(2,6) ELSE 0 END 
						AS filterBy					
					,m.modds	
					,ISNULL(mt.IsMarked, 0) AS IsMarked
					,s.oddstype			
			FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN dbo.SettlementBettypeResult s WITH(NOLOCK)
					ON	b.bettype = s.BetType
						AND b.matchid = s.MatchId
						AND s.SessionId = @SessionId
				OUTER APPLY (	
					SELECT	TOP 1 1 AS IsMarked
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
				)mt
				OUTER APPLY dbo.f_Set_SDT_modds(s.pfID, b.betteam
							,b.hdp1
							, b.hdp2, @hth, @hta, @fth, @fta, s.HomeValue, s.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc
							,CAST(b.betid AS VARCHAR(50)) -- betcheck/betid
							, 0) m
			WHERE	b.matchid = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
							AND b.recommend <> 1688156) --exclude betdaq/betfair
					AND ((b.statusId = 0 AND ISNULL(b.SecAcceptFlag,0)=0)
						 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
						 )	
					AND 1 = CASE 
								WHEN mt.IsMarked = 1 AND b.statuswinlost = CASE WHEN m.modds > 0.25 THEN 2 WHEN m.modds < -0.25 THEN 4 END THEN 0
								ELSE 1
							END
					AND m.modds IS NOT NULL
					AND 1 = CASE WHEN m.modds >= 0.5 OR m.modds <= -0.5 THEN 1 ELSE 0 END
			ORDER BY filterBy, b.custId, b.bettype
			OPTION (MAXDOP 1)
		
		END
		ELSE IF @Action LIKE 'UNDO-INST%'
		BEGIN
			INSERT INTO #tmpFinalResult (transid, filter, IsMarked)
			SELECT	b.transid
					,1 AS filterBy					
					,ISNULL(mt.IsMarked, 0) AS IsMarked				
			FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN dbo.SettlementBettypeResult s WITH(NOLOCK)
					ON	b.bettype = s.BetType
						AND b.matchid = s.MatchId
						AND s.SessionId = @SessionId
				OUTER APPLY (	
					SELECT	TOP 1 1 AS IsMarked
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
					)mt
				CROSS APPLY dbo.f_Set_SDT_modds(s.pfID, b.betteam
							,b.hdp1
							, b.hdp2, @hth, @hta, @fth, @fta, s.HomeValue, s.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc
							,CAST(b.betid AS VARCHAR(50)) -- betcheck/betid
							, 0) m
			WHERE	b.matchid = @matchid
					AND ISNULL(b.betdaqid,0) <> -2
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
							AND b.recommend <> 1688156) --exclude betdaq/betfair
					AND 1 = CASE
								WHEN b.statusId IN (112, 113)
									AND (b.statusId <> CASE
													WHEN m.modds >= 0.5 THEN 112
													WHEN m.modds <= -0.5 THEN 113
													ELSE 0
												END 
									) THEN 1
								WHEN b.statusId = 0 AND mt.IsMarked IS NOT NULL
									AND ISNULL(b.statuswinlost,0) <> 0
									AND m.modds IS NULL THEN 1
								ELSE 0
							END
			ORDER BY filterBy, b.custId, b.bettype
			OPTION (MAXDOP 1)
		END

		UPDATE #tmpFinalResult	
			SET runningtotal = @RunningTotal
				,@PreviousFilter = @CurrentFilter
				,@CurrentFilter = filter
				,@runningtotal = CASE 
									WHEN (@RunningTotal + 1 > @batchSize AND @PreviousFilter = @CurrentFilter) 
										OR @PreviousFilter <> @CurrentFilter THEN 1 
									ELSE @RunningTotal + 1 END
				,@batchNo = CASE WHEN @runningtotal = 1 THEN @batchNo + 1 ELSE @batchNo END
				,batchno = @batchNo
		OPTION (MAXDOP 1)
				
		INSERT INTO @tmpBatchNo(BatchNo,modds, oddstype, IsMarked)
		SELECT	BatchNo
				,MAX(modds)
				,MAX(oddstype) -- scorebox has oddstype = 0
				,MIN(IsMarked)
		FROM	#tmpFinalResult
		GROUP BY BatchNo
	
		EXEC dbo.NAP_Set_GlobalSettingSel	
			@LockName = 'SettlementSSB'
			,@ExecDataQueueSize =  @ExecDataQueueSize OUTPUT
			,@RunExecDataBySSB = @RunExecDataBySSB OUTPUT
			
		SELECT @AffectedTicket = COUNT(1)
		FROM	#tmpFinalResult 

		INSERT INTO dbo.SettlementProcessing (TransIds, modds, IsMarked, OddsType, MessageType, SessionId,ActionId)	
		SELECT	t.TransIds
				,b.modds
				,b.IsMarked
				,b.oddstype
				,@MessageTypePattern 
					+ CAST(CASE 
								WHEN (b.BatchNo)%@ExecDataQueueSize = 0 THEN @ExecDataQueueSize  
								ELSE (b.BatchNo)%@ExecDataQueueSize END AS VARCHAR)
				,@SessionId
				,@ActionId
		FROM	@tmpBatchNo b
			CROSS APPLY (
				SELECT CAST((SELECT	t.transid AS '@t'
						FROM	#tmpFinalResult t
						WHERE	t.BatchNo = b.BatchNo
						FOR XML PATH('r'), ROOT('root'), TYPE) AS VARCHAR(MAX)) AS TransIds
			) t

		SELECT @TotalBatch = @@ROWCOUNT
		
		IF @TotalBatch > 0
		BEGIN
			SET @MessageBody = CAST(@matchid AS VARCHAR) + '^' + CAST(@SessionId AS VARCHAR)

			IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT_' 
				OR @RunExecDataBySSB = 0
			BEGIN
				SELECT @MessageType = @MessageTypePattern + CAST(@QueueExecNo AS VARCHAR)
		
				EXEC dbo.SSB_Settlement_UpdateData @ConversationHandle = NULL
					,@MessageType = @MessageType
					,@MessageBody = @MessageBody
					,@MessageId = NULL
			END
			ELSE
			BEGIN	
				SET @QueueExecNo = 1
				SET @i = 1
				
				WHILE(1=1)
				BEGIN
					SELECT @MessageType = @MessageTypePattern + CAST(@QueueExecNo AS VARCHAR)
		
					EXEC [dbo].[SSB_Send_Message] @MessageContent = @MessageBody
						, @FunctionName = 'settlement'
						, @MessageType = @MessageType
			
					IF @i = CASE WHEN @TotalBatch > @ExecDataQueueSize THEN @ExecDataQueueSize ELSE @TotalBatch END
						BREAK					

					SET @i = @i + 1
					SET @QueueExecNo = CASE WHEN @QueueExecNo = @ExecDataQueueSize THEN 1 ELSE @QueueExecNo + 1 END
				END
			END
		END

		DELETE FROM dbo.SettlementProcessing WHERE id = @SettlementProcessingId
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()

		UPDATE	dbo.SettlementProcessing
			SET StatusId = 3 -- failed
		WHERE	Id = @SettlementProcessingId
	END CATCH
END
