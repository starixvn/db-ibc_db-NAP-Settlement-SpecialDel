/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_All] 
     @matchid                       	INT
    ,@creator                       	INT
    ,@IsExcludeBetdaq               	BIT             = 0
    ,@IsSettleAbandonedMatch            BIT             = 0
    ,@IsExcludeBetfair                  BIT             = 0
    ,@IsSettleAbandonedMatchBetFair     BIT             = 0
    ,@IsSettleAbandonedMatchIBC         BIT             = 0
    ,@hth								INT             = NULL
    ,@hta                               INT             = NULL
    ,@fth                               INT             = NULL
    ,@fta                               INT             = NULL
    ,@GoalSequence                      VARCHAR(50)     = NULL 
    ,@betstatus                        	NVARCHAR(50)    = NULL
    ,@SetResult                        	VARCHAR(50)     = NULL 
    ,@GameResult1                       VARCHAR(MAX)    = NULL
    ,@GameResult2                       VARCHAR(MAX)    = NULL
    ,@GameResult3                       VARCHAR(MAX)    = NULL
    ,@GameResult4                       VARCHAR(MAX)    = NULL
    ,@GameResult5                       VARCHAR(MAX)    = NULL
    ,@SelectedSet                       VARCHAR(50)     = NULL
    ,@SelectedSettleFinishedGame        VARCHAR(50)     = NULL  
    ,@SelectedSet1Game                	VARCHAR(MAX)    = NULL 
    ,@SelectedSet2Game                	VARCHAR(MAX)    = NULL 
    ,@SelectedSet3Game                	VARCHAR(MAX)    = NULL 
    ,@SelectedSet4Game                	VARCHAR(MAX)    = NULL 
    ,@SelectedSet5Game                	VARCHAR(MAX)    = NULL
    ,@Action                            VARCHAR(10)        = 'CAL'
    ,@SelectedQuarter					VARCHAR(50)		= NULL
    ,@ResourceResult					VARCHAR(MAX)	= NULL
    ,@IsNested                          BIT                = 1
    ,@IP                                VARCHAR(15)        = ''
    ,@ErrCode							INT                = 0      OUTPUT
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
    
    Param's Explanation:
    • @matchid: matchid need to refund
    • @IsExcludeBetdaq: Is Exclude betdaq tickets or not
    • @IsSettleAbandonedMatch: Is Settlement for Abandoned/postponed match or not
    • @IsExcludeBetfair: Is Exclude betfair tickets or not
    • @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
      @IsSettleAbandonedMatchIBC: Is Settlement for IBC ticket of Abandoned/postponed match or not
        * List of BetDaq Customers 
                    custid    --- username    -    roleid
                    50057    ---    BQUS888        -    1
                    879241    ---    BQUSMLB        -    1
                    103873    ---    BQUSNBA        -    1
                    78761    ---    ITibc101    -    1
                    1688156    ---    MTEST0101    -    2
                    851668  --- BDUS01      -   1
                    878902  --- BDUS016     -   1
        * List of Betfair Customers 
                    custid    --- username    -    roleid
                    2331    ---    BF            -    1
                    1077687    ---    BFOS        -    1
                    15523642--- BF3            -    1
    • @SelectedSettleFinishedGame: set [1-5] 
    * @SelectedQuarter: the list of selected quarter for settlement basketball
			'801,802,1H,803,804,2H,FT'
	
	* @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @start                              DATETIME
            ,@stop                              DATETIME
            ,@avaiableProcess					BIT
            ,@ScoreLog                          VARCHAR(100)
            ,@sporttype                         SMALLINT
            ,@IsRefundHT                        BIT
            ,@IsHTCal                           BIT -- checking user did CAL/Refund HT yet
            ,@oddevenht                         SMALLMONEY
            ,@betCount_1324                     INT                = 0 
            ,@HomeValue                         VARCHAR(20)
            ,@AwayValue                         VARCHAR(20)
            ,@MaxGameSet1                       INT                = 0
            ,@MaxGameSet2                       INT                = 0 
            ,@MaxGameSet3                       INT                = 0 
            ,@MaxGameSet4                       INT                = 0 
            ,@MaxGameSet5                       INT                = 0 
            ,@MaxGameSet1Parlay                 INT                = 0
            ,@MaxGameSet2Parlay                 INT                = 0 
            ,@MaxGameSet3Parlay                 INT                = 0 
            ,@MaxGameSet4Parlay                 INT                = 0 
            ,@MaxGameSet5Parlay                 INT                = 0 
            ,@SetxGameyHomeWON                  VARCHAR(MAX)     = '' 
            ,@SetxGameyAwayWON                  VARCHAR(MAX)     = ''
            ,@SetxGameyDRAW                     VARCHAR(MAX)     = ''
            ,@SetxGameyFinishedGame             VARCHAR(MAX)     = ''
            ,@BetstatusLOG                      VARCHAR(50)        = ''
            ,@IsSettleDeterminedTicketTennis    BIT                = 0
            ,@scorediff                         SMALLMONEY 
            ,@Remark                            VARCHAR(500)
            ,@ActionID                          INT
            ,@movebet                           VARCHAR(20)
            ,@matchcode                         NVARCHAR(50)
            ,@log                               VARCHAR(300)
            ,@strSettledBettypes                VARCHAR(MAX) 
            ,@strRefundBettypes					VARCHAR(MAX)
            ,@strAutoBettypes					VARCHAR(MAX)
			,@refundCommand						VARCHAR(100)
			,@refundCommand_1s					VARCHAR(100)
			,@SDTRecord							TINYINT = 0
			,@IsHedgeMatch						BIT
			,@QuarterResult						VARCHAR(MAX)
			,@xmlResultDetail					XML
			,@ht_fg								VARCHAR(10)
			,@ht_lg								VARCHAR(10)
			,@ft_fg								VARCHAR(10)
			,@ft_lg								VARCHAR(10)
			,@goaldiff							SMALLMONEY
			,@matchdate 						DATETIME
			,@goalsequenceHT					VARCHAR(50)
			,@goalsequenceFT					VARCHAR(50)
	
	DECLARE @ResourceResult_tmp AS TABLE (ResourceId VARCHAR(20),HomeValue VARCHAR(50))		
	DECLARE @GoalBettype_tmp AS TABLE (bettype INT, Voided_cnt INT, ticket_cnt INT)
	
    --START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables    

	SELECT @refundCommand 						= 'NAP_Admin_Settlement_Refund-All'
		,@refundCommand_1s						= @refundCommand
		,@IsRefundHT = 0
		,@IsHTCal = 0
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
    SELECT  @strAutoBettypes = COALESCE(@strAutoBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
    FROM	dbo.f_Set_GetGroupBettypes() f 
    WHERE   f.IsAuto = 1   

    DECLARE @TennisTotal        SMALLINT
            ,@T_Home            SMALLINT
            ,@T_Away            SMALLINT
            ,@totalgoal         SMALLMONEY
            ,@totalht           SMALLMONEY
        
    IF @IsSettleAbandonedMatch = 1
        SELECT @IsExcludeBetdaq = 1

    IF @IsSettleAbandonedMatchBetFair = 1
        SELECT @IsExcludeBetfair = 1    
	
	-- Select SDT value
	SELECT @SDTRecord = ISNULL(@IsSettleAbandonedMatch, 0) * 1 + ISNULL(@IsSettleAbandonedMatchBetFair,0) * 2 + ISNULL(@IsSettleAbandonedMatchIBC,0) * 4
	
    SELECT	@sporttype   	= m.SportType
			,@matchdate  	= eventdate
			,@matchcode		= matchcode
    FROM    DBPRO.BODB02.dbo.Match m  WITH (NOLOCK)
    WHERE    m.matchid = @matchid

	SELECT	@IsRefundHT = CASE WHEN SettlementStatusID = 2 THEN 1 ELSE 0 END
			,@IsHTCal = CASE WHEN ResultStatusID = 5 THEN 1 ELSE 0 END
    FROM	DBPRO.BODB02.dbo.ResultDetail WITH (NOLOCK)
    WHERE	matchid = @matchid
			AND ResourceId = '01'
    
    SELECT @SelectedQuarter = CASE WHEN @sporttype <> 2 THEN NULL ELSE @SelectedQuarter END
           ,@SelectedSet = CASE WHEN @sporttype <> 5 THEN NULL ELSE @SelectedSet END
    
    SELECT  @start 		= CURRENT_TIMESTAMP
			,@ActionID 	= CASE 
							WHEN  @action = 'CAL' 		THEN 109
							WHEN  @action = 'CAL-FT' 	THEN 111
							ELSE 0
						END
            ,@HomeValue = CAST(@fth AS VARCHAR(20))
            ,@HomeValue = CAST(@fta AS VARCHAR(20))
            ,@IsHedgeMatch = CASE WHEN @matchcode LIKE '%hedge%' AND @IsSettleAbandonedMatchIBC = 1 THEN 1 ELSE 0 END
			
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
        , @TennisSet		= @SelectedSet
        , @BAQuarter		= @SelectedQuarter
    
    -------------------------------------------------------------
    IF @Sporttype = 5 
    BEGIN
        IF @SelectedSet LIKE '%6%' 
        BEGIN
            SELECT @IsSettleDeterminedTicketTennis    = @IsSettleAbandonedMatch|@IsSettleAbandonedMatchBetFair
        END

        SELECT  @betCount_1324    =    ISNULL(SUM(CASE WHEN b.StatusID NOT IN (101, 102) THEN 1 ELSE 0 END),0)
                ,@MaxGameSet1    =   ISNULL(MAX(CASE WHEN LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '801%' THEN (b.betID - 80100) ELSE 0 END),0)  --  Tennis - Set x Game y Winner
                ,@MaxGameSet2    =   ISNULL(MAX(CASE WHEN LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '802%' THEN (b.betID - 80200) ELSE 0 END),0)
                ,@MaxGameSet3    =   ISNULL(MAX(CASE WHEN LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '803%' THEN (b.betID - 80300) ELSE 0 END),0)
                ,@MaxGameSet4    =   ISNULL(MAX(CASE WHEN LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '804%' THEN (b.betID - 80400) ELSE 0 END),0)
                ,@MaxGameSet5    =   ISNULL(MAX(CASE WHEN LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '805%' THEN (b.betID - 80500) ELSE 0 END),0)
        FROM    dbo.bettrans b WITH(NOLOCK)
        WHERE   bettype = 1324        --Set x Game y - Tennis 
                AND matchID = @MatchID 

        SELECT  @MaxGameSet1Parlay  =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '801%' THEN (CAST(bm.betcheck AS INT) - 80100) ELSE 0 END),0)  --  Tennis - Set x Game y Winner
                ,@MaxGameSet2Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '802%' THEN (CAST(bm.betcheck AS INT) - 80200) ELSE 0 END),0)
                ,@MaxGameSet3Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '803%' THEN (CAST(bm.betcheck AS INT) - 80300) ELSE 0 END),0)
                ,@MaxGameSet4Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '804%' THEN (CAST(bm.betcheck AS INT) - 80400) ELSE 0 END),0)
                ,@MaxGameSet5Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '805%' THEN (CAST(bm.betcheck AS INT) - 80500) ELSE 0 END),0)
        FROM    dbo.bettransm bm WITH(NOLOCK)
        WHERE   bettype = 1324        --Set x Game y - Tennis 
                AND matchID = @MatchID 

        SELECT  @MaxGameSet1    = CASE WHEN @MaxGameSet1 < @MaxGameSet1Parlay THEN @MaxGameSet1Parlay ELSE @MaxGameSet1 END 
                ,@MaxGameSet2     = CASE WHEN @MaxGameSet2 < @MaxGameSet2Parlay THEN @MaxGameSet2Parlay ELSE @MaxGameSet2 END
                ,@MaxGameSet3     = CASE WHEN @MaxGameSet3 < @MaxGameSet3Parlay THEN @MaxGameSet3Parlay ELSE @MaxGameSet3 END
                ,@MaxGameSet4     = CASE WHEN @MaxGameSet4 < @MaxGameSet4Parlay THEN @MaxGameSet4Parlay ELSE @MaxGameSet4 END
                ,@MaxGameSet5     = CASE WHEN @MaxGameSet5 < @MaxGameSet5Parlay THEN @MaxGameSet5Parlay ELSE @MaxGameSet5 END

        EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update 
            @Command                    = 'NAP_Admin_Settlement_Refund-All',
            @MatchID                    = @MatchID,
            @HomeValue                    = @HomeValue,
            @AwayValue                    = @AwayValue,
            @SetResult                    = @SetResult, 
            @GameResult1                = @GameResult1,
            @GameResult2                = @GameResult2,
            @GameResult3                = @GameResult3,
            @GameResult4                = @GameResult4,
            @GameResult5                = @GameResult5,
            @SelectedSet                = @SelectedSet,
            @SelectedSet1Game            = @SelectedSet1Game,
            @SelectedSet2Game            = @SelectedSet2Game,
            @SelectedSet3Game            = @SelectedSet3Game,
            @SelectedSet4Game            = @SelectedSet4Game,
            @SelectedSet5Game            = @SelectedSet5Game,
            @SelectedSettleFinishedGame = @SelectedSettleFinishedGame,
            @MaxGameSet1                = @MaxGameSet1,
            @MaxGameSet2                = @MaxGameSet2,
            @MaxGameSet3                = @MaxGameSet3,
            @MaxGameSet4                = @MaxGameSet4,
            @MaxGameSet5                = @MaxGameSet5,
            @action                     = @Action,
            @creator                    = @creator         
        
        IF @SelectedSettleFinishedGame IS NOT NULL 
        BEGIN
            EXEC dbo.NAP_Admin_Settlement_4 
                     @MatchID                = @MatchID
                    ,@SetxGameyHomeWON       = @SetxGameyHomeWON    OUTPUT
                    ,@SetxGameyAwayWON       = @SetxGameyAwayWON OUTPUT
                    ,@SetxGameyDRAW          = @SetxGameyDRAW    OUTPUT
                    ,@SetxGameyFinishedGame  = @SetxGameyFinishedGame OUTPUT 

            EXEC dbo.NAP_Admin_Calculate_Main 
                 @matchid                    = @matchid
                ,@action                     = 'REFUND'
                ,@mode                       = 'ABANDONED'
                ,@SelectedSet                = @SelectedSet
                ,@SelectedSettleFinishedGame = @SelectedSettleFinishedGame
                ,@SetxGameyHomeWON           = @SetxGameyHomeWON
                ,@SetxGameyAwayWON           = @SetxGameyAwayWON 
                ,@SetxGameyDRAW                 = @SetxGameyDRAW
                ,@SetxGameyFinishedGame         = @SetxGameyFinishedGame
                ,@betcount_1324                 = @betcount_1324 
        
        END 
    END    
	
	IF @sporttype = 1
	BEGIN
		SET @xmlResultDetail = CAST(@ResourceResult AS XML)
				
		INSERT INTO @ResourceResult_tmp (ResourceId,HomeValue)
		SELECT	T.c.value('./@Id','VARCHAR(20)') AS ResourceId
				,T.c.value('./@HomeValue','VARCHAR(50)') AS HomeValue
		FROM	@xmlResultDetail.nodes('/Results/Resource') AS T(c)
		OPTION ( OPTIMIZE FOR ( @xmlResultDetail = NULL ) )
	END
			
    IF @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1
    BEGIN            
        SELECT @ScoreLog = ' HTHScore=' + ISNULL(CAST(@hth AS VARCHAR(10)), '') 
                         + ' HTAScore=' + ISNULL(CAST(@hta AS VARCHAR(10)), '') 
                         + ' FTHScore=' + ISNULL(CAST(@fth AS VARCHAR(10)), '') 
                         + ' FTAScore=' + ISNULL(CAST(@fta AS VARCHAR(10)), '') 
                         + CASE 
                                WHEN @SportType IN (5, 6, 9, 30, 48) THEN ' Betstatus=Refund;' 
                                ELSE ' Betstatus='
                           END + ISNULL(@betstatus,'') + '<br/> ' 

                        + CASE WHEN @GoalSequence IS NULL THEN '' ELSE ' GoalSequence=' + @GoalSequence + '<br/> ' END  

        IF @SportType IN (6, 9, 30, 48) -- Tennis/VolleyBall/Badminton/Squash : get TotalGamesPlayed  -- Remove sporttype 5 
        BEGIN
            EXEC dbo.Admin_Settlement_2 
                @betstatus    = @betstatus
                ,@Total        = @TennisTotal    OUTPUT
                ,@TotalHome = @T_Home        OUTPUT
                ,@TotalAway = @T_Away        OUTPUT        
        END
		
        IF @Sporttype = 5 -- Tennis -- Total Games played 
        BEGIN
            EXEC dbo.NAP_Admin_Settlement_4 
                 @MatchID                           = @MatchID
                ,@SelectedSet                       = @SelectedSet
                ,@SetResult                         = @SetResult
                ,@IsSettleDeterminedTicketTennis    = @IsSettleDeterminedTicketTennis
                ,@TotalGameMatch                    = @TennisTotal    OUTPUT
                ,@TotalGameHomeMatch                = @T_Home        OUTPUT
                ,@TotalGameAwayMatch                = @T_Away        OUTPUT    

            SELECT @hth = ISNULL(@hth,0) 
                   ,@hta = ISNULL(@hta,0) 
        END 
        
        IF @sporttype = 1
        BEGIN
						
			SELECT	@ht_fg = ISNULL(MAX(CASE 
											WHEN ResourceID ='127F' 
												THEN CASE 
														WHEN HomeValue = 'N' THEN '0:0'
														WHEN HomeValue = 'H' THEN '1:1'
														WHEN HomeValue = 'A' THEN '2:1'
														ELSE ''
													END
												ELSE '' 
										END),'')		
					,@ht_lg = ISNULL(MAX(CASE 
											WHEN ResourceID ='127L' 
												THEN CASE 
														WHEN HomeValue = 'N' THEN '0:0'
														WHEN HomeValue = 'H' THEN '1:2'
														WHEN HomeValue = 'A' THEN '2:2'
														ELSE ''
													END
												ELSE '' 
										END),'')			
					
					,@ft_fg = ISNULL(MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END),'')
					,@ft_lg = ISNULL(MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END),'')
					,@goalsequenceHT = ISNULL(MAX(CASE WHEN ResourceId = '09' THEN HomeValue ELSE '' END),'')
					,@goalsequenceFT = ISNULL(MAX(CASE WHEN ResourceId = '08' THEN HomeValue ELSE '' END),'')
					
			FROM	@ResourceResult_tmp r
			
        END
        SELECT    @totalgoal        = CASE 
                                        WHEN @sporttype IN (5, 6, 9, 30, 48) AND @TennisTotal > 0 THEN @TennisTotal
                                        ELSE (@fth + @fta)
                                    END
                ,@totalht           = (@hth + @hta)
                ,@oddevenht         = (@hth + @hta) % 2
                ,@scorediff         = (@fth - @fta)

        IF @Action IN ('CAL', 'CAL-FT') AND @totalgoal IS NULL
        BEGIN
            SELECT    @ErrCode = 1001004
                    ,@ErrMsg = 'Cannot settle determined ticket(s) without FT Score!'

            ------ releasing Settlement process
            EXEC dbo.NAP_Admin_CheckingProcess
                @isExistMatch		= 1
                , @IsReleased		= 1

            RETURN
        END

        IF @Action IN ('CAL', 'CAL-HT') AND @totalht IS NULL
        BEGIN
            SELECT    @ErrCode = 1001005
                    ,@ErrMsg = 'Cannot settle determined ticket(s) without HT Score!'

            ------ releasing Settlement process
            EXEC dbo.NAP_Admin_CheckingProcess
                @isExistMatch		= 1
                , @IsReleased		= 1

            RETURN
        END
    END
    
    BEGIN TRY
		IF @sporttype = 1
		BEGIN
			-- check GoalBettype if all tickets have been voided
			INSERT INTO @GoalBettype_tmp (bettype, Voided_cnt,ticket_cnt)
			SELECT b.bettype
				, SUM(CASE WHEN statusID IN (101,102) THEN 1 ELSE 0 END) AS Voided_cnt
				, COUNT(1) AS ticket_cnt
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN dbo.f_Set_GetGroupBettypes() bt ON b.bettype = bt.BetType AND bt.IsUsedGoalRecordValue = 1
			WHERE b.matchid = @matchid 
			GROUP BY b.bettype
			
			DELETE g 
			FROM @GoalBettype_tmp g
				INNER JOIN SettlementSpecialBettypeProfile p WITH (NOLOCK) ON p.bettype = g.bettype
			WHERE g.Voided_cnt = g.ticket_cnt
				AND NOT EXISTS (SELECT 1 FROM @ResourceResult_tmp rs WHERE p.ResourceID = rs.ResourceId)
		END		
		--using this way to avoid more param @betcount
		;WITH cteBettypes
		AS
		(
			SELECT    f.BetType
			FROM    dbo.f_Set_GetGroupBettypes() f
				LEFT JOIN @GoalBettype_tmp gbt ON f.BetType = gbt.bettype
			WHERE    f.IsDetermined = 1 -- support to settle determined tickets
					AND 1 = CASE 
								WHEN @Action = 'CAL-FT' THEN -- FT, HTFT-FGLG
									CASE 
										WHEN @IsRefundHT = 1 AND f.GroupId IN (2,4) AND f.Is3x30 = 1 THEN 0
										ELSE 1
									END
								WHEN @Action = 'CAL-HT' THEN 0
								WHEN @Action = 'CAL' THEN
									CASE 
										WHEN @IsHedgeMatch = 1 AND f.Bettype IN (3,8) THEN 1 --just support bettype 3&8 for hedge match SDT
										WHEN @IsHedgeMatch = 0 THEN 1
										ELSE 0
									END
								ELSE 0
							END
					AND f.IsAuto = 0 --excluding auto bettype
					AND 1= CASE 
								WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NOT NULL THEN 1
								WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NULL THEN 0
								ELSE 1
							END	
							
		)
		SELECT @strSettledBettypes = COALESCE(@strSettledBettypes + ',' + CAST(b.bettype AS VARCHAR(10)), CAST(b.bettype AS VARCHAR(10))) 
		FROM
		(
			SELECT    bettype
			FROM    dbo.bettrans b WITH(NOLOCK)
			WHERE    matchid = @matchid
					AND statusID NOT IN (101)
					AND 1 = CASE WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
								 WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
								 WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
								 ELSE 0
							END
			GROUP BY b.bettype
		) AS b
		WHERE b.bettype IN (SELECT bettype FROM cteBettypes )
		GROUP BY b.bettype
        -- Settle tickets Abandoned Match of Soccer     
        IF (
			(@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1) 
			AND @sporttype = 1
		)
        BEGIN
					
			--just for IBC case
			SELECT @refundCommand = 'NAP_Admin_Settlement_Refund_All-Abandoned'
			WHERE @IsSettleAbandonedMatchIBC = 1
				
            IF @action = 'CAL-FT'
            BEGIN
				--just for IBC case
				SELECT @refundCommand_1s 			= 'NAP_Admin_Settlement_RefundFT-Abandoned'
				WHERE @IsSettleAbandonedMatchIBC 	= 1
			
				EXEC dbo.NAP_Admin_Calculate_Main 
                    @matchid                     	= @matchid
                    ,@action                        = 'REFUND'
                    ,@mode                          = 'ABANDONED-FT'
                    ,@fth                           = @fth
                    ,@fta                           = @fta
                    ,@hth                           = @hth
                    ,@hta                           = @hta
                    ,@totalgoal                     = @totalgoal
                    ,@totalht                       = @totalht
                    ,@scorediff                     = @scorediff
                    ,@oddevenht                     = @oddevenht
                    ,@GoalRecord                    = @GoalSequence 
					,@goalsequenceHT				= @goalsequenceHT
					,@goalsequenceFT				= @goalsequenceFT
                    ,@IsSettleAbandonedMatch        = @IsSettleAbandonedMatch
                    ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                    ,@IsSettleAbandonedMatchIBC     = @IsSettleAbandonedMatchIBC
                    ,@IsHTCal                       = @IsHTCal
                    ,@strBettypes                    = @strSettledBettypes
					
					-- including FGLG
					,@ft_fg 						= @ft_fg
					,@ft_lg 						= @ft_lg
					,@goaldiff 						= @goaldiff
					
            END
            IF @action = 'CAL'
            BEGIN
				--just for IBC case
				SELECT @refundCommand_1s 			= @refundCommand
				WHERE @IsSettleAbandonedMatchIBC 	= 1

				EXEC dbo.NAP_Admin_Calculate_Main 
                    @matchid                        = @matchid
                    ,@action                        = 'REFUND'
                    ,@mode                          = 'ABANDONED'--abandoned
                    ,@fth                           = @fth
                    ,@fta                           = @fta
                    ,@hth                           = @hth
                    ,@hta                           = @hta
                    ,@totalgoal                     = @totalgoal
                    ,@totalht                       = @totalht
                    ,@scorediff                     = @scorediff
                    ,@oddevenht                     = @oddevenht
                    ,@GoalRecord                    = @GoalSequence 
					,@goalsequenceHT				= @goalsequenceHT
					,@goalsequenceFT				= @goalsequenceFT
                    ,@IsSettleAbandonedMatch        = @IsSettleAbandonedMatch
                    ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                    ,@IsSettleAbandonedMatchIBC     = @IsSettleAbandonedMatchIBC                    
                    ,@IsHTCal                       = 0
                    ,@strBettypes                   = @strSettledBettypes
					
					-- including FGLG
					,@ht_fg 						= @ht_fg
					,@ht_lg 						= @ht_lg
					,@ft_fg 						= @ft_fg
					,@ft_lg 						= @ft_lg
					,@goaldiff 						= @goaldiff
            END
        END    
		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
            		@Command         = @refundCommand
            		,@MatchID        = @matchid
            		,@SelectedSet    = @SelectedSet
            		,@creator        = @creator
					,@BetStatus 	 = @betstatus
					,@GoalRecord	 = @GoalSequence 
					,@HTHome		 = @hth
					,@HTAway		 = @hta
					,@FTHome		 = @fth
					,@FTAway		 = @fta
					,@SelectedQuarter= @SelectedQuarter
					
        IF @sporttype = 2
		BEGIN			
			CREATE TABLE #tblResultDetail (QuarterX VARCHAR(50), ResourceId VARCHAR(50))
			INSERT INTO #tblResultDetail (QuarterX, ResourceId)
			SELECT CASE 
					WHEN f.GroupName = 'FT' THEN '00'
					WHEN f.GroupName = '1H' THEN '01'
					WHEN f.GroupName = '2H' THEN '02'
					WHEN f.GroupName = 'Special' THEN 'Q' + SUBSTRING(t.betid,3,1)
					ELSE NULL		
				END QuarterX
				,ResourceId
			FROM(
				SELECT	b.bettype
						,CAST(b.bettype AS VARCHAR(50)) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR),2,LEN(b.betid)),'') AS ResourceId						
						,CAST(b.betid AS VARCHAR(50)) AS betid
				FROM	dbo.bettrans b WITH(NOLOCK)
				WHERE	b.matchid = @matchid
				UNION ALL
				SELECT	bm.bettype
						,CAST(bm.bettype AS VARCHAR(50)) + ISNULL(SUBSTRING(bm.betcheck,2,LEN(bm.betcheck)),'') AS ResourceId						
						,bm.betcheck
				FROM	dbo.bettransm bm WITH(NOLOCK)
				WHERE	bm.matchid = @matchid
			) t
				INNER JOIN dbo.f_Set_GetGroupBettypes() f
					ON f.BetType = t.bettype
			WHERE	@SelectedQuarter LIKE '%' + CASE 
													WHEN f.GroupName = 'Special' THEN SUBSTRING(t.betid,1,3)
													ELSE f.GroupName
												END + '%'
					AND f.IsAuto = 0
			GROUP BY CASE 
					WHEN f.GroupName = 'FT' THEN '00'
					WHEN f.GroupName = '1H' THEN '01'
					WHEN f.GroupName = '2H' THEN '02'
					WHEN f.GroupName = 'Special' THEN 'Q' + SUBSTRING(t.betid,3,1)
					ELSE NULL		
				END 
				,t.ResourceId
			
			INSERT INTO #tblResultDetail(QuarterX)
				SELECT '00' WHERE @SelectedQuarter LIKE '%FT%'
				UNION ALL
				SELECT '01' WHERE @SelectedQuarter LIKE '%1H%'
				UNION ALL
				SELECT '02' WHERE @SelectedQuarter LIKE '%2H%'
				UNION ALL
				SELECT 'Q1' WHERE @SelectedQuarter LIKE '%801%'
				UNION ALL
				SELECT 'Q2' WHERE @SelectedQuarter LIKE '%802%'
				UNION ALL
				SELECT 'Q3' WHERE @SelectedQuarter LIKE '%803%'
				UNION ALL
				SELECT 'Q4' WHERE @SelectedQuarter LIKE '%804%'
				
			SELECT @QuarterResult = (
				SELECT ResourceId '@Id'
				FROM (
					SELECT QuarterX AS ResourceId
					FROM #tblResultDetail
					UNION ALL
					SELECT ResourceId
					FROM #tblResultDetail
				)t
				WHERE t.ResourceId IS NOT NULL
				GROUP BY t.ResourceId
				FOR XML PATH ('Resource'), ROOT('Results')
			)
			
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b
				@Command            = 'NAP_Admin_Settlement_Refund-All',
				@MatchID            = @MatchID,
				@creator            = @creator, 
				@SelectedQuarter    = @SelectedQuarter,
				@Results			= @QuarterResult
		END

		IF @sporttype = 1
		BEGIN
			EXEC DBPRO.BODB02.dbo.[NAP_Admin_Result_Update_1s] 
				@Command                = @refundCommand_1s
				,@MatchID               = @matchid
				,@creator               = @creator
				,@SDTRecord		= @SDTRecord
				,@fth			= @fth
				,@fta			= @fta
				,@hth			= @hth
				,@hta			= @hta
				--Refund HT then Refund FT SDT
				,@ResourceResult	= @ResourceResult
				,@Action        = @Action
		END
		
		SET @strRefundBettypes = CAST((SELECT  f.BetType '@t'
										,GroupId '@g'
										,GroupName '@n'
								FROM	dbo.f_Set_GetGroupBettypes() f
										LEFT JOIN @GoalBettype_tmp gbt ON f.BetType = gbt.bettype			  
								WHERE	f.IsAuto = 0
										AND 1= CASE 
											WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NOT NULL THEN 1
											WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NULL THEN 0
											ELSE 1
										END
								FOR XML PATH ('r'), ROOT('root'), TYPE
						) AS VARCHAR(MAX))
        
		EXEC dbo.NAP_Admin_Calculate_Main 
            @matchid                    = @matchid
            ,@action                    = 'REFUND'
            ,@mode                      = 'REFUND'
            ,@IsExcludeBetdaq           = @IsExcludeBetdaq
            ,@IsExcludeBetfair          = @IsExcludeBetfair
            ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
            ,@SelectedSet               = @SelectedSet
            ,@SelectedSettleFinishedGame= @SelectedSettleFinishedGame
            ,@SetxGameyFinishedGame     = @SetxGameyFinishedGame
            ,@strBettypes               = @strRefundBettypes
			,@matchdate					= @matchdate
			,@SelectedQuarter			= @SelectedQuarter
		
         -- Calculate charged commission of Cricket
        EXEC dbo.NAP_Admin_Calculate_500
            @MatchId = @matchId
            ,@Action = 'REFUND'
            
        -- BetTrade Winlost Sharing
        IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 901 AND 910)
            EXEC dbo.NAP_Admin_Calculate_904
                @MatchId = @matchid
                ,@Action = 'REFUND'
				
		-- CashOut Winlost Sharing
        IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 911 AND 920)
		BEGIN
            EXEC dbo.NAP_Admin_Calculate_914
                @MatchId = @matchid
                ,@Action = 'REFUND'
		END
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
            , @TennisSet		= @SelectedSet
            , @BAQuarter		= @SelectedQuarter
        
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
        , @TennisSet		= @SelectedSet
        , @BAQuarter		= @SelectedQuarter
    
    -- Compare and update pending balance with error case
    EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
        @BalanceWalletBefore	= @BalanceWalletBefore
        , @BalanceWalletAfter	= @BalanceWalletAfter
        , @ActionId				= @ActionID

    --  Betfair & Betdaq - Warning message:
    SELECT    @movebet = convert(VARCHAR(20), DATEADD(d, 1, m.kickofftime), 100),
            @matchcode    = m.matchcode
    FROM    DBPRO.bodb02.dbo.match m WITH (NOLOCK)
    WHERE    m.matchid = @matchid

    IF @matchcode not like '%Hedge%'
    BEGIN 
        IF (@IsExcludeBetdaq = 1 OR @IsSettleAbandonedMatch = 1) AND (@IsExcludeBetfair = 1 OR @IsSettleAbandonedMatchBetFair = 1)
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg    = 'Please move Betdaq and Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
        ELSE IF (@IsExcludeBetdaq = 1 OR @IsSettleAbandonedMatch = 1)
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg    = 'Please move Betdaq tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
        ELSE IF (@IsExcludeBetfair = 1 OR @IsSettleAbandonedMatchBetFair = 1)
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg    = 'Please move Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
    END 
    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------
    
    SELECT @stop = CURRENT_TIMESTAMP

    DECLARE @LogData NVARCHAR(300)

    SELECT @LogData = 'NAP: Calculate (Refund All) for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                                 + CASE WHEN @IsExcludeBetdaq = 1                THEN ', Exclude Betdaq tickets'                ELSE '' END 
                                                                 + CASE WHEN @IsSettleAbandonedMatch = 1        THEN ', Settle determined betdaq tickets'    ELSE '' END 
                                                                 + CASE WHEN @IsExcludeBetfair = 1                THEN ', Exclude Betfair tickets'            ELSE '' END 
                                                                 + CASE WHEN @IsSettleAbandonedMatchBetFair = 1 THEN ', Settle determined betfair tickets'    ELSE '' END
                                                                 + CASE WHEN @IsSettleAbandonedMatchIBC = 1        THEN ', Settle determined IBC tickets'        ELSE '' END
                                                                 + CASE WHEN (@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair =1 OR @IsSettleAbandonedMatchIBC = 1) THEN @ScoreLog ELSE '' END 
                                                                + CASE WHEN @SelectedSet IS NULL THEN '' ELSE ' Set=' + @SelectedSet + ' ' END  
                                                                + CASE WHEN @SetResult IS NULL THEN '' ELSE ' SR=' + @SetResult + ' ' END 
                                                                + CASE WHEN @SelectedSettleFinishedGame IS NULL THEN '' ELSE ' SetFG=' + @SelectedSettleFinishedGame + ' ' END  
                                                                + CASE    WHEN @SelectedSet1Game IS NULL THEN '' ELSE ' S1Game=' + @SelectedSet1Game + ' ' END  
                                                                + CASE    WHEN @GameResult1 IS NULL THEN '' ELSE ' S1GR=' + @GameResult1 + ' ' END  
                                                                + CASE    WHEN @SelectedSet2Game IS NULL THEN '' ELSE ' S2Game=' + @SelectedSet2Game + ' ' END  
                                                                + CASE    WHEN @GameResult2 IS NULL THEN '' ELSE ' S2GR:' + @GameResult2 + ' ' END  
                                                                + CASE    WHEN @SelectedSet3Game IS NULL THEN '' ELSE ' S3Game=' + @SelectedSet3Game + ' ' END  
                                                                + CASE    WHEN @GameResult3 IS NULL THEN '' ELSE ' S3GR=' + @GameResult3 + ' ' END  
                                                                + CASE    WHEN @SelectedSet4Game IS NULL THEN '' ELSE ' S4Game=' + @SelectedSet4Game + ' ' END  
                                                                + CASE    WHEN @GameResult4 IS NULL THEN '' ELSE ' S4GR=' + @GameResult4 + ' ' END  
                                                                + CASE    WHEN @SelectedSet5Game IS NULL THEN '' ELSE ' S5Game=' + @SelectedSet5Game + ' ' END  
                                                                + CASE    WHEN @GameResult5 IS NULL THEN '' ELSE ' S5GR=' + @GameResult5 + ' ' END  
                                                                + CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE 'SelectedQuarter:' + @SelectedQuarter + '<br/> ' END

    EXEC dbo.WriteLog_UserLog 
        @UserID = @creator
        ,@Doing =  @LogData

    --Write Log Settle
    SELECT @Remark = 'NAP: ExcludeBetdaqTickets='            + convert(char(1),@IsExcludeBetdaq) 
                    + ' SettleDeterminedBetdaqTickets='        + convert(char(1),@IsSettleAbandonedMatch)
                    + ' ExcludeBetfairTickets='                + convert(char(1),@IsExcludeBetfair) 
                    + ' SettleDeterminedBetfairTickets='    + convert(char(1),@IsSettleAbandonedMatchBetFair)
                    + ' SettleDeterminedIBCTickets='        + convert(char(1),@IsSettleAbandonedMatchIBC)
                    + CASE WHEN (@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair =1 OR @IsSettleAbandonedMatchIBC = 1) THEN @ScoreLog ELSE '' END 
                    + CASE WHEN @SelectedSet IS NULL THEN '' ELSE ' Set=' + @SelectedSet + '<br/> ' END  
                    + CASE WHEN @SetResult IS NULL THEN '' ELSE ' SR=' + @SetResult + '<br/> ' END 
                    + CASE WHEN @SelectedSettleFinishedGame IS NULL THEN '' ELSE ' SetFG=' + @SelectedSettleFinishedGame + '<br/> ' END  
                    + CASE    WHEN @SelectedSet1Game IS NULL THEN '' ELSE ' S1Game=' + @SelectedSet1Game + '<br/> ' END  
                    + CASE    WHEN @GameResult1 IS NULL THEN '' ELSE ' S1GR=' + @GameResult1 + '<br/> ' END  
                    + CASE    WHEN @SelectedSet2Game IS NULL THEN '' ELSE ' S2Game=' + @SelectedSet2Game + '<br/> ' END  
                    + CASE    WHEN @GameResult2 IS NULL THEN '' ELSE ' S2GR=' + @GameResult2 + '<br/> ' END  
                    + CASE    WHEN @SelectedSet3Game IS NULL THEN '' ELSE ' S3Game=' + @SelectedSet3Game + '<br/> ' END  
                    + CASE    WHEN @GameResult3 IS NULL THEN '' ELSE ' S3GR=' + @GameResult3 + '<br/> ' END  
                    + CASE    WHEN @SelectedSet4Game IS NULL THEN '' ELSE ' S4Game=' + @SelectedSet4Game + '<br/> ' END  
                    + CASE    WHEN @GameResult4 IS NULL THEN '' ELSE ' S4GR=' + @GameResult4 + '<br/> ' END  
                    + CASE    WHEN @SelectedSet5Game IS NULL THEN '' ELSE ' S5Game=' + @SelectedSet5Game + '<br/> ' END  
                    + CASE    WHEN @GameResult5 IS NULL THEN '' ELSE ' S5GR=' + @GameResult5 + '<br/> ' END  
                    + CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE 'SelectedQuarter:' + @SelectedQuarter + '<br/> ' END
                    + ' Action=' + @Action
                    + ' Duration=' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms;'

    SELECT  @BetstatusLOG = CASE 
				WHEN @SelectedSet IS NULL THEN 
					CASE 
						WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL' THEN 'Abandoned 1H' 
						ELSE 'Refund' 
					END
				ELSE '' 
			END  -- Set '' for Tennis Refund 
	
	SELECT @hth = CASE 
					WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL' THEN @hth
					WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL-FT' THEN 0
					ELSE  NULL
				END
		, @hta = CASE 
					WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL' THEN @hta
					WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL-FT' THEN 0
					ELSE  NULL
				END
		, @fth = CASE 
					WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL-FT' THEN @fth
					ELSE  NULL
				END
		, @fta = CASE 
					WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL-FT' THEN @fta
					ELSE  NULL
				END
				
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
            ,@betstatus          = @BetstatusLOG
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
            ,@betstatus          = @BetstatusLOG
            ,@Remark             = @Remark
            ,@IP                 = @IP
    END CATCH

    ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess

    IF @IsNested = 0
    BEGIN
        -- Update match_remark
        EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
            @matchid       = @matchid
            ,@command      = 'F'
            ,@SelectedSet  = @SelectedSet
            ,@SelectedQuarter = @SelectedQuarter
        
        -- Write log
        SET @log = 'NAP: Refund for matchid: ' + CONVERT(VARCHAR(10), @matchid)

        EXEC dbo.WriteLog_UserLog 
            @UserID = @creator
            ,@Doing = @Log
    END
END
GO
