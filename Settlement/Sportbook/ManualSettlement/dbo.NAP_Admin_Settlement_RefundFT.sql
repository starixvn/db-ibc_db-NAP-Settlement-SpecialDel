/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_RefundFT] 
    @matchid							INT
    ,@adminid							INT
    ,@betstatus							NVARCHAR(50)    = NULL
    ,@IP								VARCHAR(15)    	= ''
    ,@ErrCode							INT            	= 0         OUTPUT
    ,@ErrMsg							NVARCHAR(200)   = ''        OUTPUT
AS
/*
    Created: Kathy
    Date: 20140213
    Task : Refund Full-time tickets
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
        - 20140426@Kathy: Add 1H Total Goal and 1H FGLG bettypes (126, 127) [Redmine:#14449]
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140617@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]
        - 20140725@Kathy: Settle determined tickets for Correct Score(4,30), Total Goal (6,126) [Redmine:#19310]
        - 20140811@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33),
                         sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
        - 20140911@Kathy: Update SettlementStatus135 = 4 if the match hasn't any PS ticket [Redmine:#21560]
        - 20150421@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20150716@Johnson: Exclude range bettypes of Metric Gaming from settlement of SB [Redmine: #37688]
		- 20150611@Johnson: Add bettrade [Redmine: #35921]		
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
		- 20151126@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151207@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
        - 20160106@Kathy:- Integrate Cricket [Redmine:#49727]
						 - Capture balance incase of failure
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20161118@Bobby: #67462 - Implement SDT for Over/Under bettypes full winlost
		- 20170321@Bobby: #73407 - CashOut integration
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171212@Kathy: Change on Refund page [Redmine:#86890]
		- 20170801@Bobby: Implement new capture balance method [Redmine:#80774]
		- 20180510@Benjamin: Incorporate new Sports: Sepak Takraw(48)[Redmine:#94608]
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
		- 20190313@Kathy: Change command for refund HT, FT, ALL to avoid wrong replacing SP deployment [Redmine:#109007]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191223@Max: Instant Calculation for Corner Bet Types - Update result for Refund [Redmine:#124951]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20211130@Kathy: New cashout model [Redmine:#164838]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		
    Param's Explanation:
    • @matchid: matchid of match to Refund HT
    • @IsSettleAbandonedMatch: Is Settlement for Abandoned/postponed match or not
    • @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
    • @IsSettleAbandonedMatchIBC: Is Settlement for IBC ticket of Abandoned/postponed match or not
    • @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE	@Remark					VARCHAR(500)
			,@ActionID  			INT
			,@start     			DATETIME
			,@stop      			DATETIME		
			,@sporttype     		SMALLINT		
			,@RowCount				INT			
			,@strRefundBettypes		VARCHAR(MAX)		
			,@refundCommand			VARCHAR(100)			
            ,@avaiableProcess		BIT		
			,@Action				VARCHAR(20)			
			,@IsCentral			BIT 
	
	--START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables             
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	SELECT	@start    = CURRENT_TIMESTAMP
			,@ActionID  	= 111
			,@Action		= 'CAL-FT'		
			,@refundCommand = 'NAP_Admin_Settlement_Refund-FT'
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SELECT	@sporttype   = SportType	
    FROM	dbo.Match WITH (NOLOCK)
    WHERE	matchid = @matchid
	
    -- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @Matchid
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	RETURN

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

	-- check marked ticket
	EXEC dbo.NAP_Set_CheckingMarkedTransaction
			@MatchID  = @matchid
			,@Action  = 'REFUND-FT'
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
		, WalletType
		, BonusID
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType 	    = @sporttype
		, @Action 			= @Action
		, @Mode 			= 3 --@Mode Manual Refund
		, @IsCentral		= @IsCentral

    BEGIN TRY		
		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
			@Command 	= @refundCommand --'NAP_Admin_Settlement_Refund-FT'
			,@MatchID 	= @matchid		
			,@RowCount 	= @RowCount OUTPUT
			,@creator 	= @adminid
			,@BetStatus = @betstatus		

	    IF @RowCount > 0
		BEGIN		
			-- SELECT for new formation
			SET @strRefundBettypes = (SELECT  f.BetType 'r/@t'
							,f.GroupId 'r/@g'
						FROM dbo.f_Set_GetGroupBettypes() AS f								
						WHERE f.GroupId IN (2,4,6,7) 								
						FOR XML PATH ('root')
					)							
			
			-- Calculate Refund FT
			EXEC dbo.NAP_Admin_Calculate_Main 
				@matchid                     = @matchid
				,@action                     = 'REFUND'
				,@mode                       = 'REFUND-FT'	
				,@strBettypes				 = @strRefundBettypes
			
			IF @IsCentral = 1
				EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
					@matchid    = @matchid
					,@command   = 'F'
		END
    END TRY
    BEGIN CATCH
		-- Capture Balance incase of failure
		-- CAPTURE value BALANCE after settlement  
		INSERT INTO @BalanceWalletAfter (
			matchid
			, custid
			, balanceType
			, WalletType
			, BonusID
			, balance
		)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
			@MatchId 			= @matchId
			, @sportType 	    = @sporttype
			, @Action 			= @Action
			, @Mode 			= 3
			, @IsCentral		= @IsCentral
			

		-- Compare and update pending balance with error case
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
		, WalletType
		, BonusID
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType 	    = @sporttype
		, @Action 			= @Action
		, @Mode 			= 3
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
  
    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------
    
    SELECT @stop = CURRENT_TIMESTAMP

    IF @RowCount > 0 
    BEGIN
        DECLARE @LogData NVARCHAR(300)

        SELECT @LogData = 'NAP: Calculate (Refund FT) for matchid:' 
                            + CAST(@matchid AS NVARCHAR(10)) 
								
        EXEC dbo.Logfile_V2 
			@UserID = @AdminId
			,@Doing = @LogData
			,@extend = @MatchId
			
		IF @IsCentral = 1
		BEGIN			
			SELECT @Remark = 'NAP: Duration=' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms;'
			
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
					@UserID             = @adminid
					,@Matchid           = @matchid
					,@ActionID          = @ActionID
					,@finalhomescore    = 0
					,@finalawayscore    = 0
					,@hthomescore       = 0
					,@htawayscore       = 0				
					,@betstatus         = @betstatus
					,@Remark            = @Remark
					,@IP                = @IP
			END TRY

			BEGIN CATCH
				SELECT @Remark = @Remark + ' ErrMsg=' + left(ERROR_MESSAGE(), 400)

				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
					@UserID             = @adminid
					,@Matchid           = @matchid
					,@ActionID          = @ActionID
					,@finalhomescore    = 0
					,@finalawayscore    = 0
					,@hthomescore       = 0
					,@htawayscore       = 0				
					,@betstatus         = @betstatus
					,@Remark            = @Remark
					,@IP                = @IP
			END CATCH
		END
    END
END
GO