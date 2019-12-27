/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3] 
	@matchid INT
    , @mode VARCHAR(6) = 'CAL'
	, @IsReSettledTickets BIT = 1
	, @creator			INT = NULL
AS
/*
    Created: Viet
    Task : Covered SP for settlement
    Original SP: Admin_Settlement_3
    DB: DBTXN/bodb02

    Revisions:
       - 20140426@Kathy: Add 1H Total Goal (126) [Redmine:#14449]
       - 20140617@Kathy: Apply BetRadar [Redmine:#17142]
       - 20140807@Kathy: Support new 11 bettypes [Redmine:#19667]
       - 20140822@Jamie: Add bet count 11 bettypes [Redmine:#19667]
       - 20150415@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
       - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
	   - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
	   - 20151126@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
	   - 20151207@Patrick: Database - Change datatype [Redmine: #48660]
	   - 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
       - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
	   - 20160314@Patrick: Support auto-payout [Redmine: #53262]
	   - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
       - 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
	   - 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
	   - 20170316@Bobby: Integrate CashOut bettypes [Redmine:#73404]
	   - 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
	   - 20171211@Kathy: Do not calculate bettype 22 with old format (betteam:h,a) [Redmine:#80947]
	   - 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
	   - 20180510@Benjamin: Incorporate new Sports: Sepak Takraw(48)[Redmine:#94608]
	   - 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
	   - 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
	   - 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
       - 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
       - 20191213@Helen: Support Instant Calculation for Corner Bet Types - Update result for manual process [Redmine:115377]
	   - 20191223@Max: Instant Calculation for Corner Bet Types - Update result for Cal 0-0 [Redmine:#124951]


    Param's Explanation:
    @Mode:
        CAL : All BetTypes
        CAL-HT : HT Only
        CAL-FT : FT Only (All Except HT)
*/
BEGIN
    SET NOCOUNT ON;

    -- result
    DECLARE @fth					INT
            ,@fta                 	INT
            ,@hth                 	INT
            ,@hta                 	INT
            ,@home_2nd            	INT
            ,@away_2nd            	INT 
            ,@sporttype				SMALLINT
            ,@betstatus				NVARCHAR(50)
            ,@GoalRecord			VARCHAR(50) 
            ,@matchCode				NVARCHAR(50)
            ,@oddeven				SMALLMONEY
            ,@oddevenht				SMALLMONEY
            ,@oddevenhome			SMALLMONEY
            ,@oddevenhome_ht		SMALLMONEY
            ,@oddevenaway			SMALLMONEY
            ,@oddevenaway_ht		SMALLMONEY        
            ,@oddeven_2H			SMALLMONEY        
            ,@totalgoal				SMALLMONEY
            ,@totalht				SMALLMONEY
            ,@totalgoal_2H			SMALLMONEY 
            ,@totalhome				SMALLMONEY
            ,@totalaway				SMALLMONEY
            ,@scorediff				SMALLMONEY
            ,@scorediff_ht        	SMALLMONEY
            ,@scorediff_2H        	SMALLMONEY 
            ,@correctscore        	NVARCHAR(10)
            ,@correctscore_ht    	NVARCHAR(10)
			,@correctscore_2h    	NVARCHAR(10)
            ,@HTFT					NVARCHAR(10)
            ,@isRefundHT			BIT
            ,@WinFromBehind			NVARCHAR(1)
			,@goalsequenceHT		VARCHAR(50)
			,@goalsequenceFT		VARCHAR(50)
                        
            -- for tennis
            ,@TennisTotal			SMALLINT
            ,@T_Home				SMALLINT
            ,@T_Away				SMALLINT

            ,@strBettypes 			VARCHAR(MAX)
            
            ,@betcount_501			INT = 0
            ,@strResultDetail		VARCHAR(MAX)
            ,@xmlResultDetail		XML
			
			-- for FGLG declaration
			,@ht_fg 				VARCHAR(10)
			,@ht_lg 				VARCHAR(10)
			,@ft_fg 				VARCHAR(10)
			,@ft_lg 				VARCHAR(10)
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
	
	DECLARE @ResourceResult AS TABLE (ResourceId VARCHAR(20),HomeValue VARCHAR(50),AwayValue VARCHAR(50))		
	DECLARE @GoalBettype_tmp AS TABLE (bettype SMALLINT, Voided_cnt INT, ticket_cnt INT)
	
	DECLARE @ListBettype_tmp AS TABLE (bettype SMALLINT, hdp1 SMALLMONEY)
	
	DECLARE @ResultDetail_Corner AS TABLE (hdp INT, ResourceID VARCHAR(20), HomeValue VARCHAR(10),Index_Round TINYINT)
	DECLARE @ResultDetail_Corner_tmp AS TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(10))
	DECLARE @ResultDetail_Corner_ticket AS TABLE (ResourceID VARCHAR(20))
	
    SELECT	@fth = FinalHomeScore
			,@fta = FinalAwayScore
			,@hth = HTHomeScore
			,@hta = HTAwayScore
			,@sporttype = SportType
			,@betstatus = betstatus
			,@isRefundHT = CASE WHEN betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
			,@GoalRecord = ISNULL(GoalRecord, '')
			,@matchCode = ISNULL(matchCode, '')
			,@ChildMatchType = ChildMatchType
    FROM	DBPRO.BODB02.dbo.Match WITH (NOLOCK)
    WHERE	matchid = @matchid
    
	IF @Sporttype = 1 
    BEGIN
		EXEC dbo.NAP_Admin_Settlement_2 @mode = 'all'
			,@matchid = @MatchId
			,@str_resultDetail = @strResultDetail OUTPUT
			
		SET @xmlResultDetail = CAST(@strResultDetail AS XML)
				
		INSERT INTO @ResourceResult (ResourceId,HomeValue,AwayValue)
		SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
				,T.c.value('./@home','VARCHAR(50)') AS HomeValue
				,T.c.value('./@away','VARCHAR(50)') AS AwayValue
		FROM	@xmlResultDetail.nodes('/root/r') AS T(c)
		OPTION ( OPTIMIZE FOR ( @xmlResultDetail = NULL ) )		
		
		SELECT	
				-- for bettype 127 only
				@ht_fg = ISNULL(MAX(CASE 
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
												
				-- for bettype 14,448
				,@ft_fg = ISNULL(MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END),'')
				,@ft_lg = ISNULL(MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END),'')
				,@goalsequenceHT = ISNULL(MAX(CASE WHEN ResourceId = '09' THEN HomeValue ELSE '' END),'')
				,@goalsequenceFT = ISNULL(MAX(CASE WHEN ResourceId = '08' THEN HomeValue ELSE '' END),'')
		FROM	@ResourceResult r
		
    END 

    IF @SportType IN (6, 9, 30, 48) -- Tennis/VolleyBall/Badminton/Squash/Sepak Takraw : get TotalGamesPlayed
    BEGIN
        EXEC dbo.NAP_Admin_Settlement_2 @betstatus = @betstatus
            ,@Total = @TennisTotal OUTPUT
            ,@TotalHome = @T_Home OUTPUT
            ,@TotalAway = @T_Away OUTPUT
    END

    IF @SportType = 10 -- Golf, using Stroke count, so swap the score to make it become normal stype
    BEGIN
        DECLARE @tmp INT

        SELECT @tmp = @fth
              ,@fth = @fta
              ,@fta = @tmp
    END

    SELECT @oddeven = CASE 
                            WHEN @sporttype IN (6, 9, 30, 48) AND @TennisTotal > 0 THEN @TennisTotal % 2
                            ELSE ((@fth + @fta) % 2)
							END
        ,@oddevenht = ((@hth + @hta) % 2)
        ,@oddevenhome = CASE 
							WHEN @sporttype IN (6, 9, 30, 48) AND @T_Home > 0 THEN @T_Home % 2
							ELSE ((@fth ) % 2)
							END
        ,@oddevenhome_ht = @hth % 2
        ,@oddevenaway = CASE 
                            WHEN @sporttype IN (6, 9, 30, 48) AND @T_Away > 0 THEN @T_Away % 2
                            ELSE ((@fta) % 2)
							END
        ,@oddevenaway_ht = @hta % 2
        ,@oddeven_2H = ((@fth + @fta - @hth - @hta)%2)
        ,@totalgoal = CASE 
							WHEN @sporttype IN (6, 9, 30, 48) AND @TennisTotal > 0 THEN @TennisTotal
							ELSE (@fth + @fta)
							END
        ,@totalht = (@hth + @hta)
        ,@totalgoal_2H = (@fth + @fta) - (@hth + @hta)
        ,@totalhome = @fth
        ,@totalaway = @fta
        ,@scorediff = (@fth - @fta)
        ,@scorediff_ht = (@hth - @hta)
        ,@scorediff_2H = (@fth -@hth) -(@fta - @hta)
        ,@correctscore = CAST(@fth AS NVARCHAR(6)) + ':' + CAST(@fta AS NVARCHAR(6))
        ,@correctscore_ht = CAST(@hth AS NVARCHAR(6)) + ':' + CAST(@hta AS NVARCHAR(6))
		,@correctscore_2h = CAST((@fth -@hth) AS NVARCHAR(6)) + ':' + CAST((@fta - @hta) AS NVARCHAR(6))
        ,@home_2nd = (@fth - @hth)
        ,@away_2nd = (@fta - @hta)
        ,@HTFT = CASE 
                    WHEN @hth = @hta THEN '0'
                    WHEN @hth > @hta THEN '1'
                    ELSE '2'
					END + ':' 
              + CASE 
                    WHEN @fth = @fta THEN '0'
                    WHEN @fth > @fta THEN '1'
                    ELSE '2'
					END

	-- Win from behind
	DECLARE @curHome INT = 0
			,@curAway INT = 0
			,@index INT = 1
			
	IF (@fth <> @fta) AND (@fth + @fta) > 2
	BEGIN
		WHILE (@index <= LEN(REPLACE(@GoalRecord,';','')))
		BEGIN
			IF SUBSTRING(REPLACE(@GoalRecord,';',''),@index, 1) = 'H'
				SET @curHome = @curHome + 1
				
			IF SUBSTRING(REPLACE(@GoalRecord,';',''),@index, 1) = 'A' 
				SET @curAway = @curAway + 1				
			
			IF @fth > @fta AND @curHome < @curAway 
			BEGIN
				SET @WinFromBehind = 'H' 
				BREAK
			END
			IF @fta > @fth AND @curAway < @curHome
			BEGIN
				SET @WinFromBehind = 'A'
				BREAK
			END
			
			SET @index = @index + 1
		END
	END			
	IF @sporttype = 1
	BEGIN
		-- check GoalBettype if all tickets have been voided
		INSERT INTO @GoalBettype_tmp (bettype, Voided_cnt,ticket_cnt)
		SELECT b.bettype
			, SUM(CASE WHEN statusID IN (101,102) THEN 1 ELSE 0 END) AS Voided_cnt
			, COUNT(1) AS ticket_cnt
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN dbo.f_Set_GetGroupBettypes() bt ON b.bettype = bt.BetType AND IsUsedGoalRecordValue = 1
		WHERE b.matchid = @matchid 
		GROUP BY b.bettype
		
		DELETE g 
		FROM @GoalBettype_tmp g
			INNER JOIN SettlementSpecialBettypeProfile p WITH (NOLOCK) ON g.bettype = p.bettype
		WHERE g.Voided_cnt = g.ticket_cnt
			AND NOT EXISTS (SELECT 1 FROM @ResourceResult rs WHERE p.ResourceID = rs.ResourceId)
	END	
	--using this way to avoid more param @betcount
	;WITH cteBettypes
	AS(
		SELECT f.Bettype
		FROM	dbo.f_Set_GetGroupBettypes() f
			LEFT JOIN @GoalBettype_tmp gbt ON f.BetType = gbt.bettype
		WHERE	@mode IN ('CAL-HT', 'CAL') 
				AND 1 = CASE 
							WHEN f.GroupId IN (1,3) THEN 1 
							ELSE 0 END -- HT + HT Corner + HT FGLG
				AND 1 = CASE 
							WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NOT NULL THEN 1
							WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NULL THEN 0
							ELSE 1
						END
										
		UNION ALL
		SELECT f.Bettype
		FROM	dbo.f_Set_GetGroupBettypes() f
			LEFT JOIN @GoalBettype_tmp gbt ON f.BetType = gbt.bettype
		WHERE	@mode IN ('CAL-FT', 'CAL') 
				AND 1 = CASE 
							WHEN f.GroupId IN (2,4) THEN 1 
							ELSE 0 END -- FT, FT Corner + FT FGLG
				AND 1 = CASE
							WHEN @isRefundHT = 1 AND Is3x30 = 1 AND f.GroupId = 2 THEN 0 -- If this match has been refund HT --> refund all bettypes related to 2nd result 
							ELSE 1
						END
				AND 1 = CASE 
							WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NOT NULL THEN 1
							WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NULL THEN 0
							ELSE 1
						END	 		
				
	)
	INSERT INTO @ListBettype_tmp (bettype,hdp1)
	SELECT bettype,hdp1  
	FROM (
		SELECT	b.bettype,hdp1
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE 	matchid = @matchid
				AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
						 WHEN @IsReSettledTickets = 1 THEN 1
						 ELSE 0
					END
		GROUP BY b.bettype,hdp1
	
	) AS b 
	WHERE b.bettype IN (SELECT bettype	FROM cteBettypes )
	GROUP BY b.bettype,hdp1
	
	SELECT @strBettypes = COALESCE(@strBettypes + ',' + CAST(bettype AS VARCHAR(10)), CAST(bettype AS VARCHAR(10))) 
	FROM (SELECT DISTINCT bettype FROM @ListBettype_tmp) AS tmp
	
	IF @Sporttype = 1 AND @ChildMatchType = 204
	BEGIN
		SELECT @CornerResultString = CASE WHEN LEFT(@GoalRecord, 1) = ';' THEN SUBSTRING(@GoalRecord,2,LEN(@GoalRecord) - 1) ELSE @GoalRecord END

		IF EXISTS (SELECT TOP (1) 1 FROM @ListBettype_tmp WHERE bettype IN (486,487))
		BEGIN
			SELECT @CornerResultString = ISNULL(@CornerResultString,'')
				, @Position = 1
				,@HomeRaceTo = 0
				,@AwayRaceTo = 0
				
			SELECT @LenResultString = LEN(@CornerResultString)

			SET @Index_Round_tmp =  CASE WHEN CHARINDEX(';',@GoalRecord) = 0 THEN LEN(@GoalRecord) + 1 ELSE CHARINDEX(';',@GoalRecord) END

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
														, 4 AS SettlementStatusId
														, 5 AS ResultStatusId
													FROM @ResultDetail_Corner_ticket  c1
														LEFT JOIN @ResultDetail_Corner_tmp c2 ON c1.ResourceID = c2.ResourceID
													FOR XML RAW ('Resource'), ROOT ('Results')
													)

		IF @ResourceResult_Corner_Result IS NOT NULL
		BEGIN	
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
				@Command        = 'NAP_Admin_Settlement_1_InstantCalculation-CAL', -- reuse inst command
				@MatchID        = @MatchID,                  
				@ResourceResult	= @ResourceResult_Corner_Result,                    
				@creator        = @creator
		END			
			
	END
    -- call execrep SP
	EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
        ,@mode = @mode
        ,@fth = @fth
        ,@fta = @fta
        ,@hth = @hth
        ,@hta = @hta
        ,@home_2nd = @home_2nd
        ,@away_2nd = @away_2nd
        ,@sporttype = @sporttype
        ,@betstatus = @betstatus
        ,@GoalRecord = @GoalRecord
		,@goalsequenceFT = @goalsequenceFT
		,@goalsequenceHT = @goalsequenceHT
        ,@matchCode = @matchCode
        ,@oddeven = @oddeven
        ,@oddevenht = @oddevenht
        ,@oddevenhome = @oddevenhome
        ,@oddevenhome_ht = @oddevenhome_ht
        ,@oddevenaway = @oddevenaway
        ,@oddevenaway_ht = @oddevenaway_ht
        ,@oddeven_2H = @oddeven_2H
        ,@totalgoal = @totalgoal
        ,@totalht = @totalht
        ,@totalgoal_2H = @totalgoal_2H
        ,@totalhome = @totalhome
        ,@totalaway = @totalaway
        ,@scorediff = @scorediff
        ,@scorediff_ht = @scorediff_ht
        ,@scorediff_2H = @scorediff_2H
        ,@correctscore = @correctscore
        ,@correctscore_ht = @correctscore_ht
		,@correctscore_2h = @correctscore_2h
        ,@HTFT = @HTFT
        ,@WinFromBehind = @WinFromBehind
        ,@TennisTotal = @TennisTotal
        ,@T_Home = @T_Home
        ,@T_Away = @T_Away
        ,@isRefundHT = @isRefundHT      
		,@strBettypes	   = @strBettypes		
		-- including FGLG
		,@ht_fg = @ht_fg
		,@ht_lg = @ht_lg
		,@ft_fg = @ft_fg
		,@ft_lg = @ft_lg
		,@IsReSettledTickets = @IsReSettledTickets
		-- using by service broker
		,@CalledByBrokerService = 0 -- this one is called by NAP_Admin_Settlement_3 instead :)
		
					   
        --Cricket: Charged Commision
        EXEC dbo.NAP_Admin_Calculate_500
			@MatchId = @matchId
			,@Action = @Mode
			
		-- BetTrade Winlost Sharing
		IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 901 AND 910)
			EXEC dbo.NAP_Admin_Calculate_904
				@MatchId = @matchid
				,@Action = @Mode
		-- CashOut Winlost Sharing
		IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype BETWEEN 911 AND 920)
		BEGIN
			--RE-CAL winloss sharing
			EXEC dbo.NAP_Admin_Calculate_914
				@MatchId = @matchid
				,@Action = @Mode
		END
END
GO
