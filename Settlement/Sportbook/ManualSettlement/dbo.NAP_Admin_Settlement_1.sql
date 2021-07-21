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
    
    ,@SelectedQuarter	VARCHAR(50)		= NULL
    ,@QuarterResult		VARCHAR(MAX)	= NULL
    
    ,@ResourceResult	VARCHAR(MAX)	= NULL
   
    ,@action            VARCHAR(10)    	= 'CAL'
    ,@IP                VARCHAR(50)    	= ''
	,@IsReSettledTickets BIT			= 1
	,@ChildMatchIds		VARCHAR(500)	= NULL
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
		- 20210730@Kathy: Apply Settlement by Profile for minor bettype of soccer [Redmine:#158477]


    Param's Explanation:
        + @betstatus: Used for score table, FGLG status, refund status
                
        + @SelectedQuarter: the list of selected quarter for settlement basketball
			'801,802,1H,803,804,2H,FT'
		+ @QuarterResult: the result of each quarter bettype
		
		+ @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
 
*/
BEGIN
    SET NOCOUNT ON
	
    DECLARE @SkipBalanceUpdate          BIT
        ,@start                         DATETIME
        ,@stop                          DATETIME
        ,@avaiableProcess				BIT
        ,@goalrecord_old                VARCHAR(50)
        ,@LogData                       NVARCHAR(300)
        ,@eventstatus                   NVARCHAR(50)
        ,@sporttype                     SMALLINT
        ,@TicketCount                   INT    
        ,@Remark                        VARCHAR(500)
        ,@ActionID						INT
        ,@HomeValue						VARCHAR(20)
        ,@AwayValue						VARCHAR(20)
        ,@TotalAccount					INT
        ,@TotalAccount_BalanceUpdate    INT
        ,@HTDone                        BIT
        ,@FTDone                        BIT
        ,@strAutoBettypes				VARCHAR(MAX)
        ,@strHTBettypes					VARCHAR(MAX)
        ,@strBettypes					VARCHAR(MAX)	
		,@IsRefundHT					BIT	
		-- Corner match
		,@ChildMatchType		TINYINT

    --START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables    
    
    DECLARE @status TABLE (FTBet BIT, BetCount INT, InRunning INT)
    
    CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
    
    SELECT  @start                    = CURRENT_TIMESTAMP
            ,@TicketCount            = 0
            ,@ActionID                = CASE @Action
											WHEN 'CAL' THEN 100
											WHEN 'CAL-FT' THEN 101
											WHEN 'CAL-HT' THEN 102
											WHEN 'UNDO'	THEN 103
                                        END

			,@IsRefundHT			= 0

    SELECT  @sporttype        = m.sporttype
            ,@goalrecord_old    = ISNULL(m.goalrecord, '')
			,@IsRefundHT = CASE WHEN betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
			,@ChildMatchType = ChildMatchType
    FROM    dbo.match m WITH(NOLOCK)
    WHERE    m.matchid = @matchid

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @ErrCode = 1001001
            ,@ErrMsg    = 'Match does not exist!'

        RETURN
    END

	 SELECT @HomeValue  = CAST(@fth AS VARCHAR(20))
            ,@AwayValue = CAST(@fta AS VARCHAR(20)) 
            ,@SelectedQuarter = CASE WHEN @sporttype <> 2 THEN NULL ELSE @SelectedQuarter END
			,@SkipBalanceUpdate     = CASE 
										WHEN @sporttype = 1 THEN CASE WHEN @action = 'UNDO' THEN 0 ELSE 1 END
										ELSE 0
									END

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
        SELECT    @TicketCount = COUNT(1)
        FROM    dbo.bettrans b WITH(NOLOCK)
        WHERE    b.matchid = @matchid
                AND 1 = CASE 
                            WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 1
                            ELSE 0
                        END
    ELSE IF @Action = 'CAL-FT'
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
    ELSE 
        SELECT    @TicketCount = COUNT(1)
        FROM    dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
        WHERE  	b.matchid = @matchid
				AND 1 = CASE -- Basketball
						WHEN @SelectedQuarter IS NULL THEN 1
						WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
						WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
						ELSE 0
					END
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

    -------------------------------------------------------------
    ---        CAPTURE value BALANCE before settlement        ---
    ---------------------------VVVV------------------------------
    IF @SkipBalanceUpdate = 0
    BEGIN
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
            , @BAQuarter		= @SelectedQuarter
			, @IsRefundHT		= @IsRefundHT

        SELECT @TotalAccount = @@ROWCOUNT

    END --IF @SkipBalanceUpdate = 0
            --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    BEGIN TRY
            -- 20090412 : Joe : case for unsettle the game.
        IF @action = 'UNDO'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_Main 
                @matchid        = @matchid
                --,@SelectedSet    = @SelectedSet
                ,@SelectedQuarter = @SelectedQuarter
                ,@action        = 'CAL'        -- Default Action for UNDO Settlement 
                ,@mode            = 'UNDO'
                ,@strBettypes = @strBettypes
            
            --Cricket: Charged Commision
            EXEC dbo.NAP_Admin_Calculate_500
                @MatchId = @matchId
                ,@Action = @Action
            
            -- BetTrade Winlost Sharing
            IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype = 904)
                EXEC dbo.NAP_Admin_Calculate_904
                    @MatchId = @matchid
                    ,@Action = @Action
					
			-- CashOut Winlost Sharing
            IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype = 914)
			BEGIN
                EXEC dbo.NAP_Admin_Calculate_914
                    @MatchId = @matchid
                    ,@Action = @Action
			END	

            EXEC dbo.NAP_Admin_Settlement_MP
                @matchid        = @matchid
                ,@creator        = @creator
                ,@action        = 'UNDO'
                ,@SelectedQuarter = @SelectedQuarter
                ,@IP            = @IP

            EXEC DBPRO.BODB02.dbo.NAP_UpdateMatch_Remark 
                @matchid        = @matchid
                ,@command        = 'U'                
                ,@SelectedQuarter = @SelectedQuarter

            EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
                @Command        = 'NAP_Admin_Settlement_1-UNDO'
                ,@MatchID        = @matchid
                ,@betstatus        = @betstatus
                ,@SelectedQuarter = @SelectedQuarter
                ,@creator        = @creator

			IF @Sporttype = 1 -- Soccer
            BEGIN
                IF @ChildMatchType = 204 -- Corner
                BEGIN
					EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s 
						@Command            = 'NAP_Admin_Settlement_1-Corner-UNDO',
						@MatchID            = @MatchID,
						@creator            = @creator 
                END
                ELSE
                BEGIN
					EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s 
						@Command            = 'NAP_Admin_Settlement_1-UNDO',
						@MatchID            = @MatchID,
						@creator            = @creator 
				END
				EXEC DBPRO.BODB02.dbo.NAP_Set_AutoPayoutResultUpd 
					@MatchId = @matchid
					,@TypeId = NULL
					,@StatusId = NULL 
					,@IsUndoMatch = 1 --Clear data in table AutoPayoutResult if match has been undo

            END
            ELSE IF @sporttype = 2 -- basketball
            BEGIN
				 EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b
                    @Command            = 'NAP_Admin_Settlement_1-UNDO',
                    @MatchID            = @MatchID,
                    @creator            = @creator, 
                    @SelectedQuarter    = @SelectedQuarter,
                    @Results			= @QuarterResult	
            END
            
            /* --20110620@Thien: replace by calling SP instead
            -- RESET 'SaveBet' of DB06
            DELETE FROM DB06.bodb02.dbo.Save_Jobs WHERE matchid = @matchid
            UPDATE DB06.bodb02.dbo.Save_ListMatch SET IsGameFinish = 1 WHERE matchid = @matchid

            INSERT INTO DB06.bodb02.dbo.SAve_Jobs (matchid, liveindicator, savetype, bettype, typename)
            SELECT @matchid, 1, 'DEL', 0, 0
            */
            EXEC DBACC.bodb02.dbo.NAP_Admin_Match_UpdateSaveBet 
                @action            = 'UNDO'
                ,@matchid        = @matchid
                ,@SelectedQuarter = @SelectedQuarter -- Basketball
                
        END
        ELSE
        BEGIN
            /* 06 OCT 2008 : Joe
            As of Today.  Match Remark can't tell game just settled for HT yet
            need below code to determine for mark match as calculated (all bets settled)
            */
			INSERT INTO @status(FTBet, BetCount, InRunning)		
            SELECT    CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0 ELSE 1 END AS FTBet
                    ,SUM(CASE WHEN statusID IN (101, 102) THEN 0 ELSE 1 END)
                    ,SUM(CASE WHEN statusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END)
            FROM    dbo.bettrans b with (NOLOCK)
						OUTER APPLY (
										SELECT TOP 1 mt.transId
										FROM MarkedTransaction mt WITH(NOLOCK)
										WHERE b.transid = mt.TransId
									) mt
            WHERE    b.matchid = @matchid
                    AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238, 38) -- Outright, VSRacing, Betbuilder
                    AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                    AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
					AND b.bettype NOT BETWEEN 901 AND 920 --BT & CashOut 
                    AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
					
            GROUP BY CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0 ELSE 1 END    

            IF NOT EXISTS (SELECT * FROM @status WHERE FTBet = 0)
                INSERT INTO @status VALUES (0, 0,0)

            IF NOT EXISTS (SELECT * FROM @status WHERE FTBet = 1)
                INSERT INTO @status VALUES (1, 0, 0)

            SELECT    @HTDone = CASE InRunning
                                WHEN 0 THEN 1
                                ELSE 0
                                END
            FROM    @status
            WHERE    FTBet = 0

            SELECT    @FTDone = CASE InRunning
                                WHEN 0 THEN 1
                                ELSE 0
                                END
            FROM    @status
            WHERE    FTBet = 1

            /* Mode
            CAL : (default) Settle ALL BetTypes
            CAL-FT : Full Time Only
            CAL-HT : Half Time Only
            SCORE : Only Save Score -- not use
            UNDO : Unsettle the match  -- not use
            */
            SELECT    @eventstatus = CASE 
                                        WHEN @action = 'CAL' AND @Sporttype NOT IN (2,5)        THEN N'completed'
                                        WHEN @action = 'CAL' 
												AND (@sporttype = 2 AND @SelectedQuarter LIKE '%FT%') THEN N'completed'    -- Match Option checked 
                                        WHEN @action = 'CAL-HT' AND m.matchcode LIKE '%hedge%'    THEN eventstatus -- Jamie@20120330: Not change eventstatus='completed' for Hedge Match although 
                                        WHEN @action = 'CAL-FT' AND @HTDone = 1 THEN N'completed'
                                        ELSE m.eventstatus
                                        END
                    ,@FTDone        = CASE 
                                        WHEN @action = 'CAL-HT' AND m.matchcode LIKE '%hedge%' THEN 0
                                        ELSE @FTDone
                                        END
            FROM    DBPRO.BODB02.dbo.Match m WITH(NOLOCK)
            WHERE    m.matchid = @matchid

            EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
                @Command            = 'NAP_Admin_Settlement_1-CAL'
                ,@MatchID            = @matchid
                ,@FTHome            = @fth
                ,@FTAway            = @fta
                ,@HTHome            = @hth
                ,@HTAway            = @hta
                ,@BetStatus         = @betstatus
                ,@GoalRecord        = @goalrecord
                ,@SelectedQuarter	= @SelectedQuarter  -- Basketball
                ,@Action            = @action
                ,@FTDone            = @FTDone
                ,@HTDone            = @HTDone
                ,@creator            = @creator

            IF @sporttype = 2 AND @Action = 'CAL'
            BEGIN
				EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b
					@Command = 'NAP_Admin_Settlement_1-CAL'		
					,@MatchID = @matchid								
					,@Results = @QuarterResult					
					,@creator = @creator
					,@SelectedQuarter = @SelectedQuarter					
            END

            IF @Sporttype = 1 AND LEFT(@Action, 3) = 'CAL'
            BEGIN				
                EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
                    @Command        = 'NAP_Admin_Settlement_1-CAL',
                    @MatchID        = @MatchID,
                    @fth             = @fth,
                    @fta             = @fta,
                    @hth             = @hth,
                    @hta             = @hta,
                    @ResourceResult	 = @ResourceResult,
                    @Action            = @Action,
                    @IsAuto            = 0,
                    @creator        = @creator
            END
          
            IF LEFT(@action, 3) = 'CAL'
            BEGIN
				IF @sporttype = 1 -- soccer
                BEGIN
					EXEC dbo.NAP_Admin_Settlement_3_profile
						@matchId	= @matchid
						,@action	= @action
						,@ActionID	= @ActionID
						,@IsReSettledTickets = @IsReSettledTickets
						,@ResourceResult = @ResourceResult
						,@ErrCode	= @ErrCode OUTPUT
						,@ErrMsg	= @ErrMsg OUTPUT

					IF @ErrCode <> 0
						RETURN

                END
				ELSE 
					EXEC dbo.NAP_Admin_Settlement_3
						@matchid            = @matchid
						,@mode                = @action    
						,@IsReSettledTickets = @IsReSettledTickets
						,@creator = @creator
            END

        IF @eventstatus = 'completed' AND @betstatus NOT LIKE '%Refund;%' AND @betstatus NOT LIKE '%Refund FT;%' AND @betstatus NOT LIKE '%Abandoned%'
        BEGIN
            EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
                @matchid    = @matchid
                ,@command    = 'C'
                ,@SelectedQuarter = @SelectedQuarter
        END
        ELSE IF (@action = 'CAL-HT' OR (@sporttype = 2 AND @SelectedQuarter LIKE '%1H%'))
        BEGIN
            EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
                @matchid    = @matchid
                ,@command    = 'H'
        END
    END 
    END TRY
    BEGIN CATCH
        -- Capture Balance incase of failure
        IF @SkipBalanceUpdate = 0
        BEGIN
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
                , @BAQuarter		= @SelectedQuarter
        END --
        
        -- Compare and update pending balance with error case
		IF @SkipBalanceUpdate = 0
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

    IF @SkipBalanceUpdate = 0
    BEGIN
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
            , @BAQuarter		= @SelectedQuarter
			, @IsRefundHT		= @IsRefundHT
    END --IF @SkipBalanceUpdate = 0

    -------------------------------------------------------------
    ---                   compare BALANCE                     ---
    ---------------------------VVVV------------------------------

    SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT a.custid)
    FROM @BalanceWalletAfter a
        INNER JOIN @BalanceWalletBefore b 
        ON     a.matchid            = b.matchid
                AND a.custid        = b.custid
                AND a.balanceType   = b.balanceType
                AND a.walletType    = b.walletType
                AND a.bonusId       = b.bonusId
    WHERE a.balance <> b.balance

    -- Compare and update pending balance
	IF @SkipBalanceUpdate = 0
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			, @BalanceWalletAfter	= @BalanceWalletAfter
			, @ActionId				= @ActionID

    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------
    SELECT @stop = CURRENT_TIMESTAMP
	
	DECLARE @xmlQuarterResult XML = CAST(@QuarterResult AS XML)
 
	SET @QuarterResult = ''
	SELECT @QuarterResult = @QuarterResult 
				+ T.C.value('@Id', 'VARCHAR(50)') 
				+ '(' + ISNULL(T.C.value('@HomeValue', 'VARCHAR(50)'),'')
				+ CASE 
					WHEN T.C.value('@AwayValue', 'VARCHAR(50)') IS NULL THEN ''
					ELSE '-' + T.C.value('@AwayValue', 'VARCHAR(50)')
					END	
				+ '),'
	 FROM @xmlQuarterResult.nodes('Results/Resource') T(c)
	 
	 IF RIGHT(@QuarterResult,1) = ','
		SELECT @QuarterResult = LEFT(@QuarterResult,LEN(@QuarterResult)-1)
 
    SELECT @LogData = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                        + ' score:' + CAST(ISNULL(@fth, 0) AS NVARCHAR(10)) 
                                                        + '-' + CAST(ISNULL(@fta, 0) AS NVARCHAR(10)) 
                                                        + ' HT:' + CAST(ISNULL(@hth,0) AS NVARCHAR(10)) 
                                                        + '-' + CAST(ISNULL(@hta,0) AS NVARCHAR(10)) 
                                                        + ' GoalRecord:' + ISNULL(@goalrecord, '') 
                                                        + '(Old:' + @goalrecord_old + ') Remark(' + @betstatus + ')' 
														+ CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE 'SelectedQuarter:' + @SelectedQuarter + '<br/> ' END
														+ CASE WHEN @QuarterResult <> '' THEN 'Result: ' + @QuarterResult + '<br/> ' ELSE '' END
                                                        +' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

    EXEC dbo.WriteLog_UserLog 
        @UserID = @creator
        ,@Doing = @LogData

        
    SELECT @Remark ='NAP: ' + CASE    WHEN ISNULL(@goalrecord_old,'')='' THEN ''
                                    ELSE 'Old GoalRecord:' + @goalrecord_old + '<br/> '
                                    END
							+ CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE 'SelectedQuarter:' + @SelectedQuarter + '<br/> ' END
							+ CASE WHEN @QuarterResult <> '' THEN 'Result: ' + @QuarterResult + '<br/> ' ELSE '' END
                            + 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms;' 
                            + ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) + ';'
							+ CASE WHEN @action LIKE 'CAL%' THEN ' Recalc: ' + CAST (@IsReSettledTickets AS VARCHAR(1)) + ';' ELSE '' END
                            + ' Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
							+ CASE WHEN ISNULL(@ChildMatchIds,'') = '' THEN ''
								   WHEN @ChildMatchIds = '0' THEN ' RefChild:0' 
								   ELSE ' RefChild:(' + @ChildMatchIds +')' 
								   END

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
    
    ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1

	DROP TABLE #tblMatchProcess
END
GO
