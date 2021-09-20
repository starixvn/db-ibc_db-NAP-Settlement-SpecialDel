/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Profile] 
	@matchid INT
    ,@action VARCHAR(6) = 'CAL'
	,@ActionID	INT = 0
	,@creator INT = 0
	,@IsReSettledTickets BIT = 1
	,@ResourceResult VARCHAR(MAX) = NULL
	,@LogData XML
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
AS
/*
    Created: 20201123@Kathy
    Task : Covered SP for settlement
    DB: DBTXN/bodb02

    Revisions:
	   - 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
	   - 20210326@Louisa: Negative balance [Redmine:#152345]
	   - 20210621@Kathy: Prevent lock escalation [Redmine:#157286]
	   - 20210809@Kathy: Settle by custid [Redmine:159486]

*/
BEGIN
    SET NOCOUNT ON;

	DECLARE @fth			INT
			,@fta			INT
			,@hth			INT
			,@hta			INT
			,@goalrecord	NVARCHAR(50)
			,@sporttype		SMALLINT
			,@isRefundHT	BIT
		
			,@handle		INT
			,@DummyResourceIds		VARCHAR(MAX) 
			,@DummyResourceResults VARCHAR(MAX)
			,@CustId		INT
			,@Bettype		SMALLINT
			,@pfId			SMALLINT
			,@HomeValue		VARCHAR(20)
			,@AwayValue		VARCHAR(20)
			,@OddsType		SMALLINT
			,@MessageTypePattern VARCHAR(200)
			,@QueueSize		SMALLINT
			,@QueueNo		SMALLINT
			,@BatchNo		INT 
			,@MessageType	VARCHAR(50)	
			,@TotalAffectedTicket INT
			,@MaxThreadHold INT
			,@MinThreadHold INT
			,@TotalTicket	INT
			,@ThreadHold	INT
			,@IsExistCashout BIT
			,@xmlResourceResult		XML
			,@ChildMatchType		TINYINT
			,@strSpecialBettype VARCHAR(MAX) 
			,@strCashoutBettype VARCHAR(MAX)
			,@TotalCommands INT
			,@SessionId BIGINT
			,@MessageBody VARCHAR(MAX)
			,@MinCustId int
			,@MaxCustId int
			,@SettlementProcessingId BIGINT
		
	DECLARE @tmpResources TABLE(
		ResourceID VARCHAR(20)
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
	)
	
	DECLARE @tmpBatchMinMaxCustId TABLE (BatchNo INT, MinCustId INT, MaxCustId INT)

	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange

	CREATE TABLE #tmpSelectedRID (
		ResourceID		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,BetType		SMALLINT
		,BetID			BIGINT
		,pfID			SMALLINT
		,OddsType		SMALLINT
		,IsHT			BIT DEFAULT(0)
		,PRIMARY KEY (BetType,BetID)
	)	
	
	CREATE TABLE #tmpCustBettypes (CustId INT, Bettype SMALLINT, TotalTicket INT)
	CREATE TABLE #tmpCustIds (CustId INT PRIMARY KEY, BatchNo INT, TotalTicket INT, runningtotal int)
	CREATE TABLE #tmpSettlementProcessing (CustIds VARCHAR(MAX), QueueNo SMALLINT)
	
	CREATE TABLE #tmpReferTransId (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tmpDummyTicket -- cashout: 901-> 903, 911; bettrade: 901 -> 903
	(
		transid BIGINT PRIMARY KEY
		,custid INT
		,bettype SMALLINT
	)

	SELECT	
			@DummyResourceIds = ''
			,@DummyResourceResults = ''
			,@ErrCode = 0
			,@ErrMsg = ''
			,@MessageTypePattern = 'bet_settle_msg_type_prepare_'
			,@queueSize = 6
			,@MaxThreadHold = 50000
			,@MinThreadHold = 10000
			,@BatchNo = 0
			,@TotalTicket = 0
			,@xmlResourceResult = CAST(@ResourceResult AS XML)
			,@strSpecialBettype = ''
			,@strCashoutBettype = ''
			,@TotalCommands = 0
			
			,@messageBody = ''
			,@SettlementProcessingId = 0
	
	BEGIN TRY
		INSERT INTO dbo.Settlement_SettledSession (MatchId)
		SELECT @matchid
		SET @SessionId = SCOPE_IDENTITY()

		insert into SettlementTestLog (matchid, stepname, session, logtime, doing) values (@matchid, 'prepare data - start', @SessionId, getdate(), 'threads: ' + cast (@queuesize as varchar))
		
		SELECT	@fth = FinalHomeScore
				,@fta = FinalAwayScore
				,@hth = HTHomeScore
				,@hta = HTAwayScore
				,@sporttype = sporttype
				,@goalrecord = goalrecord
				,@isRefundHT = CASE WHEN betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
				,@ChildMatchType = ChildMatchType
		FROM	 DBPRO.bodb02.dbo.match WITH (NOLOCK) 
		WHERE	matchid = @matchid
   
		;WITH cteGoalResource
		AS
		(
			SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
					,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
					,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
					,T.C.value('@SettlementStatusId', 'TINYINT') AS SettlementStatusId
			FROM    @xmlResourceResult.nodes('/Results/Resource') AS T(C)
		)
		,cteResource
		AS
		(
			SELECT	CAST('01' AS VARCHAR(20)) AS ResourceID
					,CAST( @hth AS VARCHAR(50)) AS HomeValue
					,CAST( @hta AS VARCHAR(50)) AS AwayValue
			WHERE	@action IN ('CAL', 'CAL-HT')
			UNION ALL
			SELECT 	CAST('00' AS VARCHAR(20)) AS ResourceID
					,CAST( @fth AS VARCHAR(50)) AS HomeValue
					,CAST( @fta AS VARCHAR(50)) AS AwayValue
			WHERE	@action IN ('CAL', 'CAL-FT')
			UNION ALL
			SELECT  ResourceId, HomeValue, AwayValue
			FROM	cteGoalResource
			WHERE   ResourceID IS NOT NULL
					AND SettlementStatusId = 4
		)
		INSERT INTO @tmpResources (ResourceID, HomeValue, AwayValue)
		SELECT	ResourceID, HomeValue, AwayValue
		FROM	cteResource

		-- insert dummy resouceid
		-----------------------------------------add more info-----------------------------------------
		SELECT	@DummyResourceIds = @DummyResourceIds + s.ResourceID + ','
		FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			INNER JOIN @tmpResources t
				ON s.RefResourceId = t.ResourceID
		WHERE	s.SportType = @sportType
				AND s.SettleType = 'MNL'
				AND s.RefResourceId IS NOT NULL

		IF @DummyResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResources(ResourceID, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
																,Home VARCHAR(50)
																,Away VARCHAR(50)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END

		-- insert selectedRid
		INSERT INTO #tmpSelectedRID(
			ResourceID
			,HomeValue
			,AwayValue
			,BetType
			,BetID
			,pfID
			,OddsType	
			,IsHT
		)
		SELECT DISTINCT tbl.ResourceID
				,tbl.HomeValue
				,tbl.AwayValue
				,sp.BetType, sp.BetID, sp.pfID
				, sp.OddsType				
				,CASE WHEN f.groupId IN (1,3,5) THEN 1 ELSE 0 END AS IsHT
		FROM	@tmpResources tbl
			INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
				ON	sp.ResourceID = tbl.ResourceID
			INNER JOIN dbo.f_Set_GetGroupBettypes() AS f
				ON	sp.bettype = f.BetType
		WHERE	sp.SportType = @SportType
				AND 1 = CASE	
							WHEN @action IN ('CAL', 'CAL-FT') AND @isRefundHT = 1 AND Is3x30 = 1 AND GroupId = 2 THEN 0 
							ELSE 1
						END
				AND SettleType = 'MNL'
				AND pfID > 0
	
		MERGE dbo.SettlementBettypeResult AS TARGET
		USING (
			SELECT	@MatchId AS MatchId
					,BetType
					,pfID
					,HomeValue
					,AwayValue
					,OddsType
					,IsHT
			FROM	#tmpSelectedRID
		) AS SOURCE
			ON	TARGET.MatchId = SOURCE.MatchId
				AND TARGET.Bettype = SOURCE.Bettype
				AND TARGET.Pfid = SOURCE.pfId
		WHEN MATCHED THEN 
			UPDATE SET TARGET.HomeValue = SOURCE.HomeValue
						,TARGET.AwayValue = SOURCE.AwayValue
						,TARGET.OddsType = SOURCE.OddsType
		WHEN NOT MATCHED BY TARGET THEN
			INSERT (MatchId,  BetType, pfID, HomeValue, AwayValue, OddsType, IsHT)
				VALUES (SOURCE.MatchId, SOURCE.Bettype, SOURCE.pfId, SOURCE.HomeValue, SOURCE.AwayValue, SOURCE.OddsType, SOURCE.IsHT);
	
		IF @ChildMatchType = 204 AND @Action IN ('CAL', 'CAL-FT')
		BEGIN
			DECLARE @CornerResultString VARCHAR(50)
					,@Position				TINYINT
					,@HomeRaceTo			TINYINT
					,@AwayRaceTo			TINYINT
					,@LenResultString		TINYINT
					,@hdp					VARCHAR(5) = ''
					,@Index_Round_tmp		TINYINT = 0
					,@Index_Round			TINYINT = 1
					,@ResourceResult_Corner_Result	VARCHAR(MAX) = NULL
					,@Char					VARCHAR(1)

			DECLARE @tmpCornerRaceToResult TABLE (hdp INT, ResourceID VARCHAR(20), HomeValue VARCHAR(10),Index_Round TINYINT)
			DECLARE @tmpCornerResultDetail AS TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(10))
			DECLARE @tmpCornerBettype TABLE (Bettype SMALLINT, ResourceId VARCHAR(20))

			;WITH cteCornerBettypes 
			AS (
				SELECT	bettype
						,CAST(bettype AS VARCHAR) 
							+ CASE 
								WHEN bettype IN (486,487) 
									THEN CASE
											WHEN hdp1 < 10 THEN '0' ELSE '' END + CAST(hdp1 AS VARCHAR) 
								ELSE '' 
							END AS ResouceId
				FROM	dbo.bettrans b WITH(NOLOCK)
				WHERE	bettype BETWEEN 486 AND 490
						AND matchid = @matchid
						AND EXISTS (SELECT TOP 1 1 FROM #tmpSelectedRID s WHERE s.BetType = b.bettype) 
				GROUP BY bettype
						,CAST(bettype AS VARCHAR) 
							+ CASE 
								WHEN bettype IN (486,487) 
									THEN CASE
											WHEN hdp1 < 10 THEN '0' ELSE '' END + CAST(hdp1 AS VARCHAR) 
								ELSE '' 
							END
			)
			INSERT INTO @tmpCornerBettype(Bettype, ResourceId)
			SELECT	bettype
					,ResouceId
			FROM	cteCornerBettypes		

			IF EXISTS (SELECT TOP 1 1 FROM @tmpCornerBettype WHERE bettype IN (486, 487))
			BEGIN
				SELECT	@CornerResultString = ISNULL(CASE WHEN LEFT(@GoalRecord, 1) = ';' THEN SUBSTRING(@GoalRecord,2,LEN(@GoalRecord) - 1) ELSE @GoalRecord END, '')
						,@Position = 1
						,@HomeRaceTo = 0
						,@AwayRaceTo = 0					
				
				SELECT @LenResultString = LEN(@CornerResultString)

				SET @Index_Round_tmp =  CASE WHEN CHARINDEX(';',@GoalRecord) = 0 THEN LEN(@GoalRecord) + 1 ELSE CHARINDEX(';',@GoalRecord) END

				WHILE (@Position <= @LenResultString)
				BEGIN
					SET @Char = SUBSTRING(@CornerResultString, @Position, 1)
				
					IF @Char = 'H'	
					BEGIN
						SET @HomeRaceTo = @HomeRaceTo + 1

						IF @HomeRaceTo > @AwayRaceTo
						BEGIN
							IF @HomeRaceTo < 10  
								SET @hdp = '0' + CAST(@HomeRaceTo AS VARCHAR(5))
							ELSE 
								SET @hdp = CAST(@HomeRaceTo AS VARCHAR(5))
						
							IF @Position <= @Index_Round_tmp
								SET @Index_Round = 1
							ELSE 
								SET @Index_Round = 2
								 
							INSERT INTO @tmpCornerRaceToResult (HDP, ResourceID, HomeValue,Index_Round)
							VALUES (@HomeRaceTo,CAST(@hdp AS VARCHAR), @Char,@Index_Round )
						
						END	
					END
					ELSE IF @Char = 'A' 
					BEGIN
						SET @AwayRaceTo = @AwayRaceTo + 1
						IF @AwayRaceTo > @HomeRaceTo
						BEGIN
							IF @AwayRaceTo < 10  
								SET @hdp = '0' + CAST(@AwayRaceTo AS VARCHAR(5))
							ELSE 
								SET @hdp = CAST(@AwayRaceTo AS VARCHAR(5))
						
							IF @Position <= @Index_Round_tmp
								SET @Index_Round = 1
							ELSE 
								SET @Index_Round = 2
								
							INSERT INTO @tmpCornerRaceToResult (HDP,ResourceID, HomeValue, Index_Round)
							VALUES (@AwayRaceTo,CAST(@hdp AS VARCHAR), @Char,@Index_Round)

						END
					END
				
					SET @Position = @Position + 1	 	
				END

				INSERT INTO @tmpCornerResultDetail (ResourceID, HomeValue)
				SELECT	CASE WHEN Index_Round = 1 THEN '487' ELSE '486' END + ResourceID
						,HomeValue
				FROM	@tmpCornerRaceToResult
			END
								
			INSERT INTO @tmpCornerResultDetail(ResourceID, HomeValue)
			SELECT  CAST(bettype AS VARCHAR)
					,CASE 
						WHEN bettype = 490 AND CHARINDEX(';', @CornerResultString) > 0 THEN SUBSTRING(@CornerResultString,CHARINDEX(';', @CornerResultString) + 1, 1)
						ELSE LEFT (@CornerResultString, 1)
					END	 AS HomeValue
			FROM	@tmpCornerBettype
			WHERE	bettype IN (488,489,490)

			SET @ResourceResult_Corner_Result = ''
			SELECT @ResourceResult_Corner_Result = (
													SELECT DISTINCT c1.ResourceID AS Id
														, CASE 
															WHEN c2.HomeValue IS NULL THEN 'N'
															WHEN c2.HomeValue IN (';','') THEN 'N' 
															ELSE c2.HomeValue
															END AS HomeValue
														, 4 AS SettlementStatusId
														, 5 AS ResultStatusId
													FROM @tmpCornerBettype  c1
														LEFT JOIN @tmpCornerResultDetail c2 ON c1.ResourceID = c2.ResourceID
													FOR XML RAW ('Resource'), ROOT ('Results')
													)

			IF @ResourceResult_Corner_Result IS NOT NULL
			BEGIN	
				EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
					@Command        = 'NAP_Admin_Settlement_1_InstantCalculation-CAL', -- reuse inst command
					@MatchID        = @MatchID,                  
					@ResourceResult	= @ResourceResult_Corner_Result,                    
					@creator        = @creator
			END	
		END

		IF @IsReSettledTickets = 0
		BEGIN
			INSERT INTO #tmpCustBettypes (CustId, Bettype, TotalTicket)
			SELECT	b.custid
					,b.bettype
					,COUNT(1) AS TotalTicket
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = @matchid
					AND b.statusID IN (0,102)
			GROUP BY b.custid, b.bettype
		END 
		ELSE
		BEGIN
			INSERT INTO #tmpCustBettypes (CustId, Bettype, TotalTicket)
			SELECT	b.custid
					,b.bettype
					,COUNT(1) AS TotalTicket
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = @matchid
					AND b.statusID <> 101
			GROUP BY b.custid, b.bettype
		END
	
		IF @action IN ('CAL', 'CAL-FT')
		BEGIN
			SELECT @strCashoutBettype = CAST(
									(SELECT  Bettype AS '@t' 
									FROM	(VALUES (1), (3), (5), (7), (8), (15)) AS b(bettype)
									WHERE	1 = CASE WHEN @Action = 'CAL-FT' AND bettype IN(7,8,15) THEN 0 ELSE 1 END
									FOR XML PATH ('r'),ROOT ('root'), TYPE
								) AS VARCHAR(MAX))
		END
		ELSE 
		BEGIN
			SELECT @strCashoutBettype = CAST(
								(SELECT  Bettype AS '@t' 
								FROM	(VALUES (7), (8), (15)) AS b(bettype)
								FOR XML PATH ('r'),ROOT ('ROOT'), TYPE
							) AS VARCHAR(MAX))
		END

		DELETE	
		FROM	#tmpCustBettypes
		WHERE	bettype NOT IN (SELECT DISTINCT bettype FROM #tmpSelectedRID)

		INSERT INTO #tmpCustIds (CustId, TotalTicket)
		SELECT	CustId, SUM(TotalTicket)
		FROM	#tmpCustBettypes
		GROUP BY CustId
		ORDER BY CustId

		SELECT @TotalAffectedTicket = SUM(TotalTicket)
		FROM	#tmpCustIds
	
		SELECT @ThreadHold = CASE 
								WHEN @TotalAffectedTicket > @MaxThreadHold * @QueueSize THEN @MaxThreadHold 
								WHEN @TotalAffectedTicket/@QueueSize <= @MinThreadHold THEN @MinThreadHold
								ELSE @TotalAffectedTicket/@QueueSize 
							END
			,@QueueNo = 0
			,@BatchNo = 0
	
		UPDATE	#tmpCustIds
			SET runningtotal = @TotalTicket  
				,@TotalTicket = CASE WHEN @TotalTicket + TotalTicket >= @ThreadHold THEN TotalTicket ELSE @TotalTicket + TotalTicket END
				,BatchNo = @batchNo
				,@batchNo = CASE WHEN @TotalTicket = TotalTicket THEN @BatchNo + 1 ELSE @batchNo END
		
		;WITH cteBatchNo
		AS(
			SELECT	BatchNo, MIN(custid) minCustId, MAX(custid) maxCustId
			FROM	#tmpCustIds
			GROUP BY BatchNo
		)
		INSERT INTO @tmpBatchMinMaxCustId (BatchNo, MinCustId, MaxCustId)	
		SELECT CASE
					WHEN BatchNo <= @QueueSize THEN BatchNo
					ELSE CASE 
							WHEN @QueueSize%2 = 0 THEN (BatchNo + 1)/2 + @QueueSize/2 
							ELSE BatchNo/2 + (@QueueSize+1)/2
						 END
					END batchno
				,MIN(mincustId)
				,MAX(maxcustid)
		FROM cteBatchNo
		GROUP BY CASE
					WHEN batchno <= @QueueSize THEN BatchNo
					ELSE CASE 
							WHEN @QueueSize%2 = 0 THEN (BatchNo + 1)/2 + @QueueSize/2 
							ELSE BatchNo/2 + (@QueueSize+1)/2
						 END
					END

		insert into SettlementTestLog (matchid, stepname, session, logtime, doing) values (@matchid, 'prepare data - end', @SessionId, getdate(), 'threads: ' + cast (@queuesize as varchar))
	
		EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
			,@mode = 'LockMatch'
			,@IsSettingByProfile = 1
			,@SessionId = @SessionId	
	
		SELECT	@BatchNo = 1
				,@QueueNo = 1	
		WHILE(1=1)
		BEGIN
			SELECT TOP 1 @MinCustId = MinCustId
					,@MaxCustId = MaxCustId
			FROM	@tmpBatchMinMaxCustId 
			WHERE	BatchNo = @BatchNo

			IF @@ROWCOUNT = 0
				BREAK

			INSERT INTO dbo.SettlementProcessing (TransIds, modds, IsMarked, OddsType, MessageType, SessionId,ActionId)	
			SELECT '', 0,0,0,'',@SessionId,0

			SET @SettlementProcessingId = SCOPE_IDENTITY()

			SET @messageBody = 'EXEC dbo.NAP_Admin_Settlement_Queue @matchid = ' + CAST(@MatchId AS VARCHAR)
									+ ',@action  = ''' + @action + ''''
									+ ',@MinCustId = ' + CAST(@mincustid AS VARCHAR)
									+ ',@MaxCusId = ' + CAST(@maxcustid  AS VARCHAR)
									+ ',@IsReSettledTickets  = ' + CAST(@IsReSettledTickets  AS VARCHAR)
									+ ',@QueueNo  = ' + CAST(@QueueNo  AS VARCHAR)								
									+ ',@SessionId  = ' + CAST(@SessionId  AS VARCHAR(50))
									+ ',@ActionId  = ' + CAST(@ActionId  AS VARCHAR(50))
									+ ',@SettlementProcessingId  = ' + CAST(@SettlementProcessingId  AS VARCHAR(50))
		
			SELECT @MessageType = @MessageTypePattern + CASE WHEN @QueueNo < 10 THEN '0' ELSE '' END + CAST(@QueueNo AS VARCHAR)
		
			EXEC [sb].[SSB_Send_Message] @MessageContent = @messageBody
				, @FunctionName = 'settlement'
				, @MessageType = @MessageType 
		
			SET @BatchNo = @BatchNo + 1
			SET @QueueNo = CASE WHEN @QueueNo >= @QueueSize THEN 1 ELSE @QueueNo + 1 END
		END

		insert into SettlementTestLog (matchid, stepname, session, logtime, doing) values (@matchid, 'cal - start', @SessionId, getdate(), 'threads: ' + cast (@queuesize as varchar))
	
		insert into SettlementTestLog (matchid, stepname, session, logtime, doing) values (@matchid, 'others - start', @SessionId, getdate(), 'threads: ' + cast (@queuesize as varchar))

		IF @strCashoutBettype <> ''
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Main -- 911
				@matchid        = @matchid
				,@action        = 'CAL'
				,@mode          = @action
				,@strBettypes   = @strCashoutBettype
				,@sporttype		= @sporttype
		END

		insert into SettlementTestLog (matchid, stepname, session, logtime, doing) values (@matchid, 'others - end', @SessionId, getdate(), 'threads: ' + cast (@queuesize as varchar))
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	-- Release lock match
	SET @messageBody = 'EXEC dbo.NAP_Admin_MonitorProcess @SessionId = ' + CAST(@SessionId AS VARCHAR(50))
							+ ', @MatchId = ' + CAST(@MatchId AS VARCHAR)
							+ CASE 
								WHEN @ErrCode <> 0 THEN ', @HasError = 1' 
								ELSE ', @LogData = ' + @LogData
							END

	EXEC [sb].[SSB_Send_Message] @MessageContent = @messageBody
		, @FunctionName = 'settlement'
		, @MessageType = 'bet_settle_msg_type_complete'

END
