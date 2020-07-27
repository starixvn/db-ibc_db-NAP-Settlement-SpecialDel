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
		- 20191223@Max: Instant Calculation for Corner Bet Types - Update result for Refund [Redmine:#124951]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
    
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
            ,@HomeValue                         VARCHAR(20)
            ,@AwayValue                         VARCHAR(20)
            ,@BetstatusLOG                      VARCHAR(50)        = ''
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
			-- for corner bettype 
			,@ChildMatchType		TINYINT
			,@CornerResultString	NVARCHAR(MAX)
			,@Char					VARCHAR(1)
			,@Position				TINYINT
			,@HomeRaceTo			TINYINT
			,@AwayRaceTo			TINYINT
			,@LenResultString		TINYINT
			,@hdp					VARCHAR(5) = ''
			,@Index_Round_tmp		TINYINT = 0
			,@Index_Round			TINYINT = 1
			,@ResourceResult_Corner_Result	VARCHAR(MAX) = NULL
	
	DECLARE @ResourceResult_tmp AS TABLE (ResourceId VARCHAR(20),HomeValue VARCHAR(50))		
	DECLARE @GoalBettype_tmp AS TABLE (bettype INT, Voided_cnt INT, ticket_cnt INT)

	DECLARE @ListBettype_tmp AS TABLE (bettype SMALLINT, hdp1 SMALLMONEY)
	
	DECLARE @ResultDetail_Corner AS TABLE (hdp INT, ResourceID VARCHAR(20), HomeValue VARCHAR(10),Index_Round TINYINT)
	DECLARE @ResultDetail_Corner_tmp AS TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(10))
	DECLARE @ResultDetail_Corner_ticket AS TABLE (ResourceID VARCHAR(20))
	
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
			,@ChildMatchType = m.ChildMatchType
    FROM    DBPRO.BODB02.dbo.Match m  WITH (NOLOCK)
    WHERE    m.matchid = @matchid

	SELECT	@IsRefundHT = CASE WHEN SettlementStatusID = 2 THEN 1 ELSE 0 END
			,@IsHTCal = CASE WHEN ResultStatusID = 5 THEN 1 ELSE 0 END
    FROM	DBPRO.BODB02.dbo.ResultDetail WITH (NOLOCK)
    WHERE	matchid = @matchid
			AND ResourceId = '01'
    
    SELECT @SelectedQuarter = CASE WHEN @sporttype <> 2 THEN NULL ELSE @SelectedQuarter END
    
    SELECT  @start 		= CURRENT_TIMESTAMP
			,@ActionID 	= CASE 
							WHEN  @action = 'CAL' 		THEN 109
							WHEN  @action = 'CAL-FT' 	THEN 111
							ELSE 0
						END
            ,@HomeValue = CAST(@fth AS VARCHAR(20))
            ,@HomeValue = CAST(@fta AS VARCHAR(20))
            ,@IsHedgeMatch = CASE WHEN @matchcode LIKE '%hedge%' AND @IsSettleAbandonedMatchIBC = 1 THEN 1 ELSE 0 END
			
	IF @sporttype = 1
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= 'REFUND'
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
	
	-- check marked ticket
	IF @sporttype = 2
	BEGIN
		EXEC dbo.NAP_Set_EarlySettlement_CheckingMarkedTransaction
			@MatchID = @MatchID
			,@ResourceIds = @SelectedQuarter
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END
	ELSE
	BEGIN
		EXEC dbo.NAP_Set_CheckingMarkedTransaction
				@MatchID  = @matchid
				,@Action  = 'REFUND'
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg  = @ErrMsg	OUTPUT
	END 

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
        , @BAQuarter		= @SelectedQuarter
    
    -------------------------------------------------------------	
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
                                        WHEN @sporttype IN (6, 9, 30, 48) AND @TennisTotal > 0 THEN @TennisTotal
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

		INSERT INTO @ListBettype_tmp (bettype,hdp1)
		SELECT bettype,hdp1  
		FROM (
				SELECT    bettype, hdp1
				FROM    dbo.bettrans b WITH(NOLOCK)
				WHERE    matchid = @matchid
						AND statusID NOT IN (101)
						AND 1 = CASE WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
									 WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
									 WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
									 ELSE 0
								END
				GROUP BY b.bettype, hdp1
			) AS b 
		WHERE b.bettype IN (SELECT bettype	FROM cteBettypes )
		GROUP BY b.bettype,hdp1


		SELECT @strSettledBettypes = COALESCE(@strSettledBettypes + ',' + CAST(bettype AS VARCHAR(10)), CAST(bettype AS VARCHAR(10))) 
		FROM (SELECT DISTINCT bettype FROM @ListBettype_tmp) AS tmp
		
		IF (
			(@IsSettleAbandonedMatch = 0 AND @IsSettleAbandonedMatchBetFair = 0 AND @IsSettleAbandonedMatchIBC = 0) 
			AND @sporttype = 1
		)
		BEGIN
			IF @Sporttype = 1 AND @ChildMatchType = 204
			BEGIN
				SELECT @ResourceResult_Corner_Result = (
														SELECT DISTINCT 
															CASE 
																WHEN b.bettype IN (486,487) THEN CAST(b.bettype AS VARCHAR) 
																			+ CASE 
																				WHEN b.hdp1 < 10 THEN '0' + CAST(CONVERT(INT, hdp1) AS VARCHAR) 
																				ELSE CAST(CONVERT(INT,hdp1) AS VARCHAR) 
																			END
																ELSE CAST(b.bettype AS VARCHAR) 
															END AS Id
															, '' AS HomeValue
															, 1 AS SettlementStatusId
															, 5 AS ResultStatusId
														FROM bettrans b WITH (NOLOCK)
															INNER JOIN @GoalBettype_tmp gbt ON b.betType = gbt.bettype 
														WHERE b.matchid= @matchid
															and b.bettype IN(486,487,488,489,490)
														FOR XML RAW ('Resource'), ROOT ('Results')
														)

				SELECT @ResourceResult = @ResourceResult + @ResourceResult_Corner_Result
			END
		END

        -- Settle tickets Abandoned Match of Soccer     
        IF (
			(@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1) 
			AND @sporttype = 1
		)
        BEGIN

			IF @Sporttype = 1 AND @ChildMatchType = 204
			BEGIN
				IF EXISTS (SELECT TOP (1) 1 FROM @ListBettype_tmp WHERE bettype IN (486,487))
				BEGIN
					SELECT @CornerResultString = ISNULL(@GoalSequence, '')
						,@Position = 1
						,@HomeRaceTo = 0
						,@AwayRaceTo = 0
				
					SELECT @LenResultString = LEN(@CornerResultString)

					SET @Index_Round_tmp =  CASE WHEN CHARINDEX(';',@GoalSequence) = 0 THEN LEN(@GoalSequence) + 1 ELSE CHARINDEX(';',@GoalSequence) END

					WHILE (@Position <= @LenResultString)
					BEGIN
						SET @Char = SUBSTRING(@CornerResultString, @Position, 1)
				
						IF @Char = 'H'	
						BEGIN
							SET @HomeRaceTo = @HomeRaceTo + 1

							IF @HomeRaceTo > @AwayRaceTo
							BEGIN
								IF @HomeRaceTo < 10  
									SET @hdp = '0' + CAST(@HomeRaceTo AS VARCHAR(5))
								ELSE 
									SET @hdp = CAST(@HomeRaceTo AS VARCHAR(5))
						
								IF @Position <= @Index_Round_tmp
									SET @Index_Round = 1
								ELSE 
									SET @Index_Round = 2
								 
								INSERT INTO @ResultDetail_Corner (HDP, ResourceID, HomeValue,Index_Round)
								VALUES (@HomeRaceTo,CAST(@hdp AS VARCHAR), @Char,@Index_Round )
						
							END	
						END
						ELSE IF @Char = 'A' 
						BEGIN
							SET @AwayRaceTo = @AwayRaceTo + 1
							IF @AwayRaceTo > @HomeRaceTo
							BEGIN
								IF @AwayRaceTo < 10  
									SET @hdp = '0' + CAST(@AwayRaceTo AS VARCHAR(5))
								ELSE 
									SET @hdp = CAST(@AwayRaceTo AS VARCHAR(5))
						
								IF @Position <= @Index_Round_tmp
									SET @Index_Round = 1
								ELSE 
									SET @Index_Round = 2
								
								INSERT INTO @ResultDetail_Corner (HDP,ResourceID, HomeValue, Index_Round)
								VALUES (@AwayRaceTo,CAST(@hdp AS VARCHAR), @Char,@Index_Round)

							END
						END
				
						SET @Position = @Position + 1	 	
					END

					;WITH cteBettype
					AS
					(
						SELECT DISTINCT bettype
						FROM @ListBettype_tmp
						WHERE bettype IN (486,487)
					)
					INSERT INTO @ResultDetail_Corner_tmp (ResourceID,HomeValue)
					SELECT ResourceID 
						,HomeValue
					FROM cteBettype AS cte
						CROSS APPLY (
									SELECT (CAST(cte.bettype AS VARCHAR) + ResourceID) AS ResourceID
										, HomeValue
									FROM @ResultDetail_Corner
									WHERE 1 = CASE 
													WHEN cte.bettype = 487 AND Index_Round = 1 THEN 1
													WHEN cte.bettype = 487 AND Index_Round = 2 THEN 0
													ELSE 1
												END	
							
									) AS Result
									
				END
		
				IF EXISTS (SELECT TOP (1) 1 FROM @ListBettype_tmp WHERE bettype IN (488,489,490))
				BEGIN
					;WITH cteBettype
					AS
					(
						SELECT DISTINCT bettype
						FROM @ListBettype_tmp
						WHERE bettype IN (488,489,490)
					)
					INSERT INTO @ResultDetail_Corner_tmp (ResourceID,HomeValue)
					SELECT cte.bettype AS ResourceID
						, CASE 
								WHEN bettype = 490 AND CHARINDEX(';', @GoalSequence) > 0 THEN SUBSTRING(@GoalSequence,CHARINDEX(';', @GoalSequence) + 1, 1)
								ELSE LEFT (@GoalSequence, 1)
							END	 AS HomeValue
					FROM cteBettype cte		
				END

				INSERT INTO @ResultDetail_Corner_ticket (ResourceID)
					SELECT DISTINCT 
						CASE 
							WHEN bettype IN (486,487) THEN CAST(bettype AS VARCHAR) 
															+ CASE 
																WHEN hdp1 < 10 THEN '0' + CAST(hdp1 AS VARCHAR) 
																ELSE CAST(hdp1 AS VARCHAR) 
															END 
							ELSE CAST(bettype AS VARCHAR) 
						END AS ResourceID
					FROM (SELECT DISTINCT bettype, CASE WHEN bettype IN (486, 487) THEN CONVERT(INT, hdp1) 
														ELSE 0 END AS hdp1
							FROM @ListBettype_tmp 
							WHERE bettype IN (486,487,488,489,490) 
						)AS t
			
					SET @ResourceResult_Corner_Result = ''
					SELECT @ResourceResult_Corner_Result = (
															SELECT DISTINCT c1.ResourceID AS Id
																, CASE 
																	WHEN c1.ResourceID = '490' THEN ''
																	WHEN c2.HomeValue IS NULL THEN 'N'
																	WHEN c2.HomeValue IN (';','') THEN 'N' 
																	ELSE c2.HomeValue
																	END AS HomeValue
																, 5 AS SettlementStatusId
																, 5 AS ResultStatusId
															FROM @ResultDetail_Corner_ticket  c1
																LEFT JOIN @ResultDetail_Corner_tmp c2 ON c1.ResourceID = c2.ResourceID
															FOR XML RAW ('Resource'), ROOT ('Results')
															)

				IF @ResourceResult_Corner_Result IS NOT NULL
				BEGIN	
					SELECT @ResourceResult = @ResourceResult + @ResourceResult_Corner_Result
				END			
			
			END
					
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
                    + CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE 'SelectedQuarter:' + @SelectedQuarter + '<br/> ' END
                    + ' Action=' + @Action
                    + ' Duration=' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms;'

    SELECT  @BetstatusLOG =CASE 
								WHEN @IsSettleAbandonedMatchIBC = 1 AND @action = 'CAL' THEN 'Abandoned 1H' 
								ELSE 'Refund' 
							END
				
	
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
            ,@SelectedQuarter = @SelectedQuarter
        
        -- Write log
        SET @log = 'NAP: Refund for matchid: ' + CONVERT(VARCHAR(10), @matchid)

        EXEC dbo.WriteLog_UserLog 
            @UserID = @creator
            ,@Doing = @Log
    END
END
GO
