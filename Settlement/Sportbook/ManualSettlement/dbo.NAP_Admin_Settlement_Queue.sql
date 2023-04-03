/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Queue]
	@MatchId				INT
	,@Action				VARCHAR(20)
	,@ActionId				INT
	,@MinCustId				INT = 0
	,@MaxCusId				INT = 0
	,@IsReSettledTickets	BIT = 0
	,@SessionId				BIGINT
	,@QueueNo				INT
	,@SettlementProcessingId BIGINT
	,@Params				XML = ''
	,@AffectedTicket		INT = 0 OUTPUT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				VARCHAR(300) = '' OUTPUT
AS
/*
	Created by: 20210730@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20211129@Kathy: Extend datatype of table SettlementBettypeResult [Redmine:#165300]
		- 20211130@Kathy: New cashout model [Redmine:#164838]	
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		
	Param's Explanation:  
		@Params: <Params><Params/>
		   
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @hth				INT = 0
			,@hta				INT = 0
			,@fth				INT = 0
			,@fta				INT = 0
			,@IsABANDONEDHT		BIT = 0
			,@SDTRecord			TINYINT = 0
			,@IsHedgeMatch		BIT = 0
			,@DeterminedType	TINYINT = 0
			,@IsCentral			BIT = 0

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
			,@i INT

	DECLARE @tmpBatchNo TABLE (
		BatchNo INT
		,oddstype SMALLINT 
		,IsMarked TINYINT
		,modds MONEY
	)
	
	CREATE TABLE #tmpBettrans 
	(
		transid BIGINT
		,custid INT
		,recommend INT
		,bettype SMALLINT
		,betteam VARCHAR(50)
		,hdp1 SMALLMONEY
		,hdp2 SMALLMONEY
		,livehomescore SMALLINT
		,liveawayscore SMALLINT
		,transdesc VARCHAR(1000)
		,betcheck VARCHAR(50)

		,pfID INT
		,HomeValue VARCHAR(2000)
		,AwayValue VARCHAR(2000)
		,oddstype SMALLINT
	)

	CREATE TABLE #tmpAffectedTransId 
	(
		transid BIGINT
		,custid INT
		,recommend INT
		,bettype SMALLINT
		,betteam VARCHAR(50)
		,hdp1 SMALLMONEY
		,hdp2 SMALLMONEY
		,livehomescore SMALLINT
		,liveawayscore SMALLINT
		,transdesc VARCHAR(1000)
		,betcheck VARCHAR(50)

		,pfID INT
		,HomeValue VARCHAR(2000)
		,AwayValue VARCHAR(2000)
		,oddstype SMALLINT
	)

	CREATE TABLE #tmpFinalResult (
		transid BIGINT
		,custId INT
		,recommend INT
		,modds MONEY
		,oddstype SMALLINT
		,IsMarked TINYINT 
		,BatchNo INT DEFAULT (0)
		,filter INT
		,runningtotal INT
		,ScoreBoxOdds MONEY
		,ScoreBoxScore INT
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

	SELECT	@fth = T.C.value('@fth', 'int') 
			,@fta = T.C.value('@fta','int')
			,@hth = T.C.value('@hth','int')
			,@hta = T.C.value('@hta','int')
			,@SDTRecord = T.C.value('@SDTRecord','tinyint')
			,@IsHedgeMatch = T.C.value('@IsHedgeMatch','bit')
			,@IsABANDONEDHT = T.C.value('@IsABANDONEDHT','bit') 
			,@DeterminedType = T.C.value('@DeterminedType','tinyint') 
			,@IsCentral = T.C.value('@IsCentral','bit') 
	FROM	@params.nodes('/root/r') AS T(C)	
	
	BEGIN TRY
		IF @DeterminedType = 2 -- determinable ft ticket when cal ht
		BEGIN
			INSERT INTO #tmpFinalResult (transid ,filter, modds, IsMarked, oddstype)
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
					SELECT TOP 1 1 AS IsMarked
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
				)mt
				OUTER APPLY dbo.f_Set_SDT_modds(s.pfID, b.betteam
						,b.hdp1
						, b.hdp2, @hth, @hta, @hth, @hta, s.HomeValue, s.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc
						,CAST(b.betid AS VARCHAR(50)) -- betcheck/betid
						, 0) m
			WHERE	b.matchid = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND m.modds IS NOT NULL
					AND ((b.statusId = 0 AND ISNULL(b.SecAcceptFlag,0)=0)
							OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
							OR b.statusID = 102
							)
					and b.custid BETWEEN @MinCustId and @MaxCusId
					and 1 = case 
								when s.pfID = 3 then case when (@hth + @hta) - 0.25 > b.hdp1 then 1 else 0 end
								when s.pfID = 388 then case when @hta - 0.25 > b.hdp1 then 1 else 0 end
								when s.pfID = 389 then case when @hth - 0.25 > b.hdp1 then 1 else 0 end
								else 1
							end
							
			ORDER BY filterBy, b.custid, b.bettype 
			OPTION (MAXDOP 1)
		END
		ELSE
		BEGIN
			IF @Action = 'UNDO-FT' 
			BEGIN
				INSERT INTO #tmpBettrans (transid, custid, recommend, bettype, betteam, hdp1, hdp2, livehomescore, liveawayscore, transdesc, betcheck)
				SELECT	 b.transid
						,b.custid
						,b.recommend
						,b.bettype
						,b.betteam 
						,b.hdp1 
						,b.hdp2 
						,b.livehomescore
						,b.liveawayscore
						,b.transdesc 
						,CASE WHEN b.bettype IN (468, 469) THEN b.betcheck ELSE CAST(b.betid AS VARCHAR(50)) END AS betcheck
				FROM	dbo.bettrans b WITH (NOLOCK)		
					OUTER APPLY (
						SELECT	TOP (1) mt.TransId
						FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						WHERE	mt.TransId = b.transid
								AND mt.CustId = b.custId
					) mt
				WHERE	b.matchid = @MatchId
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  				AND b.statusID NOT IN (101)
					AND 1 = CASE WHEN b.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
								 WHEN b.statusID NOT IN (0, 1) THEN 1
							ELSE 0 END
					AND ISNULL(b.betdaqid,0) <> -2
					AND b.custid BETWEEN @MinCustId AND @MaxCusId
				OPTION (MAXDOP 1)

				INSERT INTO #tmpAffectedTransId (transid, custid, recommend, bettype, betteam, hdp1, hdp2
					,livehomescore, liveawayscore, transdesc, betcheck
					,pfID, HomeValue, AwayValue, oddstype
					)
				SELECT	 b.transid
						,b.custid
						,b.recommend
						,b.bettype
						,b.betteam 
						,b.hdp1 
						,b.hdp2 
						,b.livehomescore
						,b.liveawayscore
						,b.transdesc		
						,b.betcheck

						,sr.pfID
						,sr.HomeValue 
						,sr.AwayValue 
						,sr.oddstype			
				FROM	#tmpBettrans b	
	  				INNER JOIN SettlementBettypeResult sr WITH(NOLOCK)
	  					ON	sr.BetType = b.bettype
							AND sr.matchid = @matchid
				WHERE	sr.SessionId = @SessionId
				OPTION (MAXDOP 1)
			END
			ELSE IF @IsReSettledTickets = 0
			BEGIN
				INSERT INTO #tmpBettrans (transid, custid, bettype, betteam, hdp1, hdp2, livehomescore, liveawayscore, transdesc, betcheck)
				SELECT	 b.transid
						,b.custid
						,b.bettype
						,b.betteam 
						,b.hdp1 
						,b.hdp2 
						,b.livehomescore
						,b.liveawayscore
						,b.transdesc 
						,CASE WHEN b.bettype IN (468, 469) THEN b.betcheck ELSE CAST(b.betid AS VARCHAR(50)) END AS betcheck
				FROM	dbo.bettrans b WITH (NOLOCK)		
				  WHERE	b.matchid = @MatchId
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  					AND b.statusID IN (0,102)	
						AND ISNULL(b.betdaqid,0) <> -2
						AND b.custid BETWEEN @MinCustId AND @MaxCusId			
				OPTION (MAXDOP 1)

				INSERT INTO #tmpAffectedTransId (transid, custid, bettype, betteam, hdp1, hdp2
					,livehomescore, liveawayscore, transdesc, betcheck
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
						,b.betcheck
			
						,sr.pfID
						,sr.HomeValue 
						,sr.AwayValue 
						,sr.oddstype			
				FROM	#tmpBettrans b		
	  				INNER JOIN SettlementBettypeResult sr WITH(NOLOCK)
	  					ON	sr.BetType = b.bettype
							AND sr.matchid = @MatchId
				WHERE	sr.SessionId = @SessionId
				OPTION (MAXDOP 1)

			END
			ELSE
			BEGIN
				INSERT INTO #tmpBettrans (transid, custid, recommend, bettype, betteam, hdp1, hdp2, livehomescore, liveawayscore, transdesc, betcheck)
				SELECT	 b.transid
						,b.custid
						,b.recommend
						,b.bettype
						,b.betteam 
						,b.hdp1 
						,b.hdp2 
						,b.livehomescore
						,b.liveawayscore
						,b.transdesc 
						,CASE WHEN b.bettype IN (468, 469) THEN b.betcheck ELSE CAST(b.betid AS VARCHAR(50)) END AS betcheck
				FROM	dbo.bettrans b WITH (NOLOCK)		
				WHERE	b.matchid = @MatchId
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  				AND b.statusID NOT IN (101)
					AND ISNULL(b.betdaqid,0) <> -2
					AND b.custid BETWEEN @MinCustId AND @MaxCusId
				OPTION (MAXDOP 1)

				INSERT INTO #tmpAffectedTransId (transid, custid, recommend, bettype, betteam, hdp1, hdp2
					,livehomescore, liveawayscore, transdesc, betcheck
					,pfID, HomeValue, AwayValue, oddstype
					)
				SELECT	 b.transid
						,b.custid
						,b.recommend
						,b.bettype
						,b.betteam 
						,b.hdp1 
						,b.hdp2 
						,b.livehomescore
						,b.liveawayscore
						,b.transdesc		
						,b.betcheck

						,sr.pfID
						,sr.HomeValue 
						,sr.AwayValue 
						,sr.oddstype			
				FROM	#tmpBettrans b	
	  				INNER JOIN SettlementBettypeResult sr WITH(NOLOCK)
	  					ON	sr.BetType = b.bettype
							AND sr.matchid = @matchid
				WHERE	sr.SessionId = @SessionId
				OPTION (MAXDOP 1)

			END

			IF @Action LIKE 'CAL%'
			BEGIN
				INSERT INTO #tmpFinalResult (transid,filter, modds, IsMarked, oddstype, ScoreBoxOdds, ScoreBoxScore)
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
						,m.ScoreBoxOdds
						,m.ScoreBoxScore
				FROM	#tmpAffectedTransId b
					OUTER APPLY (	
						SELECT TOP 1 1 AS IsMarked
						FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						WHERE	mt.TransId = b.transid
					)mt
					CROSS APPLY dbo.f_Set_Calculate_modds_major(b.pfID, b.betteam, b.hdp1, b.hdp2, b.HomeValue, b.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, b.betcheck) m
				ORDER BY filterBy, b.custid, b.bettype 
				OPTION (MAXDOP 1)
			END 
			ELSE IF @Action LIKE 'REFUND%'
			BEGIN
				INSERT INTO #tmpFinalResult (transid, custId, recommend, filter, modds, oddstype, ScoreBoxOdds, ScoreBoxScore)
				SELECT	b.transid
						,b.custid
						,b.recommend
						,CASE 
							WHEN @IsHedgeMatch = 1 AND b.bettype NOT IN (3,8) THEN 0					
							WHEN sdt.IsSDT = 0 THEN 0
							WHEN @Action = 'REFUND-HT' AND b.bettype <> 8 THEN 0
							WHEN m.modds > 0.25 THEN POWER(2,0)
							WHEN m.modds = 0.25 THEN power (2,1)
							WHEN m.modds = 0 THEN power(2,2)
							WHEN m.modds = -0.25 THEN power (2,3)
							WHEN m.modds < -0.25 THEN power(2,4)
							ELSE 0 END
						+ CASE WHEN b.oddstype = 1 THEN POWER(2,6) ELSE 0 END 
							AS filterBy
						,CASE 
							WHEN @IsHedgeMatch = 1 AND b.bettype NOT IN (3,8) THEN NULL	
							WHEN sdt.IsSDT = 0 THEN NULL
							WHEN @Action = 'REFUND-HT' AND b.bettype <> 8 THEN NULL						
							ELSE m.modds
						END
						,b.oddstype
						,m.ScoreBoxOdds
						,m.ScoreBoxScore
				FROM	#tmpAffectedTransId b
					OUTER APPLY dbo.f_Set_SDT_modds(b.pfID, b.betteam, b.hdp1, b.hdp2, @hth, @hta, @fth, @fta, b.HomeValue, b.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, b.betcheck, @IsABANDONEDHT) m
					OUTER APPLY (
						SELECT CASE 
									WHEN @SDTRecord & 1 > 0 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
									WHEN @SDTRecord & 2 > 0 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
									WHEN @SDTRecord & 4 > 0 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
									ELSE 0
								END AS IsSDT
								,CASE 
									WHEN @SDTRecord & 8 > 0 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
									WHEN @SDTRecord & 16 > 0 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
									ELSE 0
								END AS IsExclude
					)sdt
				WHERE	1 = CASE 
								WHEN sdt.IsExclude = 1 AND sdt.IsSDT = 0 THEN 0
								WHEN sdt.IsExclude = 1 AND m.modds IS NULL THEN 0
								ELSE 1
							END
				ORDER BY filterBy, b.custid, b.bettype 
				OPTION (MAXDOP 1)
			END
			ELSE IF @Action LIKE 'UNDO%'
			BEGIN
				INSERT INTO #tmpFinalResult (transid)
				SELECT	b.transid
				FROM	#tmpAffectedTransId b
			END
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
				
		INSERT INTO @tmpBatchNo(BatchNo,modds, oddstype, IsMarked)
		SELECT	BatchNo
				,MAX(modds)
				,MAX(CASE WHEN ScoreBoxOdds IS NOT NULL THEN 2 ELSE oddstype END) -- scorebox has oddstype = 0
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
								WHEN (b.BatchNo + @QueueNo - 1)%@ExecDataQueueSize = 0 THEN @ExecDataQueueSize  
								ELSE (b.BatchNo + @QueueNo - 1) %@ExecDataQueueSize END AS VARCHAR)
				,@SessionId
				,@ActionId
		FROM	@tmpBatchNo b
			CROSS APPLY (
				SELECT CAST((SELECT	t.transid AS '@t'	
								,t.ScoreBoxOdds AS '@so'
								,t.ScoreBoxScore AS '@ss'
						FROM	#tmpFinalResult t
						WHERE	t.BatchNo = b.BatchNo
						FOR XML PATH('r'), ROOT('root'), TYPE) AS VARCHAR(MAX)) AS TransIds
			) t

		SELECT @TotalBatch = @@ROWCOUNT
		
		IF @TotalBatch > 0
		BEGIN
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
				SET @QueueExecNo = @QueueNo
				SET @i = 1
				
				WHILE(1=1)
				BEGIN
					SELECT @MessageType = @MessageTypePattern + CAST(@QueueExecNo AS VARCHAR)
		
					EXEC [dbo].[SSB_Send_Message] @MessageContent = @SessionId
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

