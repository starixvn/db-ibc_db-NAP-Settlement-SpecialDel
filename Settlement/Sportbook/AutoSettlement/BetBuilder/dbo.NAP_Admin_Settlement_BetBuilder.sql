/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_BetBuilder]
	 @AdminId			INT				
	,@MatchId			INT
	,@SelectedMarket	VARCHAR(MAX)	= NULL
	,@SelectedSelection	VARCHAR(MAX)	= NULL
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
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]

	Param's Explanation:
		@Action : CAL, UNDO, 
				
		@SelectedMarket = '<Resources>
				        <rsc m="1"/>
				        <rsc m="2"/>
				        <rsc m="3"/>
				        <rsc m="4"/>
				        <rsc m="5"/>
				        </Resources>'
		
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
		
			,@ticketCount		INT				= 0
			,@TotalAccount		INT
			,@TotalAccount_BalanceUpdate INT
			,@batchCount		INT		
			,@strDataByBatch	VARCHAR(MAX)	= ''
			
			,@xmlMarket			XML
			,@startRowIndex		INT
			--------------log---------------------------------------------------
			,@start				DATETIME
			,@stop				DATETIME
			,@avaiableProcess	BIT
			,@ResultRemarkLog	VARCHAR(MAX)	= ''
			,@Remark			VARCHAR(MAX)
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

	IF @ActionID = 0
		RETURN
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

  	------------------------------------------get market info-----------------------------------------
	SET @xmlMarket = CAST(@SelectedMarket AS XML)

	INSERT INTO #tblMarket(marketID)
	SELECT T.C.value('@m', 'VARCHAR(20)') AS MarketID
	FROM @xmlMarket.nodes('/Resources/rsc') AS T(C)
		
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
		
			EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = @ActionProcessing
			   ,@strTransIds		 = @strDataByBatch
			   ,@Is3rd				 = 1
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
				ON	a.matchID				= b.matchID
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
					  , @IsCentral			= @IsCentral
		
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
					ON	a.matchID				= b.matchID
						AND a.custID		= b.custID
						AND a.balanceType	= b.balanceType
						AND a.walletType	= b.walletType
						AND a.bonusID		= b.bonusID
				WHERE a.balance <> b.balance
					
			  SELECT	@ErrCode = 1001017
						,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE()
		
		END CATCH
	END
	------END settle---------------------------------------------------

	------ releasing Settlement process
    EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistMatch		= 1
			  ,@checkKeyValue2	= 1
			  ,@IsReleased		= 1
	
	IF @ErrCode > 0
		RETURN

	-------------------------------------------------------------
	---					  WRITE LOG						---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP
	--log marketID
	DECLARE @LogDate DATETIME = GETDATE()
			,@LogIDOutput	 BIGINT
	
	BEGIN
		
		DECLARE @xmlLogResult XML
		SET @SelectedResources = ''		
		
		SET @xmlLogResult = CAST(@SelectedSelection AS XML)
		;WITH cteData AS (
			SELECT T.C.value('@Id', 'INT') AS selectionType
				   ,T.C.value('@Result', 'VARCHAR(20)') AS result
			FROM @xmlLogResult.nodes('/Resources/Resource') AS T(C)
		)
		SELECT @SelectedResources = @SelectedResources + ',' + s.SelectionName + (CASE WHEN result IS NULL THEN '' ELSE '(' + result + ')' END)
		FROM cteData
			INNER JOIN DBPRO.bodb02.dbo.SMP_Selection s WITH(NOLOCK) 
				ON s.SelectionType = cteData.selectionType
			
		SELECT @SelectedResources = 'Selections:' + STUFF(@SelectedResources, 1, 1, '')
	END
		
	SELECT @TotalAccount_BalanceUpdate = (SELECT COUNT(DISTINCT custID) FROM #tblCustIDBalanceUpdated)
				
	IF @IsCentral = 1
	BEGIN
		SELECT @Remark = CASE WHEN @SelectedResources IS NULL THEN '' ELSE @SelectedResources + '<br/> ' END 							
							+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
							+ '; TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
							+ '; Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
				
		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle
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

	END
END
GO