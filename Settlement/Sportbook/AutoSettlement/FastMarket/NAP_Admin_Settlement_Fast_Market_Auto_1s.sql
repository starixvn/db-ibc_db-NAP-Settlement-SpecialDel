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
		- 20210107@Kathy: Support settle determined [Readmine:#147141]
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		- 20210428@Kathy: Allow to settle directly for bettype 228 [Redmine:#153155]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

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
				,@BetOptionHome_1st VARCHAR(50)
				,@BetOptionHome_2nd VARCHAR(50)
				,@BetOptionAway_1st VARCHAR(50)
				,@BetOptionAway_2nd VARCHAR(50)
				,@ResultStatus1st VARCHAR(50)				
				,@ResultStatus2nd VARCHAR(50)
				,@isExistFM BIT = 1
				,@isExistFM2 BIT = 0
				,@IsCentral			BIT

	DECLARE @tblAccumulatedScore TABLE (
		bettype					SMALLINT
		,Position				TINYINT
		,BetOption				TINYINT
		,OldAccumulatedScore	INT -- 228
		,AccumulatedScore		INT -- 228
		,AccumulatedHomeScore	INT -- 229
		,AccumulatedAwayScore	INT -- 229
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
		,OldAccumulatedScore	INT
		,AccumulatedScore		INT
		,AccumulatedHomeScore	INT
		,AccumulatedAwayScore	INT
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
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

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

	IF EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType IN (228,229))
		SET @isExistFM2 = 1

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT DISTINCT @MatchId
			,CASE 
				WHEN BetType IN (228,229) THEN 7
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
	IF @Action IN ('UNDO', 'REFUND', 'CAL') AND EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType = 228) AND @IsSettleDetermined = 0
	BEGIN
		SELECT	@BetOption1st = MAX(CASE WHEN ResourceId = '22801' THEN HomeValue ELSE '' END)
				,@BetOption2nd = MAX (CASE WHEN ResourceId = '22801' THEN AwayValue ELSE '' END)
				,@ResultStatus1st = MAX (CASE WHEN ResourceId = '22800' THEN HomeValue ELSE '' END)
				,@ResultStatus2nd = MAX (CASE WHEN ResourceId = '22800' THEN AwayValue ELSE '' END)				
		FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
		WHERE	MatchId = @MatchId 
				AND ResourceId LIKE '2280_'
		GROUP BY MatchId

		-- calculate accumulated score before settle
		IF @Action = 'CAL'
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
				SELECT rs.Position, CASE WHEN rs.ResultStatus IN (4,5,7) THEN bo.BetOption ELSE 0 END AS BetOption
				FROM cteResutStatus rs
					INNER JOIN cteBetOption bo
						ON rs.Position = bo.Position
			)
			,cteOldAccumulatedScore
			AS (
			SELECT 228 AS bettype, c1.Position, c1.BetOption, c2.BetOption AS OldAccumulatedScore
			FROM cteResult c1
				INNER JOIN cteResutStatus crs
					ON c1.Position = crs.Position
				CROSS APPLY (
					SELECT	ISNULL(SUM(c2.BetOption), 0) as BetOption
					FROM	cteResult c2
					WHERE	c2.Position <= c1.Position
				) c2
			)					
			UPDATE r 
				SET OldAccumulatedScore = a.OldAccumulatedScore
			FROM	#tblResultDetail r
				INNER JOIN cteOldAccumulatedScore a
					ON	r.BetType = a.bettype
						AND r.Position = a.Position
			WHERE r.BetType = 228
		END
	END

	-- update resultstatus
	IF @IsCentral = 1
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId = @MatchId
			,@Results = @Results
			,@EventCounters = @EventCounters
			,@Action = @Action
			,@IsAuto = @IsAuto
			,@AdminId = @AdminId					
	END
	
	-- Get Result bettype 228
	IF EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType = 228)
	BEGIN
		IF @Action = 'CAL' OR (@Action = 'REFUND' AND @IsSettleDetermined = 1)
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
				SELECT rs.Position, CASE WHEN rs.ResultStatus IN (4,5,7) THEN bo.BetOption ELSE 0 END AS BetOption
				FROM cteResutStatus rs
					INNER JOIN cteBetOption bo
						ON rs.Position = bo.Position
			)
			INSERT INTO @tblAccumulatedScore (bettype, Position, BetOption, AccumulatedScore)
			SELECT 228 AS bettype, c1.Position, c1.BetOption, c2.BetOption AS AccumulatedScore
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
					ON	r.BetType = a.bettype
						AND r.Position = a.Position
			WHERE r.BetType = 228
		END				
	END		

	-- 229
	IF EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType = 229)
	BEGIN
		IF @Action = 'CAL' 
		BEGIN
			SELECT	@BetOptionHome_1st = MAX(CASE WHEN ResourceId = '22901H' THEN HomeValue ELSE '' END)
					,@BetOptionHome_2nd = MAX (CASE WHEN ResourceId = '22901H' THEN AwayValue ELSE '' END)
					,@BetOptionAway_1st = MAX(CASE WHEN ResourceId = '22901A' THEN HomeValue ELSE '' END)
					,@BetOptionAway_2nd = MAX (CASE WHEN ResourceId = '22901A' THEN AwayValue ELSE '' END)
					,@ResultStatus1st = MAX (CASE WHEN ResourceId = '22900' THEN HomeValue ELSE '' END)
					,@ResultStatus2nd = MAX (CASE WHEN ResourceId = '22900' THEN AwayValue ELSE '' END)
			FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
			WHERE	MatchId = @MatchId 
					AND ResourceId LIKE '2290%'
			GROUP BY MatchId
		END		
		
		SELECT 	@BetOptionHome_1st = ISNULL(@BetOptionHome_1st, REPLICATE('0',50))
				,@BetOptionHome_2nd = ISNULL(@BetOptionHome_2nd, REPLICATE('0',50))
				,@BetOptionAway_1st = ISNULL(@BetOptionAway_1st, REPLICATE('0',50))
				,@BetOptionAway_2nd = ISNULL(@BetOptionAway_2nd, REPLICATE('0',50))
				,@BetOptionHome_2nd = ISNULL(@BetOptionHome_2nd, REPLICATE('0',50))
				,@ResultStatus1st = ISNULL(@ResultStatus1st, REPLICATE('0',50))
				,@ResultStatus2nd = ISNULL(@ResultStatus2nd, REPLICATE('0',50))
				
		BEGIN
			;WITH cteBetOptionHome
			AS
			(
				SELECT	f.pos AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOptionHome_1st) f
				WHERE	f.pos < 46 
				UNION ALL
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOptionHome_2nd) f
				WHERE	f.pos < 45 
			)
			,cteBetOptionAway
			AS
			(
				SELECT	f.pos AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOptionAway_1st) f
				WHERE	f.pos < 46
				UNION ALL
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOptionAway_2nd) f
				WHERE	f.pos < 45
			)
			,cteResutStatus
			AS (
				SELECT	f.pos AS Position, f.ResultStatus AS ResultStatus
				FROM	dbo.f_Set_GetChars(@ResultStatus1st) f
				WHERE	f.pos < 46 
				UNION ALL
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS ResultStatus
				FROM	dbo.f_Set_GetChars(@ResultStatus2nd) f
				WHERE	f.pos < 45
			)
			,cteResult
			AS (
				SELECT rs.Position
					,CASE WHEN rs.ResultStatus IN (4,5) THEN boh.BetOption ELSE 0 END AS BetOptionHome
					,CASE WHEN rs.ResultStatus IN (4,5) THEN boa.BetOption ELSE 0 END AS BetOptionAway
				FROM cteResutStatus rs
					INNER JOIN cteBetOptionHome boh
						ON rs.Position = boh.Position
					INNER JOIN cteBetOptionAway boa
						ON rs.Position = boa.Position

			)
			INSERT INTO @tblAccumulatedScore (bettype, Position, betoption, AccumulatedHomeScore, AccumulatedAwayScore)
			SELECT 229, c1.Position, c1.BetOptionHome + c1.BetOptionAway*10, cH.AccumulatedHomeScore, cA.AccumulatedAwayScore
			FROM cteResult c1
				INNER JOIN cteResutStatus crs
					ON c1.Position = crs.Position
				CROSS APPLY (
					SELECT	ISNULL(SUM(c2.BetOptionHome), 0) as AccumulatedHomeScore
					FROM	cteResult c2
					WHERE	c2.Position <= c1.Position
				) cH
				CROSS APPLY (
					SELECT	ISNULL(SUM(c3.BetOptionAway), 0) as AccumulatedAwayScore
					FROM	cteResult c3
					WHERE	c3.Position <= c1.Position
				) cA
				
			UPDATE r 
				SET AccumulatedHomeScore = a.AccumulatedHomeScore
					,AccumulatedAwayScore = a.AccumulatedAwayScore					
			FROM	#tblResultDetail r
				INNER JOIN @tblAccumulatedScore a
					ON	r.BetType = a.bettype
						AND r.Position = a.Position
			WHERE r.BetType = 229
		END				
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE BetType IN (228, 229))
		SET @Results = CAST((
				SELECT bettype '@Id'
					,(SELECT Position '@p'
							,BetOption '@r'
							,CASE WHEN BetType = 228 THEN OldAccumulatedScore ELSE NULL END '@oa'
							,CASE WHEN BetType = 228 THEN AccumulatedScore ELSE NULL END '@a'
							,CASE WHEN BetType = 229 THEN AccumulatedHomeScore ELSE NULL END '@ah'
							,CASE WHEN BetType = 229 THEN AccumulatedAwayScore ELSE NULL END '@aa'
							,CASE WHEN bettype = 229 THEN 0 ELSE @IsSettleDetermined END AS '@s'
							,CASE WHEN r.BetType IN (228, 229) THEN 1 ELSE NULL END AS '@i' -- HasInjuryTime
						FROM #tblResultDetail WHERE r.bettype = bettype FOR XML PATH('r'), TYPE)
				FROM #tblResultDetail r
				GROUP BY r.bettype
				FOR XML PATH('b'), ROOT ('r'), TYPE
			) AS VARCHAR(MAX))	

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
		, @IsCentral		= @IsCentral
	
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
			, @IsCentral		= @IsCentral
		
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
		, @IsCentral		= @IsCentral
	
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

	EXEC dbo.Logfile_V2 
		@UserID = @AdminId
		,@Doing = @logdata
		,@extend = @MatchId
	
	IF @IsCentral = 1
	BEGIN
		SET @LogResult = CONVERT(VARCHAR(MAX),(SELECT BetType '@Id'
			,MIN(r.position) AS 'Item/@MinPosition'
			,MAX(r.position) AS 'Item/@MaxPosition'
			, STUFF((SELECT ',' + CAST(t.Position AS VARCHAR(3)) 
					 FROM (
						SELECT	t.BetType, t.Position
						FROM	#tblResultDetail t
						WHERE	t.BetType = r.bettype
								AND 1 = CASE 
											WHEN t.bettype IN (228,229) AND t.BetOption = 0 THEN 0
											ELSE 1
										END									 
						UNION
						SELECT	a.bettype, a.Position
						FROM	 @tblAccumulatedScore a
						WHERE	a.bettype IN (228,229)
								AND a.bettype = r.BetType
								AND a.BetOption > 0
						) t
					 WHERE BetType = r.BetType 
					 ORDER BY t.Position
					 FOR XML PATH ('')),1,1,''
				) AS 'Item/@Position'
			, CASE WHEN @Action = 'CAL' THEN STUFF((SELECT ',' + CAST(t.BetOption AS VARCHAR(3)) 
													FROM (
														SELECT	t.bettype, t.BetOption, t.Position
														FROM	#tblResultDetail t
														WHERE	t.BetType = r.bettype
																AND 1 = CASE 
																			WHEN t.bettype IN (228,229) AND t.BetOption = 0 THEN 0
																			ELSE 1
																		END	
														UNION
														SELECT	a.bettype, a.BetOption, a.Position
														FROM	@tblAccumulatedScore a
														WHERE	a.bettype IN (228,229)
																AND a.bettype = r.BetType
																AND a.BetOption > 0
													) t WHERE	t.BetType = r.BetType 
														ORDER BY t.Position
														FOR XML PATH ('')),1,1,''
												) END AS 'Item/@Result'
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
	END
	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistFM			= 1
		,@isExistFM2		= 1
		, @IsReleased		= 1
	
END
GO
