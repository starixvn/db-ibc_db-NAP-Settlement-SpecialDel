/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_CoreAPI" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Auto_1s]
     @AdminID                       INT             = 148        -- calculated by system (default)
    ,@MatchID                       INT
	,@SelectedResources				VARCHAR(MAX)	= ''
    ,@Action                    	VARCHAR(10)     = 'CAL'
    ,@IsAuto                        BIT             = 1
    ,@IP                            VARCHAR(15)     = ''
	,@IsReSettledTickets			BIT				= 1
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
			,@Command			VARCHAR(100)
                                
			,@avaiableProcess	BIT
            ,@sportType			INT
			,@SelectedRID		VARCHAR(MAX)	
			,@batchNo			INT 			
			,@batchCount		INT		
			,@strTransIds		VARCHAR(MAX)	
	
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
		,PRIMARY KEY (BetType,BetID)
	)    
		
	DECLARE @tmpTransIDBatch TABLE (
		TransID		BIGINT
		,modds		SMALLMONEY
		,oddstype	SMALLINT
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
			,@Command = CASE 
							WHEN @Action = 'CAL' THEN 'NAP_Admin_Settlement_Auto_1s-CAL'
							WHEN @Action = 'REFUND' THEN 'NAP_Admin_Settlement_Auto_1s-REFUND'
							WHEN @Action = 'UNDO' THEN 'NAP_Admin_Settlement_Auto_1s-UNDO'
							ELSE ''
						END

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
	INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID, oddstype)
	SELECT DISTINCT Id, Home, Away, sp.BetType, sp.BetID, sp.pfID, sp.OddsType
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
		INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
			ON	sp.ResourceID = tbl.Id
	WHERE sp.SportType = @SportType 
	
	EXEC sp_xml_removedocument @handle

	SELECT   @SelectedRID   = (SELECT Bettype   AS '@bt'
									 ,BetID	AS '@b'
							  FROM	@tmpSelectedRID
							  FOR XML PATH('r'), ROOT( 'root' )) 

	--get transid
  	IF @Action = 'CAL'
  	BEGIN
		INSERT INTO #tmpTransID(TransID, modds, oddstype)
	  	SELECT	b.transid, m.modds, sr.oddstype
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
	  		CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, NULL, sr.HomeValue, sr.AwayValue, NULL, NULL) m
	  	WHERE	b.matchid = @MatchId
	  			AND b.statusID NOT IN (101,102)
				AND b.statusID = CASE WHEN @IsReSettledTickets = 0 THEN 0 ELSE b.statusID END
				AND mt.transId IS NULL
	END
	ELSE IF @action = 'UNDO'
	BEGIN
		--get transid
		INSERT INTO #tmpTransID(TransID)
	  	SELECT	transid
	  	FROM	dbo.bettrans b WITH (NOLOCK)
	  		INNER JOIN @tmpSelectedRID t 
				ON	b.BetType = t.BetType 
					AND (t.BetID = 0 OR b.BetID = t.BetID)
	  	WHERE	b.matchid = @MatchId
	  			AND	b.statusID NOT IN (0, 1, 102, 101)
	END 
	ELSE IF @action = 'REFUND'
	BEGIN
		--get transid
		INSERT INTO #tmpTransID(TransID)
	  	SELECT	transid
	  	FROM	dbo.bettrans b WITH (NOLOCK)
	  		INNER JOIN @tmpSelectedRID t 
				ON	b.BetType = t.BetType 
					AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  	WHERE	b.matchid = @MatchId
	  			AND	b.statusID NOT IN (103, 101, 102)
	END 
	
    EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s 
        @Command            = @Command,
        @MatchID            = @MatchID,
		@SelectedResources	= @SelectedResources,
        @IsAuto             = @IsAuto,
        @creator            = @AdminID             
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
							
	------START UPDATE BETTRANS---------------------------------------------------------------------------
	BEGIN TRY
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE	TOP(@batchNo) t
				SET	isFinish = 1
			OUTPUT	deleted.transid, deleted.modds, deleted.oddstype
			INTO	@tmpTransIDBatch(transid, modds, oddstype)
			FROM	#tmpTransID t 
			WHERE	isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
			
			IF @batchCount = 0 BREAK

			--filter selectedRID by current Profile and BetType
			SET @strTransIds = (SELECT transid	AS '@t'
										,modds	AS '@m'
										,oddstype AS '@ot'
								FROM	@tmpTransIDBatch
								FOR XML PATH('r'), ROOT( 'root' )
							)

			EXEC dbo.NAP_Admin_Calculate_Main
				@matchid	  		= @matchid
				,@action			= @action
				,@IsSettingByProfile = 1
				,@strTransIds		 = @strTransIds
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
        
    -------------------------------------------------------------
    ---                   compare BALANCE                     ---
    ---------------------------VVVV------------------------------
    	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID
	

	IF @action = 'UNDO'
    BEGIN						
        EXEC dbo.NAP_Admin_Settlement_MP
            @matchid			= @matchid
            ,@creator			= @AdminID
            ,@action			= 'UNDO'
            ,@SelectedResources = @SelectedResources
            ,@IP				= @IP
    END
    
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

	SELECT @SelectedResources = @SelectedResources
			+ T.c.value('@Id', 'VARCHAR(20)')
			+ '(' + T.c.value('@Home', 'VARCHAR(50)')
			+ '),'
	FROM	@xmlResults.nodes('Resources/Resource') T(c)

	IF RIGHT(@SelectedResources,1) = ','
		SET @SelectedResources = LEFT(@SelectedResources, LEN(@SelectedResources) - 1)

    SELECT @logdata = 'NAP: Auto-Settlement (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                           + ' Result:' + @SelectedResources + ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
    EXEC dbo.WriteLog_UserLog 
        @UserID = @AdminId
        ,@Doing = @logdata

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
GO
