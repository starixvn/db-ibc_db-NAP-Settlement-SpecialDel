/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Profile] 
	@matchid INT
	,@hth INT = 0
	,@hta INT = 0
	,@fth INT = 0
	,@fta INT = 0
	,@goalrecord NVARCHAR(50) = ''
    ,@action VARCHAR(6) = 'CAL'
	,@ActionID	INT = 0
	,@creator INT = 0
	,@IsReSettledTickets BIT = 1
	,@SessionId	BIGINT = NULL
	,@ResourceResult VARCHAR(MAX) = NULL
	,@BroadcastSessionId VARCHAR(50)	= NULL
	,@TicketCount INT = 0 OUTPUT
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
	   - 20211129@Kathy: Extend datatype of table SettlementBettypeResult [Redmine:#165300]
	   - 20211210@Kathy: Improve performance [Redmine:#165996]
	   - 20211130@Kathy: New cashout model [Redmine:#164838]
	   - 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
	   - 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
	   - 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
	   - 20221019@Louisa: insert BroadcastSessionId into queue auto void for all Action [Redmine:#179361]
	   
*/
BEGIN
    SET NOCOUNT ON;

	DECLARE @sporttype		SMALLINT
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
			,@PrepareDataQueueSize	SMALLINT
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
			,@MessageBody VARCHAR(MAX)
			,@MinCustId int
			,@MaxCustId int
			,@SettlementProcessingId BIGINT
			,@SPName NVARCHAR(128)
			,@RunPrepareDataBySSB BIT
			,@openquery NVARCHAR(MAX)
			,@strTransIds	VARCHAR(MAX)
			,@TotalSubParlay INT
			,@SelectedResourceParlay VARCHAR(MAX) 
			,@ThreadHoldRefno	INT 
			,@LockedByRefno		BIT
			,@sqlCommand		VARCHAR(MAX)
			,@ParamsXML			XML
			,@Params			VARCHAR(MAX)
			,@IsCentral	BIT
			,@WebResourceResult VARCHAR(MAX)
			
	DECLARE @tmpResources TABLE(
		ResourceID VARCHAR(20)
		,HomeValue VARCHAR(2000)
		,AwayValue VARCHAR(2000)
	)

	DECLARE @tmpAllBettypes TABLE (Bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpAffectedBettypes TABLE (Bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, winlost MONEY, statuswinlost TINYINT)
	
	DECLARE @tmpBatchMinMaxCustId TABLE (BatchNo INT, MinCustId INT, MaxCustId INT)
	DECLARE @tmpParlayAffectedBettypes TABLE (bettype SMALLINT, totalticket INT)	

	DECLARE @tmpCashoutTransId AS TABLE (TransId BIGINT, winlost MONEY DEFAULT(0), statuswinlost TINYINT, custid INT, balanceType TINYINT, WalletType TINYINT, BonusID INT, balance MONEY
		, bettype SMALLINT, betteam VARCHAR(50), hdp1 SMALLMONEY, hdp2 SMALLMONEY,livehomescore SMALLINT, liveawayscore SMALLINT, isFinished BIT DEFAULT(0)
		, currentStatuswinlost TINYINT
	)

	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange

	CREATE TABLE #tmpSelectedRID (
		ResourceID		VARCHAR(20)
		,HomeValue		VARCHAR(2000)
		,AwayValue		VARCHAR(2000)
		,BetType		SMALLINT
		,BetID			BIGINT
		,pfID			SMALLINT
		,OddsType		SMALLINT
		,RefResourceId	VARCHAR(20)
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
			,@MessageTypePattern = 'bet_settle_msg_type_prepare_'
			,@MaxThreadHold = 0
			,@MinThreadHold = 0
			,@BatchNo = 0
			,@TotalTicket = 0
			,@xmlResourceResult = CAST(@ResourceResult AS XML)
			,@strSpecialBettype = ''
			,@strCashoutBettype = ''
			,@TotalCommands = 0
			
			,@messageBody = ''
			,@SettlementProcessingId = 0
			,@SPName = OBJECT_NAME(@@PROCID)
			,@Sporttype = 1
			,@TotalSubParlay = 0
			,@ThreadHoldRefno = 0
			,@LockedByRefno = 0
			,@sqlCommand = ''
			,@IsCentral = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @SessionId IS NULL
	BEGIN
		SELECT	@ErrCode = 1001017
				,@ErrMsg = 'The SessionId is missing.'

		RETURN
	END

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

	SET	@WebResourceResult = CAST((SELECT	ResourceID AS '@Id'
											,HomeValue AS '@HomeValue'
											,AwayValue AS '@AwayValue'
											,4 AS '@SettlementStatusId'
											,5 AS '@ResultStatusId'
									FROM	@tmpResources
									FOR XML PATH('Resource'), ROOT ('Results'), TYPE
							) AS VARCHAR(MAX))

	INSERT INTO @tmpAllBettypes(Bettype)
	SELECT bettype
	FROM (
		SELECT	s.BetType
		FROM	@tmpResources t
			INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				ON t.ResourceID = s.ResourceID
		WHERE	s.SportType = @sporttype
				AND s.SettleType = 'MNL'

		UNION 
		SELECT	s.BetType
		FROM	@tmpResources t
			INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				ON t.ResourceID = s.RefResourceId
		WHERE	s.RefResourceId IS NOT NULL
				AND s.SportType = @sporttype
				AND s.SettleType = 'MNL'
		) t

	IF @IsReSettledTickets = 0
	BEGIN
		INSERT INTO #tmpCustBettypes (CustId, Bettype, TotalTicket)
		SELECT	b.custid
				,b.bettype
				,COUNT(1) AS TotalTicket
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchid
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND EXISTS (SELECT TOP 1 1 FROM @tmpAllBettypes t WHERE t.Bettype = b.bettype)
				AND 1 = CASE 
							WHEN ISNULL(b.betdaqid,0) = -2 THEN 1
							WHEN b.statusID IN (0,102) THEN 1
							ELSE 0
						END
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
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND b.statusID <> 101
				AND EXISTS (SELECT TOP 1 1 FROM @tmpAllBettypes t WHERE t.Bettype = b.bettype)
		GROUP BY b.custid, b.bettype
	END

	;WITH cteAffectedBettypes
	AS (
		SELECT	Bettype
		FROM	#tmpCustBettypes
		GROUP BY Bettype
	)
	INSERT INTO @tmpAffectedBettypes(BetType)
	SELECT	bettype
	FROM	cteAffectedBettypes

	SELECT	@isRefundHT = CASE WHEN betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
			,@ChildMatchType = ChildMatchType			
	FROM	DBPRO.bodb02.dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @matchid

	-- insert dummy resouceid
	-----------------------------------------add more info-----------------------------------------
	SELECT	@DummyResourceIds = @DummyResourceIds + s.ResourceID + ','
	FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
		INNER JOIN @tmpAffectedBettypes t
			ON s.BetType = t.BetType
	WHERE	s.SportType = @sportType
			AND s.SettleType = 'MNL'
			AND s.RefResourceId IS NOT NULL

	IF @DummyResourceIds <> ''
	BEGIN
		EXEC dbo.NAP_Set_DummyResourceResult
			@MatchID = @MatchID
			,@sportType = @sportType
			,@WebResourceResult = @WebResourceResult
			,@DummyResourceIds = @DummyResourceIds
			,@DummyResourceResults = @DummyResourceResults OUTPUT

		EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
		INSERT INTO @tmpResources(ResourceID, HomeValue, AwayValue)
		SELECT Id, Home, Away
		FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
												,Home VARCHAR(2000)
												,Away VARCHAR(2000)
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
		,RefResourceId
	)
	SELECT DISTINCT tbl.ResourceID
			,tbl.HomeValue
			,tbl.AwayValue
			,sp.BetType, sp.BetID, sp.pfID
			,ISNULL(sp.OddsType,0)	
			,sp.RefResourceId
	FROM	@tmpResources tbl
		INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
			ON	sp.ResourceID = tbl.ResourceID
		INNER JOIN @tmpAffectedBettypes ab
			ON ab.Bettype = sp.BetType
	WHERE	sp.SportType = @SportType
			AND 1 = CASE	
						WHEN @action IN ('CAL', 'CAL-FT') AND @isRefundHT = 1 AND sp.Is3x30 = 1 AND sp.GroupType = 'FT' THEN 0 
						ELSE 1
					END
			AND sp.SettleType = 'MNL'
			AND sp.pfID > 0

	INSERT INTO dbo.SettlementBettypeResult (MatchId, Bettype, pfId, HomeValue, AwayValue, OddsType, SessionId)
	SELECT	@MatchId AS MatchId
			,BetType
			,pfID
			,HomeValue
			,AwayValue
			,OddsType
			,@SessionId
	FROM	#tmpSelectedRID
		
	IF @ChildMatchType = 204
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
										WHEN hdp1 < 10 THEN '0' ELSE '' END + CAST(CAST(hdp1 AS INT) AS VARCHAR) 
							ELSE '' 
						END AS ResouceId
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	bettype BETWEEN 486 AND 490
					AND matchid = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND EXISTS (SELECT TOP 1 1 FROM #tmpSelectedRID s WHERE s.BetType = b.bettype) 
			GROUP BY bettype
					,CAST(bettype AS VARCHAR) 
						+ CASE 
							WHEN bettype IN (486,487) 
								THEN CASE
										WHEN hdp1 < 10 THEN '0' ELSE '' END + CAST(CAST(hdp1 AS INT) AS VARCHAR) 
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
			SELECT	r.ResourceID
					,r.HomeValue
			FROM	@tmpCornerBettype b
				CROSS APPLY (SELECT (CAST(b.bettype AS VARCHAR) + ResourceID) AS ResourceID
								, HomeValue
							FROM @tmpCornerRaceToResult r
							WHERE 1 = CASE 
											WHEN b.bettype = 487 AND Index_Round = 1 THEN 1
											WHEN b.bettype = 487 AND Index_Round = 2 THEN 0
											ELSE 1
										END	
							
							) AS r
			WHERE b.bettype IN (486,487) 
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
	
	IF @action = 'CAL'
	BEGIN		
		SELECT @strCashoutBettype = STUFF((SELECT ',' + CAST(f.bettype AS VARCHAR(50)) 
											FROM	dbo.f_Set_GetCashOutBettypes() f 
											FOR XML PATH('')),1,1,'')
	END
	ELSE IF @action = 'CAL-FT'
	BEGIN
		SELECT @strCashoutBettype = STUFF((SELECT ',' + CAST(f.bettype AS VARCHAR(50)) 
											FROM	dbo.f_Set_GetCashOutBettypes() f 
											WHERE	f.GroupName = 'FT'
											FOR XML PATH('')),1,1,'')
	END
	ELSE IF @action = 'CAL-HT'
	BEGIN
		SELECT @strCashoutBettype = STUFF((SELECT ',' + CAST(f.bettype AS VARCHAR(50)) 
											FROM	dbo.f_Set_GetCashOutBettypes() f 
											WHERE	f.GroupName = 'HT'
											FOR XML PATH('')),1,1,'')
	END

	INSERT INTO #tmpCustIds (CustId, TotalTicket)
	SELECT	CustId, SUM(TotalTicket)
	FROM	#tmpCustBettypes
	GROUP BY CustId
	ORDER BY CustId

	SELECT @TotalAffectedTicket = SUM(TotalTicket)
	FROM	#tmpCustIds
	
	SET @TicketCount = @TotalAffectedTicket

	EXEC dbo.NAP_Set_GlobalSettingSel	
		@LockName = 'SettlementSSB'
		,@PrepareDataQueueSize =  @PrepareDataQueueSize OUTPUT
		,@RunPrepareDataBySSB = @RunPrepareDataBySSB OUTPUT
		,@MaxThreadHold = @MaxThreadHold OUTPUT
		,@MinThreadHold = @MinThreadHold OUTPUT

	SELECT @ThreadHold = CASE 
							WHEN @TotalAffectedTicket > @MaxThreadHold * @PrepareDataQueueSize THEN @MaxThreadHold 
							WHEN @TotalAffectedTicket/@PrepareDataQueueSize <= @MinThreadHold THEN @MinThreadHold
							ELSE @TotalAffectedTicket/@PrepareDataQueueSize 
						END
		,@QueueNo = 0
		,@BatchNo = 0
	
	UPDATE	#tmpCustIds
		SET runningtotal = @TotalTicket  
			,@TotalTicket = CASE WHEN @TotalTicket + TotalTicket >= @ThreadHold THEN TotalTicket ELSE @TotalTicket + TotalTicket END
			,BatchNo = @batchNo
			,@batchNo = CASE WHEN @TotalTicket = TotalTicket THEN @BatchNo + 1 ELSE @batchNo END
	OPTION (MAXDOP 1)

	;WITH cteBatchNo
	AS(
		SELECT	BatchNo, MIN(custid) minCustId, MAX(custid) maxCustId
		FROM	#tmpCustIds
		GROUP BY BatchNo
	)
	INSERT INTO @tmpBatchMinMaxCustId (BatchNo, MinCustId, MaxCustId)	
	SELECT BatchNo
			,MIN(mincustId)
			,MAX(maxcustid)
	FROM cteBatchNo
	GROUP BY BatchNo
	
	SET @Params =  ' IsCentral=''' + CAST(@IsCentral AS VARCHAR(1)) + ''''

	SET @ParamsXML =  CAST('<root><r ' + REPLACE(@Params,'''','"') + ' /></root>' AS XML)

	EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
		,@mode = 'LockMatch'
		,@IsSettingByProfile = 1
		,@SessionId = @SessionId	
		
	IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT_' 
		OR @RunPrepareDataBySSB = 0
	BEGIN
		SELECT	@MinCustId = MIN(CustId)
				,@MaxCustId = MAX(CustId)
		FROM #tmpCustIds

		INSERT INTO dbo.SettlementProcessing (TransIds, modds, IsMarked, OddsType, MessageType, SessionId,ActionId)	
		SELECT '', 0,0,0,'',@SessionId,0

		SET @SettlementProcessingId = SCOPE_IDENTITY()

		EXEC dbo.NAP_Admin_Settlement_Queue @matchid = @matchid
			,@action  = @action
			,@MinCustId = @MinCustId
			,@MaxCusId = @MaxCustId
			,@IsReSettledTickets = @IsReSettledTickets
			,@QueueNo  = 1
			,@SessionId  = @SessionId
			,@ActionId  = @ActionID
			,@Params = @ParamsXML
			,@SettlementProcessingId  = @SettlementProcessingId
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT

	END
	ELSE
	BEGIN
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

			SET @messageBody = CAST((SELECT @matchid AS '@MatchId'
											,@action AS '@Action'
											,@MinCustId AS '@MinCustId'
											,@MaxCustId AS '@MaxCustId'
											,@IsReSettledTickets AS '@IsReSettledTickets'
											,@QueueNo AS '@QueueNo'
											,@SessionId AS '@SessionId'
											,@ActionID AS '@ActionID'
											,@SettlementProcessingId AS '@SettlementProcessingId'
											,@Params AS '@Params'
									FOR XML PATH('r'), ROOT('root')
									) AS VARCHAR(MAX))

			SELECT @MessageType = @MessageTypePattern + CASE WHEN @QueueNo < 10 THEN '0' ELSE '' END + CAST(@QueueNo AS VARCHAR)
		
			EXEC [dbo].[SSB_Send_Message] @MessageContent = @messageBody
				, @FunctionName = 'settlement'
				, @MessageType = @MessageType 
		
			SET @BatchNo = @BatchNo + 1
			SET @QueueNo = CASE WHEN @QueueNo >= @PrepareDataQueueSize THEN 1 ELSE @QueueNo + 1 END
		END
	END

	IF @strCashoutBettype <> ''
	BEGIN
		INSERT INTO @tmpCashoutTransId(TransId, statuswinlost, custid, bettype, betteam, hdp1, hdp2, WalletType, BonusID, balance, livehomescore, liveawayscore, currentStatuswinlost)
		SELECT	b.transid, NULL, b.custid, b.bettype, b.betteam, b.hdp1, b.hdp2, ISNULL(b.WalletType,2)
				,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
				,(b.winlost - b.actual_stake + b.playercomm) AS balance
				,b.livehomescore, b.liveawayscore
				,b.statuswinlost
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	matchid = @matchid
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND b.statusID NOT IN (101)
				AND ISNULL(b.betdaqid,0) = - 2
				AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strCashoutBettype + ',') > 0

		IF EXISTS (SELECT TOP 1 1 FROM @tmpCashoutTransId)
		BEGIN
			UPDATE t 
				SET winlost = ISNULL(c.Winlost,0)
			FROM	@tmpCashoutTransId t
				INNER JOIN dbo.CashOutSelling c WITH(NOLOCK)
					ON t.TransId = c.TransID

			UPDATE t 
				SET statuswinlost = CASE 
										WHEN m.modds > 0.25 THEN 2
										WHEN m.modds = 0.25 THEN 1
										WHEN m.modds = 0 THEN 0
										WHEN m.modds = -0.25 THEN 3
										ELSE 4
									END
			FROM	@tmpCashoutTransId t
				INNER JOIN SettlementBettypeResult sr WITH(NOLOCK)
	  				ON	sr.BetType = t.bettype
						AND sr.matchid = @matchid
				CROSS APPLY dbo.f_Set_Calculate_modds_major(sr.pfID, t.betteam, t.hdp1, t.hdp2, sr.HomeValue, sr.AwayValue, t.livehomescore, t.liveawayscore, NULL, NULL) m
			WHERE	sr.SessionId = @SessionId

			DELETE 
			FROM	@tmpCashoutTransId
			WHERE	currentStatuswinlost IS NOT NULL
					AND currentStatuswinlost = statuswinlost
			
			IF EXISTS (SELECT TOP 1 1 FROM @tmpCashoutTransId)
			BEGIN 
				INSERT INTO @BalanceWalletBefore (matchid, custid, balanceType, WalletType, BonusID, balance)
				SELECT	@matchid, custid, balanceType, WalletType, BonusID, SUM(balance)
				FROM	@tmpCashoutTransId
				GROUP BY	custid, balanceType, WalletType, BonusID

				WHILE (1=1)
				BEGIN
					DELETE @tmpTransIDBatch
					SET @strTransIds = ''

					UPDATE	TOP (2000) t
						SET isFinished = 1
					OUTPUT deleted.TransId, deleted.statuswinlost, deleted.winlost INTO @tmpTransIDBatch(TransID, statuswinlost, winlost)
					FROM	@tmpCashoutTransId t
					WHERE	isFinished = 0					

					IF @@ROWCOUNT = 0
						BREAK

					SET @strTransIds = (SELECT transid	AS '@t'
												,winlost	AS '@w'	
												,statuswinlost AS '@s'
										FROM @tmpTransIDBatch
										FOR XML PATH('r'), ROOT( 'root' ))

					EXEC dbo.NAP_Admin_Calculate_Main
						@matchid	  = @matchid
						,@action	  = 'Cashout'
						,@mode		  = 'CAL'
						,@strTransIds = @strTransIds
				END

				INSERT INTO @BalanceWalletAfter (matchid, custid, balanceType, WalletType, BonusID, balance)
				SELECT	@matchid, t.custid, t.balanceType, t.WalletType, t.BonusID, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	@tmpCashoutTransId t
					INNER JOIN dbo.bettrans b WITH(NOLOCK)
						ON t.TransId = b.transid
				GROUP BY	t.custid, t.balanceType, t.WalletType, t.BonusID			
		
				-- Compare and update pending balance with error case
				EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					@BalanceWalletBefore	= @BalanceWalletBefore
					,@BalanceWalletAfter	= @BalanceWalletAfter
					,@ActionId				= @ActionID		
			END
		END
	END

	-- parlay
	INSERT INTO @tmpParlayAffectedBettypes(bettype, totalticket)
	SELECT 	bm.bettype, COUNT(1) AS totalticket
	FROM	dbo.bettransm bm WITH(NOLOCK)
	WHERE	bm.matchid = @MatchID
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND bm.statusID NOT IN (101)
			AND 1 = CASE 
						WHEN @IsReSettledTickets = 0 AND bm.statusID IN (0,102) THEN 1
						WHEN @IsReSettledTickets = 1 THEN 1
						ELSE 0
					END
			AND EXISTS (SELECT	TOP 1 1
						FROM	@tmpAllBettypes t
						WHERE	t.BetType = bm.bettype
					)
	GROUP BY bm.bettype

	SELECT	@TotalSubParlay = SUM(totalticket)
	FROM	@tmpParlayAffectedBettypes

	IF @TotalSubParlay > 0
	BEGIN	
		-- insert dummy resouceid
		-----------------------------------------add more info-----------------------------------------
		SET @DummyResourceIds = ''
		SET @DummyResourceResults = ''

		SELECT	@DummyResourceIds = @DummyResourceIds + s.ResourceID + ','
		FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			INNER JOIN @tmpParlayAffectedBettypes t
				ON s.BetType = t.BetType
			LEFT JOIN @tmpAffectedBettypes st
				ON s.BetType = st.Bettype
		WHERE	s.SportType = @sportType
				AND s.SettleType = 'MNL'
				AND s.RefResourceId IS NOT NULL
				AND st.Bettype IS NULL

		IF @DummyResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@WebResourceResult = @WebResourceResult
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResources(ResourceID, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
													,Home VARCHAR(2000)
													,Away VARCHAR(2000)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END

		;WITH cteSelectedRID
		AS (
			SELECT DISTINCT tbl.ResourceID
					,tbl.HomeValue
					,tbl.AwayValue
					,sp.BetType
					,sp.pfID
					,sp.RefResourceId
			FROM	@tmpResources tbl
				INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
					ON	sp.ResourceID = tbl.ResourceID
				INNER JOIN @tmpParlayAffectedBettypes ab
					ON	sp.BetType = ab.Bettype
			WHERE	sp.SportType = @SportType
					AND 1 = CASE	
								WHEN @action IN ('CAL', 'CAL-FT') AND @isRefundHT = 1 AND sp.Is3x30 = 1 AND sp.GroupType = 'FT' THEN 0 
								ELSE 1
							END
					AND sp.SettleType = 'MNL'
					AND sp.pfID > 0
		)
		SELECT @SelectedResourceParlay = CAST((SELECT ResourceID AS '@Id'
											,CASE WHEN RefResourceId IS NOT NULL THEN RefResourceId ELSE NULL END AS '@RefResourceId' 
											,bettype AS '@Bettype'
											,pfid	AS '@pfId'
											,HomeValue AS '@Home'
											,AwayValue AS '@Away'
									FROM	cteSelectedRID
									FOR XML PATH ('Resource'), ROOT('Resources'), TYPE) AS VARCHAR(MAX))
			
		EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHoldRefno OUTPUT

		IF @TotalSubParlay <= @ThreadHold
			SET @LockedByRefno = 1

		SET	@sqlCommand =  'EXEC [dbo].[NAP_Admin_Settlement_Profile_Parlay] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
								+ ', @creator = ' + CONVERT(NVARCHAR(50), @creator) 												
								+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResourceParlay) + ''''														
								+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 														
								+ ', @IsReSettledTickets = ' + CONVERT(VARCHAR(1), @IsReSettledTickets) 	
								+ ', @IsCentral = ' + CONVERT(VARCHAR(1), @IsCentral) 	
								+ ', @ErrCode = @ErrCode OUTPUT' 
								+ ', @ErrMsg = @ErrMsg OUTPUT'

		IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT[1-9]'
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Profile_Parlay
				@creator			= @creator
				,@MatchID			= @MatchId
				,@Action		  	= @Action
				,@SelectedResources = @SelectedResourceParlay
				,@IsReSettledTickets = @IsReSettledTickets
				,@LockedByRefno		= 1 -- always lock refno for testing
				,@IsCentral			= @IsCentral

				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg 			= @ErrMsg OUTPUT
		END
		ELSE
		BEGIN
			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype, LockedByRefno, BroadcastSessionId)
			SELECT @MatchID, 0, @creator, '', CURRENT_TIMESTAMP, @action, @sqlCommand, @sportType, @LockedByRefno, @BroadcastSessionId + '_parlay'
		END
	END
	ELSE
	BEGIN
		--UPDATE dbo.TicketVoiding_AutoVoidRequest_Queue  WITH (ROWLOCK, UPDLOCK)
		--	SET StatusId = 0, Starttime = GETDATE()
		--WHERE MatchId = @matchid
		--	AND Action = 'MixParlay'
		--	AND StatusId IN (99,100) --99: Running Event, 100: Completed Event

		INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue (RequestId, MatchId, sporttype, StatusId, UserId, Ip, starttime, action, BroadcastSessionId)
		SELECT 0, @MatchId, @sporttype, 0,10278938,'125.227.140.97', GETDATE(), 'CAL-PAR', @BroadcastSessionId + '_parlay'
	END
END
