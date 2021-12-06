/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_RefundFT] 
    @matchid							INT
    ,@adminid							INT
    ,@IsExcludeBetdaq					BIT				= 0
    ,@IsSettleAbandonedMatch			BIT				= 0
    ,@IsExcludeBetfair					BIT				= 0
    ,@IsSettleAbandonedMatchBetFair		BIT				= 0
    ,@IsSettleAbandonedMatchIBC			BIT				= 0
    ,@fth								INT				= NULL
    ,@fta								INT				= NULL
    ,@GoalSequence						VARCHAR(50)     = NULL 
    ,@betstatus							NVARCHAR(50)    = NULL
    ,@ResourceResult					VARCHAR(MAX)	= NULL
    
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
			,@HTDone				BIT
			,@FTDone				BIT			
            ,@ScoreLog				VARCHAR(100)
			,@sporttype     		SMALLINT
			,@hth           		INT
			,@hta           		INT 
			,@IsHTCal       		BIT
			,@IsRefundHT    		BIT
			,@oddevenht     		SMALLMONEY
			,@scorediff     		SMALLMONEY
			,@RowCount				INT
			,@movebet				VARCHAR(20)
			,@matchcode				nvarchar(50)
			,@strSettledBettypes	VARCHAR(MAX) 
			,@strRefundBettypes		VARCHAR(MAX)
			,@strAutoBettypes		VARCHAR(MAX)
			,@strHTBettypes			VARCHAR(MAX)
			,@refundCommand			VARCHAR(100)
			,@SDTRecord				TINYINT
			,@matchdate				DATETIME
			,@ht_fg					VARCHAR(10)
			,@ht_lg					VARCHAR(10)
			,@ft_fg					VARCHAR(10)
			,@ft_lg					VARCHAR(10)
			,@strResultDetail		VARCHAR(MAX)
            ,@xmlResultDetail		XML
            
            ,@avaiableProcess		BIT
			
			,@TennisTotal			SMALLINT
            ,@T_Home         		SMALLINT
            ,@T_Away         		SMALLINT
            ,@totalgoal      		SMALLMONEY
            ,@totalgoal_2H   		SMALLMONEY

			,@Action				VARCHAR(20)
			,@goalsequenceHT		VARCHAR(50)
			,@goalsequenceFT		VARCHAR(50)
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
	
	DECLARE @status TABLE (FTBet BIT, BetCount INT, InRunning INT)	
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
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	SELECT	@start    = CURRENT_TIMESTAMP
			,@ActionID  	= 111
			,@Action		= 'CAL-FT'
			,@SDTRecord = ISNULL(@IsSettleAbandonedMatch, 0) * 1 + ISNULL(@IsSettleAbandonedMatchBetFair,0) * 2 + ISNULL(@IsSettleAbandonedMatchIBC,0) * 4 -- Select SDT value
			,@refundCommand = 'NAP_Admin_Settlement_Refund-FT'
			,@IsRefundHT = 0
			,@IsHTCal = 0
	
	SELECT	@sporttype   = SportType
			,@hth        = hthomescore
			,@hta        = htawayscore
			,@matchdate	 = eventdate
			,@ChildMatchType = ChildMatchType
    FROM	DBPRO.BODB02.dbo.Match WITH (NOLOCK)
    WHERE	matchid = @matchid

	SELECT	@IsRefundHT = CASE WHEN SettlementStatusID = 2 THEN 1 ELSE 0 END
			,@IsHTCal = CASE WHEN ResultStatusID = 5 THEN 1 ELSE 0 END
    FROM	DBPRO.BODB02.dbo.ResultDetail WITH (NOLOCK)
    WHERE	matchid = @matchid
			AND ResourceId = '01'
	    
	IF @IsSettleAbandonedMatch = 1
        SELECT @IsExcludeBetdaq = 1

    IF @IsSettleAbandonedMatchBetFair = 1
        SELECT @IsExcludeBetfair = 1
        
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

	IF @sporttype = 1
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= 'REFUND-FT'
			,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END
			
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

	SELECT 	@strAutoBettypes = COALESCE(@strAutoBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM	dbo.f_Set_GetGroupBettypes() f 
	WHERE  	f.IsAuto = 1

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
		, @IsRefundHT		= @IsRefundHT

	SELECT 	@strHTBettypes = COALESCE(@strHTBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM	dbo.f_Set_GetGroupBettypes() f 
	WHERE  	f.GroupId IN (1,3)

	INSERT INTO @status (FTBet, BetCount, InRunning)
	SELECT	CASE 
				WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0
				ELSE 1
			END FTBet
			,SUM(CASE 
					WHEN statusID IN (101, 102) THEN 0
					ELSE 1
				END) AS BetCount
			,SUM(CASE
					WHEN statusID = 0 THEN 1
					ELSE 0
					END) AS IsRunning
	FROM	dbo.bettrans b WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238, 38) -- Outright, VSRacing, Betbuilder
			AND b.bettype NOT BETWEEN 1301 AND 1334 -- exclude sporting solution product
			AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
			AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
			AND b.bettype NOT BETWEEN 901 AND 920 --BT & CashOut 
			AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
			
	GROUP BY CASE 
				WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0
				ELSE 1
			END

    IF NOT EXISTS (SELECT * FROM @status WHERE FTBet = 0)
        INSERT INTO @status VALUES (0, 0, 0)

    IF NOT EXISTS (SELECT *    FROM @status WHERE FTBet = 1)
        INSERT INTO @status VALUES (1, 0, 0)

    SELECT @HTDone = CASE InRunning
                        WHEN 0 THEN 1
                        ELSE 0
						END
    FROM	@status
    WHERE	FTBet = 0

    SELECT	@FTDone = CASE InRunning
                        WHEN 0 THEN 1
                        ELSE 0
						END
    FROM	@status
    WHERE	FTBet = 1

    ---===============================================
    --Check if match already Refund HT => refund whole match
    IF @IsRefundHT = 1 AND @HTDone = 1
    BEGIN  
		------ releasing Settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			, @IsReleased		= 1

		EXEC dbo.NAP_Admin_Settlement_Refund_All 
            @matchid							= @matchid
            ,@creator							= @adminid
            ,@IsExcludeBetdaq					= @IsExcludeBetdaq
            ,@IsSettleAbandonedMatch			= @IsSettleAbandonedMatch
            ,@IsExcludeBetfair					= @IsExcludeBetfair
            ,@IsSettleAbandonedMatchBetFair		= @IsSettleAbandonedMatchBetFair
            ,@IsSettleAbandonedMatchIBC			= @IsSettleAbandonedMatchIBC
            ,@hth                             	= NULL
            ,@hta                             	= NULL
            ,@fth                             	= @fth
            ,@fta                             	= @fta
            ,@GoalSequence                    	= @GoalSequence        
            ,@betstatus                        	= @betstatus          
            ,@Action                        	= 'CAL-FT'
			,@ResourceResult					= @ResourceResult
            ,@IP                            	= @IP
            ,@ErrCode							= @ErrCode OUTPUT
            ,@ErrMsg							= @ErrMsg OUTPUT

        RETURN
    END
	
	IF @sporttype = 1
	BEGIN
			SET @xmlResultDetail = CAST(@ResourceResult AS XML)
			
			INSERT INTO @ResourceResult_tmp (ResourceId, HomeValue)
			SELECT	T.c.value('./@Id','VARCHAR(20)') AS ResourceId
					,T.c.value('./@HomeValue','VARCHAR(50)') AS HomeValue
			FROM	@xmlResultDetail.nodes('/Results/Resource') AS T(c)
			OPTION ( OPTIMIZE FOR ( @xmlResultDetail = NULL ) )		
	END			
    /*  Settle Abandoned Match for Over/Under */      
    IF (@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1) AND @HTDone = 1
    BEGIN			
        SELECT @ScoreLog = ' FTHScore=' + CAST(@fth AS VARCHAR(10)) 
                         + ' FTAScore=' + CAST(@fta AS VARCHAR(10)) 
                         + ' BetStatus=' + ISNULL(@betstatus,'')
                         + CASE WHEN @GoalSequence IS NULL THEN '' ELSE ' GoalSequence=' + @GoalSequence + '<br/> ' END  
                        
        IF @SportType IN (5, 6, 9, 30, 48) -- Tennis/VolleyBall/Badminton/Squash/Sepak Takraw : get TotalGamesPlayed
            EXEC dbo.Admin_Settlement_2 
                @betstatus  = @betstatus
                ,@Total     = @TennisTotal   OUTPUT
                ,@TotalHome = @T_Home        OUTPUT
                ,@TotalAway = @T_Away        OUTPUT
		
		IF @sporttype = 1
		BEGIN
			SELECT	
					-- for bettype 14,448
					@ft_fg = ISNULL(MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END),'')
					, @ft_lg = ISNULL(MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END),'')					
					,@goalsequenceHT = ISNULL(MAX(CASE WHEN ResourceId = '09' THEN HomeValue ELSE '' END),'')
					,@goalsequenceFT = ISNULL(MAX(CASE WHEN ResourceId = '08' THEN HomeValue ELSE '' END),'')
			FROM	@ResourceResult_tmp r
			
		END
        SELECT	@totalgoal    	= CASE 
									WHEN @sporttype IN (5, 6, 9, 30, 48) AND @TennisTotal > 0 THEN @TennisTotal
									ELSE (@fth + @fta)
								END
				,@oddevenht    	= (@hth + @hta) % 2
				,@scorediff    	= (@fth - @fta)
				,@totalgoal_2H 	= (@fth + @fta) - (@hth + @hta)
		
		
        IF @totalgoal IS NULL
        BEGIN
            SELECT	@ErrCode = 1000004
					,@ErrMsg    = 'Cannot settle determined ticket(s) without FT Score!'

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
		AS(
			SELECT  f.BetType
			FROM	dbo.f_Set_GetGroupBettypes() f
					LEFT JOIN @GoalBettype_tmp gbt ON f.BetType = gbt.bettype
			WHERE	f.GroupId IN (2,4) -- FT bettypes, FT FGLG
					AND IsDetermined = 1 -- support to settle determined tickets
					AND 1 = CASE 
								WHEN @IsRefundHT = 1 AND Is3x30 = 1 THEN 0 
								ELSE 1 
							END
					AND 1= CASE 
								WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NOT NULL THEN 1
								WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NULL THEN 0
								ELSE 1
							END		
		)

		INSERT INTO @ListBettype_tmp (bettype,hdp1)
		SELECT bettype,hdp1  
		FROM (
				SELECT	b.bettype, hdp1
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	matchid = @matchid
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


		--SELECT @strSettledBettypes = COALESCE(@strSettledBettypes + ',' + CAST(b.bettype AS VARCHAR(10)), CAST(b.bettype AS VARCHAR(10))) 
		--FROM
		--(
		--	SELECT	b.bettype
		--	FROM	dbo.bettrans b WITH(NOLOCK)
		--	WHERE	matchid = @matchid
		--			AND statusID NOT IN (101)
		--			AND 1 = CASE WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
		--						 WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
		--						 WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
		--						 ELSE 0
		--					END
		--	GROUP BY b.bettype
			
		--) AS b
		--WHERE b.bettype IN (SELECT bettype FROM cteBettypes)
		--GROUP BY b.bettype

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
															, 3 AS SettlementStatusId
															, 5 AS ResultStatusId
														FROM bettrans b WITH (NOLOCK)
															INNER JOIN @GoalBettype_tmp gbt ON b.betType = gbt.bettype 
														WHERE b.matchid= @matchid
															and b.bettype IN(486,488,490)
														FOR XML RAW ('Resource'), ROOT ('Results')
														)

				SELECT @ResourceResult = @ResourceResult + @ResourceResult_Corner_Result
			END
		END
		
		/* --- END Settle Abandoned Match ---*/
		IF (
			(@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1) 
			AND @HTDone 	= 1
			AND @sporttype 	= 1
		)
		BEGIN   									
			
			IF @Sporttype = 1 AND @ChildMatchType = 204
			BEGIN
				SELECT @CornerResultString = CASE WHEN LEFT(@GoalSequence, 1) = ';' THEN SUBSTRING(@GoalSequence,2,LEN(@GoalSequence) - 1) ELSE @GoalSequence END

				IF EXISTS (SELECT TOP (1) 1 FROM @ListBettype_tmp WHERE bettype IN (486,487))
				BEGIN
					SELECT @CornerResultString = ISNULL(@CornerResultString,'')
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
								WHEN bettype = 490 AND CHARINDEX(';', @CornerResultString) > 0 THEN SUBSTRING(@CornerResultString,CHARINDEX(';', @CornerResultString) + 1, 1)
								ELSE LEFT (@CornerResultString, 1)
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
																	WHEN c2.HomeValue IS NULL THEN 'N'
																	WHEN c2.HomeValue IN (';','') THEN 'N' 
																	ELSE c2.HomeValue
																	END AS HomeValue
																, 6 AS SettlementStatusId
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
			SELECT @refundCommand = 'NAP_Admin_Settlement_RefundFT-Abandoned'
			WHERE @IsSettleAbandonedMatchIBC = 1			
			
			EXEC dbo.NAP_Admin_Calculate_Main 
				@matchid                        = @matchid
				,@action                        = 'REFUND'
				,@mode                        	= 'ABANDONED-FT'
				,@fth                         	= @fth
				,@fta                         	= @fta
				,@hth                         	= @hth
				,@hta                         	= @hta
				,@totalgoal                     = @totalgoal
				,@totalgoal_2H                  = @totalgoal_2H
				,@oddevenht                     = @oddevenht
				,@scorediff                     = @scorediff
				,@GoalRecord                    = @GoalSequence		
				,@goalsequenceFT				= @goalsequenceFT
				,@goalsequenceHT				= @goalsequenceHT			
				,@IsHTCal                       = @IsHTCal
				,@IsSettleAbandonedMatch        = @IsSettleAbandonedMatch
				,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
				,@IsSettleAbandonedMatchIBC     = @IsSettleAbandonedMatchIBC
				,@strBettypes					= @strSettledBettypes
				-- including FGLG
				,@ft_fg 						= @ft_fg
				,@ft_lg 						= @ft_lg
		END

		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
			@Command 	= @refundCommand --'NAP_Admin_Settlement_Refund-FT'
			,@MatchID 	= @matchid
			,@HTDone 	= @HTDone
			,@RowCount 	= @RowCount OUTPUT
			,@creator 	= @adminid
			,@BetStatus = @betstatus
			,@FTHome	= @fth
			,@FTAway	= @fta
			,@GoalRecord = @GoalSequence

		IF @sporttype = 1
		BEGIN
			EXEC DBPRO.BODB02.dbo.[NAP_Admin_Result_Update_1s] 
				@Command				= @refundCommand --'NAP_Admin_Settlement_Refund-FT'
				,@MatchID				= @matchid
				,@creator				= @adminid
				,@SDTRecord				= @SDTRecord
				,@fth					= @fth
				,@fta					= @fta
				,@ResourceResult		= @ResourceResult
		END
	    IF @RowCount > 0
		BEGIN		
			-- SELECT for new formation
			SET @strRefundBettypes = (SELECT  f.BetType 'r/@t'
							,f.GroupId 'r/@g'
						FROM dbo.f_Set_GetGroupBettypes() AS f	
							LEFT JOIN @GoalBettype_tmp gbt ON f.BetType = gbt.bettype		
						WHERE f.GroupId IN (2,4,6,7) 
							AND 1= CASE 
									WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NOT NULL THEN 1
									WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NULL THEN 0
									ELSE 1
								END				
						FOR XML PATH ('root')
					)							
			
			-- Calculate Refund FT
			EXEC dbo.NAP_Admin_Calculate_Main 
				@matchid                     = @matchid
				,@action                     = 'REFUND'
				,@mode                       = 'REFUND-FT'
				,@IsExcludeBetdaq            = @IsExcludeBetdaq
				,@IsExcludeBetfair           = @IsExcludeBetfair
				,@IsSettleAbandonedMatchIBC	 = @IsSettleAbandonedMatchIBC
				,@fth                        = @fth
				,@fta                        = @fta
				,@strBettypes				 = @strRefundBettypes
				,@matchdate					 = @matchdate
	        

			-- Calculate charged commission of Cricket
			EXEC dbo.NAP_Admin_Calculate_500
				@MatchId = @matchId
				,@Action = 'REFUND-FT'
				
			-- BetTrade Winlost Sharing
			IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 901 AND 910)
				EXEC dbo.NAP_Admin_Calculate_904
					@MatchId = @matchid
					,@Action = 'REFUND-FT'
			
			-- CashOut Winlost Sharing
			IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 911 AND 920)
			BEGIN
				EXEC dbo.NAP_Admin_Calculate_914
					@MatchId = @matchid
					,@Action = 'REFUND'
			END
			
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
		, @IsRefundHT		= @IsRefundHT

	-- Compare and update pending balance with error case
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID

	
    ---------------------------------------
    --  Betfair & Betdaq - Warning message:
    SELECT	@movebet = convert(VARCHAR(20), DATEADD(d, 1, kickofftime), 100),
			@matchcode    = matchcode
    FROM	DBPRO.bodb02.dbo.match WITH (NOLOCK)
    WHERE	matchid = @matchid
    
    IF @matchcode not like '%Hedge%'
    BEGIN 
        IF (@IsExcludeBetdaq = 1 OR @IsSettleAbandonedMatch = 1) AND (@IsExcludeBetfair = 1 OR @IsSettleAbandonedMatchBetFair = 1) AND @HTDone = 1
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg    = 'Please move Betdaq and Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
        ELSE IF (@IsExcludeBetdaq = 1 OR @IsSettleAbandonedMatch = 1) AND @HTDone = 1
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg    = 'Please move Betdaq tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
        ELSE IF (@IsExcludeBetfair = 1 OR @IsSettleAbandonedMatchBetFair = 1) AND @HTDone = 1
        BEGIN
            SELECT @ErrCode = 1000006
                ,@ErrMsg    = 'Please move Betfair tickets to a new match before ' + @movebet + ' GMT-4. Otherwise they will bring harm to the system'
        END
    END
    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------
    
    SELECT @stop = CURRENT_TIMESTAMP

    IF @RowCount > 0 OR ((@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1) AND @HTDone = 1)
    BEGIN
        DECLARE @LogData NVARCHAR(300)

        SELECT @LogData = 'NAP: Calculate (Refund FT) for matchid:' 
                            + CAST(@matchid AS NVARCHAR(10)) + CASE WHEN @IsExcludeBetdaq = 1 THEN ', Exclude Betdaq tickets' ELSE '' END 
                                                             + CASE WHEN @IsSettleAbandonedMatch = 1 THEN ', Settle determined betdaq tickets' ELSE '' END 
                                                             + CASE WHEN @IsExcludeBetfair = 1 THEN ', Exclude Betfair tickets' ELSE '' END 
                                                             + CASE WHEN @IsSettleAbandonedMatchBetFair = 1 THEN ', Settle determined betfair tickets' ELSE '' END 
                                                             + CASE WHEN @IsSettleAbandonedMatchIBC = 1 THEN ', Settle determined IBC tickets' ELSE '' END

        EXEC dbo.WriteLog_UserLog 
            @UserId = @AdminID
            ,@Doing = @LogData

        --Write Log Settle
        DECLARE @hthomescore    INT
            ,@htawayscore       INT
			,@finalhomescore	INT
			,@finalawayscore	INT
            ,@goalrecord        VARCHAR(50)

        SELECT @Remark = 'NAP: ExcludeBetdaqTickets='      + convert(CHAR(1), @IsExcludeBetdaq) 
                      + ' SettleDeterminedBetdaqTickets=' + convert(CHAR(1), @IsSettleAbandonedMatch) 
                      + ' ExcludeBetfairTickets='         + convert(CHAR(1), @IsExcludeBetfair) 
                      + ' SettleDeterminedBetfairTickets=' + convert(CHAR(1), @IsSettleAbandonedMatchBetFair) 
                      + ' SettleDeterminedIBCTickets='    + convert(CHAR(1), @IsSettleAbandonedMatchIBC) 
                      + CASE WHEN (@IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1) AND @HTDone = 1 THEN @ScoreLog
                             ELSE ''
                        END 
                      + ' Duration=' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms;'

        SELECT @hthomescore 	= hthomescore
            ,@htawayscore    	= htawayscore
            ,@goalrecord    	= goalrecord
            ,@betstatus        	= betstatus
			,@finalhomescore    = finalhomescore
            ,@finalawayscore    = finalawayscore
        FROM DBPRO.BODB02.dbo.match WITH (NOLOCK)
        WHERE matchid = @matchid

        BEGIN TRY
            EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
                @UserID             = @adminid
                ,@Matchid           = @matchid
                ,@ActionID          = @ActionID
                ,@finalhomescore    = @finalhomescore
                ,@finalawayscore    = @finalawayscore
                ,@hthomescore       = @hthomescore
                ,@htawayscore       = @htawayscore
                ,@GoalRecord        = @goalrecord
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
                ,@finalhomescore    = @finalhomescore
                ,@finalawayscore    = @finalawayscore
                ,@hthomescore       = @hthomescore
                ,@htawayscore       = @htawayscore
                ,@GoalRecord        = @goalrecord
                ,@betstatus         = @betstatus
                ,@Remark            = @Remark
                ,@IP                = @IP
        END CATCH
    END

    ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
END
GO