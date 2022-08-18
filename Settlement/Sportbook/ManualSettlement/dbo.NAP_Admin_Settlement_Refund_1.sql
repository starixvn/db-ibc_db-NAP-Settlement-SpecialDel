/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_1] 
     @matchid                       	INT
    ,@creator                       	INT
	,@SDTRecord							TINYINT			= 0
    ,@hth								INT             = NULL
    ,@hta                               INT             = NULL
    ,@fth                               INT             = NULL
    ,@fta                               INT             = NULL
    ,@GoalSequence                      VARCHAR(50)     = NULL 
    ,@betstatus                        	NVARCHAR(50)    = NULL
    
    ,@Action                            VARCHAR(10)     = 'REFUND'
    ,@ResourceResult					VARCHAR(MAX)	= NULL
    ,@IP                                VARCHAR(15)     = ''
	,@IsAuto							BIT				= 0
	,@KeyId								INT				= 0
    ,@ErrCode							INT             = 0      OUTPUT
    ,@ErrMsg                            NVARCHAR(200)   = ''        OUTPUT
AS
/*
    Created: Kathy
    Date: 20211215
    Task : refund tickets 
    DB: DBTXN/BODB02

    Revisions: 
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
    
    Param's Explanation:
	* @SDTRecord: Used to store a bitmap of these settings: (from right to left)
				bit[1]: Is Settlement for Betdaq ticket of Abandoned/postponed match or not
				bit[2]: Is Settlement for Betfair ticket of Abandoned/postponed match or not
				bit[3]: Is Settlement for IBC ticket of Abandoned/postponed match or not
				bit[4]: Is Exclude betdaq tickets or not
				bit[5]: Is Exclude betfair tickets or not
	
	* @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @starttime                          DATETIME
			,@ActionID                          INT
            ,@avaiableProcess					BIT
			
			,@Sporttype							SMALLINT
			,@handle							INT
			,@DummySDTResourceIds				VARCHAR(MAX) = ''
			,@DummySDTResourceResults			VARCHAR(MAX) = ''
			
			,@ChildMatchType					TINYINT
			,@IsRefundHT                        BIT
			,@IsABANDONEDHT						BIT
			 ,@movebet                          VARCHAR(20)
            ,@matchcode                         NVARCHAR(50)
			,@openquery							NVARCHAR(MAX)
			,@IsHedgeMatch						BIT
			
			,@ResourceResult_Corner_Result		VARCHAR(MAX) = NULL
			,@ResourceResult_Main_Result		VARCHAR(MAX) = NULL		
			,@IsSettleAbandonedMatchIBC			BIT
			
			,@SPName							NVARCHAR(128)
			,@TotalSubParlay					INT
			,@SelectedResourceParlay			VARCHAR(MAX) 
			,@ThreadHoldRefno					INT 
			,@LockedByRefno						BIT
			,@sqlCommand						VARCHAR(MAX)

			,@Params							VARCHAR(MAX)
			,@ParamsXML							XML
			,@TotalAffectedTicket				INT
			,@PrepareDataQueueSize				SMALLINT
			,@RunPrepareDataBySSB				BIT
			,@MaxThreadHold						INT
			,@MinThreadHold						INT
			,@ThreadHold						INT
			,@QueueNo							SMALLINT
			,@BatchNo							INT 
			,@TotalTicket						INT
			,@SessionId							BIGINT
			,@MinCustId							int
			,@MaxCustId							int
			,@SettlementProcessingId			BIGINT
			,@MessageBody						VARCHAR(MAX)
			,@MessageTypePattern				VARCHAR(200)
			,@MessageType						VARCHAR(50)	

			,@ModeCO							VARCHAR(20) 
			,@strTransIds						VARCHAR(MAX)

			,@LogData							XML
			,@CommandMonitor					NVARCHAR(MAX)
			,@SSBStatus							TINYINT
			,@IsCentral							BIT 	

	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange

	DECLARE @tmpMatchInfo TABLE (sporttype SMALLINT, betstatus VARCHAR(50), childmatchtype TINYINT, matchcode NVARCHAR(50), kickofftime DATETIME, HTSettlementStatusId TINYINT, HTResultStatusID TINYINT)
	DECLARE @tmpAllBettypes TABLE (Bettype SMALLINT PRIMARY KEY, ResourceId VARCHAR(20), RefResourceId VARCHAR(20), SDTResourceId VARCHAR(20), IsSDTParlay BIT DEFAULT(0), SDTpfId SMALLINT, OddsType SMALLINT)
	DECLARE @tmpAffectedBettypes TABLE (Bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpDummySDTResourceResults TABLE (SDTResourceId VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000))
	DECLARE @tmpBatchMinMaxCustId TABLE (BatchNo INT, MinCustId INT, MaxCustId INT)	
	DECLARE @tmpCashoutTransId AS TABLE (TransId BIGINT, winlost MONEY DEFAULT(0)
		, statuswinlost TINYINT, custid INT, balanceType TINYINT, WalletType TINYINT, BonusID INT, balance MONEY, IsFinished BIT DEFAULT(0)
		, currentStatuswinlost TINYINT)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, winlost MONEY, statuswinlost TINYINT)
	DECLARE @tmpParlayAffectedBettypes TABLE (
		ResourceId VARCHAR(20)
		, RefResourceId VARCHAR(20)
		, bettype SMALLINT
		, IsSDTParlay BIT
		, totalticket INT
		, SDTResourceId VARCHAR(20)
		, HomeValue VARCHAR(2000)
		, AwayValue VARCHAR(2000)
	)
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpSelectedRID (
		HomeValue		VARCHAR(2000)
		,AwayValue		VARCHAR(2000)
		,BetType		SMALLINT
		,SDTpfID		SMALLINT
		,OddsType		SMALLINT
		,PRIMARY KEY (BetType)
	)	
	CREATE TABLE #tmpCustBettypes (CustId INT, Bettype SMALLINT, TotalTicket INT)
	CREATE TABLE #tmpCustIds (CustId INT PRIMARY KEY, BatchNo INT, TotalTicket INT, runningtotal int)

	SELECT	@MessageTypePattern = 'bet_settle_msg_type_prepare_'
			,@MaxThreadHold = 0
			,@MinThreadHold = 0
			,@BatchNo = 0
			,@TotalTicket = 0
			
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

	SET @SDTRecord = CASE WHEN @SDTRecord & 1 > 0 AND @SDTRecord & 8 = 0 THEN @SDTRecord + 8 ELSE @SDTRecord END
	SET @SDTRecord = CASE WHEN @SDTRecord & 2 > 0 AND @SDTRecord & 16 = 0 THEN @SDTRecord + 16 ELSE @SDTRecord END

	SET @openquery = 'SELECT sporttype, betstatus, childmatchtype, matchcode, kickofftime, SettlementStatusId, ResultStatusID
					  FROM	OPENQUERY(DBPRO, ''SELECT m.sporttype, m.childmatchtype, m.matchcode, m.kickofftime, m.betstatus, r.SettlementStatusId, r.ResultStatusID
											   FROM bodb02.dbo.match m WITH(NOLOCK)
													LEFT JOIN bodb02.dbo.resultdetail r WITH(NOLOCK)
														ON	r.matchid = m.matchid
															AND r.resourceId =''''01''''
											   WHERE m.matchid = ' + CAST(@matchid AS VARCHAR)+ '
													'')'

	INSERT INTO @tmpMatchInfo(sporttype, betstatus, childmatchtype, matchcode, kickofftime, HTSettlementStatusId, HTResultStatusID)
	EXEC (@openquery)

    SELECT	@sporttype   	= m.SportType
			,@matchcode		= matchcode
			,@movebet		= CONVERT(VARCHAR(20), DATEADD(d, 1, m.kickofftime), 100)
			,@ChildMatchType = m.ChildMatchType
			,@IsABANDONEDHT = CASE WHEN @Action = 'REFUND' AND @SDTRecord & 4 > 0 THEN 1 ELSE 0 END
			,@IsRefundHT = CASE WHEN m.HTSettlementStatusId = 2 THEN 1 ELSE 0 END
			,@IsHedgeMatch = CASE WHEN m.matchcode LIKE '%hedge%' AND @SDTRecord & 4 > 0 THEN 1 ELSE 0 END 
			
    FROM    @tmpMatchInfo m
    
    SELECT  @starttime 		= CURRENT_TIMESTAMP
			,@ActionID 	= CASE 
							WHEN @action = 'REFUND'	THEN 109
							WHEN @action = 'REFUND-FT' THEN 111
							WHEN @Action = 'REFUND-HT' THEN 110
							ELSE 0
						END
			,@IsSettleAbandonedMatchIBC = CASE WHEN @SDTRecord & 4 > 0 THEN 1 ELSE 0 END
			
	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
		@MatchId	= @Matchid
		,@ErrCode	= @ErrCode OUTPUT
		,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0	    
		RETURN

	EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
		@MatchId	= @matchid
		,@Action	= @Action
		,@IsAutoRefund = @IsAuto
		,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
		,@ErrCode	= @ErrCode	OUTPUT
		,@ErrMsg	= @ErrMsg	OUTPUT

	IF @ErrCode > 0
		RETURN

	IF @IsAuto = 1
	BEGIN
		EXEC NAP_Set_AutoRefund_MatchChecking_Ticket
			@MatchId		= @matchid
			,@sporttype		= 1
			,@ErrCode 		= @ErrCode OUTPUT
			,@ErrMsg 		= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode,0) <> 0
			RETURN
	END

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

	EXEC dbo.NAP_Set_CheckingMarkedTransaction
		@MatchID  = @matchid
		,@Action  = @Action
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg  = @ErrMsg	OUTPUT

	IF @ErrCode <> 0
	BEGIN
		------ releasing Settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			, @IsReleased		= 1
			
		RETURN
	END 
   
   BEGIN TRY
		;WITH cteMainResource
		AS
		(
			SELECT	CAST('01' AS VARCHAR(20)) AS ResourceID
					,CAST( @hth AS VARCHAR(50)) AS HomeValue
					,CAST( @hta AS VARCHAR(50)) AS AwayValue
			WHERE	@action IN ('REFUND', 'REFUND-HT')
			UNION ALL
			SELECT 	CAST('00' AS VARCHAR(20)) AS ResourceID
					,CAST( @fth AS VARCHAR(50)) AS HomeValue
					,CAST( @fta AS VARCHAR(50)) AS AwayValue
			WHERE	@action IN ('REFUND', 'REFUND-FT')
			
		)
		SELECT	@ResourceResult_Main_Result = CAST((SELECT	ResourceID AS '@Id'
												,HomeValue AS '@HomeValue'
												,AwayValue AS '@AwayValue'
										FROM	cteMainResource
										FOR XML PATH('Resource'), ROOT ('Results'), TYPE
								) AS VARCHAR(MAX))

		SET @ResourceResult_Main_Result = @ResourceResult_Main_Result + @ResourceResult

		INSERT INTO @tmpAllBettypes(ResourceId, RefResourceId, SDTResourceId, BetType, SDTpfId, IsSDTParlay, OddsType)
		SELECT	sp.ResourceID, sp.RefResourceId, sp.SDTResourceId, sp.BetType
				,CASE WHEN @SDTRecord & 7 > 0 THEN sp.SDTpfId ELSE 0 END
				,CASE WHEN @IsSettleAbandonedMatchIBC = 1 THEN sp.IsSDT ELSE 0 END AS IsSDTParlay
				,ISNULL(sp.OddsType,0)	
		FROM	dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
		WHERE	SportType = @sportType
				AND sp.SettleType = 'MNL'
				AND 1 = CASE 
							WHEN @Action = 'REFUND-HT' AND sp.Is3x30 = 1 THEN 1
							WHEN @Action = 'REFUND-FT' AND sp.GroupType = 'FT' AND 1 = CASE WHEN @IsRefundHT = 1 AND sp.Is3x30 = 1 THEN 0 ELSE 1 END  THEN 1
							WHEN @Action = 'REFUND' THEN 1
							ELSE 0
						END
		
		INSERT INTO #tmpCustBettypes (CustId, Bettype, TotalTicket)
		SELECT	b.custid
				,b.bettype
				,COUNT(1) AS TotalTicket
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchid
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND EXISTS (SELECT TOP 1 1 FROM @tmpAllBettypes t WHERE t.Bettype = b.bettype)
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

		IF @SDTRecord & 7 = 0
		BEGIN
			SELECT @ResourceResult_Corner_Result = (
					SELECT DISTINCT 
							CASE 
								WHEN b.bettype IN (486, 487) THEN CAST(b.bettype AS VARCHAR) 
											+ CASE 
												WHEN b.hdp1 < 10 THEN '0' + CAST(CONVERT(INT, hdp1) AS VARCHAR) 
												ELSE CAST(CONVERT(INT,hdp1) AS VARCHAR) 
											END
								ELSE CAST(b.bettype AS VARCHAR) 
							END AS Id
							, '' AS HomeValue
							, 2 AS SettlementStatusId
							, 5 AS ResultStatusId
					FROM	dbo.bettrans b WITH (NOLOCK)
					WHERE	b.matchid= @matchid
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							AND 1 = CASE 
										WHEN @Action = 'REFUND-HT' AND b.bettype IN (487,489,490) THEN 1
										WHEN @Action = 'REFUND-FT' AND b.bettype IN (486,488,490) THEN 1
										WHEN @Action = 'REFUND' THEN 1
										ELSE 0
									END
							AND b.bettype IN (486,487,488,489,490)
					FOR XML RAW ('Resource'), ROOT ('Results')
			)
		END
		ELSE 
		BEGIN
			DECLARE @CornerResultString VARCHAR(50)
				,@Position				TINYINT
				,@HomeRaceTo			TINYINT
				,@AwayRaceTo			TINYINT
				,@LenResultString		TINYINT
				,@hdp					VARCHAR(5) = ''
				,@Index_Round_tmp		TINYINT = 0
				,@Index_Round			TINYINT = 1
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
						AND EXISTS (SELECT TOP 1 1 FROM @tmpAffectedBettypes s WHERE s.BetType = b.bettype) 
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
				SELECT	@CornerResultString = ISNULL(CASE WHEN LEFT(@GoalSequence, 1) = ';' THEN SUBSTRING(@GoalSequence,2,LEN(@GoalSequence) - 1) ELSE @GoalSequence END, '')
						,@Position = 1
						,@HomeRaceTo = 0
						,@AwayRaceTo = 0					
				
				SELECT @LenResultString = LEN(@CornerResultString)

				SET @Index_Round_tmp =  CASE WHEN CHARINDEX(';',@GoalSequence) = 0 THEN LEN(@GoalSequence) + 1 ELSE CHARINDEX(';',@GoalSequence) END

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
		END
	
		SELECT @ResourceResult = ISNULL(@ResourceResult,'') + ISNULL(@ResourceResult_Corner_Result,'')

		EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
			@Command        = 'NAP_Admin_Settlement_1_InstantCalculation-CAL', -- reuse inst command
			@MatchID        = @MatchID,                  
			@ResourceResult	= @ResourceResult_Corner_Result,                    
			@creator        = @creator

		SELECT	@DummySDTResourceIds = @DummySDTResourceIds + CAST(a.SDTResourceId AS VARCHAR(20)) + ','
		FROM	@tmpAllBettypes a 
			INNER JOIN @tmpAffectedBettypes t
				ON a.BetType = t.Bettype
		WHERE	a.SDTResourceId IS NOT NULL
		
		IF @DummySDTResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@WebResourceResult = @ResourceResult_Main_Result
				,@IsDetermined = 1
				,@DummyResourceIds = @DummySDTResourceIds
				,@DummyResourceResults = @DummySDTResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummySDTResourceResults
			INSERT INTO @tmpDummySDTResourceResults(SDTResourceId, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
													,Home VARCHAR(2000)
													,Away VARCHAR(2000)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END

		-- insert selectedRid
		INSERT INTO #tmpSelectedRID(
			HomeValue
			,AwayValue
			,BetType
			,SDTpfID
			,OddsType	
		)
		SELECT	t.HomeValue
				,t.AwayValue
				,a.BetType
				,ISNULL(a.SDTpfId,0)
				,ISNULL(a.OddsType,0)
		FROM	@tmpAllBettypes a
			INNER JOIN @tmpAffectedBettypes ab
				ON ab.Bettype = a.BetType
			OUTER APPLY (
				SELECT	t.HomeValue, t.AwayValue
				FROM	@tmpDummySDTResourceResults t
				WHERE	t.SDTResourceId = a.SDTResourceId
						AND a.SDTResourceId IS NOT NULL
			)t
			
		INSERT INTO dbo.Settlement_SettledSession (MatchId)
		SELECT @matchid
		SET @SessionId = SCOPE_IDENTITY()

		INSERT INTO dbo.SettlementBettypeResult (MatchId, Bettype, pfId, HomeValue, AwayValue, OddsType, SessionId)
		SELECT	@MatchId AS MatchId
				,BetType
				,SDTpfID
				,HomeValue
				,AwayValue
				,OddsType
				,@SessionId
		FROM	#tmpSelectedRID

		INSERT INTO #tmpCustIds (CustId, TotalTicket)
		SELECT	CustId, SUM(TotalTicket)
		FROM	#tmpCustBettypes
		GROUP BY CustId
		ORDER BY CustId

		SELECT @TotalAffectedTicket = SUM(TotalTicket)
		FROM	#tmpCustIds

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

		SET @Params = CASE WHEN @fth IS NOT NULL THEN 'fth=''' + CAST (@fth AS VARCHAR(20)) + '''' ELSE '' END
						+ CASE WHEN @fta IS NOT NULL THEN ' fta=''' + CAST (@fta AS VARCHAR(20)) + '''' ELSE '' END
						+ CASE WHEN @hth IS NOT NULL THEN ' hth=''' + CAST (@hth AS VARCHAR(20)) + '''' ELSE '' END
						+ CASE WHEN @hta IS NOT NULL THEN ' hta=''' + CAST (@hta AS VARCHAR(20)) + '''' ELSE '' END
						+ CASE WHEN @SDTRecord IS NOT NULL THEN ' SDTRecord=''' + CAST (@SDTRecord AS VARCHAR(20)) + '''' ELSE '' END
						+ CASE WHEN @IsHedgeMatch IS NOT NULL THEN ' IsHedgeMatch=''' + CAST (@IsHedgeMatch AS VARCHAR(1)) + '''' ELSE '' END
						+ CASE WHEN @IsABANDONEDHT IS NOT NULL THEN ' IsABANDONEDHT=''' + CAST (@IsABANDONEDHT AS VARCHAR(1)) + '''' ELSE '' END
						+ ' IsCentral=''' + CAST(@IsCentral AS VARCHAR(1)) + ''''
		
		EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
			,@mode = 'LockMatch'
			,@IsSettingByProfile = 1
			,@SessionId = @SessionId	
	
		IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT_' 
			OR @RunPrepareDataBySSB = 0
		BEGIN
			SET @ParamsXML =  CAST('<root><r ' + REPLACE(@Params,'''','"') + ' /></root>' AS XML)
			
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
				,@IsReSettledTickets = 1
				,@QueueNo  = 1
				,@SessionId  = @SessionId
				,@ActionId  = @ActionID
				,@SettlementProcessingId  = @SettlementProcessingId
				,@Params = @ParamsXML
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
												,1 AS '@IsReSettledTickets'
												,@QueueNo AS '@QueueNo'
												,@SessionId AS '@SessionId'
												,@ActionID AS '@ActionID'
												,@SettlementProcessingId AS '@SettlementProcessingId'
												,@Params AS '@Params'
										FOR XML PATH('r'), ROOT('root'), TYPE
										) AS VARCHAR(MAX))
				
				SELECT @MessageType = @MessageTypePattern + CASE WHEN @QueueNo < 10 THEN '0' ELSE '' END + CAST(@QueueNo AS VARCHAR)
		
				EXEC [dbo].[SSB_Send_Message] @MessageContent = @messageBody
					, @FunctionName = 'settlement'
					, @MessageType = @MessageType 
		
				SET @BatchNo = @BatchNo + 1
				SET @QueueNo = CASE WHEN @QueueNo >= @PrepareDataQueueSize THEN 1 ELSE @QueueNo + 1 END
			END
		END

		INSERT INTO @tmpCashoutTransId(TransId, statuswinlost, custid, balanceType, WalletType, BonusID, balance, currentStatuswinlost)
		SELECT	b.transid
				,CASE 
					WHEN @SDTRecord & 4 > 0 
						THEN CASE 
								WHEN m.modds > 0.25 THEN 2
								WHEN m.modds = 0.25 THEN 1
								WHEN m.modds = 0 THEN 0
								WHEN m.modds = -0.25 THEN 3
								WHEN m.modds < -0.25 THEN 4
								ELSE 6
							END
					ELSE 6
				END
				,b.custid
				,1
				,ISNULL(b.WalletType,2)
				,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
				,(b.winlost - b.actual_stake + b.playercomm) AS balance
				,b.statuswinlost
		FROM	dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.f_Set_GetCashoutBettypes() f
				ON b.bettype = f.bettype
			INNER JOIN dbo.SettlementBettypeResult s
				ON b.bettype = s.Bettype
			OUTER APPLY dbo.f_Set_SDT_modds(s.pfID, b.betteam, b.hdp1, b.hdp2, @hth, @hta, @fth, @fta, s.HomeValue, s.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, b.betcheck, @IsABANDONEDHT) m
		WHERE	b.matchid = @matchid
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND b.statusID NOT IN (101)
				AND ISNULL(b.betdaqid,0) = - 2
				AND s.SessionId = @SessionId		

		DELETE 
		FROM	@tmpCashoutTransId
		WHERE	currentStatuswinlost IS NOT NULL
				AND currentStatuswinlost = statuswinlost

		IF EXISTS (SELECT TOP 1 1 FROM @tmpCashoutTransId)
		BEGIN
			UPDATE t 
				SET winlost = c.Winlost
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
				SET @ModeCO = 'REFUND'

				UPDATE 	TOP (2000) t
					SET isFinished = 1
				OUTPUT deleted.TransId, deleted.statuswinlost, deleted.winlost INTO @tmpTransIDBatch(TransID, statuswinlost, winlost)
				FROM	@tmpCashoutTransId t					
				WHERE	statuswinlost = 6
						AND isfinished = 0

				IF @@ROWCOUNT = 0
				BEGIN
					SET @ModeCO = 'CAL'

					UPDATE 	TOP (2000) t
						SET isFinished = 1
					OUTPUT deleted.TransId, deleted.statuswinlost, deleted.winlost INTO @tmpTransIDBatch(TransID, statuswinlost, winlost)
					FROM	@tmpCashoutTransId t						
					WHERE	statuswinlost <> 6
							AND isFinished = 0

					IF @@ROWCOUNT = 0
						BREAK
				END

				SET @strTransIds = (SELECT transid	AS '@t'
											,winlost	AS '@w'	
											,statuswinlost AS '@s'
									FROM @tmpTransIDBatch
									FOR XML PATH('r'), ROOT( 'root' ))

				EXEC dbo.NAP_Admin_Calculate_Main
					@matchid	  = @matchid
					,@action	  = 'Cashout'
					,@mode		  = @ModeCO
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

		IF @IsCentral = 1
		BEGIN
			IF @IsAuto = 1
			BEGIN
				EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefund_ResultUpd
				@MatchId = @matchid
				, @TypeId  = 1
				, @StatusId = 2
			END
		END

		INSERT INTO @tmpParlayAffectedBettypes(ResourceId, RefResourceId, SDTResourceId, bettype, IsSDTParlay, totalticket)
		SELECT	a.ResourceID, a.RefResourceId, a.SDTResourceId, bm.bettype, ISNULL(a.IsSDTParlay,0), COUNT(1)		
		FROM	dbo.bettransm bm WITH(NOLOCK)
			INNER JOIN @tmpAllBettypes a
				ON bm.bettype = a.BetType
		WHERE	bm.matchid = @MatchID
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND bm.statusID NOT IN (101)
				AND 1 = CASE WHEN @IsSettleAbandonedMatchIBC = 0 AND bm.statusID = 103  THEN 0 ELSE 1 END 
		GROUP BY a.ResourceID, a.RefResourceId, a.SDTResourceId, bm.bettype, a.IsSDTParlay

		IF @@ROWCOUNT > 0
		BEGIN		
			SELECT	@TotalSubParlay = SUM(totalticket)
			FROM	@tmpParlayAffectedBettypes

			SET @DummySDTResourceIds = ''

			SELECT	@DummySDTResourceIds = @DummySDTResourceIds + CAST(s.SDTResourceId AS VARCHAR(20)) + ','
			FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				INNER JOIN @tmpParlayAffectedBettypes t
					ON s.ResourceId = t.ResourceId
			WHERE	s.SportType = @sportType
					AND s.SDTResourceId IS NOT NULL
			
			IF @DummySDTResourceIds <> ''
			BEGIN
				EXEC dbo.NAP_Set_DummyResourceResult
					@MatchID = @MatchID
					,@sportType = @sportType
					,@WebResourceResult = @ResourceResult_Main_Result
					,@IsDetermined = 1
					,@DummyResourceIds = @DummySDTResourceIds
					,@DummyResourceResults = @DummySDTResourceResults OUTPUT
				
				DELETE FROM @tmpDummySDTResourceResults

				EXEC sp_xml_preparedocument @handle OUTPUT, @DummySDTResourceResults
				INSERT INTO @tmpDummySDTResourceResults(SDTResourceId, HomeValue, AwayValue)
				SELECT Id, Home, Away
				FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
																	,Home VARCHAR(2000)
																	,Away VARCHAR(2000)
													) AS tbl
				EXEC sp_xml_removedocument @handle

				UPDATE t 
					SET HomeValue = d.HomeValue
						,AwayValue = d.AwayValue
				FROM	@tmpParlayAffectedBettypes t
					INNER JOIN @tmpDummySDTResourceResults d
						ON t.SDTResourceId = d.SDTResourceId
			END

			SELECT @SelectedResourceParlay = CAST((SELECT ResourceID AS '@Id'
												,CASE WHEN RefResourceId IS NOT NULL THEN RefResourceId ELSE NULL END AS '@RefResourceId' 
												,bettype AS '@Bettype'			
												,IsSDTParlay AS '@IsSDT'
												,SDTResourceId AS '@SDTResourceId'
												,HomeValue AS '@Home'
												,AwayValue AS '@Away'
										FROM	@tmpParlayAffectedBettypes
										FOR XML PATH ('Resource'), ROOT('Resources'), TYPE) AS VARCHAR(MAX))
			
			EXEC dbo.NAP_Set_GlobalSettingSel 
				@LockName = 'ParlayRefno'
				,@ThreadHold = @ThreadHoldRefno OUTPUT

			IF @TotalSubParlay <= @ThreadHoldRefno
				SET @LockedByRefno = 1
				
			SET	@sqlCommand =  'EXEC [dbo].[NAP_Admin_Settlement_Profile_Parlay] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
									+ ', @creator = ' + CONVERT(NVARCHAR(50), @creator) 												
									+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResourceParlay) + ''''
									+ ', @hth = ' + CONVERT(NVARCHAR(50), @hth) 
									+ ', @hta = ' + CONVERT(NVARCHAR(50), @hta) 
									+ ', @fth = ' + CONVERT(NVARCHAR(50), @fth) 
									+ ', @fta = ' + CONVERT(NVARCHAR(50), @fta)
									+ ', @IsAuto = ' + CONVERT(NVARCHAR(50), @IsAuto)									
									+ ', @Action = ''' + @Action + ''''	
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
					,@hth				= @hth
					,@hta				= @hta
					,@fth				= @fth
					,@fta				= @fta
					,@IsAuto			= @IsAuto
					,@LockedByRefno		= 1 -- always lock refno for testing
					,@IsCentral			= @IsCentral
					,@ErrCode			= @ErrCode OUTPUT
					,@ErrMsg 			= @ErrMsg OUTPUT
			END
			ELSE
			BEGIN
				INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype, LockedByRefno)
				SELECT @MatchID, 0, @creator, '', CURRENT_TIMESTAMP, @action, @sqlCommand, @sportType, @LockedByRefno
			END
		END
		ELSE IF @IsCentral = 1
		BEGIN
			IF @IsAuto = 1
			BEGIN
				EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefund_ResultUpd
					@MatchId = @matchid 
					, @TypeId  = 10
					, @StatusId = 2
			END
		END

		IF @matchcode not like '%Hedge%'
		BEGIN 
			IF @SDTRecord & 3  = 3
			BEGIN
				SELECT @ErrCode = 1000006
					,@ErrMsg    = 'Please move Betdaq and Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
			END
			ELSE IF @SDTRecord & 1 = 1
			BEGIN
				SELECT @ErrCode = 1000006
					,@ErrMsg    = 'Please move Betdaq tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
			END
			ELSE IF @SDTRecord & 2 = 2
			BEGIN
				SELECT @ErrCode = 1000006
					,@ErrMsg    = 'Please move Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
			END
		END 
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = 1001017 
				,@ErrMsg = ERROR_MESSAGE() 
	END CATCH

	SELECT @LogData = (					
		SELECT	@betstatus AS '@betstatus'			
				,@ActionID AS '@ActionID'
				,@action AS '@Action'
				,@fth AS '@fth'
				,@fta AS '@fta'
				,@hth AS '@hth'
				,@hta AS '@hta'
				,@creator AS '@AdminId'
				,@IP AS '@IP'
				,@SDTRecord AS '@SDTRecord'
				,@starttime AS '@Starttime'
				,@ErrMsg AS '@ErrMsg'
				,@ErrCode AS '@ErrCode'
				,@GoalSequence AS '@goalrecord'
				,@IsAuto AS '@IsAuto'
		FOR XML PATH('r'), ROOT('root'), TYPE)

	SET @CommandMonitor = 'EXEC dbo.NAP_Admin_MonitorProcess @SessionId = ' + CAST(@SessionId AS VARCHAR(50))
						+ ', @MatchId = ' + CAST(@MatchId AS VARCHAR)		
						+ ', @HasError = ' + CAST(CASE WHEN @ErrCode = 1000006 THEN 0 ELSE @ErrCode END AS VARCHAR)
						+ ', @LogData = ' + '''' + CAST(@LogData AS VARCHAR(MAX)) + ''''
						+ ', @IsCentral = ' + CAST(@IsCentral AS VARCHAR)	
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
GO
