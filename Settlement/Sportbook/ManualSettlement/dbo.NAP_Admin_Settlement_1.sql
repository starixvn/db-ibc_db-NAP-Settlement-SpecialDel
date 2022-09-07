/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1] 
    @creator			INT
    ,@matchid			INT
    ,@fth            	SMALLINT        = NULL
    ,@fta            	SMALLINT        = NULL
    ,@hth            	SMALLINT
    ,@hta            	SMALLINT
    ,@goalrecord        VARCHAR(50)     = NULL
    ,@betstatus        	NVARCHAR(50)    = NULL     
    
    ,@ResourceResult	VARCHAR(MAX)	= NULL
   
    ,@action            VARCHAR(10)    	= 'CAL'
    ,@IP                VARCHAR(50)    	= ''
	,@IsReSettledTickets BIT			= 1
	,@ChildMatchIds		VARCHAR(500)	= NULL
	,@KeyId				INT				= 0
	,@RefResultStatus	TINYINT			= 0
	,@BroadcastSessionId VARCHAR(50)	= NULL
    ,@ErrCode			INT            	= 0		OUTPUT
    ,@ErrMsg            NVARCHAR(200)	= ''    OUTPUT
AS
/*    Creator: Kathy
    Date: 20140213
    Task: main SP for settlement
    DB: DBTXN/BODB02
    Original: Admin_Settlement_1
    
    Revisions:
        - 20140423@Kathy: Remove check weekend peak-hour
        - 20140426@Kathy: Add 1H Total Goal and 1H FGLG bettypes (126, 127) [Redmine:#14449]
        - 20140617@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]
        - 20140808@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33),
                         sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
        - 20140910@Kathy: Update SettlementStatus135 = 4 if the match hasn't any PS ticket [Redmine:#21560]
        - 20141009@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150406@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150610@Johnson: Add bettrade [Redmine: #35921]
        - 20150715@Johnson: Exclude range bettype of Metric Gaming from settlement of SB [Redmine: #37688]
        - 20150806@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
        - 20150918@Johnson: Check status of corner tickets when settle FT [Redmine: #43806]
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)        
        - 20151126@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
        - 20151207@Patrick: Database - Change datatype [Redmine: #48660]
        - 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
        - 20160106@Kathy: - Integrate Cricket [Redmine:#49727]
                          - Capture balance incase of failure
        - 20160419@Kathy: change main SP to NAP_Admin_Settlement_MP [Redmine:#52426]
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170521@Kathy: Correct balance for Basketball [Redmine:#76931]
		- 20170522@Kathy: Correct balance for Tennis [Redmine:#76931]
		- 20170316@Bobby: Integrate CashOut bettypes [Redmine:#71355]
		- 20170609@Kathy: Remove some "early settlement" bettypes [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171226@Kathy: Clear data in table AutoPayoutResult if match has been undo [Redmine:#86890]
		- 20170801@Bobby: Implement new capture balance method [Redmine:#80774]
		- 20180419@Benjamin: Add ISNULL(@hth,0),ISNULL(@hta,0) IN @LogData [Redmine:#86964]
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190528@Kathy: Write log @IsReSettledTickets [Redmine:#113460]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20191213@Helen: Support Instant Calculation for Corner Bet Types - Update result for manual process [Redmine:115377]
		- 20200120@Sol:	Settlement with Ticket Exclusion for Other Sports - [Redmine:#126963]
		- 20200221@Sol:	HotFix - Event status of match still Running although there are no tickets running - [Redmine:#128657]
		- 20200306@Sol:	Don't change Event Status to Completed When Calculate HT - [Redmine:#129884]
		- 20200423@Kathy: Write log @IsReSettledTickets for all sportType [Redmine:#131765]
		- 20200519@Kathy: Do not update match_remark if match is refund [Redmine:#134192]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto refund ET & PEN match [Redmine:#145597]
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210326@Louisa: Negative balance [Redmine:#152345]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20211216@Louisa: Hide confirmed result [Redmine:#165656]
		- 20211130@Kathy: New cashout model [Redmine:#164838]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
        + @betstatus: Used for score table, FGLG status, refund status
                
		+ @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

		+ @RefResultStatus ( detect by Web )
				 1: no reference result exist (result not yet confirmed or not exists Provider score)
				 2: values inconsistency
*/
BEGIN
    SET NOCOUNT ON
	
    DECLARE @RunBySSBProcess	        BIT
        ,@starttime                     DATETIME
        ,@stop                          DATETIME
        ,@avaiableProcess				BIT
        ,@goalrecord_old                VARCHAR(50)
        ,@LogData                       NVARCHAR(300)
        ,@eventstatus                   NVARCHAR(50)
        ,@sporttype                     SMALLINT       
        ,@Remark                        VARCHAR(500)
        ,@ActionID						INT
        ,@HomeValue						VARCHAR(20)
        ,@AwayValue						VARCHAR(20)
        ,@TotalAccount					INT
        ,@TotalAccount_BalanceUpdate    INT
		,@TicketCount					INT
        ,@HTDone                        BIT
        ,@FTDone                        BIT
        ,@strAutoBettypes				VARCHAR(MAX)
        ,@strHTBettypes					VARCHAR(MAX)
        ,@strBettypes					VARCHAR(MAX)	
		,@IsRefundHT					BIT	

		-- Corner match
		,@ChildMatchType				TINYINT
		,@LogDataSoccer					XML
		,@CommandMonitor				NVARCHAR(MAX)
		,@SessionId						BIGINT
		,@SSBStatus						TINYINT
		,@strTransIds					VARCHAR(MAX)

		-- parlay
		,@SPName						NVARCHAR(128)
		,@TotalSubParlay				INT
		,@SelectedResourceParlay		VARCHAR(MAX) 
		,@ThreadHoldRefno				INT 
		,@LockedByRefno					BIT
		,@sqlCommand					VARCHAR(MAX)
		,@AutoSetting					TINYINT

		,@IsCentral						BIT
		
	DECLARE @tmpParlayAffectedBettypes TABLE (ResourceId VARCHAR(20), RefResourceId VARCHAR(20), bettype SMALLINT, totalticket INT)	

    --START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables    
    
    DECLARE @status TABLE (FTBet BIT, BetCount INT, InRunning INT)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, winlost MONEY, statuswinlost TINYINT)
    
    CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	DECLARE @tmpCashoutTransId AS TABLE (TransId BIGINT, winlost MONEY, statuswinlost TINYINT)
    
    SELECT  @sporttype        = m.sporttype
            ,@goalrecord_old    = ISNULL(m.goalrecord, '')
			,@IsRefundHT = CASE WHEN m.betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
			,@ChildMatchType = m.ChildMatchType
			,@AutoSetting = ISNULL(m.AutoSetting, l.AutoSetting)	
    FROM    dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
    WHERE    m.matchid = @matchid
	
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @ErrCode = 1001001
            ,@ErrMsg    = 'Match does not exist!'

        RETURN
    END

	 SELECT  @starttime = CURRENT_TIMESTAMP		
            ,@ActionID = CASE @Action
							WHEN 'CAL' THEN 100
							WHEN 'CAL-FT' THEN 101
							WHEN 'CAL-HT' THEN 102
							WHEN 'UNDO'	THEN 103
                        END
						
			,@HomeValue = CAST(@fth AS VARCHAR(20))
            ,@AwayValue = CAST(@fta AS VARCHAR(20))         
			,@RunBySSBProcess = CASE 
									WHEN @sporttype = 1 
										THEN CASE 
												WHEN @action = 'UNDO' THEN 0 ELSE 1 END
									ELSE 0
								END
			,@IsCentral = 0
			
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

    -- check result of horse racing fixodds
    IF @action = 'CAL' AND @sporttype = 154 AND (@fth = 0 OR @fth IS NULL OR @fta = 0 OR @fta IS NULL)
    BEGIN
        SELECT @ErrCode = 1001002
            ,@ErrMsg    = 'Score is not valid.'

        RETURN
    END

	IF @sporttype = 1 AND @action LIKE 'CAL%'
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= @action
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
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
		
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @RunBySSBProcess = 1
	BEGIN
		INSERT INTO dbo.Settlement_SettledSession (MatchId)
		SELECT @matchid
		SET @SessionId = SCOPE_IDENTITY()
		
		BEGIN TRY
			EXEC dbo.NAP_Admin_Settlement_3_profile
				@matchId	= @matchid
				,@hth = @hth
				,@hta = @hta
				,@fth = @fth 
				,@fta = @fta
				,@goalrecord = @goalrecord
				,@action	= @action
				,@ActionID	= @ActionID
				,@IsReSettledTickets = @IsReSettledTickets
				,@ResourceResult = @ResourceResult
				,@SessionId = @SessionId
				,@BroadcastSessionId = @BroadcastSessionId
				,@creator = @creator
				,@TicketCount = @TicketCount OUTPUT
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END TRY
		BEGIN CATCH
				SELECT  @ErrCode = 1001017 
						,@ErrMsg = ERROR_MESSAGE()   
		END CATCH

		SELECT @LogDataSoccer = (					
				SELECT	@goalrecord_old AS '@oldGoalRecord'
						,@goalrecord AS '@goalrecord'
						,@betstatus AS '@betstatus'
						,@IsReSettledTickets AS '@IsReSettledTickets'
						,@ChildMatchIds AS '@ChildMatchIds'
						,@ActionID AS '@ActionID'
						,@action AS '@Action'
						,@fth AS '@fth'
						,@fta AS '@fta'
						,@hth AS '@hth'
						,@hta AS '@hta'
						,@creator AS '@AdminId'
						,@IP AS '@IP'
						,@TicketCount AS '@TicketCount'
						,CASE WHEN @AutoSetting & 2 > 0 AND @action = 'CAL-HT' THEN 1 ELSE NULL END AS '@DeterminedFTStatus'
						,@starttime AS '@Starttime'
						,@ErrMsg AS '@ErrMsg'
				FOR XML PATH('r'), ROOT('root'), TYPE)

		SET @CommandMonitor = 'EXEC dbo.NAP_Admin_MonitorProcess @SessionId = ' + CAST(@SessionId AS VARCHAR(50))
						+ ', @MatchId = ' + CAST(@MatchId AS VARCHAR)				
						+ ', @HasError = ' + CAST(@ErrCode AS VARCHAR)
						+ ', @LogData = ' + '''' + CAST(@LogDataSoccer AS VARCHAR(MAX)) + ''''
						+ ', @IsCentral = ' + CAST(@IsCentral AS VARCHAR)	
						+ CASE WHEN @BroadcastSessionId IS NOT NULL 
												THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
												ELSE '' END
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

		RETURN
	END

	SELECT  @strAutoBettypes = COALESCE(@strAutoBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM    dbo.f_Set_GetGroupBettypes() f 
	WHERE   f.IsAuto = 1   

	SELECT	@strHTBettypes = COALESCE(@strHTBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM    dbo.f_Set_GetGroupBettypes() f 
	WHERE  	f.GroupId IN (1,3) -- include HT-FGLG groupId = 3
			AND f.IsAuto = 0
	
	SET @strBettypes = CAST((SELECT  BetType '@t'
								,GroupId '@g'
								,GroupName '@n'
						FROM	dbo.f_Set_GetGroupBettypes()			
						WHERE	IsAuto = 0
						FOR XML PATH ('r'), ROOT('root'), TYPE
							) AS VARCHAR(MAX))
	
	IF @Action = 'CAL-HT'
	BEGIN
		SELECT    @TicketCount = COUNT(1)
		FROM    dbo.bettrans b WITH(NOLOCK)
		WHERE    b.matchid = @matchid
				AND 1 = CASE 
							WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 1
							ELSE 0
						END
	END
	ELSE IF @Action = 'CAL-FT'
	BEGIN
		SELECT    @TicketCount = COUNT(1)
		FROM    dbo.bettrans b WITH(NOLOCK)
		WHERE    b.matchid = @matchid
				AND 1 = CASE 
							WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0
							WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') > 0 THEN 0
							ELSE 1
						END
				AND b.bettype NOT BETWEEN 901 AND 910
				AND b.bettype NOT BETWEEN 801 AND 899
				AND b.bettype NOT BETWEEN 911 AND 920
				AND b.bettype <> 38 --BetBuilder
	END
	ELSE 
	BEGIN
		SELECT    @TicketCount = COUNT(1)
		FROM    dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
		WHERE  	b.matchid = @matchid					
				AND b.bettype <= 19000
				AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238, 38) -- Outright, VSRacing, Betbuilder
				AND b.bettype NOT BETWEEN 1501 AND 1599 -- Keno
				AND 1 = CASE 
							WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') > 0 THEN 0
							ELSE 1
						END
				AND b.bettype NOT BETWEEN 901 AND 910
				AND b.bettype NOT BETWEEN 801 AND 899
				AND b.bettype NOT BETWEEN 911 AND 920
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
        , @sportType 	    = @sporttype
        , @Action 			= @Action
        , @Mode 			= 2 --@Mode Manual Settlement       
		, @IsRefundHT		= @IsRefundHT

    SELECT @TotalAccount = @@ROWCOUNT
          
    BEGIN TRY
            -- 20090412 : Joe : case for unsettle the game.
        IF @action = 'UNDO'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_Main 
                @matchid        = @matchid              
                ,@action        = 'CAL'        -- Default Action for UNDO Settlement 
                ,@mode            = 'UNDO'
                ,@strBettypes = @strBettypes

			INSERT INTO @tmpCashoutTransId(TransId, statuswinlost)
			SELECT	b.transid, NULL
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	matchid = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND b.statusID NOT IN (101)
					AND ISNULL(b.betdaqid,0) = - 2
					AND b.statuswinlost IS NOT NULL

			IF EXISTS (SELECT TOP 1 1 FROM @tmpCashoutTransId)
			BEGIN
				UPDATE t 
					SET winlost = c.Winlost
				FROM	@tmpCashoutTransId t
					INNER JOIN dbo.CashOutSelling c WITH(NOLOCK)
						ON t.TransId = c.TransID

				WHILE (1=1)
				BEGIN
					DELETE @tmpTransIDBatch
					SET @strTransIds = ''

					DELETE 	TOP (2000)
					FROM	@tmpCashoutTransId
						OUTPUT deleted.TransId, deleted.statuswinlost, deleted.winlost INTO @tmpTransIDBatch(TransID, statuswinlost, winlost)

					IF @@ROWCOUNT = 0
						BREAK

					SET @strTransIds 		= (SELECT transid	AS '@t'
													   ,winlost	AS '@w'	
													   ,statuswinlost AS '@s'
											   FROM @tmpTransIDBatch
											   FOR XML PATH('r'), ROOT( 'root' ))

					EXEC dbo.NAP_Admin_Calculate_Main
						@matchid	  		 = @matchid
					   ,@action				 = 'Cashout'
					   ,@mode				 = 'UNDO'
					   ,@strTransIds		 = @strTransIds
					
				END
			END
            
			IF @sporttype <> 1
			BEGIN
				EXEC dbo.NAP_Admin_Settlement_MP
					@matchid        = @matchid
					,@creator        = @creator
					,@action        = 'UNDO'              
					,@IP            = @IP
			END 
			ELSE
			BEGIN
				;WITH cteResource 
				AS (
					SELECT	sp.ResourceID, sp.RefResourceId, sp.BetType
					FROM	dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
					WHERE	SportType = @sportType
							AND sp.SettleType = 'MNL'
					GROUP BY sp.ResourceID, sp.RefResourceId, sp.BetType
				)
				INSERT INTO @tmpParlayAffectedBettypes(ResourceId, RefResourceId, bettype, totalticket)
				SELECT	c.ResourceID, c.RefResourceId, bm.bettype, COUNT(1)		
				FROM	dbo.bettransm bm WITH(NOLOCK)
					INNER JOIN cteResource c
						ON bm.bettype = c.BetType
				WHERE	bm.matchid = @MatchID
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND bm.statusID NOT IN (101,0)
				GROUP BY c.ResourceID, c.RefResourceId, bm.bettype

				IF @@ROWCOUNT > 0
				BEGIN		
					SELECT	@TotalSubParlay = SUM(totalticket)
					FROM	@tmpParlayAffectedBettypes

					SELECT @SelectedResourceParlay = CAST((SELECT ResourceID AS '@Id'
														,CASE WHEN RefResourceId IS NOT NULL THEN RefResourceId ELSE NULL END AS '@RefResourceId' 
														,bettype AS '@Bettype'			
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
							,@LockedByRefno		= 1 -- always lock refno for testing
							,@IsCentral			= @IsCentral
							,@ErrCode			= @ErrCode OUTPUT
							,@ErrMsg 			= @ErrMsg OUTPUT
					END
					ELSE
					BEGIN
						INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype, LockedByRefno, BroadcastSessionId)
						SELECT @MatchID, 0, @creator, '', CURRENT_TIMESTAMP, @Action, @sqlCommand, @sportType, @LockedByRefno, @BroadcastSessionId + '_parlay'
					END
				END
			END
        END
        ELSE
        BEGIN           
			EXEC dbo.NAP_Admin_Settlement_3
				@matchid            = @matchid
				,@mode                = @action    
				,@IsReSettledTickets = @IsReSettledTickets
				,@creator = @creator
				,@IsCentral = @IsCentral
		END 
    END TRY
    BEGIN CATCH
        -- Capture Balance incase of failure
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
            , @sportType 	    = @sporttype
            , @Action 			= @Action
            , @Mode 			= 2 --@Mode Manual Settlement              
				

		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			, @BalanceWalletAfter	= @BalanceWalletAfter
			, @ActionId				= @ActionID

        SELECT    @ErrCode = 1001017 
                ,@ErrMsg = ERROR_MESSAGE()            
    END CATCH
    
	IF @ErrCode <> 0
		RETURN

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
        , @sportType 	    = @sporttype
        , @Action 			= @Action
        , @Mode 			= 2 --@Mode Manual Settlement           
		, @IsRefundHT		= @IsRefundHT

	SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT a.custid)
	FROM @BalanceWalletAfter a
		INNER JOIN @BalanceWalletBefore b 
		ON     a.matchid            = b.matchid
				AND a.custid        = b.custid
				AND a.balanceType   = b.balanceType
				AND a.walletType    = b.walletType
				AND a.bonusId       = b.bonusId
	WHERE a.balance <> b.balance

	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID


	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1


	SELECT @stop = CURRENT_TIMESTAMP	
	
	SELECT @LogData = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                    + ' score:' + CAST(ISNULL(@fth, 0) AS NVARCHAR(10)) 
                                                    + '-' + CAST(ISNULL(@fta, 0) AS NVARCHAR(10)) 
                                                    + ' HT:' + CAST(ISNULL(@hth,0) AS NVARCHAR(10)) 
                                                    + '-' + CAST(ISNULL(@hta,0) AS NVARCHAR(10)) 
                                                    + ' GoalRecord:' + ISNULL(@goalrecord, '') 
                                                    + '(Old:' + @goalrecord_old + ') Remark(' + @betstatus + ')' 
													+' (' + CAST(DATEDIFF(millisecond, @starttime, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.Logfile_V2 
		@UserID = @creator
		,@Doing = @LogData
		,@extend = @MatchId
	
	SELECT @Remark ='NAP: ' + CASE    WHEN ISNULL(@goalrecord_old,'')='' THEN ''
                                ELSE 'Old GoalRecord:' + @goalrecord_old + '<br/> '
                                END
						+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @starttime, @stop) AS NVARCHAR(50)) + ' ms;' 
                        + ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) + ';'
						+ CASE WHEN @action LIKE 'CAL%' THEN ' Recalc: ' + CAST (@IsReSettledTickets AS VARCHAR(1)) + ';' ELSE '' END
                        + ' Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
						+ CASE WHEN ISNULL(@ChildMatchIds,'') = '' THEN ''
								WHEN @ChildMatchIds = '0' THEN ' RefChild:0' 
								ELSE ' RefChild:(' + @ChildMatchIds +')' 
								END
						+ CASE @RefResultStatus WHEN 1 THEN ' confirmed/provider:no'
												WHEN 2 THEN ' value consistency:no'
												ELSE ''
												END

	IF @IsCentral = 1
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
				@UserID                = @creator
				,@Matchid            = @matchid
				,@ActionID            = @ActionID
				,@finalhomescore    = @fth
				,@finalawayscore    = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@GoalRecord        = @goalrecord
				,@betstatus            = @betstatus
				,@Remark            = @Remark
				,@IP                = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
				@UserID                = @creator
				,@Matchid            = @matchid
				,@ActionID            = @ActionID
				,@finalhomescore    = @fth
				,@finalawayscore    = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@GoalRecord        = @goalrecord
				,@betstatus            = @betstatus
				,@Remark            = @Remark
				,@IP                = @IP
		END CATCH
	END
	
	DROP TABLE #tblMatchProcess

END
