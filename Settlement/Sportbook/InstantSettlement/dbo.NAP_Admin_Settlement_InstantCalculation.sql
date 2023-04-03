/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_InstantCalculation
	@AdminId 			INT
	,@MatchId			INT
	,@Action			VARCHAR(10)		
	,@HomeScore			VARCHAR(50)
	,@AwayScore			VARCHAR(50)
	,@ResourceResult	VARCHAR(MAX)	= NULL
	,@IP				VARCHAR(15)
	,@IsAutoInst		BIT 			= 0
	,@KeyId				INT				= 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
	
AS
/*    
	Creator: 20230404@Kathy
    Task: Implement Instant Calculation
    DB: DBTXN/BODB02
	Original:NAP_Admin_Settlement_1_InstantCalculation

    Revisions:
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]

    Param's Explanation:
        - @Action: ['CALINST-HT', 'CALINST-FT' 'UNDOINST-FT', 'UNDOINST-HT']
        - @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
        - @IsAutoInst: 1-Auto Instant 0-Manual Instant
    
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE 
		@StartTime			DATETIME
		,@sporttype			SMALLINT		
		,@ActionId			INT		
		,@avaiableProcess	BIT
		,@CalculationType	TINYINT
		,@handle			INT
		,@SettlementProcessingId BIGINT
		,@SPName			NVARCHAR(128)
		,@LogData			XML
		,@CommandMonitor	NVARCHAR(MAX)
		,@SSBStatus			TINYINT
		,@TicketCount		INT
	
		,@IsCentral			BIT
		,@SessionId			INT
		,@DummyResourceIds	VARCHAR(MAX) 
		,@DummyResourceResults VARCHAR(MAX)
		,@TotalSubParlay	INT
		,@SelectedResourceParlay VARCHAR(MAX) 
		,@ThresholdRefno	INT 
		,@LockedByRefno		BIT
		,@sqlCommand		VARCHAR(MAX)
		,@DeterminedType	TINYINT
		,@Threshold			INT
		,@SourceId			TINYINT
		,@fth				INT
		,@fta				INT
		,@hth				INT
		,@hta				INT
		
	DECLARE @tmpAllBettypes TABLE (Bettype SMALLINT PRIMARY KEY, ResourceId VARCHAR(20), SDTResourceId VARCHAR(20), SDTpfId SMALLINT, OddsType TINYINT, RefResourceId VARCHAR(20), DeterminedType TINYINT)
	DECLARE @tmpAffectedBettypes TABLE (Bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpParlayAffectedBettypes TABLE (bettype SMALLINT, totalticket INT, DeterminedType TINYINT DEFAULT(0))	
	DECLARE @tmpResources TABLE(
		ResourceID VARCHAR(20)
		,SDTResourceId VARCHAR(20)
		,HomeValue VARCHAR(2000)
		,AwayValue VARCHAR(2000)
	)

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	SELECT @CalculationType 			= CASE 
										WHEN @Action LIKE '%HT%' THEN 101
										WHEN @Action LIKE '%FT%' THEN 102
										ELSE 0
									END
		,@DeterminedType = CASE 
								WHEN @Action LIKE '%HT%' THEN 1
								WHEN @Action LIKE '%FT%' THEN 4
								ELSE 0
							END
		,@ActionId = CASE 
						WHEN @CalculationType = 101 AND @IsAutoInst = 0 THEN 178
						WHEN @CalculationType = 102 AND @IsAutoInst = 0 THEN 179
						WHEN @CalculationType = 101 AND @IsAutoInst = 1 THEN 195
						WHEN @CalculationType = 102 AND @IsAutoInst = 1 THEN 196									  
					END
						
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	-- check match validation
	SELECT	@sporttype 		= m.sporttype		
			,@SourceId = CASE 
							WHEN m.ChildMatchType = 204 THEN 100
							WHEN @IsAutoInst = 0 THEN 100 
							ELSE 5 
						END			
			,@fth = CAST(@HomeScore AS INT)
			,@fta = CAST(@AwayScore AS INT)
			,@hth = CASE WHEN @DeterminedType = 1 THEN CAST(@HomeScore AS INT) ELSE m.hthomescore END
			,@hta = CASE WHEN @DeterminedType = 1 THEN CAST(@AwayScore AS INT) ELSE m.htawayscore END
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @matchid

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @Matchid
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
	    SELECT	@ErrCode 
				,@ErrMsg 
	    
	    RETURN
	END

	IF @IsAutoInst = 0 AND @Action LIKE 'CAL%'
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= @action
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END

	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT @matchid AS matchid
		,1 AS KeyId
			
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode		= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@sporttype IS NULL OR  @ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	INSERT INTO dbo.Settlement_SettledSession (MatchId)
	SELECT @matchid
	SET @SessionId = SCOPE_IDENTITY()

	BEGIN TRY
		-- Collect instant Bettypes
		INSERT INTO @tmpAllBettypes(Bettype, SDTResourceId, SDTpfId, OddsType, ResourceId, RefResourceId, DeterminedType)
		SELECT	DISTINCT s.BetType, s.SDTResourceId, s.SDTpfId, s.OddsType, s.ResourceId, s.RefResourceId, s.DeterminedType
		FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
		WHERE	s.SportType = @sporttype
				AND ISNULL(s.DeterminedType,0) & @DeterminedType > 0
	
		;WITH cteAffectedBettypes
		AS (
			SELECT	b.Bettype
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND EXISTS (SELECT TOP 1 1 FROM @tmpAllBettypes t WHERE t.Bettype = b.bettype)
					AND ((b.statusId = 0 AND ISNULL(b.SecAcceptFlag,0)=0)
					 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
					 )
			GROUP BY b.custid, b.bettype
		)
		INSERT INTO @tmpAffectedBettypes(BetType)
		SELECT	bettype
		FROM	cteAffectedBettypes
			
		-- Generate result
		BEGIN		
			INSERT INTO @tmpResources(ResourceID, HomeValue, AwayValue)
			SELECT	CASE 
						WHEN @CalculationType = 101 THEN CAST('01' AS VARCHAR(20))
						WHEN @CalculationType = 102 THEN CAST('00' AS VARCHAR(20))
						ELSE ''
					END AS ResourceID
					,CAST( @HomeScore AS VARCHAR(50)) AS HomeValue
					,CAST( @AwayScore AS VARCHAR(50)) AS AwayValue
			UNION ALL
			SELECT	CAST('00' AS VARCHAR(20)) AS ResourceID
					,CAST( @HomeScore AS VARCHAR(50)) AS HomeValue
					,CAST( @AwayScore AS VARCHAR(50)) AS AwayValue
			WHERE	@CalculationType = 101

			SELECT	@DummyResourceIds = STRING_AGG(CAST(s.SDTResourceId AS VARCHAR(MAX)), ',')
			FROM	@tmpAllBettypes s
			WHERE	s.SDTResourceId IS NOT NULL
					AND EXISTS (SELECT TOP 1 1 FROM @tmpAffectedBettypes b WHERE b.Bettype = s.BetType)
				
			IF @DummyResourceIds <> ''
			BEGIN

				EXEC dbo.NAP_Set_DummyResourceResult
					@MatchID = @MatchID
					,@sportType = @sportType
					,@IsDetermined = 1
					,@WebResourceResult = @ResourceResult
					,@Action = @Action
					,@DummyResourceIds = @DummyResourceIds
					,@DummyResourceResults = @DummyResourceResults OUTPUT

				EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
				INSERT INTO @tmpResources (SDTResourceId, HomeValue, AwayValue)
				SELECT	Id, Home, Away
				FROM	OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(2000)
														,Away VARCHAR(2000)
													) AS tbl
				EXEC sp_xml_removedocument @handle
			END
			
			INSERT INTO dbo.SettlementBettypeResult(MatchId, Bettype, pfId, HomeValue, AwayValue, OddsType, SessionId)
			SELECT	@matchid, t.BetType, t.SDTpfId, t.HomeValue, t.AwayValue, t.OddsType, @SessionId
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
						,@HomeScore
						,@AwayScore
						,s.OddsType
				FROM	@tmpAllBettypes s
				WHERE	s.SDTResourceId IS NULL
			) t
			WHERE  EXISTS (SELECT TOP 1 1 FROM @tmpAffectedBettypes b WHERE b.Bettype = t.BetType)
		END
	
		EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
			,@mode = 'LockMatch'
			,@IsSettingByProfile = 1
			,@SessionId = @SessionId	
	
		IF @IsCentral = 0 AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLogIns','P') IS NOT NULL 
		BEGIN
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns
				@SystemName		= 'Settlement'
				,@FunctionName	= 'CalculateSoccer'
				,@TableName		= 'SiteDB_SettlementLock'
				,@Action		= 'I'
				,@MatchId		= @matchid
				,@SessionId		= @SessionId
		END

		INSERT INTO dbo.SettlementProcessing (TransIds, modds, IsMarked, OddsType, MessageType, SessionId,ActionId)	
		SELECT '', 0, 0, 0, '', @SessionId, 0

		SET @SettlementProcessingId = SCOPE_IDENTITY()

		EXEC dbo.NAP_Admin_Settlement_TransId
			@MatchId = @MatchId
			,@Action = @Action
			,@ActionId = @ActionId
			,@hth = @hth
			,@hta = @hta
			,@fth = @fth
			,@fta = @fta
			,@SessionId = @SessionId
			,@SettlementProcessingId = @SettlementProcessingId
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@AffectedTicket = @TicketCount OUTPUT

		--UPDATE back to AutoPayoutResult
		IF @IsCentral = 1 AND @Action LIKE 'CAL%'
			EXEC DBPRO.BODB02.dbo.NAP_Set_AutoPayoutResultUpd 
				@MatchId = @matchid
				,@TypeId = @CalculationType
				,@StatusId = 2
				,@IsIncludedUpdateMatch = 1
				,@SourceID = @SourceID
	
		INSERT INTO @tmpParlayAffectedBettypes(bettype, totalticket, DeterminedType)
		SELECT 	bm.bettype, COUNT(1) AS totalticket, @DeterminedType AS DeterminedType
		FROM	dbo.bettransm bm WITH(NOLOCK)
		WHERE	bm.matchid = @MatchId		
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				--AND (bm.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND bm.recommend <> 1688156) --exclude betdaq/betfair
				AND ((bm.statusId = 0 AND ISNULL(bm.SecAcceptFlag,0)=0)
					 OR (bm.statusID = 0 AND bm.SecAcceptFlag=1 AND ISNULL(bm.checktime,CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
					 )	
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
				SELECT	Id, Home, Away
				FROM	OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
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
						,s.DeterminedType
				FROM	@tmpAllBettypes s
					INNER JOIN @tmpResources t
						ON s.SDTResourceId = t.SDTResourceId
				WHERE	s.SDTResourceId IS NOT NULL
						AND EXISTS (SELECT TOP 1 1 FROM @tmpParlayAffectedBettypes b WHERE b.Bettype = s.BetType)
				UNION 
				SELECT	s.ResourceID
						,s.SDTpfId
						,s.BetType				
						,t.HomeValue
						,t.AwayValue
						,s.RefResourceId
						,s.DeterminedType
				FROM	@tmpAllBettypes s
					INNER JOIN @tmpResources t
						ON ISNULL(s.RefResourceId,s.ResourceId) = t.ResourceID
				WHERE	s.SDTResourceId IS NULL
						AND EXISTS (SELECT TOP 1 1 FROM @tmpParlayAffectedBettypes b WHERE b.Bettype = s.BetType)
			)
			SELECT @SelectedResourceParlay = CAST((SELECT ResourceID AS '@Id'
														,CASE WHEN RefResourceId IS NOT NULL THEN RefResourceId ELSE NULL END AS '@RefResourceId' 
														,bettype AS '@Bettype'
														,SDTpfId AS '@SDTpfId'
														,HomeValue AS '@Home'
														,AwayValue AS '@Away'
														,DeterminedType AS '@DeterminedType'
												FROM	cteSelectedRID
												FOR XML PATH ('Resource'), ROOT('Resources'), TYPE) AS VARCHAR(MAX))
			
			EXEC dbo.NAP_Set_GlobalSettingSel 
				@LockName = 'ParlayRefno'
				,@ThreadHold = @ThresholdRefno OUTPUT

			IF @TotalSubParlay <= @Threshold
				SET @LockedByRefno = 1
			
			SET	@sqlCommand =  'EXEC [dbo].[NAP_Admin_Settlement_Profile_Parlay] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
									+ ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 												
									+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResourceParlay) + ''''
									+ ', @hth = ' + CONVERT(NVARCHAR(50), @hth) 
									+ ', @hta = ' + CONVERT(NVARCHAR(50), @hta) 
									+ ', @fth = ' + CONVERT(NVARCHAR(50), @fth) 
									+ ', @fta = ' + CONVERT(NVARCHAR(50), @fta) 
									+ ', @IsReSettledTickets = 0'			
									+ ', @IsCentral = ' + CONVERT(VARCHAR(1), @IsCentral)
									+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
									+ ', @DeterminedType = ' + CONVERT(VARCHAR(3), @DeterminedType)
									+ ', @ErrCode = @ErrCode OUTPUT' 
									+ ', @ErrMsg = @ErrMsg OUTPUT'

			IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT[1-9]'
			BEGIN
				EXEC dbo.NAP_Admin_Settlement_Profile_Parlay
					@creator			= @AdminId
					,@MatchID			= @MatchId
					,@Action		  	= @Action
					,@SelectedResources = @SelectedResourceParlay
					,@IsReSettledTickets = 0
					,@LockedByRefno		= 1 -- always lock refno for testing
					,@IsCentral			= @IsCentral
					,@DeterminedType	= @DeterminedType

					,@ErrCode			= @ErrCode OUTPUT
					,@ErrMsg 			= @ErrMsg OUTPUT
			END
			ELSE
			BEGIN
				INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype, LockedByRefno)
				SELECT @MatchID, 0, @AdminId, '', CURRENT_TIMESTAMP, @Action, @sqlCommand, @sportType, @LockedByRefno
			END
		END
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = 1001017 
				,@ErrMsg = ERROR_MESSAGE()  
	END CATCH

	SELECT @LogData = (					
			SELECT	@action AS '@Action'
					,@ActionId AS '@ActionID'
					,CASE WHEN @Action LIKE '%HT%' THEN @HomeScore ELSE @hth END AS '@hth'
					,CASE WHEN @Action LIKE '%HT%' THEN @AwayScore ELSE @hta END AS '@hta'
					,CASE WHEN @Action LIKE '%FT%' THEN @HomeScore ELSE NULL END AS '@fth'
					,CASE WHEN @Action LIKE '%FT%' THEN @AwayScore ELSE NULL END AS '@fta'
					,@AdminId AS '@AdminId'
					,@SourceId AS '@SourceId'
					,@IP AS '@IP'
					,@TicketCount AS '@TicketCount'
					,@starttime AS '@Starttime'
					,@ErrMsg AS '@ErrMsg'
			FOR XML PATH('r'), ROOT('root'), TYPE)

	SET @CommandMonitor = 'EXEC dbo.NAP_Admin_MonitorProcess @SessionId = ' + CAST(@SessionId AS VARCHAR(50))
					+ ', @MatchId = ' + CAST(@MatchId AS VARCHAR)
					+ ', @HasError = ' + CAST(@ErrCode AS VARCHAR)
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