/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Main]
    @matchid                        INT
    ,@mode                          VARCHAR(20) = 'CAL'
    ,@action                        VARCHAR(20) = 'CAL'
    ,@fth                           INT         = NULL
    ,@fta                           INT         = NULL
    ,@hth                           INT         = NULL
    ,@hta                           INT         = NULL
    ,@home_2nd                      INT         = NULL
    ,@away_2nd                      INT         = NULL
    ,@sporttype                     SMALLINT    = NULL
    ,@betstatus                     NVARCHAR(50)= NULL
    ,@GoalRecord                    VARCHAR(50) = NULL
	,@goalsequenceFT				VARCHAR(50) = NULL
	,@goalsequenceHT				VARCHAR(50) = NULL
    ,@matchCode                     NVARCHAR(50)= NULL
    ,@oddeven                       SMALLMONEY  = NULL
    ,@oddevenht                     SMALLMONEY  = NULL
    ,@oddevenhome                   SMALLMONEY  = NULL
    ,@oddevenhome_ht                SMALLMONEY  = NULL
    ,@oddevenaway                   SMALLMONEY  = NULL
    ,@oddevenaway_ht                SMALLMONEY  = NULL
    ,@oddeven_2H                    SMALLMONEY  = NULL
    ,@totalgoal                     SMALLMONEY  = NULL
    ,@totalht                       SMALLMONEY  = NULL
    ,@totalgoal_2H                  SMALLMONEY  = NULL
    ,@totalhome                     SMALLMONEY  = NULL
    ,@totalaway                     SMALLMONEY  = NULL
    ,@goaldiff                      SMALLMONEY  = NULL
    ,@scorediff                     SMALLMONEY  = NULL
    ,@scorediff_ht                  SMALLMONEY  = NULL
    ,@scorediff_2H                  SMALLMONEY  = NULL
    ,@correctscore                  NVARCHAR(10)= NULL
    ,@correctscore_ht               NVARCHAR(10)= NULL
    ,@correctscore_2h               NVARCHAR(10)= NULL
    ,@HTFT                          NVARCHAR(10)= NULL
    ,@ft_fg                         VARCHAR(10) = NULL
    ,@ft_lg                         VARCHAR(10) = NULL
    ,@ht_fg                         VARCHAR(10) = NULL
    ,@ht_lg                         VARCHAR(10) = NULL
    ,@WinFromBehind                 VARCHAR(1)  = NULL
    ,@T_Home                        SMALLINT    = NULL
    ,@T_Away                        SMALLINT    = NULL
    ,@ResourceIDs                   VARCHAR(MAX)= NULL  
    ,@isRefundHT                    BIT         = NULL
    ,@IsHTCal                       BIT         = NULL
    ,@strBettypes                   VARCHAR(MAX)= NULL

    --to do instant calculation
    ,@strTransIds                   VARCHAR(MAX)= NULL

    ,@IsSettleAbandonedMatch        BIT         = 0
    ,@IsSettleAbandonedMatchBetFair BIT         = 0
    ,@IsExcludeBetdaq               BIT         = 0
    ,@IsExcludeBetfair              BIT         = 0
    ,@IsSettleAbandonedMatchIBC     BIT         = 0
    ,@LGOnly                        BIT         = NULL
    ,@IncludeLG                     BIT         = NULL
    ,@matchdate                     DATETIME    = NULL
    ,@xmlData                       VARCHAR(MAX)= NULL
	,@strTransCashout				VARCHAR (MAX) = NULL OUTPUT
    ,@CalledByBrokerService         BIT         = 0
    ,@IsSettingByProfile            BIT 		= NULL
	,@IsReSettledTickets			BIT			= 1
	,@RunOnServer					VARCHAR(100)= NULL
	,@isCashout						BIT			= 0
	,@CashoutVersion				TINYINT		= 0
	,@CustId						INT			= NULL
	,@strCustIds					VARCHAR(MAX)= NULL
	,@SettlementProcessingId		BIGINT		= NULL
	,@ActionId						INT			= NULL
	,@TotalCommands					INT			= NULL
	,@SessionId						BIGINT		 = NULL
	,@MessageType					VARCHAR(200) = NULL
	,@oddstype						SMALLINT = NULL
	,@ismarked						BIT = NULL
	,@modds							MONEY = NULL
	,@ErrMessage					VARCHAR(300) = '' OUTPUT
	,@EventDate						DATETIME = NULL
