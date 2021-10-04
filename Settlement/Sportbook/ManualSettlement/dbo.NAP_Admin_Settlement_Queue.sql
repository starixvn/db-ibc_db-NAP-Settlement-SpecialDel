/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Queue]
	@MatchId				INT
	,@Action				VARCHAR(20)
	,@ActionId				INT
	,@MinCustId				INT
	,@MaxCusId				INT
	,@IsReSettledTickets	BIT = 0
	,@SessionId				BIGINT
	,@QueueNo				INT
	,@SettlementProcessingId BIGINT
AS
/*
	Created by: 20210730@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MinRowId INT
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

	DECLARE @tmpBatchNo TABLE (
		BatchNo INT
		,oddstype SMALLINT 
		,IsMarked TINYINT
		,modds MONEY
	)
	CREATE TABLE #tmpAffectedTransId 
	(
		transid BIGINT
		,custid INT
		,bettype SMALLINT
		,betteam VARCHAR(50)
		,hdp1 SMALLMONEY
		,hdp2 SMALLMONEY
		,livehomescore SMALLINT
		,liveawayscore SMALLINT
		,transdesc VARCHAR(1000)
		,betid BIGINT

		,pfID INT
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
		,oddstype SMALLINT
	)

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

	IF @IsReSettledTickets = 0
	BEGIN
		SELECT	 b.transid
				,b.custid
				,b.bettype
				,b.betteam 
				,b.hdp1 
				,b.hdp2 
				,b.livehomescore
				,b.liveawayscore
				,b.transdesc 
				,b.betid
		INTO #tmpBettrans
		FROM	dbo.bettrans b WITH (NOLOCK)		
		  WHERE	b.matchid = @MatchId
	  			AND b.statusID IN (0,102)	
				AND b.custid BETWEEN @MinCustId AND @MaxCusId			
		OPTION (MAXDOP 1)

		INSERT INTO #tmpAffectedTransId (transid, custid, bettype, betteam, hdp1, hdp2
			,livehomescore, liveawayscore, transdesc, betid
			,pfID, HomeValue, AwayValue, oddstype
			)
		SELECT	 b.transid
				,b.custid
				,b.bettype
				,b.betteam 
				,b.hdp1 
				,b.hdp2 
				,b.livehomescore
				,b.liveawayscore
				,b.transdesc 
				,b.betid
			
				,sr.pfID
				,sr.HomeValue 
				,sr.AwayValue 
				,sr.oddstype			
		FROM	#tmpBettrans b		
	  		INNER JOIN SettlementBettypeResult sr WITH(NOLOCK)
	  			ON	sr.BetType = b.bettype
					AND sr.matchid = @MatchId
		  WHERE	sr.IsHT = CASE 
								WHEN @action = 'CAL-HT' THEN 1
								WHEN @action = 'CAL-FT' THEN 0
								ELSE sr.isht
							END
		OPTION (MAXDOP 1)
	END
	ELSE
	BEGIN
		SELECT	 b.transid
				,b.custid
				,b.bettype
				,b.betteam 
				,b.hdp1 
				,b.hdp2 
				,b.livehomescore
				,b.liveawayscore
				,b.transdesc 
				,b.betid
		into #tmpBettrans2
		FROM	dbo.bettrans b WITH (NOLOCK)		
		WHERE	b.matchid = @MatchId
	  		AND b.statusID NOT IN (101)
			AND b.custid BETWEEN @MinCustId AND @MaxCusId
		OPTION (MAXDOP 1)

		INSERT INTO #tmpAffectedTransId (transid, custid, bettype, betteam, hdp1, hdp2
			,livehomescore, liveawayscore, transdesc, betid
			,pfID, HomeValue, AwayValue, oddstype
			)
		SELECT	 b.transid
				,b.custid
				,b.bettype
				,b.betteam 
				,b.hdp1 
				,b.hdp2 
				,b.livehomescore
				,b.liveawayscore
				,b.transdesc 
				,b.betid
			
				,sr.pfID
				,sr.HomeValue 
				,sr.AwayValue 
				,sr.oddstype			
		FROM	#tmpBettrans2 b	
	  		INNER JOIN SettlementBettypeResult sr WITH(NOLOCK)
	  			ON	sr.BetType = b.bettype
					AND sr.matchid = @matchid
		WHERE	sr.IsHT = CASE 
								WHEN @action = 'CAL-HT' THEN 1
								WHEN @action = 'CAL-FT' THEN 0
								ELSE sr.isht
							END
		OPTION (MAXDOP 1)
	END

	INSERT INTO #tmpFinalResult (transid,filter, modds, IsMarked, oddstype)
	SELECT	b.transid
			,CASE 
				WHEN m.modds > 0.25 THEN POWER(2,0)
				WHEN m.modds = 0.25 THEN power (2,1)
				WHEN m.modds = 0 THEN power(2,2)
				WHEN m.modds = -0.25 THEN power (2,3)
				ELSE power(2,4) END
			+ CASE WHEN mt.IsMarked IS NOT NULL THEN POWER(2,5) ELSE 0 END
			+ CASE WHEN b.oddstype = 1 THEN POWER(2,6) ELSE 0 END 			
				AS filterBy
			,m.modds
			,ISNULL(mt.IsMarked, 0) AS IsMarked
			,b.oddstype
	FROM	#tmpAffectedTransId b
		OUTER APPLY (	
			SELECT TOP 1 1 AS IsMarked
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	mt.TransId = b.transid
		)mt
		CROSS APPLY dbo.f_Set_Calculate_modds_major(b.pfID, b.betteam, b.hdp1, b.hdp2, b.HomeValue, b.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, b.betid) m
	ORDER BY filterBy, b.custid, b.bettype 
	OPTION (MAXDOP 1)

	UPDATE #tmpFinalResult	
		SET runningtotal = @RunningTotal
			,@PreviousFilter = @CurrentFilter
			,@CurrentFilter = filter
			,@runningtotal = CASE 
								WHEN (@RunningTotal + 1 > 2000 AND @PreviousFilter = @CurrentFilter) 
									OR @PreviousFilter <> @CurrentFilter THEN 1 
								ELSE @RunningTotal + 1 END
			,@batchNo = CASE WHEN @runningtotal = 1 THEN @batchNo + 1 ELSE @batchNo END
			,batchno = @batchNo

	INSERT INTO @tmpBatchNo(BatchNo,modds, oddstype, IsMarked)
	SELECT	BatchNo, MIN(modds), MIN(oddstype), MIN(IsMarked)
	FROM	#tmpFinalResult
	GROUP BY BatchNo
	
	EXEC dbo.NAP_Set_GlobalSettingSel	
		@LockName = 'SettlementSSB'
		,@ExecDataQueueSize =  @ExecDataQueueSize OUTPUT
		,@RunExecDataBySSB = @RunExecDataBySSB OUTPUT


	INSERT INTO dbo.SettlementProcessing (TransIds, modds, IsMarked, OddsType, MessageType, SessionId,ActionId)	
	SELECT	CAST((SELECT	t.transid AS '@t'						
					FROM	#tmpFinalResult t
					WHERE	t.BatchNo = b.BatchNo
					FOR XML PATH('r'), ROOT('root'), TYPE) AS VARCHAR(MAX)) AS TransIds
			,b.modds
			,b.IsMarked
			,b.oddstype
			,@MessageTypePattern 
				+ CAST(CASE 
							WHEN (b.BatchNo + @QueueNo - 1)%@ExecDataQueueSize = 0 THEN @ExecDataQueueSize  
							ELSE (b.BatchNo + @QueueNo - 1) %@ExecDataQueueSize END AS VARCHAR)
			,@SessionId
			,@ActionId
	FROM	@tmpBatchNo b

	SELECT @TotalBatch = @@ROWCOUNT
	
	IF @TotalBatch < @ExecDataQueueSize
		SET @ExecDataQueueSize = @TotalBatch
		
	SET @QueueExecNo = 1

	IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT_' 
		OR @RunExecDataBySSB = 0
	BEGIN
		SELECT @MessageType = @MessageTypePattern + CAST(@QueueExecNo AS VARCHAR)
		
		EXEC dbo.SSB_Settlement_UpdateData @ConversationHandle = NULL
			,@MessageType = @MessageType
			,@MessageBody = @SessionId
			,@MessageId = NULL
	END
	ELSE
	BEGIN	
		WHILE(1=1)
		BEGIN
			SELECT @MessageType = @MessageTypePattern + CAST(@QueueExecNo AS VARCHAR)
		
			EXEC [sb].[SSB_Send_Message] @MessageContent = @SessionId
				, @FunctionName = 'settlement'
				, @MessageType = @MessageType
			
			IF @QueueExecNo = @ExecDataQueueSize
				BREAK

			SET @QueueExecNo = @QueueExecNo + 1
		END
	END

	DELETE FROM dbo.SettlementProcessing WHERE id = @SettlementProcessingId
END

