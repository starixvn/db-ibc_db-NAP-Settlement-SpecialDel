/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_BetBuilder]
	 @AdminId			INT				
	,@MatchId			INT
	,@Resources			VARCHAR(MAX)	
	,@Action			VARCHAR(10)		= 'CAL'
	,@IsAuto			BIT				= 1
	,@VendorID			SMALLINT		= 34
	,@IP				VARCHAR(15)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: Vicky
	Date: 20181228
	Task: BetBuilder Auto/Manual Settlement
	DB: DBTXN/BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200713@Kathy: Add more param for function f_Set_Calculate_modds [Redmine:#135846]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
		@Action : CAL, UNDO, 
				  CAL_MARKET: settle by marketIDs, ignore validation, @IsAuto should be = 0
				  
		IF @IsAuto = 1 OR @Action LIKE '%MARKET'
			@Resources = '<Resources>
				            <rsc m="1"/>
				            <rsc m="2"/>
				            <rsc m="3"/>
				            <rsc m="4"/>
				            <rsc m="5"/>
				         </Resources>'
			
		------------------------------------------------------------------------
		IF @IsAuto = 0			  
			@Resources = '<Resources>
								<Resource Id="200" Result="WON"/>
								<Resource Id="201" Result="WON"/>
								<Resource Id="202" Result="WON"/>
								<Resource Id="203" Result="REFUND"/>
								<Resource Id="204" Result="LOSE"/>
						   </Resources>'
		
		Example:
				--settle by auto
				DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
				SELECT @ErrCode = 0, @ErrMsg = ''
					EXEC [dbo].[NAP_Admin_Settlement_BetBuilder] @MatchId	= 1
																  ,@Action	= 'CAL'
																  ,@AdminId = 8
																  ,@IsAuto	= 1
																  ,@Resources = '<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'
																  ,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
				SELECT @ErrCode,@ErrMsg
			
			
				--settle by SAS		
				DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
				SELECT @ErrCode = 0, @ErrMsg = ''												         
				EXEC [dbo].[NAP_Admin_Settlement_BetBuilder] @MatchId	= 1
															  ,@Action	= 'CAL_MARKET'
															  ,@AdminId = 8
															  ,@IsAuto	= 0
															  ,@Resources = '<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'
															  ,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
				SELECT @ErrCode,@ErrMsg
			
			
				--settle by manual
				DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
				SELECT @ErrCode = 0, @ErrMsg = ''
				EXEC [dbo].[NAP_Admin_Settlement_BetBuilder] @MatchId	= 1
															  ,@Action	= 'CAL'
															  ,@AdminId = 8
															  ,@IsAuto	= 0
															  ,@Resources = '<Resources><Resource Id="200" Result="WON"/><Resource Id="203" Result="REFUND"/></Resources>'
															  ,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
				SELECT @ErrCode,@ErrMsg
*/	
BEGIN
	SET NOCOUNT ON
		
	DECLARE --------hard code---------------------------------------------------
			@Bettype			INT				= 38
			,@pfID				SMALLINT		= 38
			,@batchNo			INT 			= 2000
			,@maximumRows		INT				= 2000
			,@ActionIDLogMarketID INT			= 81011
			--------------------------------------------------------------------
			,@ActionID			INT
			,@sportType 		INT
			,@ResultStatusID	TINYINT
			,@IsSettleByMarket	BIT				= 0
			,@ticketCount		INT				= 0
			,@TotalAccount		INT
			,@TotalAccount_BalanceUpdate INT
			,@batchCount		INT		
			,@strDataByBatch	VARCHAR(MAX)	= ''
			,@xml				XML
			,@startRowIndex		INT
			--------------log---------------------------------------------------
			,@start				DATETIME
			,@stop				DATETIME
			,@avaiableProcess	BIT
			,@ResultRemarkLog	VARCHAR(MAX)	= ''
			,@Remark			VARCHAR(MAX)
			,@LogData			NVARCHAR(MAX)
			,@ErrMsgMarketID	VARCHAR(MAX)
			,@SelectedResources	VARCHAR(MAX)
			,@ActionProcessing	VARCHAR(MAX)
			,@minMarketID 		VARCHAR(20)
			,@maxMarketID		VARCHAR(20)
			,@fth				INT
			,@fta				INT
			,@hth				INT
			,@hta				INT
			,@IsCentral			BIT

  	--START Balance tables
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		   , @BalanceWalletAfter		TVP_BalanceWalletChange
	--END Balance tables

	CREATE TABLE #tblMatchProcessKeyValue2 (matchID INT, keyID TINYINT, KeyValue2 VARCHAR(20))
	CREATE TABLE #tblTransID (transID BIGINT, modds SMALLMONEY, result VARCHAR(20), custID INT)
	CREATE TABLE #tblTransIDRefund (transID BIGINT)
	CREATE TABLE #tblTransIDUndo (transID BIGINT, custID INT)
	CREATE TABLE #tblDataByBatch (vID BIGINT,strID VARCHAR(20), modds SMALLMONEY, result VARCHAR(20))
	CREATE TABLE #tblMarket (rowNum INT NOT NULL IDENTITY(1,1) PRIMARY KEY, marketID VARCHAR(20), result VARCHAR(20), modds SMALLINT
							,UNIQUE CLUSTERED (rowNum)
							,UNIQUE NONCLUSTERED (marketID)
							)
	CREATE TABLE #tblMarketSelection (marketSelectionID BIGINT, result VARCHAR(20))
	CREATE TABLE #tblCustIDBalanceUpdated (custID INT NOT NULL)
	----------------------------------------------------------------------------------------------------------------------

  	SELECT  @start = CURRENT_TIMESTAMP
		   ,@ActionProcessing = @Action
		   ,@ActionID = CASE
						  WHEN @Action IN ('CAL','CAL_MARKET')  AND @IsAuto = 0 THEN 81009
						  WHEN @Action = 'UNDO' AND @IsAuto = 0 THEN 81010
						  WHEN @Action = 'CAL'  AND @IsAuto = 1 THEN 81012
						  ELSE 0
					   END
			,@ResultStatusID = CASE 
						WHEN @Action = 'UNDO' THEN 3 					--undo
						WHEN @IsAuto = 1 THEN 2 						--auto cal
						ELSE 5 END 										--manual cal
			,@IsSettleByMarket = CASE
						WHEN @IsAuto = 1 OR @Action LIKE '%MARKET' THEN 1
						ELSE 0 END

	IF @ActionID = 0
		RETURN
	
	--get info of match
  	/*SELECT @fth			= finalhomescore
		  ,@fta			= finalawayscore
		  ,@hth			= hthomescore
		  ,@hta			= htawayscore
  	FROM DBPRO.BODB02.dbo.match WITH (NOLOCK)
  	WHERE matchid = @matchid*/

	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

  	------------------------------------------get market info-----------------------------------------
	IF @IsSettleByMarket = 1
	BEGIN

		SET @xml = CAST(@Resources AS XML)
				
		;WITH TmpData AS (
			SELECT T.C.value('@m', 'VARCHAR(20)') AS MarketID
			FROM @xml.nodes('/Resources/rsc') AS T(C)
		)
		INSERT INTO #tblMarket (MarketID)
		SELECT	d.MarketID
		FROM TmpData d
			INNER JOIN DBPRO.bodb02.dbo.SMP_Market mk WITH (NOLOCK) ON d.MarketID = mk.MarketID	
		WHERE mk.MatchID = @MatchID
			AND mk.VendorID = @VendorID
			AND (mk.ResultStatusID NOT IN (2, 5, 3) OR @IsAuto = 0) --Auto Settled, Manually settled, UNDO
			AND mk.Result IS NOT NULL
	END
	ELSE
	BEGIN
	
		INSERT INTO #tblMarket (MarketID)
		EXEC DBPRO.bodb02.dbo.NAP_Admin_ChangedMarket_Sel
					@matchID			= @matchID
					,@VendorID			= @VendorID
					,@action			= @Action
					,@Resources			= @Resources
					,@ResultStatusID	= @ResultStatusID
		
	END
		
	-- check and not allow attempt to settlement same game while it's still not finish
  	INSERT INTO #tblMatchProcessKeyValue2(matchID, KeyID, KeyValue2)
  	SELECT	@matchID AS matchID, 5 AS KeyID, MarketID
  	FROM #tblMarket
  	----------------------------------------------------------------------------------------------------------------------
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch			= 1
		  , @avaiableProcess 	= @avaiableProcess OUTPUT
		  , @checkKeyValue2		= 1
		  , @ErrCode			= @ErrCode OUTPUT
		  , @ErrMsg				= @ErrMsg OUTPUT

	--check error
	IF(@ErrCode <> 0 OR @avaiableProcess = 0)
	BEGIN
		SELECT   @ErrCode   = 1000000
				,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

		RETURN
	END
	
		
	SELECT @minMarketID = MIN(marketID)
		   ,@maxMarketID = MAX(marketID)
	FROM #tblMarket
	
	/*IF @IsAuto = 1
	BEGIN
		------------------------------skip MarketIDs have been already settled
		DELETE r
		FROM #tblMarket r
			INNER JOIN DBPRO.bodb02.dbo.SMP_Market m WITH (NOLOCK) ON r.MarketID = m.MarketID	
		WHERE m.ResultStatusID IN (2, 5, 3) --Auto Settled, Manually settled, UNDO
			AND MatchID = @MatchID
			AND VendorID = @VendorID
	END*/
	

	---------lock table SMP_Market---------------------------------------------
	SET @startRowIndex = 0
	WHILE 1=1
	BEGIN
		TRUNCATE TABLE #tblDataByBatch
		
		INSERT INTO #tblDataByBatch(strID, result)
		SELECT MarketID, result
		FROM #tblMarket t 
		WHERE RowNum BETWEEN @startRowIndex AND (@startRowIndex + 5000)

		SELECT @batchCount 		= @@ROWCOUNT
			  ,@startRowIndex 	= @startRowIndex + 5000
		
		IF @batchCount = 0 BREAK

		SET @strDataByBatch 	= (SELECT strID		AS '@m'
								   FROM #tblDataByBatch
								   FOR XML PATH('Resource'), ROOT( 'Resources'))
				   
		EXEC DBPRO.bodb02.dbo.NAP_Admin_SMPMarket_Update @matchID 			= @matchID
														,@VendorID			= @VendorID
														,@action			= @action
														,@resources 		= @strDataByBatch
														,@resultStatusID 	= @ResultStatusID
														,@mode				= 'ResultStatusID'
	END

	
	---------SMP_MarketSelection---------------------------------------------------
	IF @IsSettleByMarket = 1
	BEGIN
		
		INSERT INTO #tblMarketSelection (marketSelectionID)
		SELECT ml.marketSelectionID
		FROM DBPRO.bodb02.dbo.SMP_MarketSelection ml WITH (NOLOCK)
		WHERE EXISTS (SELECT MarketID FROM #tblMarket WHERE ml.MarketID = #tblMarket.MarketID)
			AND ml.MatchID = @MatchID
			AND ml.MarketID BETWEEN @minMarketID AND @maxMarketID
	END
	ELSE
	BEGIN
		INSERT INTO #tblMarketSelection (marketSelectionID, Result)
		EXEC DBPRO.bodb02.dbo.NAP_Admin_MarketSelection_Sel 
					@matchID						= @MatchID
					,@action						= @action
					,@Resources						= @Resources
	END
	
	
	---- UPDATE SMP_MarketSelection
	IF @IsCentral = 1
	BEGIN
		SET @startRowIndex = 0
		WHILE 1=1
		BEGIN
			TRUNCATE TABLE #tblDataByBatch
		
			/*INSERT INTO #tblDataByBatch(vID, result)
			SELECT marketSelectionID, result
			FROM #tblMarketSelection t 
			WHERE RowNum BETWEEN @startRowIndex AND (@startRowIndex + @maximumRows) - 1*/
		
			DELETE TOP (4000) #tblMarketSelection
			OUTPUT DELETED.marketSelectionID, DELETED.result
			INTO #tblDataByBatch(vID, result)

			SELECT @batchCount 	= @@ROWCOUNT
				  --,@startRowIndex = @startRowIndex + @maximumRows
		
			IF @batchCount = 0 BREAK
		
			SET @strDataByBatch 	= (SELECT vID		AS '@msl'
									  		  ,result	AS '@rs'
									   FROM #tblDataByBatch
									   FOR XML PATH('Resource'), ROOT( 'Resources' ))
		
			EXEC DBPRO.bodb02.dbo.NAP_Admin_SMPMarketSelection_Update @matchID 	= @matchID
															,@action			= @action
															,@resources 		= @strDataByBatch
															,@resultStatusID 	= @ResultStatusID
		END
	END
	-- -------END SMP_MarketSelection-----------------------------------------------
	
			
	
	--update result of markets into temp table
	IF @IsSettleByMarket <> 1 AND @IsCentral = 1
  	BEGIN
	  	
	  	---------Update Result and ResultStatusID for SMP_Market--------------------------------------------------------
	  	
		SET @startRowIndex = 0
		WHILE 1=1
		BEGIN
			TRUNCATE TABLE #tblDataByBatch
			
			INSERT INTO #tblDataByBatch(strID, result)
			SELECT MarketID, result
			FROM #tblMarket t 
			WHERE RowNum BETWEEN @startRowIndex AND (@startRowIndex + @maximumRows) - 1
	
			SELECT @batchCount 		= @@ROWCOUNT
				  ,@startRowIndex 	= @startRowIndex + @maximumRows
			
			IF @batchCount = 0 BREAK
	
			SET @strDataByBatch 	= (SELECT strID				AS '@m'
									   FROM #tblDataByBatch
									   FOR XML PATH('Resource'), ROOT( 'Resources'))
							   
			EXEC DBPRO.bodb02.dbo.NAP_Admin_SMPMarket_Update @matchID 			= @matchID
															,@action			= @action
															,@resources 		= @strDataByBatch
															,@resultStatusID 	= @ResultStatusID
		END
	END
	
	-- -------END SMP_Market--------------------------------------------------------
	
	
	---------START get transID--------------------------------------------------
  	IF @Action LIKE 'CAL%'
  	BEGIN
		--update result of market into temp table
		UPDATE #tblMarket
		SET Result = mk.Result
			,modds = m.modds
		FROM #tblMarket tmk
			INNER JOIN DBPRO.bodb02.dbo.SMP_Market mk WITH (NOLOCK) ON tmk.MarketID = mk.MarketID
			CROSS APPLY dbo.f_Set_Calculate_modds(@pfID, NULL, NULL, NULL, mk.Result, NULL, NULL, NULL, NULL, NULL) m
		WHERE mk.MatchID = @MatchID 
				AND mk.MarketID BETWEEN @minMarketID AND @maxMarketID
				AND mk.VendorID = @VendorID
			
	  	INSERT INTO #tblTransID(TransID, modds, Result, custID)
	  	SELECT transID
	  			,mk.modds
	  			,mk.Result
	  			,b.custID
	  	FROM dbo.bettrans b WITH (NOLOCK)
	  		INNER JOIN #tblMarket mk ON b.BetCheck = mk.MarketID
	  	WHERE b.matchID = @MatchID
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  		AND b.Bettype = @Bettype
	  		AND b.statusID NOT IN (101,102) --VOID, REJECT
	  		AND 1 = CASE WHEN mk.Result = 'REFUND' AND b.statusID = 103 THEN 0
	  					 WHEN mk.Result IS NULL AND b.statusID = 0 THEN 0
	  					 ELSE 1 END
	  	
	  	SELECT @TotalAccount = (SELECT COUNT(DISTINCT custID) FROM #tblTransID)
	  	
	  	DELETE t
	  	OUTPUT DELETED.TransID INTO #tblTransIDRefund (TransID)
	  	FROM #tblTransID t
		WHERE Result = 'REFUND'
		
		
		DELETE t
	  	OUTPUT DELETED.TransID INTO #tblTransIDUndo (TransID)
	  	FROM #tblTransID t
		WHERE Result IS NULL
		
	END
	ELSE IF @action LIKE 'UNDO%'
	BEGIN
		
		INSERT INTO #tblTransIDUndo(TransID, custID)
	  	SELECT transID, b.custID
	  	FROM dbo.bettrans b WITH (NOLOCK)
	  		INNER JOIN #tblMarket m ON b.BetCheck = m.MarketID
	  	WHERE b.matchID = @MatchID
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  		AND b.Bettype = @Bettype
	  		AND	b.statusID NOT IN (102, 101, 0, 1)--VOID, REJECT, RUNNING
	  		AND m.Result IS NULL
	  		
	  	SELECT @TotalAccount = (SELECT COUNT(DISTINCT custID) FROM #tblTransIDUndo)
	END 
	--END get transID-----------------------------------------------------
	
	
	
	------START CAL, UNDO-------------------------------------------------
	SELECT @startRowIndex = 0,@ActionProcessing = @Action
	WHILE 1=1
	BEGIN
		-------------BEGIN TRY--------------------------------------------
		BEGIN TRY
		
			TRUNCATE TABLE #tblDataByBatch
			DELETE FROM @BalanceWalletBefore
			DELETE FROM @BalanceWalletAfter
			
			IF @ActionProcessing LIKE 'CAL%'
			BEGIN
				
				DELETE TOP (@batchNo) #tblTransID
				OUTPUT DELETED.transID, DELETED.modds
				INTO #tblDataByBatch(vID, modds)
				
				SELECT @batchCount 	= @@ROWCOUNT
				
				IF @batchCount = 0
				BEGIN
					SELECT @ActionProcessing = 'REFUND'
				END
			END
			
			
			IF @ActionProcessing LIKE 'REFUND%'
			BEGIN
				
				DELETE TOP (@batchNo) #tblTransIDRefund
				OUTPUT DELETED.transID
				INTO #tblDataByBatch(vID)
				
				SELECT @batchCount 	= @@ROWCOUNT
				
				IF @batchCount = 0
				BEGIN
					SELECT @ActionProcessing = 'UNDO'
				END
			END
			
			IF @ActionProcessing LIKE 'UNDO%'
			BEGIN
				
				DELETE TOP (@batchNo) #tblTransIDUndo
				OUTPUT DELETED.transID
				INTO #tblDataByBatch(vID)
				
				SELECT @batchCount 	= @@ROWCOUNT
			END
			
			SELECT @ticketCount	+= @batchCount
				  
			
			IF @batchCount = 0 BREAK

			
			SET @strDataByBatch 	= (SELECT vID		AS '@t'
											   ,modds	AS '@m'
											   ,1		AS '@ot'
									   FROM #tblDataByBatch
									   FOR XML PATH('r'), ROOT( 'root' ))

			--------------------------------------------------------------------
			---		CAPTURE value BALANCE before settlement		---
			---------------------------VVVV-------------------------------------
			
			
			INSERT INTO @BalanceWalletBefore (matchID, custID, balanceType, WalletType, BonusID, balance)
			EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
							@MatchID 				  = @matchID
							,@sportType				  = @sportType
							,@Action 				  = @ActionProcessing
							,@Mode 					  = 2
							,@TransIDs				  = @strDataByBatch
							,@IsCentral				  = @IsCentral
		
		    EXEC dbo.NAP_Admin_Calculate_Main
							@matchid	  		 = @matchid
						   ,@action				 = @ActionProcessing
						   ,@IsSettingByProfile  = 1
						   ,@strTransIds		 = @strDataByBatch

			------END UPDATE BETTRANS---------------------------------------------------------------------------
			
			   
			-------------------------------------------------------------
			---		 CAPTURE value BALANCE after settlement		---
			---------------------------VVVV------------------------------
			INSERT INTO @BalanceWalletAfter (matchID, custID, balanceType, WalletType, BonusID, balance)
			EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
						@MatchID		  	= @matchID
						,@sportType			= @sportType
						,@Action 			= @ActionProcessing
						,@Mode 			  	= 2 --Used for Manual settle process
						,@TransIDs			= @strDataByBatch
						,@IsCentral				  = @IsCentral
		
			-- Compare and update pending balance with error case
			EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
						@BalanceWalletBefore	= @BalanceWalletBefore
						,@BalanceWalletAfter	= @BalanceWalletAfter
						,@ActionID				= @ActionID
			
			
						
			--SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT a.custID)
			INSERT INTO #tblCustIDBalanceUpdated(custID)
			SELECT a.custID
			FROM @BalanceWalletAfter a
				INNER JOIN @BalanceWalletBefore b 
				ON	 a.matchID				= b.matchID
						AND a.custID		= b.custID
						AND a.balanceType	= b.balanceType
						AND a.walletType	= b.walletType
						AND a.bonusID		= b.bonusID
			WHERE a.balance <> b.balance
			
		END TRY
		BEGIN CATCH
			  -------------------------------------------------------------
			  ---		 CAPTURE value BALANCE after settlement		---
			  ---------------------------VVVV------------------------------
			  
			  INSERT INTO @BalanceWalletAfter (matchID, custID, balanceType, WalletType, BonusID, balance)
			  EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
					  @MatchID 				= @matchID
					  , @sportType			= @sportType
					  , @Action 			= @ActionProcessing
					  , @Mode 				= 2 --Used for Manual settle process
					  , @TransIDs			= @strDataByBatch
					  , @IsCentral				  = @IsCentral
		
			  -- Compare and update pending balance with error case
			  EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					  @BalanceWalletBefore	= @BalanceWalletBefore
					  , @BalanceWalletAfter	= @BalanceWalletAfter
					  , @ActionID			= @ActionID
			  
			  --SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT a.custID)
			  INSERT INTO #tblCustIDBalanceUpdated(custID)
			  SELECT a.custID
			  FROM @BalanceWalletAfter a
					INNER JOIN @BalanceWalletBefore b 
					ON	 a.matchID				= b.matchID
							AND a.custID		= b.custID
							AND a.balanceType	= b.balanceType
							AND a.walletType	= b.walletType
							AND a.bonusID		= b.bonusID
				WHERE a.balance <> b.balance
					
				
			  SELECT	@ErrCode = 1001017
						,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE()
		
			  ------ releasing Settlement process
			  EXEC dbo.NAP_Admin_CheckingProcess
						  @isExistMatch		= 1
						  ,@IsReleased		= 1
		
			  RETURN
		END CATCH
	END
	------END settle---------------------------------------------------

	------ releasing Settlement process
    EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistMatch		= 1
			  ,@checkKeyValue2	= 1
			  ,@IsReleased		= 1
	
	
	-------------------------------------------------------------
	---					  WRITE LOG						---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP
	
	
	----------------------------------------------------------------------------
	
	
	

				
	--log marketID
	DECLARE @LogDate DATETIME = GETDATE()
			,@LogIDOutput	 BIGINT
	
	IF @IsSettleByMarket = 1 AND EXISTS(SELECT TOP 1 1 FROM #tblMarket)
	BEGIN
		SELECT @Remark = ''

		SELECT @Remark = @Remark + CAST(marketID AS VARCHAR(20)) + ','
		FROM	#tblMarket

		SET @SelectedResources = 'MarketIds: ' + STUFF(@Remark, LEN(@Remark), 1, '')
	END
	ELSE
	BEGIN
		
		DECLARE @xmlLogResult XML
		SET @SelectedResources = ''
		
		
		SET @xmlLogResult = CAST(@Resources AS XML)
		;WITH cteData AS (
			SELECT T.C.value('@Id', 'INT') AS selectionType
				   ,T.C.value('@Result', 'VARCHAR(20)') AS result
			FROM @xmlLogResult.nodes('/Resources/Resource') AS T(C)
		)
		SELECT @SelectedResources = @SelectedResources + ',' + s.SelectionName + (CASE WHEN result IS NULL THEN '' ELSE '(' + result + ')' END)
		FROM cteData
			INNER JOIN DBPRO.bodb02.dbo.SMP_Selection s WITH(NOLOCK) ON s.SelectionType = cteData.selectionType
			
		SELECT @SelectedResources = 'Selections:' + STUFF(@SelectedResources, 1, 1, '')
	END
		
	SELECT @TotalAccount_BalanceUpdate = (SELECT COUNT(DISTINCT custID) FROM #tblCustIDBalanceUpdated)
	
	SELECT @logdata = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10))
							+ CASE WHEN @SelectedResources IS NULL THEN '' ELSE '; ' + @SelectedResources + '<br/> ' END
							+ '; IsAuto:' + CAST(@IsAuto AS VARCHAR(10))
							+ '; Bettype:' + CAST(@Bettype AS VARCHAR(10))
							+ '<br/> '
							+ '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.Logfile_V2 
		@UserID = @AdminId
		,@Doing = @logdata
		,@extend = @MatchId
				
	IF @IsCentral = 1
	BEGIN
		SELECT @Remark = CASE WHEN @SelectedResources IS NULL THEN '' ELSE @SelectedResources + '<br/> ' END 
							/*+ ' IsAuto:' + CAST(@IsAuto AS VARCHAR(10))
							+ '; Bettype:' + CAST(@Bettype AS VARCHAR(10))
							+ '<br/> ' */
							+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
							+ '; TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
							+ '; Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
				
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
					@userid				= @AdminId
					,@matchid			= @MatchID
					,@actionid			= @ActionID
					,@finalhomescore	= @fth
					,@finalawayscore	= @fta
					,@hthomescore		= @hth
					,@htawayscore		= @hta
					,@GoalRecord		= NULL
					,@Remark			= @Remark
					,@ip				= @ip
		END TRY
		BEGIN CATCH
		
			SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
					@UserID				= @AdminId
					,@MatchID			= @MatchID
					,@actionid			= @ActionID
					,@finalhomescore	= @fth
					,@finalawayscore	= @fta
					,@hthomescore		= @hth
					,@htawayscore		= @hta
					,@GoalRecord		= NULL
					,@betstatus			= NULL
					,@Remark			= @Remark
					,@IP				= @ip
		END CATCH
	END
END
GO