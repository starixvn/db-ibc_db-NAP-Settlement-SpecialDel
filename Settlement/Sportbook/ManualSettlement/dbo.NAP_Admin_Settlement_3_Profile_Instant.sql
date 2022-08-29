/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Profile_Instant] 
	@matchid INT
	,@hth INT = 0
	,@hta INT = 0
    ,@action VARCHAR(6) = 'CAL-HT'
	,@ActionID	INT = 0
	,@creator INT = 0
	,@SessionId	BIGINT = NULL
	,@TicketCount INT = 0 OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
AS
/*
    Created: 20220418@Kathy
    Task : Covered SP for settlement
    DB: DBTXN/bodb02

    Revisions:
	   - 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
	   - 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

*/
BEGIN
    SET NOCOUNT ON;

	DECLARE @sporttype		SMALLINT			
			,@handle		INT			
			,@MessageTypePattern VARCHAR(200)
			,@PrepareDataQueueSize	SMALLINT
			,@QueueNo		SMALLINT
			,@BatchNo		INT 
			,@TotalTicket	INT
			,@MessageType	VARCHAR(50)	
			,@ThreadHold	INT
			,@IsExistCashout BIT
			
			,@MessageBody VARCHAR(MAX)
			,@MinCustId int
			,@MaxCustId int
			,@SettlementProcessingId BIGINT
			,@SPName NVARCHAR(128)
			,@RunPrepareDataBySSB BIT
			,@strTransIds	VARCHAR(MAX)
			,@TotalSubParlay INT
			,@SelectedResourceParlay VARCHAR(MAX) 
			,@ThreadHoldRefno	INT 
			,@LockedByRefno		BIT
			,@sqlCommand		VARCHAR(MAX)
			,@ParamsXML			XML
			,@Params			VARCHAR(MAX)

			,@DummyResourceIds		VARCHAR(MAX) 
			,@DummyResourceResults VARCHAR(MAX)
			,@IsCentral	BIT
			
	DECLARE @tmpResources TABLE(
		ResourceID VARCHAR(20)
		,SDTResourceId VARCHAR(20)
		,HomeValue VARCHAR(2000)
		,AwayValue VARCHAR(2000)
	)
	DECLARE @tmpAllBettypes TABLE (Bettype SMALLINT PRIMARY KEY, ResourceId VARCHAR(20), SDTResourceId VARCHAR(20), SDTpfId SMALLINT, OddsType TINYINT, RefResourceId VARCHAR(20))
	DECLARE @tmpAffectedBettypes TABLE (Bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, winlost MONEY, statuswinlost TINYINT)	
	DECLARE @tmpBatchMinMaxCustId TABLE (BatchNo INT, MinCustId INT, MaxCustId INT)
	DECLARE @tmpParlayAffectedBettypes TABLE (bettype SMALLINT, totalticket INT, DeterminedType TINYINT DEFAULT(0))	
	DECLARE @tmpCashoutTransId AS TABLE (TransId BIGINT, winlost MONEY DEFAULT(0), statuswinlost TINYINT, custid INT, balanceType TINYINT, WalletType TINYINT, BonusID INT, balance MONEY
		, bettype SMALLINT, betteam VARCHAR(50), hdp1 SMALLMONEY, hdp2 SMALLMONEY,livehomescore SMALLINT, liveawayscore SMALLINT, isFinished BIT DEFAULT(0))
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange

	CREATE TABLE #tmpSettlementProcessing (CustIds VARCHAR(MAX), QueueNo SMALLINT)	
	CREATE TABLE #tmpCustBettypes (CustId INT, Bettype SMALLINT, TotalTicket INT)
	CREATE TABLE #tmpCustIds (CustId INT PRIMARY KEY, BatchNo INT, TotalTicket INT, runningtotal int)
	CREATE TABLE #tmpSelectedRID (pfID SMALLINT, BetType SMALLINT, HomeValue VARCHAR(2000), AwayValue VARCHAR(2000), OddsType SMALLINT)	

	SELECT	@sporttype = 1
			,@DummyResourceIds = ''
			,@DummyResourceResults = ''
			,@MessageTypePattern = 'bet_settle_msg_type_prepare_'
			,@ThreadHold = 0
			,@QueueNo = 0
			,@BatchNo = 0
			,@TotalTicket = 0
			
			,@messageBody = ''
			,@SettlementProcessingId = 0
			,@SPName = OBJECT_NAME(@@PROCID)
			,@TotalSubParlay = 0
			,@ThreadHoldRefno = 0
			,@LockedByRefno = 0
			,@sqlCommand = ''
			,@IsCentral = 0
			
	IF @SessionId IS NULL
	BEGIN
		SELECT	@ErrCode = 1001017
				,@ErrMsg = 'The SessionId is missing.'

		RETURN
	END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	-- Get min/max custid
	BEGIN
		INSERT INTO @tmpAllBettypes(Bettype, SDTResourceId, SDTpfId, OddsType, ResourceId, RefResourceId)
		SELECT	DISTINCT s.BetType, s.SDTResourceId, s.SDTpfId, s.OddsType, s.ResourceId, s.RefResourceId
		FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
		WHERE	s.SportType = @sporttype
				AND s.SettleType = 'MNL'
				AND s.DeterminedType = 2

		INSERT INTO #tmpCustBettypes(CustId, Bettype, TotalTicket)
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
		
		;WITH cteAffectedBettypes
		AS (
			SELECT	Bettype
			FROM	#tmpCustBettypes
			GROUP BY Bettype
		)
		INSERT INTO @tmpAffectedBettypes(BetType)
		SELECT	bettype
		FROM	cteAffectedBettypes

		INSERT INTO #tmpCustIds (custId, totalticket)
		SELECT	custid, SUM(TotalTicket)
		FROM	#tmpCustBettypes b
		GROUP BY b.custid
		ORDER BY b.custid

		EXEC dbo.NAP_Set_GlobalSettingSel	
			@LockName = 'SettlementSSB'
			,@PrepareDataQueueSize =  @PrepareDataQueueSize OUTPUT
			,@RunPrepareDataBySSB = @RunPrepareDataBySSB OUTPUT
			,@MaxThreadHold = @ThreadHold OUTPUT

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
		SELECT BatchNo
				,MIN(mincustId)
				,MAX(maxcustid)
		FROM cteBatchNo
		GROUP BY BatchNo
	END

	-- Generate result
	BEGIN
		
		SELECT	@DummyResourceIds = @DummyResourceIds + CAST(s.SDTResourceId AS VARCHAR(20)) + ','
		FROM	@tmpAllBettypes s
		WHERE	s.SDTResourceId IS NOT NULL
				AND EXISTS (SELECT TOP 1 1 FROM @tmpAffectedBettypes b WHERE b.Bettype = s.BetType)
		
		IF @DummyResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@IsDetermined = 1
				,@Action = @Action
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResources (SDTResourceID, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
													,Home VARCHAR(2000)
													,Away VARCHAR(2000)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END
	
		INSERT INTO dbo.SettlementBettypeResult(MatchId, Bettype, pfId, HomeValue, AwayValue, OddsType, SessionId)
		SELECT @matchid, t.BetType, t.SDTpfId, t.HomeValue, t.AwayValue, t.OddsType, @SessionId
		FROM (
			SELECT	s.SDTpfId
					,s.BetType
					,t.HomeValue
					,t.AwayValue					
					,s.OddsType
			FROM    @tmpAllBettypes s 
				INNER JOIN @tmpResources t
					ON s.SDTResourceId = t.SDTResourceId
			WHERE	s.SDTResourceId IS NOT NULL
			UNION 
			SELECT	s.SDTpfId
					,s.BetType				
					,CAST(@hth AS VARCHAR(2000)) AS HomeValue
					,CAST(@hta AS VARCHAR(2000)) AS AwayValue
					,s.OddsType
			FROM	@tmpAllBettypes s
			WHERE	s.SDTResourceId IS NULL
		) t
		WHERE  EXISTS (SELECT TOP 1 1 FROM @tmpAffectedBettypes b WHERE b.Bettype = t.BetType)

	END
	
	SET @Params = CASE WHEN @hth IS NOT NULL THEN ' hth=''' + CAST (@hth AS VARCHAR(20)) + '''' ELSE '' END
					+ CASE WHEN @hta IS NOT NULL THEN ' hta=''' + CAST (@hta AS VARCHAR(20)) + '''' ELSE '' END
					+ ' DeterminedType=''2''' 
					+ ' IsCentral=''' + CAST(@IsCentral AS VARCHAR(1)) + ''''

	SET @ParamsXML =  CAST('<root><r ' + REPLACE(@Params,'''','"') + ' /></root>' AS XML)

	EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
		,@mode = 'LockMatch'
		,@IsSettingByProfile = 1
		,@SessionId = @SessionId	
		
	IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT_' 
		OR @RunPrepareDataBySSB = 0
	BEGIN
		SELECT	@MinCustId = MIN(MinCustId)
				,@MaxCustId = MAX(MaxCustId)
		FROM @tmpBatchMinMaxCustId

		INSERT INTO dbo.SettlementProcessing (TransIds, modds, IsMarked, OddsType, MessageType, SessionId,ActionId)	
		SELECT '', 0,0,0,'',@SessionId,0

		SET @SettlementProcessingId = SCOPE_IDENTITY()

		EXEC dbo.NAP_Admin_Settlement_Queue @matchid = @matchid
			,@action  = @action
			,@MinCustId = @MinCustId
			,@MaxCusId = @MaxCustId
			,@IsReSettledTickets = 0
			,@QueueNo  = 1
			,@SessionId  = @SessionId
			,@ActionId  = @ActionID 
			,@SettlementProcessingId  = @SettlementProcessingId
			,@Params = @ParamsXML
			,@AffectedTicket = @TicketCount OUTPUT
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
											,@QueueNo AS '@QueueNo'
											,@SessionId AS '@SessionId'
											,@ActionID AS '@ActionID'
											,0 AS '@IsReSettledTickets'
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

	-- CO
	BEGIN
		INSERT INTO @tmpCashoutTransId(TransId, statuswinlost, custid, balanceType, WalletType, BonusID, balance)
		SELECT	b.transid
				,CASE 
					WHEN m.modds > 0.25 THEN 2
					WHEN m.modds = 0.25 THEN 1
					WHEN m.modds = 0 THEN 0
					WHEN m.modds = -0.25 THEN 3
					ELSE 4
				END
				,b.custid
				,1
				,ISNULL(b.WalletType,2)
				,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
				,(b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM	dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.SettlementBettypeResult s
				ON b.bettype = s.Bettype
			OUTER APPLY dbo.f_Set_SDT_modds(s.pfID, b.betteam, b.hdp1, b.hdp2, @hth, @hta, @hth, @hta, s.HomeValue, s.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, b.betcheck, 0) m
		WHERE	b.matchid = @matchid
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND b.statusID NOT IN (101)
				AND ISNULL(b.betdaqid,0) = - 2
				AND s.SessionId = @SessionId					
				AND m.modds IS NOT NULL
				AND b.statuswinlost IS NULL

		IF EXISTS (SELECT TOP 1 1 FROM @tmpCashoutTransId)
		BEGIN
			UPDATE t 
				SET winlost = ISNULL(c.Winlost,0)
			FROM	@tmpCashoutTransId t
				INNER JOIN dbo.CashOutSelling c WITH(NOLOCK)
					ON t.TransId = c.TransID
			
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

	INSERT INTO @tmpParlayAffectedBettypes(bettype, totalticket, DeterminedType)
	SELECT 	bm.bettype, COUNT(1) AS totalticket, 2 AS DeterminedType
	FROM	dbo.bettransm bm WITH(NOLOCK)
	WHERE	bm.matchid = @MatchId		
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND bm.statusID IN (0,102)
			AND EXISTS (SELECT TOP 1 1 FROM @tmpAllBettypes t WHERE t.Bettype = bm.bettype)
	GROUP BY bm.bettype

	SELECT	@TotalSubParlay = SUM(totalticket)
	FROM	@tmpParlayAffectedBettypes

	IF @TotalSubParlay > 0
	BEGIN	
		-- insert dummy resouceid
		-----------------------------------------add more info-----------------------------------------
		SET @DummyResourceIds = ''
		SET @DummyResourceResults = ''

		SELECT	@DummyResourceIds = @DummyResourceIds + CAST(s.SDTResourceId AS VARCHAR(20)) + ','
		FROM	@tmpAllBettypes s
		WHERE	s.SDTResourceId IS NOT NULL
				AND EXISTS (SELECT TOP 1 1 FROM @tmpParlayAffectedBettypes b WHERE b.Bettype = s.BetType)
				AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.SettlementBettypeResult sb WITH(NOLOCK) WHERE sb.BetType = s.BetType AND sb.SessionId = @SessionId)
	
		IF @DummyResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@IsDetermined = 1
				,@action = @action
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResources (SDTResourceID, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
													,Home VARCHAR(2000)
													,Away VARCHAR(2000)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END

		;WITH cteSelectedRID
		AS (
			SELECT	s.ResourceID
					,s.SDTpfId
					,s.BetType
					,t.HomeValue
					,t.AwayValue					
					,s.RefResourceId
			FROM	@tmpAllBettypes s
				INNER JOIN @tmpResources t
					ON s.SDTResourceId = t.SDTResourceId
			WHERE	s.SDTResourceId IS NOT NULL
					AND  EXISTS (SELECT TOP 1 1 FROM @tmpParlayAffectedBettypes b WHERE b.Bettype = s.BetType)
			UNION 
			SELECT	s.ResourceID
					,s.SDTpfId
					,s.BetType				
					,CAST(@hth AS VARCHAR(2000)) AS HomeValue
					,CAST(@hta AS VARCHAR(2000)) AS AwayValue
					,s.RefResourceId
			FROM	@tmpAllBettypes s
			WHERE	s.SDTResourceId IS NULL
					AND  EXISTS (SELECT TOP 1 1 FROM @tmpParlayAffectedBettypes b WHERE b.Bettype = s.BetType)
		)
		SELECT @SelectedResourceParlay = CAST((SELECT ResourceID AS '@Id'
											,CASE WHEN RefResourceId IS NOT NULL THEN RefResourceId ELSE NULL END AS '@RefResourceId' 
											,bettype AS '@Bettype'
											,SDTpfId AS '@SDTpfId'
											,HomeValue AS '@Home'
											,AwayValue AS '@Away'
											,2 AS '@DeterminedType'
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
								+ ', @hth = ' + CONVERT(NVARCHAR(50), @hth) 
								+ ', @hta = ' + CONVERT(NVARCHAR(50), @hta) 
								+ ', @IsReSettledTickets = 0'			
								+ ', @IsCentral = ' + CONVERT(VARCHAR(1), @IsCentral)
								+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
								+ ', @ErrCode = @ErrCode OUTPUT' 
								+ ', @ErrMsg = @ErrMsg OUTPUT'

		IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT[1-9]'
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Profile_Parlay
				@creator			= @creator
				,@MatchID			= @MatchId
				,@Action		  	= @Action
				,@SelectedResources = @SelectedResourceParlay
				,@IsReSettledTickets = 0
				,@hth				= @hth
				,@hta				= @hta
				,@LockedByRefno		= 1 -- always lock refno for testing
				,@IsCentral			= @IsCentral

				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg 			= @ErrMsg OUTPUT
		END
		ELSE
		BEGIN
			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype, LockedByRefno)
			SELECT @MatchID, 0, @creator, '', CURRENT_TIMESTAMP, 'SDT-FT', @sqlCommand, @sportType, @LockedByRefno
		END
	END
END
GO
