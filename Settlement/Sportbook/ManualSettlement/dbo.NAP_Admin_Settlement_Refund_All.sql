/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_All] 
     @matchid                       	INT
    ,@creator                       	INT
    ,@hth								INT             = NULL
    ,@hta                               INT             = NULL
    ,@fth                               INT             = NULL
    ,@fta                               INT             = NULL
    ,@GoalSequence                      VARCHAR(50)     = NULL 
    ,@betstatus                        	NVARCHAR(50)    = NULL
    
    ,@Action                            VARCHAR(10)     = 'CAL'
    ,@IsNested                          BIT             = 1
    ,@IP                                VARCHAR(15)     = ''
	
    ,@ErrCode							INT             = 0      OUTPUT
    ,@ErrMsg                            NVARCHAR(200)   = ''        OUTPUT
AS
/*
    Created: Kathy
    Date: 20140213
    Task : refund tickets 
    Original: refund
    DB: DBTXN/BODB02

    Revisions: 
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
        - 20140426@Kathy: Add 1H FGLG (127) [Redmine:#14449]
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140704@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]
        - 20140725@Kathy: Settle determined tickets for Correct Score(4,30), Total Goal (6,126) [Redmine:#19310]
        - 20140812@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33),
                         sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
        - 201409010@Kathy: Update SettlementStatus135 = 4 if the match hasn't any PS ticket [Redmine:#21560]
        - 20141024@Jamie: Sportting Solution Tennis Settlement [Redmine:#23034]
        - 20150414@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20150610@Johnson: Add bettrade [Redmine: #35921]
        - 20150716@Johnson: Exclude range bettypes of Metric Gaming from settlement of SB [Redmine: #37688]    
        - 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
        - 20151126@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
        - 20151207@Patrick: Database - Change datatype [Redmine: #48660]
        - 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
        - 20160106@Kathy:- Integrate Cricket [Redmine:#49727]
                         - Capture balance incase of failure
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20161118@Bobby: #67462 - Implement SDT for Over/Under bettypes full winlost
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170521@Kathy: Correct balance for Basketball [Redmine:#76931]
		- 20170522@Kathy: Correct balance for Tennis [Redmine:#76931]
		- 20170321@Bobby: #73407 - CashOut integration
		- 20170601@Bobby: #76877 - Correct order for updating match result
		- 20170609@Kathy: Remove some "early settlement" bettypes [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171212@Kathy: Change on Refund page [Redmine:#86890]
        - 20170801@Bobby: Implement new capture balance method [Redmine:#80774]
        - 20180720@Vicky: Refund FT without Settle Determined [Redmine:#92859]
		- 20180510@Benjamin: Incorporate new Sports: Sepak Takraw(48)[Redmine:#94608]
		- 20190313@Kathy: Change command for refund HT, FT, ALL to avoid wrong replacing SP deployment [Redmine:#109007]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191028@Sol: Prevent Direct Actions for Soccer Matches - Fixed wrong settlement when Refund All button is clicked second times [Redmine:#122176]
		- 20191223@Max: Instant Calculation for Corner Bet Types - Update result for Refund [Redmine:#124951]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20200820@Kathy: Do not check refund flag if refund FT [Redmine:#136390]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto refund ET & PEN match [Redmine:#145597]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20211130@Kathy: New cashout model [Redmine:#164838]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		
    Param's Explanation:
    • @matchid: matchid need to refund
    
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @start                              DATETIME
            ,@stop                              DATETIME
            ,@avaiableProcess					BIT
            ,@sporttype                         SMALLINT    
            ,@Remark                            VARCHAR(500)
            ,@ActionID                          INT       
            ,@log                               VARCHAR(300)     
            ,@strRefundBettypes					VARCHAR(MAX)
  			,@refundCommand						VARCHAR(100)
		
			,@IsCentral			BIT = 0	
	
    --START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables    

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
    SELECT  @start 		= CURRENT_TIMESTAMP
			,@ActionID 	= CASE 
							WHEN  @action = 'CAL' 		THEN 109
							WHEN  @action = 'CAL-FT' 	THEN 111
							ELSE 0
						END
			,@refundCommand 						= 'NAP_Admin_Settlement_Refund-All'
           
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
    SELECT	@sporttype  = m.SportType		
    FROM    dbo.Match m  WITH (NOLOCK)
    WHERE    m.matchid = @matchid

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @Matchid
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0	    
		RETURN

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
			,@Action  = 'REFUND'
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
        , @Mode 			= 3 --@Mode Manual Refund       
		, @IsCentral		= @IsCentral
    
    BEGIN TRY		
		IF @IsCentral = 1
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
            	@Command         = @refundCommand
            	,@MatchID        = @matchid
            	,@creator        = @creator
				,@BetStatus 	 = @betstatus
				,@GoalRecord	 = @GoalSequence 
				,@HTHome		 = @hth
				,@HTAway		 = @hta
				,@FTHome		 = @fth
				,@FTAway		 = @fta				
		END
		
		SET @strRefundBettypes = CAST((SELECT  f.BetType '@t'
										,GroupId '@g'
										,GroupName '@n'
								FROM	dbo.f_Set_GetGroupBettypes() f  
								WHERE	f.IsAuto = 0
								FOR XML PATH ('r'), ROOT('root'), TYPE
						) AS VARCHAR(MAX))
        
		EXEC dbo.NAP_Admin_Calculate_Main 
            @matchid                    = @matchid
            ,@action                    = 'REFUND'
            ,@mode                      = 'REFUND'         
            ,@strBettypes               = @strRefundBettypes		
    END TRY
    BEGIN CATCH
        -- CAPTURE value BALANCE after settlement  
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
            , @Mode 			= 3 --@Mode Manual Refund          
			, @IsCentral		= @IsCentral
        
        -- Compare and update pending balance with error case
        EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
            @BalanceWalletBefore	= @BalanceWalletBefore
            , @BalanceWalletAfter	= @BalanceWalletAfter
            , @ActionId				= @ActionID

        SELECT    @ErrCode = 1001017 
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
        , @sportType 	    = @sporttype
        , @Action 			= @Action
        , @Mode 			= 3 --@Mode Manual Refund     
		, @IsCentral		= @IsCentral
    
    -- Compare and update pending balance with error case
    EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
        @BalanceWalletBefore	= @BalanceWalletBefore
        , @BalanceWalletAfter	= @BalanceWalletAfter
        , @ActionId				= @ActionID

    ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess

    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------
    
    SELECT @stop = CURRENT_TIMESTAMP

    DECLARE @LogData NVARCHAR(300)

    SELECT @LogData = 'NAP: Calculate (Refund All) for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                               
    EXEC dbo.Logfile_V2 
		@UserID = @creator
		,@Doing = @LogData
		,@extend = @MatchId
	
	IF @IsNested = 0
	BEGIN
		-- Write log
		SET @log = 'NAP: Refund for matchid: ' + CONVERT(VARCHAR(10), @matchid)
		
			EXEC dbo.Logfile_V2 
			@UserID = @creator
			,@Doing = @Log
			,@extend = @MatchId
	END

	IF @IsCentral = 1
	BEGIN
		--Write Log Settle
		SELECT @Remark = 'NAP: Action=' + @Action					
						+ ' Duration=' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms;' 

		BEGIN TRY		
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
				@UserID              = @creator
				,@Matchid            = @matchid
				,@ActionID           = @ActionID
				,@finalhomescore     = @fth
				,@finalawayscore     = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@GoalRecord         = @GoalSequence
				,@betstatus          = 'Refund'
				,@Remark             = @Remark
				,@IP                 = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
				@UserID              = @creator
				,@Matchid            = @matchid
				,@ActionID           = @ActionID
				,@finalhomescore     = @fth
				,@finalawayscore     = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@GoalRecord         = @GoalSequence
				,@betstatus          = 'Refund'
				,@Remark             = @Remark
				,@IP                 = @IP
		END CATCH

		IF @IsNested = 0
		BEGIN
			-- Update match_remark
			EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
				@matchid       = @matchid
				,@command      = 'F'			
		END
	END
END
GO
