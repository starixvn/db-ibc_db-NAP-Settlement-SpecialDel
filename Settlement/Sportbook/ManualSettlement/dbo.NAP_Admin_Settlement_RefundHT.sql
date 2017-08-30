/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_RefundHT] 
	@matchid INT
    ,@adminid INT
    ,@IsExcludeBetdaq BIT = 0
    ,@IsSettleAbandonedMatch BIT = 0
    ,@IsExcludeBetfair BIT = 0
    ,@IsSettleAbandonedMatchBetFair BIT = 0
    ,@hth INT = NULL
    ,@hta INT = NULL
    ,@isExistTotalCorner            BIT    = 0 
    ,@isExistHTFCorner                BIT    = 0 
    ,@isExistHTLCorner                BIT    = 0 
    ,@isExistFTFCorner                BIT    = 0 
    ,@isExistFTLCorner                BIT    = 0  
     ,@ResourceResult				VARCHAR(MAX)	= NULL
    ,@IP VARCHAR(15) = ''
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
    Created: Kathy
    Date: 20140213
    Task : Refund Half-time in case there are HT tickets bet on special matches that have 3 sets
    DB: DBTXN/BODB02
    Original: Admin_Settlement_RefundHT

    Revisions:
        - 20140421@Kathy: Add new bettype 126 [Redmine:#14449]
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140617@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]    
        - 20140811@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20150422@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20150611@Johnson: Add bettrade [Redmine: #35921]
        - 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
        - 20151016@Kathy: Refund HT/FT & 2nd FT bettypes in case of match 3x30 [Redmine:#45626]
		- 20151126@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160705@Kathy: - PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
						  - Capture balance incase of failure
		- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [R
		- 20160905@Bobby: #63553 - Include FGLG (14,127) bet types
		- 20170321@Bobby: #73407 - CashOut integration
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
        - 20170801@Bobby: Implement new capture balance method [Redmine:#80774]
		
    Param's Explanation:
    • @matchid: matchid of match to Refund HT
		
    Param's Explanation:
    • @matchid: matchid of match to Refund HT
    • @IsExcludeBetdaq: Is Exclude betdaq tickets or not
    • @IsSettleAbandonedMatch: Is Settlement for Betdaq ticket of Abandoned/postponed match or not
    • @IsExcludeBetfair: Is Exclude betfair tickets or not
    • @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
    • @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

*/
BEGIN
    SET NOCOUNT ON
	
    --START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables      
	DECLARE @Remark VARCHAR(500)
        ,@ActionID INT
        ,@start DATETIME
        ,@stop DATETIME
        ,@strBettypes VARCHAR(MAX) 
		,@strRefundBettypes VARCHAR(MAX) 
		,@matchdate DATETIME
		,@avaiableProcess	BIT
        ,@sportType INT

    --START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables      

    CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

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

	SELECT @strBettypes = COALESCE(@strBettypes + ',' + CAST(bettype AS VARCHAR(10)), CAST(bettype AS VARCHAR(10))) 
	FROM	dbo.f_Set_GetGroupBettypes ()
	WHERE	Is3x30 = 1
	
	-- SELECT for new formation
	SET @strRefundBettypes = (SELECT  f.BetType 'r/@t'
						FROM	dbo.f_Set_GetGroupBettypes() AS f			
						WHERE	f.Is3x30 = 1
						FOR XML PATH ('root')
							)	
							
	
	SELECT @matchdate = eventdate
        , @sporttype    = sporttype
    FROM	DBPRO.BODB02.dbo.Match WITH (NOLOCK)
    WHERE	matchid = @matchid
	
    SELECT @start = CURRENT_TIMESTAMP
        , @ActionID = 110
        , @Action = 'CAL-HT'

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
        , @sporttype        = @sporttype
		, @Action 			= @Action
		, @Mode 			= 3 --@Mode Manual Refund

    IF @IsSettleAbandonedMatch = 1
        SELECT @IsExcludeBetdaq = 1

    IF @IsSettleAbandonedMatchBetFair = 1
        SELECT @IsExcludeBetfair = 1

    --Check if match already Refund FT => refund whole match
    IF EXISTS (
            SELECT 1
            FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
            WHERE matchid = @matchid AND betstatus LIKE '%Refund FT%'
            )
    BEGIN
        ------ releasing Settlement process
        EXEC dbo.NAP_Admin_CheckingProcess
            @isExistMatch		= 1
            , @IsReleased		= 1

		EXEC dbo.NAP_Admin_Settlement_Refund_All @matchid = @matchid
            ,@creator = @adminid
            ,@IsExcludeBetdaq = @IsExcludeBetdaq
            ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
            ,@IsExcludeBetfair = @IsExcludeBetfair
            ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
            ,@hth = @hth
            ,@hta = @hta
            ,@fth = NULL
            ,@fta = NULL
            ,@betstatus = NULL
            ,@hthCorners = NULL
            ,@htaCorners = NULL
            ,@HTFCorner     = NULL
            ,@isExistTotalCorner= @isExistTotalCorner
            ,@isExistHTFCorner    = @isExistHTFCorner
            ,@isExistHTLCorner    = @isExistHTLCorner
            ,@isExistFTFCorner    = @isExistFTFCorner
            ,@isExistFTLCorner    = @isExistFTLCorner
            ,@Action = 'CAL-HT'
            ,@IP = @IP
            ,@ErrCode = @ErrCode OUTPUT
            ,@ErrMsg = @ErrMsg OUTPUT

        RETURN
    END
	
	BEGIN TRY
		IF @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1
		BEGIN
			DECLARE @ScoreLog VARCHAR(100)

			SELECT @ScoreLog = ' HTHScore=' + CAST(@hth AS VARCHAR(10)) + ' HTAScore=' + CAST(@hta AS VARCHAR(10))

			DECLARE @totalht SMALLMONEY

			SELECT @totalht = (@hth + @hta)

			IF @totalht IS NULL
			BEGIN
				SELECT @ErrCode = 1000005
					,@ErrMsg = 'Cannot settle determined ticket(s) without HT Score!'

				------ releasing Settlement process
                EXEC dbo.NAP_Admin_CheckingProcess
                    @isExistMatch		= 1
                    , @IsReleased		= 1

				RETURN
			END
			-- bettype 8
			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				,@action = 'REFUND'
				,@mode = 'ABANDONED-HT'
				,@totalht = @totalht
				,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
				,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
		END

		/* --- END Settle Abandoned Match ---*/
		DECLARE @RowCount INT

		 EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_RefundHT'
			,@Matchid = @matchid
			,@RowCount = @Rowcount OUTPUT
			,@creator = @adminid

		EXEC DBPRO.BODB02.dbo.[NAP_Admin_Result_Update_1s] 
			@Command            = 'NAP_Admin_Settlement_RefundHT'
			,@MatchID            = @matchid
			,@isExistTotalCorner= @isExistTotalCorner
			,@isExistHTFCorner    = @isExistHTFCorner
			,@isExistHTLCorner    = @isExistHTLCorner
			,@creator            = @adminid
			,@ResourceResult = @ResourceResult

		IF @Rowcount > 0
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark @matchid = @matchid
				,@command = 'F'

			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				,@action = 'REFUND'
				,@mode = 'REFUND-HT'
				,@IsExcludeBetdaq = @IsExcludeBetdaq
				,@IsExcludeBetfair = @IsExcludeBetfair
				,@strBettypes = @strRefundBettypes 
				,@matchdate		= @matchdate
				
			-- BetTrade Winlost Sharing
			IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 901 AND 910)
				EXEC dbo.NAP_Admin_Calculate_904
				@MatchId = @matchid
				,@Action = 'REFUND-HT'
			
			-- CashOut Winlost Sharing
			IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 911 AND 920)
			BEGIN
				EXEC dbo.NAP_Admin_Calculate_914
				@MatchId = @matchid
				,@Action = 'REFUND-HT'
			END
		END
	END TRY
	BEGIN CATCH
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
            , @sporttype        = @sporttype
            , @Action 			= @Action
            , @Mode 			= 3 --@Mode Manual Refund
            

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
        , @sporttype        = @sporttype
        , @Action 			= @Action
        , @Mode 			= 3 --@Mode Manual Refund

    -- Compare and update pending balance with error case
    EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
        @BalanceWalletBefore	= @BalanceWalletBefore
        , @BalanceWalletAfter	= @BalanceWalletAfter
        , @ActionId				= @ActionID

    ---------------------------------------
    --  Betfair & Betdaq - Warning message:
    DECLARE @movebet VARCHAR(20)
        ,@matchcode NVARCHAR(50)

    SELECT @movebet = convert(VARCHAR(20), DATEADD(d, 1, kickofftime), 100)
        ,@matchcode = matchcode
    FROM match WITH (NOLOCK)
    WHERE matchid = @matchid

    IF @matchcode NOT LIKE '%Hedge%'
    BEGIN
        IF (@IsExcludeBetdaq = 1 OR @IsSettleAbandonedMatch = 1) AND (@IsExcludeBetfair = 1 OR @IsSettleAbandonedMatchBetFair = 1)
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg = 'Please move Betdaq and Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
        ELSE IF (@IsExcludeBetdaq = 1 OR @IsSettleAbandonedMatch = 1)
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg = 'Please move Betdaq tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
        ELSE IF (@IsExcludeBetfair = 1 OR @IsSettleAbandonedMatchBetFair = 1)
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg = 'Please move Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
    END

    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------
    SELECT @stop = CURRENT_TIMESTAMP

    IF @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @Rowcount > 0
    BEGIN
        DECLARE @LogData NVARCHAR(300)

        SELECT @LogData = 'NAP: Calculate (Refund HT) for matchid:' + CAST(@matchid AS NVARCHAR(10))

        EXEC dbo.WriteLog_UserLog @UserID = @AdminID
            ,@Doing = @LogData

        --Write Log Settle
        DECLARE @finalhomescore INT
            ,@finalawayscore INT
            ,@betstatus NVARCHAR(50)
            ,@goalrecord VARCHAR(50)

        SELECT @finalhomescore = finalhomescore
            ,@finalawayscore = finalawayscore
            ,@goalrecord = goalrecord
            ,@betstatus = betstatus
        FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
        WHERE matchid = @matchid

        SELECT @Remark = 'NAP: ExcludeBetdaqTickets=' + convert(CHAR(1), @IsExcludeBetdaq) + ' SettleDeterminedBetdaqTickets=' + convert(CHAR(1), @IsSettleAbandonedMatch) + ' ExcludeBetfairTickets=' + convert(CHAR(1), @IsExcludeBetfair) + ' SettleDeterminedBetfairTickets=' + convert(CHAR(1), @IsSettleAbandonedMatchBetFair) + CASE 
                WHEN @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 THEN @ScoreLog
                ELSE ''
                END + ' Duration=' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms;'

        BEGIN TRY
            EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @adminid
                ,@Matchid = @matchid
                ,@ActionID = @ActionID
                ,@finalhomescore = @finalhomescore
                ,@finalawayscore = @finalawayscore
                ,@hthomescore = 0
                ,@htawayscore = 0
                ,@GoalRecord = @goalrecord
                ,@betstatus = @betstatus
                ,@Remark = @Remark
                ,@IP = @IP
        END TRY

        BEGIN CATCH
            SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 400)

            EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @adminid
                ,@Matchid = @matchid
                ,@ActionID = @ActionID
                ,@finalhomescore = @finalhomescore
                ,@finalawayscore = @finalawayscore
                ,@hthomescore = 0
                ,@htawayscore = 0
                ,@GoalRecord = @goalrecord
                ,@betstatus = @betstatus
                ,@Remark = @Remark
                ,@IP = @IP
        END CATCH
    END

    ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_RefundHT] TO [bodbAdminNet]
GO
