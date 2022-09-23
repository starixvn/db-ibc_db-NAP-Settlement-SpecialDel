/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_CoreAPI" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Auto_1s]
     @AdminID                       INT             = 148        -- calculated by system (default)
    ,@MatchID                       INT
	,@SelectedResources				VARCHAR(MAX)	= ''
    ,@Action                    	VARCHAR(10)     = 'CAL'
    ,@IsAuto                        BIT             = 1
    ,@IP                            VARCHAR(15)     = ''
	,@IsReSettledTickets			BIT				= 1
	,@BroadcastSessionId			VARCHAR(50)		= NULL
    ,@ErrCode            			INT             = 0		OUTPUT
    ,@ErrMsg            			NVARCHAR(200)   = ''    OUTPUT
AS
/*  Creator: Jamie
    Date: 20150120
    Task: BetRadar Auto/Manual Settlement
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
        - 20150610@Johnson: Add bettrade [Redmine: #35921]
        - 20150806@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
        - 20160525@Kathy: Change the main Parlay Settlement SP
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
        - 20170215@Kathy: Get list bettypes with xml format [Redmine:#71372]
        - 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20170425@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190528@Kathy: Write log @IsReSettledTickets [Redmine:#113460]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200515@Kathy: Settlement Exclusion [Redmine:#134103]
		- 20200428@Kathy: PHAIO 5 - Add new penalty bettype[Redmine:#132805]
		- 20200713@Kathy: Add more param for function f_Set_Calculate_modds [Redmine:#135846]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201113@Louisa: Check Hold Result [Redmine:#135097]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
		 @SelectedResources: <Resources>
						    	<Resource Id="" Home="" Away="" />
						    	<Resource Id="" Home="" Away="" />
						      </Resources>
*/    
BEGIN
    SET NOCOUNT ON 

    DECLARE @start              DATETIME
            ,@stop              DATETIME
            ,@fth               INT
            ,@fta               INT
            ,@hth               INT
            ,@hta               INT
            ,@goalrecord        VARCHAR(50)
            ,@betstatus         VARCHAR(50) 
            ,@ActionID          INT
            ,@Remark			VARCHAR(500)
            ,@LogData           NVARCHAR(300)
			,@handle			INT			
                                
			,@avaiableProcess	BIT
            ,@sportType			INT
			,@SelectedRID		VARCHAR(MAX)	
			,@batchNo			INT 			
			,@batchCount		INT		
			,@strTransIds		VARCHAR(MAX)	
			,@homeRound			TINYINT
			,@awayRound			TINYINT
			,@IsExistDetermined BIT
			,@TotalSubParlay	INT 
			,@SelectedResourceParlay VARCHAR(MAX) 
			,@ThreadHold		INT 
			,@LockedByRefno		BIT
			,@sqlCommand		VARCHAR(MAX)
			,@procName			SYSNAME
			,@ActionParlay		VARCHAR(20)
			,@IsCentral			BIT

	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
			,@BalanceWalletAfter			TVP_BalanceWalletChange

	DECLARE @tmpSelectedRID TABLE(
		ResourceID	VARCHAR(20)
		,HomeValue	VARCHAR(50)
		,AwayValue	VARCHAR(50)
		,BetType	SMALLINT
		,BetID		BIGINT
		,pfID		SMALLINT
		,oddstype	SMALLINT
		,IsDetermined BIT
		,PRIMARY KEY (BetType,BetID)
	)    
		
	DECLARE @tmpTransIDBatch TABLE (
		TransID		BIGINT
		,modds		SMALLMONEY
		,oddstype	SMALLINT
		,IsMarked	BIT
		,srecommend INT
		,bettype	SMALLINT
	)
	
	CREATE TABLE #tblMatchProcess (
		matchid INT
		,KeyID TINYINT
	)

	CREATE TABLE #tmpTransID (
		TransID		BIGINT
		,modds		SMALLMONEY
		,isFinish	BIT
		,oddstype	SMALLINT
		,IsMarked	BIT
		,srecommend INT
		,bettype SMALLINT
	)
	
    SELECT   @start = CURRENT_TIMESTAMP
			,@ActionID = CASE 
							WHEN @Action = 'CAL'    THEN 148 
                            WHEN @Action = 'UNDO'    THEN 149 
                            WHEN @Action = 'REFUND'THEN 150
                            ELSE 0 
						END 
			,@SelectedRID = ''
			,@batchNo = 2000
			,@strTransIds = ''
			
			,@IsExistDetermined = 0
			,@TotalSubParlay = 0
			,@SelectedResourceParlay = ''
			,@ThreadHold = 0
			,@LockedByRefno = 0
			,@sqlCommand = ''
			,@procName = OBJECT_NAME(@@procid)
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

    --Write Log Settle
    SELECT   @fth            = finalhomescore
            ,@fta            = finalawayscore
            ,@hth            = hthomescore
            ,@hta            = htawayscore
            ,@goalrecord    = goalrecord 
            ,@betstatus        = betstatus 
            ,@sportType     = sportType
    FROM    DBPRO.BODB02.dbo.match WITH (NOLOCK)
    WHERE    matchid = @matchid

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
		@MatchId	= @Matchid
		,@IsEarly	= 1
		,@SelectedResources = @SelectedResources
		,@ErrCode	= @ErrCode OUTPUT
		,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
	    SELECT	@ErrCode
				,@ErrMsg
	    
	    RETURN
	END

	IF @Action IN ('CAL', 'REFUND')
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= @action
			,@IsEarly 	= 1
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END
        
    INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @matchId AS matchid
		, 1 AS KeyID
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
	
	--CHECK avaiable process
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID, oddstype, IsDetermined)
	SELECT DISTINCT Id, Home, Away, sp.BetType, sp.BetID, sp.pfID, sp.OddsType, ISNULL(tbl.IsDetermined, 0)
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
														,IsDetermined BIT
										) AS tbl
		INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
			ON	sp.ResourceID = tbl.Id
	WHERE sp.SportType = @SportType 

	IF @Action = 'REFUND'
	BEGIN
		DECLARE @ResourceIds VARCHAR(MAX) = ''

		SELECT @ResourceIds = @ResourceIds + ResourceID + ','
		FROM	@tmpSelectedRID

		EXEC dbo.NAP_Set_EarlySettlement_CheckingMarkedTransaction
			@MatchID = @MatchID
			,@ResourceIds = @ResourceIds
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch		= 1
				, @IsReleased		= 1
			
			RETURN
		END
	END

	EXEC sp_xml_removedocument @handle

	SELECT   @SelectedRID   = (SELECT Bettype   AS '@bt'
									 ,BetID	AS '@b'
							  FROM	@tmpSelectedRID
							  FOR XML PATH('r'), ROOT( 'root' )) 

	
	IF (@action = 'REFUND' AND EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID WHERE IsDetermined = 1))
	BEGIN
		SET @IsExistDetermined = 1
	END

	--get transid
  	IF @Action = 'CAL'
  	BEGIN
		INSERT INTO #tmpTransID(TransID, modds, oddstype, IsMarked, srecommend, bettype)
	  	SELECT	b.transid, m.modds, sr.oddstype, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked, b.srecommend, b.bettype
	  	FROM	dbo.bettrans b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transId
			)mt
	  		CROSS APPLY(
	  			SELECT TOP 1 pfID, HomeValue, AwayValue, t.oddstype
	  			FROM	@tmpSelectedRID t
	  			WHERE	b.BetType = t.BetType 
						AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  		) sr
	  		CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, NULL
													, CASE WHEN b.bettype = 376 THEN ISNULL(sr.HomeValue,'') + ISNULL(sr.AwayValue,'') ELSE sr.HomeValue END
													, CASE WHEN b.bettype = 376 THEN b.betcheck ELSE sr.AwayValue END, NULL, NULL, NULL, NULL) m
	  	WHERE	b.matchid = @MatchId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  			AND b.statusID NOT IN (101)
	  			AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END 

		SELECT @TotalSubParlay = COUNT(1)			
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
							FROM	@tmpSelectedRID t
							WHERE	t.BetType = bm.bettype
									AND (t.BetID = 0 OR t.BetID = bm.betcheck))
	END
	ELSE IF @action = 'UNDO'
	BEGIN
		--get transid
		INSERT INTO #tmpTransID(TransID)
	  	SELECT	b.transid
	  	FROM	dbo.bettrans b WITH (NOLOCK)
	  		INNER JOIN @tmpSelectedRID t 
				ON	b.BetType = t.BetType 
					AND (t.BetID = 0 OR b.BetID = t.BetID)
			OUTER APPLY (
					SELECT	TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
				) mt		
	  	WHERE	b.matchid = @MatchId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  			AND	b.statusID NOT IN (101)
	  			AND 1 = CASE WHEN b.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
							 WHEN b.statusID NOT IN (0, 1) THEN 1
							ELSE 0 END

		SELECT @TotalSubParlay = COUNT(1)			
		FROM	dbo.bettransm bm WITH(NOLOCK)
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK) 
				ON	b.matchid = 29
					AND b.bettype = 29
					AND b.refno = bm.refno
			OUTER APPLY (
				SELECT	TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transid
						AND mt.MatchId = @MatchID
			) mt
		WHERE	bm.matchid = @MatchID
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND bm.statusID NOT IN (101)
				AND 1 = CASE WHEN bm.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
								WHEN bm.statusID NOT IN (0, 1) THEN 1
								ELSE 0 
						END
				AND EXISTS (SELECT	TOP 1 1
							FROM	@tmpSelectedRID t
							WHERE	t.BetType = bm.bettype
									AND (t.BetID = 0 OR t.BetID = bm.betcheck))
	END
	ELSE IF @action = 'REFUND' AND @IsExistDetermined = 0
	BEGIN
		--get transid
		INSERT INTO #tmpTransID(TransID)
	  	SELECT	transid
	  	FROM	dbo.bettrans b WITH (NOLOCK)
	  		INNER JOIN @tmpSelectedRID t 
				ON	b.BetType = t.BetType 
					AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  	WHERE	b.matchid = @MatchId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  			AND	b.statusID NOT IN (103, 101)

		SELECT @TotalSubParlay = COUNT(1)			
		FROM	dbo.bettransm bm WITH(NOLOCK)
		WHERE	bm.matchid = @MatchID
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND bm.statusID NOT IN (101, 103)
				AND EXISTS (SELECT	TOP 1 1
							FROM	@tmpSelectedRID t
							WHERE	t.BetType = bm.bettype
									AND (t.BetID = 0 OR t.BetID = bm.betcheck))
	END 
	ELSE IF @action = 'REFUND' AND @IsExistDetermined = 1
	BEGIN
		SELECT 
			@homeRound = ISNULL(RIGHT(MAX(CASE WHEN ResourceID LIKE '3820[12345]' THEN ResourceID END),1),0), 
			@awayRound = ISNULL(RIGHT(MAX(CASE WHEN ResourceID LIKE '3810[12345]' THEN ResourceID END),1),0) 
		FROM 
		(
			SELECT t.ResourceID
			FROM @tmpSelectedRID t
			UNION 
			SELECT	r.ResourceId
			FROM	DBPRO.BODB02.dbo.ResultDetail r WITH(NOLOCK)
			WHERE	MatchID = @MatchID 
					AND ResourceID LIKE '38[12]0[12345]'
					AND SettlementStatusID = 4
					AND ResultStatusID = 5
					AND NOT EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID t WHERE t.ResourceID = r.ResourceId)
		)t

		INSERT INTO #tmpTransID(TransID, modds, oddstype, IsMarked, srecommend, bettype)
	  	SELECT	b.transid, m.modds, sr.oddstype, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked, b.srecommend, b.bettype
	  	FROM	dbo.bettrans b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transId
			)mt
	  		CROSS APPLY(
	  			SELECT TOP 1 pfID, HomeValue, AwayValue, t.oddstype
	  			FROM	@tmpSelectedRID t
	  			WHERE	b.BetType = t.BetType 
						AND (t.BetID = 0 OR b.BetID = t.BetID) 
						AND t.IsDetermined = 1
	  		) sr
	  		CROSS APPLY dbo.f_Set_SDT_CalModds_Early(sr.pfID, b.betteam, b.hdp1, NULL, sr.HomeValue, sr.AwayValue, NULL, NULL, @homeRound, @awayRound) m
	  	WHERE	b.matchid = @MatchId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  			AND b.statusID NOT IN (101)
		
		-- add tranid without determinded and refund
		INSERT INTO #tmpTransID(TransID)
	  	SELECT	transid
	  	FROM	dbo.bettrans b WITH (NOLOCK)
	  		INNER JOIN @tmpSelectedRID t 
				ON	b.BetType = t.BetType 
					AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  	WHERE	b.matchid = @MatchId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  			AND	b.statusID NOT IN (103, 101)
				AND t.IsDetermined = 0

		SELECT @TotalSubParlay = COUNT(1)			
		FROM	dbo.bettransm bm WITH(NOLOCK)
		WHERE	bm.matchid = @MatchID
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND bm.statusID NOT IN (101)
				AND EXISTS (SELECT	TOP 1 1
							FROM	@tmpSelectedRID t
							WHERE	t.BetType = bm.bettype
									AND (t.BetID = 0 OR t.BetID = bm.betcheck))
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
        , @sportType        = @sportType
        , @Action 			= @Action
        , @Mode 			= 2
        , @SelectedRID      = @SelectedRID
		, @IsCentral		= @IsCentral
							
	------START UPDATE BETTRANS---------------------------------------------------------------------------
	BEGIN TRY
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE	TOP(@batchNo) t
				SET	isFinish = 1
			OUTPUT	deleted.transid, deleted.modds, deleted.oddstype, deleted.IsMarked, deleted.srecommend, deleted.bettype
			INTO	@tmpTransIDBatch(transid, modds, oddstype,IsMarked, srecommend, bettype)
			FROM	#tmpTransID t 
			WHERE	isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
			
			IF @batchCount = 0 BREAK

			IF (@IsExistDetermined = 1)
			BEGIN
				--Cal first
				--filter selectedRID by current Profile and BetType
				SET @strTransIds = (SELECT transid	AS '@t'
											,modds	AS '@m'
											,oddstype AS '@ot'
											,IsMarked AS '@im'
											,srecommend AS '@sr'
											,bettype AS '@bt'
									FROM	@tmpTransIDBatch
									WHERE modds IS NOT NULL
									FOR XML PATH('r'), ROOT( 'root' )
								)

				IF (@strTransIds IS NOT NULL OR @strTransIds <> '')
				BEGIN
					EXEC dbo.NAP_Admin_Calculate_Main
						@matchid	  		= @matchid
						,@action			= 'CAL'
						,@IsSettingByProfile = 1
						,@strTransIds		 = @strTransIds
				END

				--Refund after 
				SET @strTransIds = (SELECT transid	AS '@t'
											,modds	AS '@m'
											,oddstype AS '@ot'
											,IsMarked AS '@im'
											,srecommend AS '@sr'
											,bettype AS '@bt'
									FROM	@tmpTransIDBatch
									WHERE modds IS NULL
									FOR XML PATH('r'), ROOT( 'root' )
								)
				
				IF (@strTransIds IS NOT NULL OR @strTransIds <> '')
				BEGIN
					EXEC dbo.NAP_Admin_Calculate_Main
						@matchid	  		= @matchid
						,@action			= 'REFUND'
						,@IsSettingByProfile = 1
						,@strTransIds		 = @strTransIds
				END
			END
			ELSE 
			BEGIN
				--filter selectedRID by current Profile and BetType
				SET @strTransIds = (SELECT transid	AS '@t'
											,modds	AS '@m'
											,oddstype AS '@ot'
											,IsMarked AS '@im'
											,srecommend AS '@sr'
											,bettype AS '@bt'
									FROM	@tmpTransIDBatch
									FOR XML PATH('r'), ROOT( 'root' )
								)

				EXEC dbo.NAP_Admin_Calculate_Main
					@matchid	  		= @matchid
					,@action			= @Action
					,@IsSettingByProfile = 1
					,@strTransIds		 = @strTransIds
			END
			
		END
	END TRY
	BEGIN CATCH
		INSERT INTO @BalanceWalletAfter (matchid, custid, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
				@MatchId 		= @matchId
				, @sportType	= @sportType
				, @Action 		= @Action
				, @Mode 		= 2 
				, @SelectedRID	= @SelectedRID
				, @IsCentral		= @IsCentral
	
		-- Compare and update pending balance with error case
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				@BalanceWalletBefore	= @BalanceWalletBefore
				, @BalanceWalletAfter	= @BalanceWalletAfter
				, @ActionId			= @ActionID		  
		  
		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE()
	
		------ releasing Settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
					@isExistMatch		= 1
					, @IsReleased		= 1
	
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
        , @sportType        = @sportType
        , @Action 			= @Action
        , @Mode 			= 2
		, @SelectedRID      = @SelectedRID
		, @IsCentral		= @IsCentral
        
    -------------------------------------------------------------
    ---                   compare BALANCE                     ---
    ---------------------------VVVV------------------------------
    	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID
    
	 ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1

    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------

    SELECT @stop = CURRENT_TIMESTAMP

	DECLARE @xmlResults XML
	SET @xmlResults = CAST(@SelectedResources AS XML)
	SET @SelectedResources = ''

	SELECT @SelectedResources = @SelectedResources + ISNULL(Id,'') +
            CASE WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND AwayValue IS NOT NULL AND AwayValue <> '' THEN '(' + HomeValue + '-' + AwayValue + ')'
				 WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND (AwayValue IS NULL OR AwayValue = '') THEN '(' + HomeValue + ')'
				 WHEN HomeValue IS NULL AND AwayValue IS NULL THEN ''
				 ELSE '' 
              END
              +
              CASE WHEN IsDetermined IS NOT NULL AND 'REFUND' = 'REFUND' THEN ' SDT(' + IsDetermined + ')' ELSE '' END
    FROM 
        (
            SELECT 
			    T.c.value('@Id', 'VARCHAR(20)') as Id
			    ,T.c.value('@Home', 'VARCHAR(50)') as HomeValue
			    ,T.c.value('@Away', 'VARCHAR(50)') as AwayValue
			    ,T.c.value('@IsDetermined','VARCHAR(1)') as IsDetermined
	        FROM @xmlResults.nodes('Resources/Resource') T(c)
        ) t

	IF RIGHT(@SelectedResources,1) = ','
		SET @SelectedResources = LEFT(@SelectedResources, LEN(@SelectedResources) - 1)

    SELECT @logdata = 'NAP: Auto-Settlement (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                           + ' Result:' + @SelectedResources + ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.Logfile_V2 
		@UserID = @AdminId
		,@Doing = @logdata
		,@extend = @MatchId

	IF @IsCentral = 1
	BEGIN
		SELECT @Remark = 'NAP: Result:' + @SelectedResources +  ' <br/> ' 
							+ ' Recalc: ' + CAST (@IsReSettledTickets AS VARCHAR(1)) + '<br/>' 
							+ ' IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
							+ ' Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + 'ms' 
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
				@userid                = @AdminId
				,@matchid            = @MatchID
				,@actionid            = @ActionID
				,@finalhomescore    = @fth
				,@finalawayscore    = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@GoalRecord        = @goalrecord
				,@betstatus            = @betstatus
				,@Remark            = @Remark
				,@ip                = @ip
		END TRY

		BEGIN CATCH
			SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
				@UserID                = @AdminId
				,@MatchID            = @matchid
				,@actionid            = @actionid
				,@finalhomescore    = @fth
				,@finalawayscore    = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@GoalRecord        = @goalrecord
				,@betstatus            = @betstatus
				,@Remark            = @Remark
				,@IP                = @ip
		END CATCH	
	END

	IF @TotalSubParlay > 0
	BEGIN	
		SET @ActionParlay = @Action + '_EAR'

		SELECT @SelectedResourceParlay = CAST((SELECT ResourceID AS '@Id'
											,bettype AS '@Bettype'
											,pfid	AS '@pfId'
											,HomeValue AS '@Home'
											,AwayValue AS '@Away'
											,IsDetermined AS '@IsSDT'
											,@homeRound AS '@HomeRound'
											,@awayRound AS '@AwayRound'
									FROM	@tmpSelectedRID
									FOR XML PATH ('Resource'), ROOT('Resources'), TYPE) AS VARCHAR(MAX))
			
		EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

		IF @TotalSubParlay <= @ThreadHold
			SET @LockedByRefno = 1

		SET	@sqlCommand =  'EXEC [dbo].[NAP_Admin_Settlement_Profile_Parlay] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
								+ ', @creator = ' + CONVERT(NVARCHAR(50), @AdminID) 												
								+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResourceParlay) + ''''														
								+ ', @Action = ''' + @ActionParlay + '''' 														
								+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + ''''
								+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) 
								+ ', @IsCentral = ' + CAST(@IsCentral AS VARCHAR)
								+ ', @ErrCode = @ErrCode OUTPUT' 
								+ ', @ErrMsg = @ErrMsg OUTPUT'

		IF @procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT[1-9]'
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Profile_Parlay
				@creator			= @AdminID
				,@MatchID			= @MatchId
				,@Action		  	= @ActionParlay
				,@IP	 			= @Ip
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
			SELECT @MatchID, 0, @AdminID, @IP, CURRENT_TIMESTAMP, @action, @sqlCommand, @sportType, @LockedByRefno, @BroadcastSessionId + '_parlay'
		END
	END
END
GO