AS
/*
    Created: Viet
    Task : Covered SP for settlement
    Original SP: Admin_Settlement_3
    DB: EXECREP SP (DBTrans_Bet)

    Revisions:
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil
        - 20140424@Lukas: add DBTP server
        - 20140426@Kathy: Add 1H Total Goal and 1H FGLG bettypes (126, 127) [Redmine:#14449]
        - 20140617@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]
        - 20140728@Kathy: Settle determined tickets for Correct Score(4,30), Total Goal (6,126) [Redmine:#19310]
        - 20140807@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20141016@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150128@Jamie: Hotfix Settlement SS
        - 20150206@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150529@Johnson: Add bettrade [Redmine: #35921]
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
        - 20151019@Kathy: add more param @IsRefundHT for calculate_4 (Refund HT/FT & 2nd FT bettypes in case of match 3x30 [Redmine:#45626])
        - 20151124@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
        - 20151207@Patrick: Database - Change datatype [Redmine: #48660]
        - 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
        - 20160314@Patrick: Support auto-payout [Redmine: #53262]
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160824@Bobby: #62921 - Include FGLG (14,127) bet types into CAL/Refund single process
        - 20161010@Bobby: #62003 - Implement instant calculation process
        - 20161108@Kathy: Settlement for new server [Redmine:#66849]
        - 20160428@Patrick: Fast market integration [Redmine: #56367]
        - 20161118@Bobby: #67462 - Implement SDT for Over/Under bettypes full winlost
        - 20161201@Bobby: #68128 - Implement Uncalculate instant settlement process
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170317@Bobby: #73404 - Integrate CashOut bettypes
        - 20170614@Kathy: Setup settlement on new DB Servers DBLicAPI2 [Redmine:#77991]
        - 20170613@Kathy: Early Settlement [Redmine:#77835]
        - 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
        - 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
        - 20171211@Kathy: Do not calculate bettype 22 with old format (betteam:h,a) [Redmine:#80947]
        - 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
        - 20180419@Benjamin: Adding 2 New Bet Types: 465,466 for Asian 1x2 [Redmine:#93654]
        - 20180622@Kathy: Do not settle on server DB042, correct server name DBLicAPI2 to DBLicAPI02 [Redmine#97076]
        - 20180717@Kathy: Allow to UNDO on DB042 [Redmine:#97842]
		- 20181106@Kathy: correct datatype of SetxGameyHomeWON & SetxGameyAwayWON when sending to subscriber [Redmine:#103985]
        - 20181109@Helen: Wrong member balance while doing Cashout /Bettrade at the same time of Instant settle [Redmine:101652]
        - 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190315@Kathy: Add 2 new servers DB061, DB062 [Redmine:#110276]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190426@Kathy: Remove redundant param on cricket sp [Redmine:#112572]
		- 20190603@Sol: Incorporate PHAIO 4 [Redmine:#112885]
		- 20190620@Kathy: Remove corner, auto betradar bettypes [Redmine:#109584]
		- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190718@Sol: Relocate bettype 22 From early settlement to Main settlement [Redmine:#115232]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191119@Helen: Do not settle ticket on DB054 [Redmine:#123963]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200120@Sol:	Settlement with Ticket Exclusion for Other Sports - [Redmine:#126963]
        - 20200114@Sol: Server replacement - DB042 to DB055 [Redmine:#127173]
		- 20200417@Sol: Ticket Exclusion for Other Sports - Phase 4: Remaining Sports of Other Sports [Redmine:#131765]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200825@Kathy: Check server is using service broker by new SP instead of servername [Redmine:#140045]
		- 20200901@Kathy: Change Calculate Formula for HDP Bet Types of Football [Redmine:#140769]
		- 20200921@Louisa: Implement for Myanmar odds (apply bettype 1,3,7,8 remove 301->304) [Redmine:#141824]
		- 20210118@Louisa: Change Instant Name of DB054 - DB054C2\DB054 [Redmine:#148785]
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]
		- 20210416@Kathy: - Do not run replicated commands on servers which setup service broker [Redmine:#145127]
						  - Remove unused param matchCode
		- 20210804@Helen: Support Cashout for Basketball [Redmine:#159617]				  
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20211130@Kathy: New cashout model [Redmine:#164838]	
		- 20220110@Kathy: Update winlostdate = eventdate if these values are different [Redmine:#167246]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220309@Kathy: Remove code old Cashout model [Redmine:#169643]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
        @action             @mode
        + CAL               CAL, CAL-HT, CAL-FT, UNDO,
        + CAL-FGLG          CAL, CAL-HT, CAL-FT
        + REFUND            ALL, HT, FT, BetDaq, BetFair
        + REFUND-FGLG       REFUND-FT, REFUND-HT
        + CAL-SET           CAL        --Tennis
        + CAL-CORNER
        + CAL-INST          INST-HT,INST-FT
		+ MoveTicket
*/
BEGIN
    SET NOCOUNT ON;
	
	DECLARE @sMessage			NVARCHAR(MAX)
		,@isUndo				BIT
		,@IsEnableServiceBroker BIT
		,@IsSkipValidation		BIT
		,@ServerAlias			VARCHAR(50)
		,@TotalQueue			INT = 0
		
	SET @IsSkipValidation = CASE WHEN @action = 'MoveTicket' THEN 1 ELSE 0 END 

    SET @isUndo = CASE
                    WHEN @mode LIKE '%UNDO%' THEN 1
                    WHEN @action LIKE '%UNDO%' THEN 1
                    ELSE 0
                END

	SET @IsEnableServiceBroker = 0
	SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)
	
	IF @RunOnServer <> @@SERVERNAME
	BEGIN
		PRINT 'This command was skipped because run wrong server'
		RETURN
	END

	IF @IsSkipValidation = 0
		IF @@SERVERNAME IN ('DB054','DB054C2\DB054','DB042', 'SITDB042','DB232\SQLSERVER2008R2', 'DB233\SQLSERVER2008R2', 'TESTDB055', 'SITDB055', 'DB055', 'DB-61\DEVDB055' ) AND @isUndo = 0
			RETURN

	EXEC dbo.NAP_Set_ServerInfo 
		@IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT
		,@ServerAlias = @ServerAlias OUTPUT	
		,@TotalQueue = @TotalQueue OUTPUT

	IF (@@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DBTP','DB061', 'DB062', 'DB055') OR @IsEnableServiceBroker = 1)
		 AND @CalledByBrokerService = 0
    BEGIN
        -- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
		IF @SettlementProcessingId IS NOT NULL AND @Mode = 'profile-major'
		BEGIN
			IF OBJECT_ID('SettlementProcessing', 'U') IS NOT NULL
			BEGIN
				DECLARE @MessageTypeNew VARCHAR(200) 
					,@QueueNoNew INT 
			
				SET @QueueNoNew = @SettlementProcessingId%@totalqueue 
									+ CASE WHEN @SettlementProcessingId%@totalqueue = 0 THEN @TotalQueue ELSE 0 END

				SET @MessageTypeNew = 'bet_settle_msg_type_' 
										+ CASE WHEN @QueueNoNew < 10 THEN '0' ELSE '' END + CAST(@QueueNoNew AS VARCHAR)
			
				INSERT INTO dbo.SettlementProcessing (SessionId, TransIds, OddsType, modds, IsMarked, MessageType)
				SELECT @SessionId, @strTransIds, @oddstype, @modds, @ismarked,  @MessageTypeNew
			END
		END
		ELSE
		BEGIN
			SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_Main @matchid = ' + CONVERT(NVARCHAR(50), @matchid) + '
            ,@mode = ' + CASE
                WHEN @mode IS NULL THEN 'NULL'
                ELSE '''' + CONVERT(NVARCHAR(50), @mode) + ''''
                END + '
            ,@action = ' + CASE
                WHEN @action IS NULL THEN 'NULL'
                ELSE '''' + CONVERT(NVARCHAR(50), @action) + ''''
                END + '
            ,@fth = ' + CASE
                WHEN @fth IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @fth)
                END + '
            ,@fta = ' + CASE
                WHEN @fta IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @fta)
                END + '
            ,@hth = ' + CASE
                WHEN @hth IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @hth)
                END + '
            ,@hta = ' + CASE
                WHEN @hta IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @hta)
                END
            + CASE WHEN @home_2nd IS NULL THEN '' ELSE ',@home_2nd = ' + CONVERT(NVARCHAR(50), @home_2nd) END
            + CASE WHEN @away_2nd IS NULL THEN '' ELSE ',@away_2nd = ' + CONVERT(NVARCHAR(50), @away_2nd) END
            + CASE WHEN @sporttype IS NULL THEN '' ELSE ',@sporttype = ' + CONVERT(NVARCHAR(50), @sporttype) END
            + CASE WHEN @betstatus IS NULL THEN '' ELSE ',@betstatus = ' + '''' + CONVERT(NVARCHAR(50), @betstatus) + '''' END
            + CASE WHEN @GoalRecord IS NULL THEN '' ELSE ',@GoalRecord = ' + '''' + CONVERT(NVARCHAR(50), @GoalRecord) + '''' END
			+ CASE WHEN @goalsequenceHT IS NULL THEN '' ELSE ',@goalsequenceHT = ' + '''' + CONVERT(NVARCHAR(50), @goalsequenceHT) + '''' END
			+ CASE WHEN @goalsequenceFT IS NULL THEN '' ELSE ',@goalsequenceFT = ' + '''' + CONVERT(NVARCHAR(50), @goalsequenceFT) + '''' END
            + CASE WHEN @oddeven IS NULL THEN '' ELSE ',@oddeven = ' + CONVERT(NVARCHAR(50), @oddeven) END
            + CASE WHEN @oddevenht IS NULL THEN '' ELSE ',@oddevenht = ' + CONVERT(NVARCHAR(50), @oddevenht) END
            + CASE WHEN @oddevenhome IS NULL THEN '' ELSE ',@oddevenhome = ' + CONVERT(NVARCHAR(50), @oddevenhome) END
            + CASE WHEN @oddevenhome_ht IS NULL THEN '' ELSE ',@oddevenhome_ht = ' + CONVERT(NVARCHAR(50), @oddevenhome_ht) END
            + CASE WHEN @oddevenaway IS NULL THEN '' ELSE ',@oddevenaway = ' + CONVERT(NVARCHAR(50), @oddevenaway) END
            + CASE WHEN @oddevenaway_ht IS NULL THEN '' ELSE ',@oddevenaway_ht = ' + CONVERT(NVARCHAR(50), @oddevenaway_ht)END
            + CASE WHEN @oddeven_2H IS NULL THEN '' ELSE ',@oddeven_2H = ' + CONVERT(NVARCHAR(50), @oddeven_2H) END
            + CASE WHEN @totalgoal IS NULL THEN '' ELSE ',@totalgoal = ' + CONVERT(NVARCHAR(50), @totalgoal) END
            + CASE WHEN @totalht IS NULL THEN '' ELSE ',@totalht = ' + CONVERT(NVARCHAR(50), @totalht) END
            + CASE WHEN @totalgoal_2H IS NULL THEN '' ELSE ',@totalgoal_2H = ' + CONVERT(NVARCHAR(50), @totalgoal_2H) END
            + CASE WHEN @totalhome IS NULL THEN '' ELSE ',@totalhome = ' + CONVERT(NVARCHAR(50), @totalhome) END
            + CASE WHEN @totalaway IS NULL THEN '' ELSE ',@totalaway = ' + CONVERT(NVARCHAR(50), @totalaway) END
            + CASE WHEN @goaldiff IS NULL THEN '' ELSE ',@goaldiff = ' + CONVERT(NVARCHAR(50), @goaldiff) END
            + CASE WHEN @scorediff IS NULL THEN '' ELSE ',@scorediff = ' + CONVERT(NVARCHAR(50), @scorediff) END
            + CASE WHEN @scorediff_ht IS NULL THEN '' ELSE ',@scorediff_ht = ' + CONVERT(NVARCHAR(50), @scorediff_ht) END
            + CASE WHEN @scorediff_2H IS NULL THEN '' ELSE ',@scorediff_2H = ' + CONVERT(NVARCHAR(50), @scorediff_2H) END
            + CASE WHEN @correctscore IS NULL THEN '' ELSE ',@correctscore = ' + '''' + CONVERT(NVARCHAR(50), @correctscore) + '''' END
            + CASE WHEN @correctscore_ht IS NULL THEN '' ELSE ',@correctscore_ht = ' + '''' + CONVERT(NVARCHAR(50), @correctscore_ht) + '''' END
            + CASE WHEN @correctscore_2h IS NULL THEN '' ELSE ',@correctscore_2h = ' + '''' + CONVERT(NVARCHAR(50), @correctscore_2h) + '''' END
            + CASE WHEN @HTFT IS NULL THEN '' ELSE ',@HTFT = ' + '''' + CONVERT(NVARCHAR(50), @HTFT) + '''' END
            + CASE WHEN @ft_fg IS NULL THEN '' ELSE ',@ft_fg = ' + '''' + CONVERT(NVARCHAR(50), @ft_fg) + '''' END
            + CASE WHEN @ft_lg IS NULL THEN '' ELSE ',@ft_lg = ' + '''' + CONVERT(NVARCHAR(50), @ft_lg) + '''' END
            + CASE WHEN @ht_fg IS NULL THEN '' ELSE ',@ht_fg = ' + '''' + CONVERT(NVARCHAR(50), @ht_fg) + '''' END
            + CASE WHEN @ht_lg IS NULL THEN '' ELSE ',@ht_lg = ' + '''' + CONVERT(NVARCHAR(50), @ht_lg) + '''' END
            + CASE WHEN @T_Home IS NULL THEN '' ELSE ',@T_Home = ' + CONVERT(NVARCHAR(50), @T_Home) END
            + CASE WHEN @T_Away IS NULL THEN '' ELSE ',@T_Away = ' + CONVERT(NVARCHAR(50), @T_Away) END    
			+ CASE WHEN @ResourceIDs IS NULL THEN '' ELSE ',@ResourceIDs = ' + '''' + @ResourceIDs + '''' END
            + CASE WHEN @WinFromBehind IS NULL THEN '' ELSE ',@WinFromBehind = ' + '''' + @WinFromBehind + '''' END
            + CASE WHEN @isRefundHT IS NULL THEN '' ELSE ',@isRefundHT = ' + CONVERT(NVARCHAR(50),@isRefundHT,0) END
            + CASE WHEN @IsHTCal IS NULL THEN '' ELSE ',@IsHTCal = ' + CONVERT(NVARCHAR(50),@IsHTCal,0) END
            + CASE WHEN @IsSettleAbandonedMatch IS NULL THEN '' ELSE ',@IsSettleAbandonedMatch = ' + CONVERT(NVARCHAR(50), @IsSettleAbandonedMatch) END
            + CASE WHEN @IsSettleAbandonedMatchBetFair IS NULL THEN '' ELSE ',@IsSettleAbandonedMatchBetFair = ' + CONVERT(NVARCHAR(50), @IsSettleAbandonedMatchBetFair) END
            + CASE WHEN @IsExcludeBetdaq IS NULL THEN '' ELSE ',@IsExcludeBetdaq = ' + CONVERT(NVARCHAR(50), @IsExcludeBetdaq) END
            + CASE WHEN @IsExcludeBetfair IS NULL THEN '' ELSE ',@IsExcludeBetfair = ' + CONVERT(NVARCHAR(50), @IsExcludeBetfair) END
            + CASE WHEN @IsSettleAbandonedMatchIBC IS NULL THEN '' ELSE ',@IsSettleAbandonedMatchIBC = ' + CONVERT(NVARCHAR(50), @IsSettleAbandonedMatchIBC) END
            + CASE WHEN @LGOnly IS NULL THEN '' ELSE ',@LGOnly = ' + CONVERT(NVARCHAR(50), @LGOnly) END
            + CASE WHEN @IncludeLG IS NULL THEN '' ELSE ',@IncludeLG = ' + CONVERT(NVARCHAR(50), @IncludeLG) END
            + CASE WHEN @matchdate IS NULL THEN '' ELSE ',@matchdate = ' + '''' + CONVERT(NVARCHAR(50), @matchdate) + '''' END
            + CASE WHEN @strBettypes IS NULL THEN '' ELSE ',@strBettypes = ''' + CONVERT(VARCHAR(MAX), @strBettypes) + '''' END
            + CASE WHEN @strTransIds IS NULL THEN '' ELSE ',@strTransIds = ''' + CONVERT(VARCHAR(MAX), @strTransIds) + '''' END
            + CASE WHEN @xmlData IS NULL THEN '' ELSE ',@xmlData = ''' + @xmlData + '''' END
      
            + CASE WHEN @IsSettingByProfile IS NULL THEN '' ELSE ',@IsSettingByProfile = ' + CONVERT(NVARCHAR(50), @IsSettingByProfile) END
			+ CASE WHEN @IsReSettledTickets IS NULL THEN '' ELSE ',@IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) END
			+ CASE WHEN @RunOnServer IS NULL THEN '' ELSE ',@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END
			+ CASE WHEN @isCashout IS NULL THEN '' ELSE ',@isCashout = ' + CONVERT(NVARCHAR(50),@isCashout,0) END
			+ CASE WHEN @CashoutVersion IS NULL THEN '' ELSE ',@CashoutVersion = ' + CONVERT(NVARCHAR(50),@CashoutVersion,0) END
			+ CASE WHEN @strCustIds IS NULL THEN '' ELSE ',@strCustIds = ' + '''' + @strCustIds + '''' END
			+ CASE WHEN @TotalCommands IS NULL THEN '' ELSE ',@TotalCommands = ' + CONVERT(NVARCHAR(50), @TotalCommands) END
			+ CASE WHEN @SessionId IS NULL THEN '' ELSE ',@SessionId = ' + CONVERT(NVARCHAR(50), @SessionId) END
			+ CASE WHEN @ActionId IS NULL THEN '' ELSE ',@ActionId = ' + CONVERT(NVARCHAR(50), @ActionId) END
			+ CASE WHEN @MessageType IS NULL THEN '' ELSE ',@MessageType = ' + '''' + @MessageType + '''' END
			+ CASE WHEN @EventDate IS NULL THEN '' ELSE ',@EventDate = ' + '''' + CONVERT(VARCHAR(20),@EventDate) + '''' END
			
            + ',@CalledByBrokerService = 1'
			
			EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
				,@toService = N'//Service/Calculation_receive'
				,@onContract = N'//Contract/Calculation'
				,@messageType = N'//Message/Calculation'
				,@messageBody = @sMessage
		END

        RETURN
    END
    ELSE
    BEGIN
        DECLARE @tblBettypes TABLE (bettype SMALLINT PRIMARY KEY)
        DECLARE @xml XML
		
        IF @IsSettingByProfile IS NOT NULL
        BEGIN
			IF @mode IN ('LockMatch', 'ReleaseMatch') AND @ServerAlias <> 'DBTXN' AND @IsEnableServiceBroker = 1
			BEGIN
				EXEC dbo.ExecRep_NAP_Admin_01 
					@MatchId = @MatchId
					,@Mode = @Mode
					,@SessionId = @SessionId
					,@TotalQueue = @TotalQueue
			END
			
			IF @mode = 'profile-major'
			BEGIN
				EXEC dbo.NAP_Admin_Calculate_Profile
					@transIds   		= @strTransIds
					,@modds				= @modds
					,@Oddstype			= @Oddstype
					,@IsMarked			= @IsMarked
					,@matchid = @matchid
					,@ServerAlias = @ServerAlias
					,@SettlementProcessingId = @SettlementProcessingId
					,@ActionId = @ActionId		
					,@ErrMessage = @ErrMessage OUTPUT 
			END
			ELSE
			BEGIN
				IF @action LIKE 'CAL%' AND @strTransIds IS NOT NULL
					EXEC dbo.NAP_Admin_Calculate_TransID
						  @transIds   		= @strTransIds						  
						  ,@matchid			= @matchid

				IF @action LIKE 'REFUND%' AND @strTransIds IS NOT NULL
					EXEC dbo.NAP_Admin_Calculate_Refund_TransID
						   @transIds   		= @strTransIds						 
						   ,@matchid			= @matchid
	                  
				IF @action LIKE 'UNDO%' AND @strTransIds IS NOT NULL
					EXEC dbo.NAP_Admin_Calculate_Undo_TransID
						   @transIds   		= @strTransIds						  
						   ,@matchid			= @matchid
				
				IF @sporttype = 2
				BEGIN
					IF  @CashoutVersion =  2
						EXEC dbo.ExecRep_NAP_Admin_03
							@transIds = @strTransIds
							,@mode = @mode							
							,@matchid = @matchid
				END
			END
	        RETURN
        END 
	
        IF @Action = 'MoveTicket'
		BEGIN
			EXEC dbo.ExecRep_NAP_Admin_02 @matchid = @matchid
				,@Mode = @Mode 
				,@strTransIds = @strTransIds
				,@EventDate = @EventDate
				
			RETURN
		END
		
        IF @action = 'CAL' 
        BEGIN
			IF @sporttype <> 1
			BEGIN
				IF @Mode <> 'UNDO' 
				BEGIN
					SET @xml = CONVERT(XML, REPLACE('<root><r t="' + @strBettypes + '"/></root>', ',','"/><r t="'))

					INSERT INTO @tblBettypes (bettype)
					SELECT T.c.value('./@t','SMALLINT')
					FROM @xml.nodes('/root/r') AS T(c)
					OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
				END

				IF @Mode IN ('CAL-FT', 'CAL') 
				BEGIN
                
					-- bettype 1 : Handicap
					-- IF @betcount_1 > 0
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 1)
						EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
							,@bettype = 1
							,@fth = @fth
							,@fta = @fta
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets
							,@SportType = @Sporttype
               
					-- bettype 20 : Money Line
					-- IF @betcount_20 > 0
					IF @SportType = 154
					BEGIN
						-- for horse racing fixodds swap win positions to resuse calculating SP
						IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 20)
							EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
								,@bettype = 20
								,@fth = @fta
								,@fta = @fth
								,@betcount = 1
					END
					ELSE
						IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 20)
							EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
								,@bettype = 20
								,@fth = @fth
								,@fta = @fta
								,@betcount = 1
								,@IsReSettledTickets = @IsReSettledTickets

					-- bettype 2 : Odd/Even
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 2)
											EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
							,@bettype = 2
							,@oddeven = @oddeven
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets

					-- bettype 3 : Over/Under
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 3)
						EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
							,@bettype = 3
							,@totalgoal = @totalgoal
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets            

					-- bettype 5 : 1x2
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 5)
											EXEC dbo.NAP_Admin_Calculate_5 @matchid = @matchid
							,@bettype = 5
							,@whowin = @scorediff
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets
           
					--Home Team Over/Under
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 401)
						EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
							,@bettype = 401
							,@totalgoal = @totalhome
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets
               
					--Away Team Over/Under
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 402)
						EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
							,@bettype = 402
							,@totalgoal = @totalaway
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets                

					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 501)
						EXEC dbo.NAP_Admin_Calculate_501 @matchid = @matchid
							,@bettype = 501
							,@betcount = 1
							,@ScoreDiff = @ScoreDiff
							,@IsReSettledTickets = @IsReSettledTickets

				END -- END CAL/CAL-FT

				IF @Mode IN ('CAL-HT', 'CAL')
					AND @SportType NOT IN (180, 181, 182, 183, 184, 185, 186)
				BEGIN
					-- exec in all cases, both 'FT' and 'HT'
				   IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 7)
						EXEC dbo.NAP_Admin_Calculate_7 @matchid = @matchid
							,@bettype = 7
							,@hth = @hth
							,@hta = @hta
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets
							,@Sporttype = @Sporttype

					-- bettype 21: 1st moneyline
				   IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 21)
						EXEC dbo.NAP_Admin_Calculate_7 @matchid = @matchid
							,@bettype = 21
							,@hth = @hth
							,@hta = @hta
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets
               
					-- bettype 8 : 1st Over/Under
					IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 8)
											EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
							,@bettype = 8
							,@totalht = @totalht
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets

					-- bettype 12 : 1st Odd/Even
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 12)
											EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
							,@bettype = 12
							,@oddeven = @oddevenht
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets

					-- bettype 15 : 1st 1x2
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 15)
											EXEC dbo.NAP_Admin_Calculate_5 @matchid = @matchid
							,@bettype = 15
							,@whowin = @scorediff_ht
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets          
               
					--1H Home Team Over/Under
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 403)
											EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
							,@bettype = 403
							,@totalht = @hth
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets

					--1H Away Team Over/Under
					IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 404)
											EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
							,@bettype = 404
							,@totalht = @hta
							,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets
				END
			END
            
            IF @Mode = 'UNDO'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_Undo
                    @matchid       = @matchid
                    ,@strBettypes   = @strBettypes                           
            END
        END

        IF @action = 'CAL-FM'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_221 @matchid = @matchid
                , @result = @xmlData
                , @action = @Mode -- CAL, REFUND, UNDO
				, @IsReSettledTickets = @IsReSettledTickets
        END

        IF @action = 'REFUND'
        BEGIN      
            IF @mode = 'REFUND-FT'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_RefundFT @matchid = @matchid
                    ,@IsExcludeBetdaq = @IsExcludeBetdaq
                    ,@IsExcludeBetfair = @IsExcludeBetfair
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@strBettypes = @strBettypes            
            END

            IF @mode = 'REFUND-HT'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_RefundHT @matchid = @matchid
                    ,@IsExcludeBetdaq = @IsExcludeBetdaq
                    ,@IsExcludeBetfair = @IsExcludeBetfair
                    ,@strBettypes = @strBettypes              
            END
          
            IF @mode = 'REFUND'
            BEGIN                
                    EXEC dbo.NAP_Admin_Calculate_RefundAll
                     @matchid                    = @matchid
                    ,@IsExcludeBetdaq            = @IsExcludeBetdaq
                    ,@IsExcludeBetfair            = @IsExcludeBetfair
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@strBettypes                   = @strBettypes                   
            END

            IF @mode = 'BetDaq'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_Refund_BetDaq @matchid = @matchid
            END

            IF @mode = 'BetFair'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_Refund_BetFair @matchid = @matchid
            END

            IF @mode = 'REFUND-EARLY'
            BEGIN
                EXEC [dbo].[NAP_Admin_Calculate_603]
                    @matchid            = @MatchId
                    ,@strResourceIds    = @ResourceIds
                    ,@Action            = @Action
            END
        END

        IF @action IN ('CAL-INST', 'UNDO-INST')
        BEGIN
             EXEC dbo.NAP_Admin_InstantCalculate_3
                @matchid        = @matchid
                ,@action        = @action
                ,@strTransIds   = @strTransIds
                ,@strTransCashout = @strTransCashout OUTPUT
        END

        IF @Action = 'UNDO'
        BEGIN
            IF @Mode = 'UNDO-EARLY'
            BEGIN
                EXEC [dbo].[NAP_Admin_Calculate_603]
                    @matchid            = @MatchId
                    ,@strResourceIds    = @ResourceIds
                    ,@Action            = @Action
            END

        END

		IF @action = 'Cashout'
		BEGIN
			EXEC dbo.ExecRep_NAP_Admin_03
				@transIds = @strTransIds
				,@mode = @mode
				,@matchid = @matchid
		END
    END
    
END

