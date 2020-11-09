/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] @MatchId INT
	,@Action				VARCHAR(20)
	,@Results				VARCHAR(MAX)
	,@EventCounters			VARCHAR(MAX)	= NULL

	,@IsAuto				BIT				= 0
	,@AdminId				INT				= 0
	,@Ip					VARCHAR(20)		= ''
	,@IsReSettledTickets	BIT				= 1
	,@IsSettleDetermined	BIT				= 0

	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20160427@Patrick
	Task: Fast market - Auto/Manual settlement
	DB: DBTXN.BODB02
	Original:
	
	Revisions:
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
		- 20170801@Bobby: Implement new capture balance method [Redmine:#80774]
		- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190404@Kathy: New keyId for Fast Market [Redmine:#106823]
		- 20190528@Kathy: Write log @IsReSettledTickets [Redmine:#113460]
		- 20190813@Helen: Remove vnteam in metadata
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20200928@Helen: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
		- 20201106@Kathy: Add "Water Break" Concept to Fast Markets [Readmine:#143573]
		
	Param's Explanation:
		If @IsAuto = 0:
			- @Results = <r>
							<b Id="221">
								<r p="0" r="36" sw="30" ew="32" sd="1" />
								<r p="1" r="1" />
								<r p="2" r="4" />
							</b>
						</r>
			- @EventCounters: '<r>
								<e Id="221CNT02">
									<r p="0" r="2" />
									<r p="1" r="1" />
								</e>
								<e Id="221CNT03">
									<r p="0" r="4" />
									<r p="1" r="2" />
								</e>
								...
							</r>'

		If @IsAuto = 1:
			@Results = <r>
							<b Id="221">
								<r p="0"/>
								<r p="1"/>
								<r p="2"/>
							</b>
						</r>
*/
BEGIN
	SET NOCOUNT ON
	 
	DECLARE		@Start 		DATETIME
				,@Stop 		DATETIME
				,@fth		INT
				,@fta 		INT
				,@hth 		INT
				,@hta 		INT
				,@ActionID	INT
				,@Remark	VARCHAR(MAX)
				,@LogData	NVARCHAR(300)						
				,@LogResult VARCHAR(MAX) = ''	
				,@strFMBettypes	VARCHAR(MAX)
				,@XmlData XML
				,@rowcount	INT
				,@avaiableProcess BIT
				,@sportType INT
				,@xmlEventCounter	XML
				,@LogEventCounter	VARCHAR(MAX) = ''
				,@BetOption1st VARCHAR(50)
				,@BetOption2nd VARCHAR(50)
				,@ResultStatus1st VARCHAR(50)				
				,@ResultStatus2nd VARCHAR(50)
				,@isExistFM BIT = 1
				,@isExistFM2 BIT = 0

	DECLARE @tblAccumulatedScore TABLE (
		Position TINYINT
		,BetOption TINYINT
		,AccumulatedScore INT
	)
	
	--START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblResultDetail (
		BetType				SMALLINT
		,ResourceId			VARCHAR(20)
		,Position			TINYINT
		,BetOption			TINYINT
		,AccumulatedScore	INT
	)

	CREATE TABLE #tblEventCounter (
		ResourceId	VARCHAR(20)
		,Position	TINYINT
		,Result		VARCHAR(8)
	)

	SET @XmlData =  CONVERT(XML, @Results)
	SET @xmlEventCounter = CONVERT(XML,@EventCounters)

	SELECT	@start = CURRENT_TIMESTAMP
	SELECT	@ActionID = CASE 
							WHEN @Action = 'CAL' THEN 165 
							WHEN @Action = 'UNDO' THEN 166 
							WHEN @Action = 'REFUND' THEN 167
							ELSE 0 
						END  
	--Write Log Settle
	SELECT	 @fth = finalhomescore
			,@fta = finalawayscore
			,@hth = hthomescore
			,@hta = htawayscore
			,@sportType	= sportType
	FROM	dbo.match WITH (NOLOCK)
	WHERE	matchid = @matchid

	IF @Action IN ('CAL', 'REFUND') AND @IsAuto = 0
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= @action
			,@IsEarly 	= 1
			,@IsSettleDetermined = @IsSettleDetermined
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END

	CREATE INDEX IX_ResultDetail_Bettype ON #tblResultDetail (BetType)
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
			,X.C.value('@r','TINYINT') as BetOption
		FROM @xmlData.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
	)
	INSERT INTO #tblResultDetail (
		BetType
		,ResourceId
		,Position
		,BetOption
	)
	SELECT	BetType
			,CAST(BetType * 100 + 1 AS VARCHAR(20)) AS ResourceId
			,Position
			,ISNULL(BetOption,0)
	FROM TmpData
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )

	-- check and not allow attempt to settlement same game while it's still not finish
	IF EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType BETWEEN 221 AND 227)
		SET @isExistFM = 1

	IF EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType = 228)
		SET @isExistFM2 = 1

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT DISTINCT @MatchId
			,CASE 
				WHEN BetType = 228 THEN 7
				ELSE 6 -- 221-->227
			END AS KeyId
	FROM	#tblResultDetail
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistFM			= @isExistFM
		,@isExistFM2		= @isExistFM2
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
	
	--CHECK avaiable process
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	;WITH TmpEventCounter AS (
		SELECT T.C.value('@Id', 'VARCHAR(20)') AS ResourceId
				,X.C.value('@p','TINYINT') as Position
				,X.C.value('@r','TINYINT') as Result
		FROM @xmlEventCounter.nodes('/r/e') AS T(C)
				CROSS APPLY
					C.nodes('r') AS X(C)
	)
	INSERT INTO #tblEventCounter(ResourceId, Position, Result)
	SELECT	ResourceId
			,Position
			,Result
	FROM	TmpEventCounter
	OPTION ( OPTIMIZE FOR ( @xmlEventCounter = NULL ) )
	
	-- get score before update for UNDO action
	IF @Action IN ('UNDO', 'REFUND') AND EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType = 228)
		SELECT	@BetOption1st = MAX(CASE WHEN ResourceId = '22801' THEN HomeValue ELSE '' END)
				,@BetOption2nd = MAX (CASE WHEN ResourceId = '22801' THEN AwayValue ELSE '' END)
				,@ResultStatus1st = MAX (CASE WHEN ResourceId = '22800' THEN HomeValue ELSE '' END)
				,@ResultStatus2nd = MAX (CASE WHEN ResourceId = '22800' THEN AwayValue ELSE '' END)				
		FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
		WHERE	MatchId = @MatchId 
				AND ResourceId LIKE '2280_'
		GROUP BY MatchId

	-- update resultstatus
	EXEC DBPRO.bodb02.dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId = @MatchId
		,@Results = @Results
		,@EventCounters = @EventCounters
		,@Action = @Action
		,@IsAuto = @IsAuto
		,@AdminId = @AdminId					
		
		-- Get Result bettype 228
	IF EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType = 228)
	BEGIN
		IF @Action = 'CAL'
		BEGIN
			SELECT	@BetOption1st = MAX(CASE WHEN ResourceId = '22801' THEN HomeValue ELSE '' END)
					,@BetOption2nd = MAX (CASE WHEN ResourceId = '22801' THEN AwayValue ELSE '' END)
					,@ResultStatus1st = MAX (CASE WHEN ResourceId = '22800' THEN HomeValue ELSE '' END)
					,@ResultStatus2nd = MAX (CASE WHEN ResourceId = '22800' THEN AwayValue ELSE '' END)				
			FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
			WHERE	MatchId = @MatchId 
					AND ResourceId LIKE '2280_'
			GROUP BY MatchId
		END		
		IF @BetOption1st IS NOT NULL OR @BetOption2nd IS NOT NULL
		BEGIN
			;WITH cteBetOption
			AS
			(
				SELECT	f.pos AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOption1st) f
				WHERE	f.pos < 46 AND ISNULL(@BetOption1st,'') <> ''
				UNION ALL
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOption2nd) f
				WHERE	f.pos < 45 AND ISNULL(@BetOption2nd,'') <> ''
			)
			,cteResutStatus
			AS (
				SELECT	f.pos AS Position, f.ResultStatus AS ResultStatus
				FROM	dbo.f_Set_GetChars(@ResultStatus1st) f
				WHERE	f.pos < 46 AND ISNULL(@ResultStatus1st,'') <> ''
				UNION ALL
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS ResultStatus
				FROM	dbo.f_Set_GetChars(@ResultStatus2nd) f
				WHERE	f.pos < 45 AND ISNULL(@ResultStatus2nd,'') <> ''
			)
			,cteResult
			AS (
				SELECT rs.Position, CASE WHEN rs.ResultStatus IN (4,5) THEN bo.BetOption ELSE 0 END AS BetOption
				FROM cteResutStatus rs
					INNER JOIN cteBetOption bo
						ON rs.Position = bo.Position
			)
			INSERT INTO @tblAccumulatedScore (Position, BetOption, AccumulatedScore)
			SELECT c1.Position, c1.BetOption, c2.BetOption
			FROM cteResult c1
				INNER JOIN cteResutStatus crs
					ON c1.Position = crs.Position
				CROSS APPLY (
					SELECT	ISNULL(SUM(c2.BetOption), 0) as BetOption
					FROM	cteResult c2
					WHERE	c2.Position <= c1.Position
				) c2
				
			UPDATE r 
				SET AccumulatedScore = a.AccumulatedScore
					,BetOption = a.BetOption
			FROM	#tblResultDetail r
				INNER JOIN @tblAccumulatedScore a
					ON	r.BetType = 228
						AND r.Position = a.Position

			SET @Results = CAST((
				SELECT bettype '@Id'
					,(SELECT Position '@p'
							,BetOption '@r'
							,CASE WHEN BetType = 228 THEN AccumulatedScore ELSE NULL END '@a'
						FROM #tblResultDetail WHERE r.bettype = bettype FOR XML PATH('r'), TYPE)
				FROM #tblResultDetail r
				GROUP BY r.bettype
				FOR XML PATH('b'), ROOT ('r'), TYPE
			) AS VARCHAR(MAX))	
		END				
	END		
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------

	INSERT INTO @BalanceWalletBefore (
		matchid
		, custid
		, balanceType
		, walletType
		, bonusId
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType		= @sportType
		, @Action 			= @Action
		, @Mode 			= 7 --@Mode fast market
		, @FMResults		= @Results
	
	SELECT @rowcount = COUNT(DISTINCT custid)
	FROM @BalanceWalletBefore	

	IF @rowcount > 0
	BEGIN TRY	
			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				,@action = 'CAL-FM'
				,@mode = @Action
				,@XmlData = @Results
				,@IsReSettledTickets = @IsReSettledTickets
	END TRY
	BEGIN CATCH
		-- Capture Balance incase of failure
		-------------------------------------------------------------
		---         CAPTURE value BALANCE after settlement        ---
		---------------------------VVVV------------------------------
		
		INSERT INTO @BalanceWalletAfter (
			matchid
			, custid
			, balanceType
			, walletType
			, bonusId
			, balance
		)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
			@MatchId 			= @matchId
			, @sportType		= @sportType
			, @Action 			= @Action
			, @Mode 			= 7 --@Mode fast market
			, @FMResults		= @Results
		
		-- Compare Balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			, @BalanceWalletAfter	= @BalanceWalletAfter
			, @ActionId				= @ActionID
		
		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE()
		
		RETURN

	END CATCH

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	INSERT INTO @BalanceWalletAfter (
		matchid
		, custid
		, balanceType
		, walletType
		, bonusId
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType 		= @sporttype
		, @Action 			= @Action
		, @Mode 			= 7 --@Mode fast market
		, @FMResults		= @Results
	
	-- Compare and update pending balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID

	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------

	SELECT @stop = CURRENT_TIMESTAMP

	SELECT @logdata = 'NAP: Fast Market (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
		+ '(' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.WriteLog_UserLog @UserID = @AdminId, @Doing = @logdata
	
	SET @LogResult = CONVERT(VARCHAR(MAX),(SELECT BetType '@Id'
		, STUFF((SELECT ',' + CAST(Position AS VARCHAR(3)) FROM #tblResultDetail WHERE BetType = r.BetType FOR XML PATH ('')),1,1,'') AS 'Item/@Position'
		, CASE WHEN @Action = 'CAL' THEN STUFF((SELECT ',' + CAST(BetOption AS VARCHAR(3)) FROM #tblResultDetail WHERE BetType = r.BetType FOR XML PATH ('')),1,1,'') END AS 'Item/@Result'
		
	FROM #tblResultDetail r
	GROUP BY BetType
	FOR XML PATH('BetType'), ROOT ('BetTypes'), TYPE))

	INSERT INTO #tblEventCounter (ResourceId, Position, Result)
	SELECT	t.ResourceId
			,t.Position
			,0 as Result
	FROM (
		SELECT	re.ResourceId
				,p.Position
		FROM (
			SELECT	Position
			FROM	#tblEventCounter
			GROUP BY Position
		) p
			CROSS APPLY (
				SELECT ResourceId
				FROM (VALUES ('221CNT01'), ('221CNT02'), ('221CNT03'), ('221CNT04'), ('221CNT05'), ('221CNT06'), ('221CNT07'), ('221CNT08')) AS re (ResourceId)
			) re
	)t
		LEFT JOIN #tblEventCounter e
			ON	t.ResourceId = e.ResourceId
				AND t.Position = e.Position
	WHERE	e.ResourceId IS NULL

	SET @LogEventCounter = ISNULL(CONVERT(VARCHAR(MAX), (
													SELECT Position AS '@Position'
															,(SELECT	Result + '' 
																FROM	#tblEventCounter r
																WHERE	Position = t.Position 
																ORDER BY ResourceId DESC
																FOR XML PATH ('')) AS '@Result'
													FROM #tblEventCounter t
													GROUP BY Position
													ORDER BY Position
													FOR XML PATH('Item'), Root('EventCounters'), TYPE)
												) ,'')
		
	SELECT @Remark = 'NAP: IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
			+ ' Recalc: ' + CAST (@IsReSettledTickets AS VARCHAR(1)) + '<br/>'
			+  CASE WHEN @IsSettleDetermined = 1 THEN ' SDT: 1 <br/>' ELSE '' END
			+ ' Duration: ' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + 'ms' 
			
	BEGIN TRY
		SELECT @Remark = @Remark + '|'  -- signal for web
						+ @LogResult + '|'
						+ @LogEventCounter 
						+ CASE 
							WHEN @Action = 'CAL' THEN '|' 
														+ CASE WHEN ISNULL(@BetOption1st,'')<> '' THEN '1H:'+ @BetOption1st ELSE '' END
														+ CASE WHEN ISNULL(@BetOption2nd,'')<> '' THEN ', 2H:'+ @BetOption2nd ELSE '' END
							ELSE ''
						END
	
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @userid = @AdminId
			, @matchid			= @MatchID
			, @actionid			= @ActionID
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= ''
			, @betstatus		= ''
			, @Remark			= @Remark
			, @ip				= @ip
	END TRY

	BEGIN CATCH
		SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250) + '|' -- signal for web
							+ @LogResult + '|'
							+ @LogEventCounter 
							+ CASE 
								WHEN @Action = 'CAL' THEN '|' 
															+ CASE WHEN ISNULL(@BetOption1st,'')<> '' THEN '1H:'+ @BetOption1st ELSE '' END
															+ CASE WHEN ISNULL(@BetOption2nd,'')<> '' THEN ', 2H:'+ @BetOption2nd ELSE '' END
								ELSE ''
							END
							

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			, @MatchID			= @matchid
			, @actionid			= @actionid
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= ''
			, @betstatus		= ''
			, @Remark			= @Remark
			, @IP				= @ip
	END CATCH
	
	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistFM			= 1
		,@isExistFM2		= 1
		, @IsReleased		= 1
	
END
GO
