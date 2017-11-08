/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3] 
	@matchid INT
    , @mode VARCHAR(6) = 'CAL'
    , @isExcludeCorner BIT = 0 
	, @IsAutoCalculatePage BIT = 0
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
       
    Param's Explanation:
    • @Mode:
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
                        
            -- for tennis
            ,@TennisTotal			SMALLINT
            ,@T_Home				SMALLINT
            ,@T_Away				SMALLINT

            --corners bets
            ,@fthCorners        	INT = 0
            ,@ftaCorners        	INT = 0
            ,@hthCorners        	INT = 0
            ,@htaCorners        	INT = 0     
            ,@oddevenCorners    	SMALLMONEY    
            ,@oddevenCorners_ht		SMALLMONEY
            ,@totalCorners			SMALLMONEY
            ,@totalCorners_ht		SMALLMONEY
            ,@FTFCorner            	VARCHAR(10) =''
            ,@FTLCorner            	VARCHAR(10) =''
            ,@HTFCorner            	VARCHAR(10) =''
            ,@HTLCorner            	VARCHAR(10) =''     
            ,@strBettypes 			VARCHAR(MAX)
            
            ,@betcount_501			INT = 0
            ,@strResultDetail		VARCHAR(MAX)
            ,@xmlResultDetail		XML
			
			-- for FGLG declaration
			,@ht_fg 				VARCHAR(10)
			,@ht_lg 				VARCHAR(10)
			,@ft_fg 				VARCHAR(10)
			,@ft_lg 				VARCHAR(10)
			
    SELECT	@fth = FinalHomeScore
			,@fta = FinalAwayScore
			,@hth = HTHomeScore
			,@hta = HTAwayScore
			,@sporttype = SportType
			,@betstatus = betstatus
			,@isRefundHT = CASE WHEN betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
			,@GoalRecord = ISNULL(GoalRecord, '')
			,@matchCode = ISNULL(matchCode, '')
    FROM	DBPRO.BODB02.dbo.Match WITH (NOLOCK)
    WHERE	matchid = @matchid
    
	IF @Sporttype = 1 
    BEGIN
		
		EXEC dbo.NAP_Admin_Settlement_2 @mode = 'all'
			,@matchid = @MatchId
			,@str_resultDetail = @strResultDetail OUTPUT
			
		SET @xmlResultDetail = CAST(@strResultDetail AS XML)
		
		;WITH cteResult
		AS(
			SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
					,T.c.value('./@home','VARCHAR(50)') AS HomeValue
					,T.c.value('./@away','VARCHAR(50)') AS AwayValue
			FROM	@xmlResultDetail.nodes('/root/r') AS T(c)
		)
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
				,@ft_fg = ISNULL(MAX(CASE 
										WHEN ResourceID ='14F' 
											THEN CASE 
													WHEN HomeValue = 'N' THEN '0:0'
													WHEN HomeValue = 'H' THEN '1:1'
													WHEN HomeValue = 'A' THEN '2:1'
													ELSE ''
												END
											ELSE '' 
									END),'')		
				,@ft_lg = ISNULL(MAX(CASE 
										WHEN ResourceID ='14L' 
											THEN CASE 
													WHEN HomeValue = 'N' THEN '0:0'
													WHEN HomeValue = 'H' THEN '1:2'
													WHEN HomeValue = 'A' THEN '2:2'
													ELSE ''
												END
											ELSE '' 
									END),'')					
				,@fthCorners = ISNULL(MAX(CASE WHEN ResourceID ='04' THEN HomeValue ELSE 0 END),0)
				,@ftaCorners = ISNULL(MAX(CASE WHEN ResourceID ='04' THEN AwayValue ELSE 0 END),0)
                ,@hthCorners = ISNULL(MAX(CASE WHEN ResourceID ='05' THEN HomeValue ELSE 0 END),0)
                ,@htaCorners = ISNULL(MAX(CASE WHEN ResourceID ='05' THEN AwayValue ELSE 0 END),0)
                ,@FTFCorner = ISNULL(MAX(CASE WHEN ResourceID ='206' THEN HomeValue ELSE '' END),'')
                ,@HTFCorner = ISNULL(MAX(CASE WHEN ResourceID ='207' THEN HomeValue ELSE '' END),'')
                ,@FTLCorner = ISNULL(MAX(CASE WHEN ResourceID ='208' THEN HomeValue ELSE '' END),'')
                ,@HTLCorner = ISNULL(MAX(CASE WHEN ResourceID ='209' THEN HomeValue ELSE '' END),'')
		FROM	cteResult r
		OPTION ( OPTIMIZE FOR ( @xmlResultDetail = NULL ) )
		
        SELECT  @oddevenCorners		= ((@fthCorners + @ftaCorners)%2)
                ,@oddevenCorners_ht = ((@hthCorners + @htaCorners)%2)
                ,@totalCorners      = (@fthCorners + @ftaCorners)
                ,@totalCorners_ht   = (@hthCorners + @htaCorners)
    END 

    IF @SportType IN (6, 9, 30) -- Tennis/VolleyBall/Badminton/Squash : get TotalGamesPlayed
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
                            WHEN @sporttype IN (6, 9, 30) AND @TennisTotal > 0 THEN @TennisTotal % 2
                            ELSE ((@fth + @fta) % 2)
							END
        ,@oddevenht = ((@hth + @hta) % 2)
        ,@oddevenhome = CASE 
							WHEN @sporttype IN (6, 9, 30) AND @T_Home > 0 THEN @T_Home % 2
							ELSE ((@fth ) % 2)
							END
        ,@oddevenhome_ht = @hth % 2
        ,@oddevenaway = CASE 
                            WHEN @sporttype IN (6, 9, 30) AND @T_Away > 0 THEN @T_Away % 2
                            ELSE ((@fta) % 2)
							END
        ,@oddevenaway_ht = @hta % 2
        ,@oddeven_2H = ((@fth + @fta - @hth - @hta)%2)
        ,@totalgoal = CASE 
							WHEN @sporttype IN (6, 9, 30) AND @TennisTotal > 0 THEN @TennisTotal
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
	
    IF EXISTS (
            SELECT	transid
            FROM	dbo.bettrans WITH (NOLOCK)
            WHERE	matchid = @matchid 
					AND bettype = 22
            ) AND LEN(@GoalRecord) <> @TotalGoal
    BEGIN
        RAISERROR ('Goal record is not consistent with the score, please correct Goal record before calculating.', 16, 1)

        RETURN
    END
	
	--using this way to avoid more param @betcount
	;WITH cteBettypes
	AS(
		SELECT Bettype
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	@mode IN ('CAL-HT', 'CAL') 
				AND 1 = CASE 
							WHEN @IsAutoCalculatePage = 1 AND GroupId IN (1,5) THEN 1 
							WHEN @IsAutoCalculatePage = 0 AND GroupId IN (1,3,5) THEN 1 
							ELSE 0 END -- HT + HT Corner + HT FGLG
				AND 1 = CASE
							WHEN @isExcludeCorner = 1 AND GroupId = 5 THEN 0 -- exclude HT corner
							ELSE 1
						END
		UNION ALL
		SELECT Bettype
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	@mode IN ('CAL-FT', 'CAL') 
				AND 1 = CASE 
							WHEN @IsAutoCalculatePage = 1 AND GroupId IN (2,6) THEN 1 
							WHEN @IsAutoCalculatePage = 0 AND GroupId IN (2,4,6) THEN 1 
							ELSE 0 END -- FT, FT Corner + FT FGLG
				AND 1 = CASE
							WHEN @isRefundHT = 1 AND Is3x30 = 1 AND GroupId = 2 THEN 0 -- If this match has been refund HT --> refund all bettypes related to 2nd result 
							WHEN @isExcludeCorner = 1 AND GroupId = 6 THEN 0 -- exclude FT corner
							WHEN @IsAutoCalculatePage = 1 AND IsUsedGoalRecordValue = 1 THEN 0
							ELSE 1
						END
				
	)
	SELECT @strBettypes = COALESCE(@strBettypes + ',' + CAST(bettype AS VARCHAR(10)), CAST(bettype AS VARCHAR(10))) 
	FROM (
		SELECT	bettype
		FROM	dbo.bettrans WITH(NOLOCK)
		WHERE 	matchid = @matchid
		GROUP BY bettype
	
	) AS b 
	WHERE b.bettype IN (SELECT bettype FROM cteBettypes)
	GROUP BY bettype
	
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
        ,@fthCorners = @fthCorners
        ,@ftaCorners = @ftaCorners
        ,@hthCorners = @hthCorners
        ,@htaCorners = @htaCorners
        ,@oddevenCorners = @oddevenCorners
        ,@oddevenCorners_ht    = @oddevenCorners_ht
        ,@totalCorners = @totalCorners
        ,@totalCorners_ht = @totalCorners_ht
        ,@ftFCorner = @ftFCorner
        ,@ftLCorner = @ftLCorner
        ,@htFCorner = @htFCorner
        ,@htLCorner = @htLCorner
        ,@isRefundHT = @isRefundHT      
        ,@isExcludeCorner = @isExcludeCorner  
		,@strBettypes	   = @strBettypes		
		-- including FGLG
		,@ht_fg = @ht_fg
		,@ht_lg = @ht_lg
		,@ft_fg = @ft_fg
		,@ft_lg = @ft_lg
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