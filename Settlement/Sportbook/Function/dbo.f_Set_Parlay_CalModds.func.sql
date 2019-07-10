/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Parlay_CalModds] (
	@bettype SMALLINT
	, @betteam VARCHAR(50)
	, @betcheck NVARCHAR(50)
	, @livehomescore INT
	, @liveawayscore INT
	, @hdp1 SMALLMONEY
	, @hdp2 SMALLMONEY
	, @transdesc NVARCHAR(1000)
	, @fth INT = NULL
	, @fta INT = NULL
	, @hth INT = NULL
	, @hta INT = NULL
	, @HT_FGLG1 VARCHAR(10)
	, @HT_FGLG2 VARCHAR(10)
	, @FGLG1 VARCHAR(10)
	, @FGLG2 VARCHAR(10)
	, @TennisTotal INT = NULL
	, @TotalGameHomeMatch INT = NULL
	, @TotalGameAwayMatch INT = NULL
	, @homeScoreSet1 TINYINT
	, @homeScoreSet2 TINYINT
	, @homeScoreSet3 TINYINT
	, @homeScoreSet4 TINYINT
	, @homeScoreSet5 TINYINT
	, @awayScoreSet1 TINYINT
	, @awayScoreSet2 TINYINT
	, @awayScoreSet3 TINYINT
	, @awayScoreSet4 TINYINT
	, @awayScoreSet5 TINYINT
	, @SetxGameyHomeWON VARCHAR(MAX) = NULL
	, @SetxGameyAwayWON VARCHAR(MAX) = NULL
	, @SetxGameyDRAW VARCHAR(MAX) = NULL
	, @SetxGameyREFUND VARCHAR(MAX) = NULL
	, @SelectedSetCAL VARCHAR(50) = NULL
	, @SelectedSetREFUND VARCHAR(50) = NULL
	, @WinFromBehind NVARCHAR(1)
	, @FirstGoal NVARCHAR(50)
	, @FirstGoal2H VARCHAR(1)
	, @LastGoal VARCHAR(1)
	, @LastGoal1H VARCHAR(1)
	, @csHTFT NVARCHAR(10)
	, @home_firstteam2goals INT
	, @away_firstteam2goals INT
	, @home_firstteam3goals INT
	, @away_firstteam3goals INT
	, @FTHighestQuarter	VARCHAR(10) = NULL	
	, @HomeValue		VARCHAR(50) = NULL
	, @QXHome				INT = NULL
	, @QXAway				INT = NULL
	, @totalgoal SMALLINT = 0
	, @scorediff SMALLINT = 0
	, @oddeven SMALLINT = 0
	, @totalht SMALLINT = 0
    , @totalgoal_2H SMALLINT = 0
	, @ResultCornerRace VARCHAR(200)
	, @NeitherRaceTo TINYINT
	, @ResultCornerRace1H VARCHAR(200)
	, @NeitherRaceTo1H TINYINT
)
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
    Created:20161129@Bobby
    Task: Implement SDT Parlay @bettypes - Modds Calculation
    DB: DBTXN/bodb02
    Revisions:
			- 20170525@Kathy: Add logic for bettype 617 [Redmine:#77046]
			- 20170613@Kathy: Early Settlement [Redmine:#77835] 
			- 20170901@Kathy: Settle parlay tickets of tennis in case of they have result [Redmine:#82122]
			- 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
			- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
			- 20180123@Helen: Hotfix - match 3x30 - Just change position of input params totalgoal & scorediff of this function ONLY [Redmine:#89388]
			- 20190603@Sol: Incorporate PHAIO 4 [Redmine:#112885]
			- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
			- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
			
    Parameters Explanation:    
	
*/

RETURN (
	SELECT odds.modds
		, ip.IsRefundGame
	FROM (
		SELECT 
			CASE WHEN  @bettype = 1324 AND CHARINDEX(SUBSTRING(CAST(@betcheck AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 1 ELSE 0 END  AS IsRefundGame
			,CASE WHEN @betcheck = '801' THEN @homeScoreSet1
									   WHEN @betcheck = '802' THEN @homeScoreSet2
									   WHEN @betcheck = '803' THEN @homeScoreSet3
									   WHEN @betcheck = '804' THEN @homeScoreSet4
									   WHEN @betcheck = '805' THEN @homeScoreSet5
									   ELSE 0
									END AS TotalGameHomeSetx
			,CASE WHEN @betcheck = '801' THEN @awayScoreSet1
								   WHEN @betcheck = '802' THEN @awayScoreSet2
								   WHEN @betcheck = '803' THEN @awayScoreSet3
								   WHEN @betcheck = '804' THEN @awayScoreSet4
								   WHEN @betcheck = '805' THEN @awayScoreSet5
								   ELSE 0
								   END   AS TotalGameAwaySetx
			,CASE WHEN @bettype = 416 THEN SUBSTRING(@transdesc,0, CHARINDEX('/',@transdesc)) ELSE NULL END AS ExcludingHTChoice
			,CASE WHEN @bettype = 416 THEN SUBSTRING(@transdesc,CHARINDEX('/',@transdesc)+1,LEN(@transdesc)) ELSE NULL END AS ExcludingFTChoice
	) AS ip
	CROSS APPLY (
		SELECT 
			CASE @bettype
				WHEN 1 THEN -- Handicap
					CASE @betteam
						WHEN N'h' THEN (@hdp2 - @hdp1) + (@fth - @livehomescore) - (@fta - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (@fth - @livehomescore) + (@fta - @liveawayscore)
						END
				WHEN 7 THEN -- 1st Handicap
					CASE @betteam
						WHEN N'h' THEN (@hdp2 - @hdp1) + (@hth - @livehomescore) - (@hta - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (@hth - @livehomescore) + (@hta - @liveawayscore)
						END
				WHEN 3 THEN -- Over/Under
					CASE @betteam
						WHEN N'h' THEN (CASE 
								WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
								ELSE @TennisTotal END
								) - @hdp1
						WHEN N'a' THEN @hdp1 - (CASE 
								WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
								ELSE @TennisTotal END
								)
						END
				WHEN 8 THEN -- 1st Over/Under
					CASE @betteam
						WHEN N'h' THEN (@hth + @hta) - @hdp1
						WHEN N'a' THEN @hdp1 - (@hth + @hta)
						END
				WHEN 2 THEN -- Odd/Even
					CASE 
						WHEN (@betteam = N'h') AND (
								(CASE 
									WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
									ELSE @TennisTotal END
									) & 1 = 1
								) THEN 1
						WHEN (@betteam = N'a') AND (
								(CASE 
									WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
									ELSE @TennisTotal END
									) & 1 = 0
								) THEN 1
						ELSE - 1
						END
				WHEN 12 THEN -- 1st Odd/Even
					CASE 
						WHEN (@betteam = N'h') AND ((@hth + @hta) & 1 = 1) THEN 1
						WHEN (@betteam = N'a') AND ((@hth + @hta) & 1 = 0) THEN 1
						ELSE - 1
						END
				WHEN 4 THEN -- Correct Score
					CASE 
						WHEN @betteam = (CAST(@fth AS VARCHAR(4)) + ':' + CAST(@fta AS VARCHAR(4))) THEN 1
						WHEN @betteam = '5:0' AND (@fth - @fta) >= 5 THEN 1
						WHEN @betteam = '0:5' AND (@fth - @fta) <= - 5 THEN 1
						ELSE - 1
						END
				WHEN 30 THEN -- 1st Correct Score
					CASE 
						WHEN @betteam = (CAST(@hth AS VARCHAR(4)) + ':' + CAST(@hta AS VARCHAR(4))) THEN 1
						WHEN @betteam = '4:0' AND (@hth - @hta) >= 4 THEN 1 -- 4UP for 1st Correct Score
						WHEN @betteam = '0:4' AND (@hth - @hta) <= - 4 THEN 1 -- 4UP for 1st Correct Score
						WHEN @betteam = '5:0' AND (@hth - @hta) >= 5 THEN 1
						WHEN @betteam = '0:5' AND (@hth - @hta) <= - 5 THEN 1
						ELSE - 1
						END
				WHEN 16 THEN -- HT/FT
					CASE 
						WHEN @betteam = CASE 
								WHEN @hth = @hta THEN '0'
								WHEN @hth > @hta THEN '1'
								ELSE '2'
								END + ':' + CASE 
								WHEN @fth = @fta THEN '0'
								WHEN @fth > @fta THEN '1'
								ELSE '2'
								END THEN 1
						ELSE - 1
						END
				/*
				WHEN 16 THEN -- HT/FT
					CASE 
						WHEN @betteam = CASE
											WHEN @hth > @hta THEN 'H' + CASE
																			WHEN @fth > @fta THEN 'H'
																			WHEN @fth = @fta THEN 'D'
																			WHEN @fth < @fta THEN 'A'
																			ELSE NULL
																		END
											WHEN @hth = @hta THEN 'D' + CASE
																			WHEN @fth > @fta THEN 'H'
																			WHEN @fth = @fta THEN 'D'
																			WHEN @fth < @fta THEN 'A'
																			ELSE NULL
																		END
											WHEN @hth < @hta THEN 'A' + CASE
																			WHEN @fth > @fta THEN 'H'
																			WHEN @fth = @fta THEN 'D'
																			WHEN @fth < @fta THEN 'A'
																			ELSE NULL
																		END
									END THEN 1
						ELSE - 1
						END
				*/
				WHEN 17 THEN  
					CASE @betteam
						WHEN N'h' THEN (@hdp2 - @hdp1) + (@fth - @hth - @livehomescore) - (@fta - @hta - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (@fth - @hth - @livehomescore) + (@fta - @hta - @liveawayscore)
						END
				WHEN 18 THEN  
					CASE @betteam
						WHEN N'o' THEN (@fth + @fta - @hth - @hta) - @hdp1
						WHEN N'u' THEN @hdp1 - (@fth + @fta - @hth - @hta)
						END
				WHEN 5 THEN -- 1x2
					CASE 
						WHEN (@betteam = N'1') AND (@fth > @fta) THEN 1
						WHEN (@betteam = N'2') AND (@fta > @fth) THEN 1
						WHEN (@betteam = N'x') AND (@fth = @fta) THEN 1
						ELSE - 1
						END
				WHEN 15 THEN -- 1st 1x2
					CASE 
						WHEN (@betteam = N'1') AND (@hth > @hta) THEN 1
						WHEN (@betteam = N'2') AND (@hta > @hth) THEN 1
						WHEN (@betteam = N'x') AND (@hth = @hta) THEN 1
						ELSE - 1
						END
				WHEN 6 THEN -- Total Goal
					CASE 
						WHEN (CASE 
								WHEN @TennisTotal IS NULL THEN @fth + @fta
								ELSE @TennisTotal END >= cast(left(@betteam, 1) AS INT) AND CASE 
								WHEN @TennisTotal IS NULL THEN @fth + @fta
								ELSE @TennisTotal END <= (CASE 
									WHEN right(@betteam, 1) = 'r' THEN 999
									ELSE cast(right(@betteam, 1) AS INT) END
									)
								) THEN 1
						ELSE - 1
						END
				WHEN 126 THEN -- 1H total goal
					CASE WHEN (
								CASE WHEN @TennisTotal IS NULL THEN @hth + @hta ELSE @TennisTotal END >= CAST(LEFT(@betteam,1) AS int) AND
								CASE WHEN @TennisTotal IS NULL then @hth + @hta ELSE @TennisTotal END <= (
									CASE when RIGHT(@betteam,1)= 'r' then 999 ELSE CAST(RIGHT(@betteam,1)AS int) END 
									)
							) then 1 ELSE -1 END 
				WHEN 13 THEN -- Clean Sheet
					CASE 
						WHEN @betteam = 'hy' AND @fta = 0 THEN 1
						WHEN @betteam = 'hn' AND @fta > 0 THEN 1
						WHEN @betteam = 'ay' AND @fth = 0 THEN 1
						WHEN @betteam = 'an' AND @fth > 0 THEN 1
						ELSE - 1
						END
				WHEN 20 THEN -- Money Line
					CASE @betteam
						WHEN N'h' THEN @fth - @fta
						ELSE @fta - @fth
						END
				WHEN 21 THEN -- 1st Money Line
					CASE @betteam
						WHEN N'h' THEN @hth - @hta
						ELSE @hta - @hth
						END
				WHEN 24 THEN -- Double Chance
					CASE 
						WHEN @betteam = '1X' AND (@fth - @fta) >= 0 THEN 1
						WHEN @betteam = '2X' AND (@fth - @fta) <= 0 THEN 1
						WHEN @betteam = '12' AND (@fth - @fta) <> 0 THEN 1
						ELSE - 1
						END
				WHEN 25 THEN -- Draw No Bet
					CASE 
						WHEN (@fth - @fta) = 0 THEN 0
						WHEN @betteam = 'h' AND (@fth - @fta) > 0 THEN 1
						WHEN @betteam = 'a' AND (@fth - @fta) < 0 THEN 1
						ELSE - 1
						END
				WHEN 26 THEN -- Both/One/Neither team to score
					CASE 
						WHEN @betteam = 'b' AND (@fth > 0 AND @fta > 0) THEN 1
						WHEN @betteam = 'o' AND ((@fth > 0 AND @fta = 0) OR (@fta > 0 AND @fth = 0)) THEN 1
						WHEN @betteam = 'n' AND (@fth = 0 AND @fta = 0) THEN 1
						ELSE - 1
						END
				WHEN 27 THEN -- To win to nil
					CASE 
						WHEN @betteam = 'h' AND (@fth > @fta AND @fta = 0) THEN 1
						WHEN @betteam = 'a' AND (@fta > @fth AND @fth = 0) THEN 1
						ELSE - 1
						END
				WHEN 28 THEN -- 3-way handicap
					CASE 
						WHEN @betteam = '1' AND (@hdp2 - @hdp1 + @fth - @fta) > 0 THEN 1
						WHEN @betteam = '2' AND (@hdp1 - @hdp2 + @fta - @fth) > 0 THEN 1
						WHEN @betteam = 'x' AND ((@hdp1 - @hdp2) - (@fth - @fta)) = 0 THEN 1
						ELSE - 1
						END
				WHEN 121 THEN -- home no bet
					CASE 
						WHEN (@fth - @fta) > 0 THEN 0
						WHEN @betteam = 'x' AND (@fth - @fta) = 0 THEN 1
						WHEN @betteam = 'a' AND (@fth - @fta) < 0 THEN 1
						ELSE - 1
						END
				WHEN 122 THEN -- away no bet
					CASE 
						WHEN (@fth - @fta) < 0 THEN 0
						WHEN @betteam = 'h' AND (@fth - @fta) > 0 THEN 1
						WHEN @betteam = 'x' AND (@fth - @fta) = 0 THEN 1
						ELSE - 1
						END
				WHEN 123 THEN -- draw/no draw
					CASE 
						WHEN @betteam = 'h' AND (@fth - @fta) = 0 THEN 1
						WHEN @betteam = 'a' AND (@fth - @fta) <> 0 THEN 1
						ELSE - 1
						END
				WHEN 133 THEN -- Home To Win Both Halves
					CASE 
						WHEN @betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
						WHEN @betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
						ELSE -1
						END 
				WHEN 134 THEN -- Away To Win Both Halves 
					CASE 
						WHEN @betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
						WHEN @betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
						ELSE -1
						END 
				WHEN 140 THEN -- Highest Scoring Half
					CASE 
						WHEN @betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
						WHEN @betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
						WHEN @betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
						ELSE -1
						END
				WHEN 141 THEN -- Highest Scoring Half Home Team
					CASE 
						WHEN @betteam = '1h' AND @hth > (@fth - @hth) THEN 1
						WHEN @betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
						WHEN @betteam = '2h' AND @hth < (@fth - @hth) THEN 1
						ELSE -1
						END 
				WHEN 142 THEN -- Highest Scoring Half Away Team
					CASE 
						WHEN @betteam = '1h' AND @hta > (@fta - @hta) THEN 1
						WHEN @betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
						WHEN @betteam = '2h' AND @hta < (@fta - @hta) THEN 1
						ELSE -1
						END 
				WHEN 145 THEN -- Both Teams To Score
					CASE 
						WHEN @betteam = 'y' AND (@fth > 0) AND (@fta > 0) THEN 1
						WHEN @betteam = 'n' AND ((@fth = 0) OR (@fta = 0)) THEN 1
						ELSE -1
						END 
				WHEN 146 THEN -- 2nd Half Both Teams To Score
					CASE 
						WHEN @betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
						WHEN @betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
						ELSE -1
						END
				WHEN 147 THEN -- Home To Score In Both Halves 
					CASE 
						WHEN @betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
						WHEN @betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
						ELSE -1
						END
				WHEN 148 THEN -- Away To Score In Both Halves 
					CASE 
						WHEN @betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
						WHEN @betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
						ELSE -1
						END
				WHEN 149 THEN -- Home To Win Either Half 
					CASE 
						WHEN @betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
						WHEN @betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
						ELSE -1
						END
				WHEN 150 THEN -- Away To Win Either Half
					CASE 
						WHEN @betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
						WHEN @betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
						ELSE -1
						END 
				WHEN 151 THEN -- 1st Half Double Chance
					CASE 
						WHEN @betteam = '1x' AND (@hth - @hta) >= 0 THEN 1
						WHEN @betteam = '2x' AND (@hta - @hth) >= 0 THEN 1
						WHEN @betteam = '12' AND (@hth - @hta) <> 0 THEN 1
						ELSE -1
						END
				WHEN 152 THEN -- Half Time/Full Time Correct Score
					CASE 
						WHEN @betteam = @csHTFT THEN 1
						ELSE -1
						END 
				--WHEN 135 THEN -- Penalty Shootout
				--	CASE 
				--		WHEN @betteam = @penaltyshootout THEN 1
				--		ELSE -1
				--		END        
				WHEN 128 THEN -- HT/FT Odd/Even
					CASE
						WHEN @betteam = 'oo' AND (@hth + @hta) % 2 = 1 AND (@fth + @fta) % 2 = 1 THEN 1
						WHEN @betteam = 'oe' AND (@hth + @hta) % 2 = 1 AND (@fth + @fta) % 2 = 0 THEN 1
						WHEN @betteam = 'eo' AND (@hth + @hta) % 2 = 0 AND (@fth + @fta) % 2 = 1 THEN 1
						WHEN @betteam = 'ee' AND (@hth + @hta) % 2 = 0 AND (@fth + @fta) % 2 = 0 THEN 1
						ELSE -1
						END                
				WHEN 129 THEN -- 1H Exact Goal
					CASE
						WHEN @betteam = '5&over' AND (@hth + @hta) >= 5 THEN 1
						WHEN @betteam <> '5&over' AND cast(@betteam as INT) = (@hth + @hta) THEN 1
						ELSE -1
						END
				WHEN 130 THEN --  Exact Goal
					CASE 
						WHEN @betteam = '7&over' AND (@fth + @fta) >= 7 THEN 1
						WHEN @betteam <> '7&over' AND cast(@betteam AS INT) = (@fth + @fta) THEN 1
						ELSE -1
						END
				WHEN 131 THEN -- Home Team Total Goal 
					CASE
						WHEN cast(LEFT(@betteam,1) as INT) <= @fth 
							AND case when right(@betteam,1) = 'r' 
										then 999 
									 else cast(RIGHT(@betteam,1) as int) 
									 END >= @fth THEN 1
						ELSE -1
						END        
				WHEN 132 THEN -- Away Team Total Goal
					CASE 
						WHEN cast(left(@betteam,1) as int) <= @fta    
							AND case when right(@betteam,1) = 'r'
										then 999
									 else cast(right(@betteam,1) as int)
									 END >= @fta THEN 1
						ELSE -1
						END
				WHEN 136 THEN -- 1H Home Team Odd/Even            
					CASE    
						WHEN @betteam = 'o' and (@hth % 2) = 1 THEN 1
						WHEN @betteam = 'e' and (@hth % 2) = 0 THEN 1
						ELSE -1
						END
				WHEN 137 THEN -- Home Team Odd/Even
					CASE
						WHEN @betteam = 'o' and (@fth % 2) = 1 THEN 1
						WHEN @betteam = 'e' and (@fth % 2) = 0 THEN 1
						ELSE -1
						END 
				WHEN 138 THEN -- 1H Away Team Odd/Even             
					CASE    
						WHEN @betteam = 'o' and (@hta % 2) = 1 THEN 1
						WHEN @betteam = 'e' and (@hta % 2) = 0 THEN 1
						ELSE -1
						END
				WHEN 139 THEN -- Away Team Odd/Even
					CASE
						WHEN @betteam = 'o' and (@fta % 2) = 1 THEN 1
						WHEN @betteam = 'e' and (@fta % 2) = 0 THEN 1
						ELSE -1
						END 
				WHEN 143 THEN -- 1H Result/Total Goals
					CASE
						WHEN @betteam = 'ho' and (@hth - @hta) > 0 THEN (@hth+ @hta) - @hdp1
						WHEN @betteam = 'hu' and (@hth - @hta) > 0 THEN @hdp1 - (@hth+ @hta) 
						WHEN @betteam = 'ao' and (@hth - @hta) < 0 THEN (@hth+ @hta) - @hdp1
						WHEN @betteam = 'au' and (@hth - @hta) < 0 THEN @hdp1 - (@hth+ @hta) 
						WHEN @betteam = 'do' and (@hth - @hta) = 0 THEN (@hth+ @hta) - @hdp1
						WHEN @betteam = 'du' AND (@hth - @hta) = 0 THEN @hdp1 - (@hth+ @hta) 
						ELSE -1
						END        
				WHEN 144 THEN -- Result/Total Goals
					CASE
						WHEN @betteam = 'ho' and (@fth - @fta) > 0 THEN (@fth+ @fta) - @hdp1
						WHEN @betteam = 'hu' and (@fth - @fta) > 0 THEN @hdp1 - (@fth+ @fta)
						WHEN @betteam = 'ao' and (@fth - @fta) < 0 THEN (@fth+ @fta) - @hdp1
						WHEN @betteam = 'au' and (@fth - @fta) < 0 THEN @hdp1 - (@fth+ @fta)
						WHEN @betteam = 'do' and (@fth - @fta) = 0 THEN (@fth+ @fta) - @hdp1
						WHEN @betteam = 'du' AND (@fth - @fta) = 0 THEN @hdp1 - (@fth+ @fta)
						ELSE -1
						END        
				
				-- Betradar 2 Manual @bettype 
				WHEN 157 THEN 
					CASE WHEN @betteam =N'h' AND ((@fth + @fta) &1) = 1 THEN 1 
						 WHEN @betteam =N'a' AND ((@fth + @fta) &1) = 0 THEN 1 
						 ELSE - 1 
						 END 
				WHEN 159 THEN 
					CASE WHEN @betteam LIKE 'G[0-5]' AND ((@fth + @fta) = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 WHEN @betteam ='G6' AND ((@fth + @fta) >=CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 ELSE - 1 
						 END 
				WHEN 161 THEN 
					CASE WHEN @betteam LIKE 'G[0-2]' AND (@fth = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 WHEN @betteam ='G3' AND (@fth >=CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 ELSE - 1 
						 END 
				WHEN 162 THEN 
					CASE WHEN @betteam LIKE 'G[0-2]' AND (@fta = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 WHEN @betteam ='G3' AND (@fta >=CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 ELSE - 1 
						 END 
				WHEN 163 THEN 
					CASE WHEN @betteam = 'ho' AND (@fth -@fta) > 0 THEN (@fth + @fta) - @hdp1
						 WHEN @betteam = 'hu' AND (@fth -@fta) > 0 THEN @hdp1 - (@fth + @fta)
						 WHEN @betteam = 'ao' AND (@fth -@fta) < 0 THEN (@fth + @fta) - @hdp1
						 WHEN @betteam = 'au' AND (@fth -@fta) < 0 THEN @hdp1 - (@fth + @fta)
						 WHEN @betteam = 'do' AND (@fth -@fta) = 0 THEN (@fth + @fta) - @hdp1
						 WHEN @betteam = 'du' AND (@fth -@fta) = 0 THEN @hdp1 - (@fth + @fta)    
						 ELSE -1 
						 END 
				WHEN 165 THEN 
					CASE 
						WHEN @betteam = (CAST(@hth AS VARCHAR(4)) + ':' + CAST(@hta AS VARCHAR(4))) THEN 1
						ELSE - 1
						END                
				WHEN 166 THEN 
					CASE 
						WHEN @betteam = (CAST(@fth AS VARCHAR(4)) + ':' + CAST(@fta AS VARCHAR(4))) THEN 1
						ELSE - 1
						END    
				WHEN 167 THEN 
					CASE 
						WHEN (@betteam = N'1') AND (@fth > @fta) THEN 1
						WHEN (@betteam = N'2') AND (@fta > @fth) THEN 1
						WHEN (@betteam = N'x') AND (@fth = @fta) THEN 1
						ELSE - 1
						END
				WHEN 170 THEN        
					CASE 
						WHEN @betteam =N'h' AND (@fth > 0 AND @fta = 0) THEN 1
						WHEN @betteam =N'a' AND (@fth = 0 AND @fta > 0) THEN 1
						WHEN @betteam =N'b' AND (@fth > 0 AND @fta > 0) THEN 1
						WHEN @betteam =N'n' AND (@fth = 0 AND @fta = 0) THEN 1
						ELSE -1
						END 
				WHEN 171 THEN    
					CASE 
						WHEN @betteam = 'h1' AND (@fth -@fta) = 1 THEN 1        --171 
						WHEN @betteam = 'h2' AND (@fth -@fta) = 2 THEN 1 
						WHEN @betteam = 'h3' AND (@fth -@fta) >=3 THEN 1 
						WHEN @betteam = 'd' AND (@fth -@fta) =0 THEN 1 
						WHEN @betteam = 'a1' AND (@fth -@fta) =-1 THEN 1 
						WHEN @betteam = 'a2' AND (@fth -@fta) =-2 THEN 1 
						WHEN @betteam = 'a3' AND (@fth -@fta)<=-3 THEN 1 
						ELSE - 1                    
						END
				WHEN 172 THEN    
					CASE 
						WHEN @betteam = 'HH' AND @FirstGoal='H' AND (@fth - @fta) >0 THEN 1 
						WHEN @betteam = 'DH' AND @FirstGoal='H' AND (@fth - @fta) =0 THEN 1
						WHEN @betteam = 'AH' AND @FirstGoal='H' AND (@fth - @fta) <0 THEN 1
						WHEN @betteam = 'HA' AND @FirstGoal='A' AND (@fth - @fta) >0 THEN 1
						WHEN @betteam = 'DA' AND @FirstGoal='A' AND (@fth - @fta) =0 THEN 1
						WHEN @betteam = 'AA' AND @FirstGoal='A' AND (@fth - @fta) <0 THEN 1
						WHEN @betteam = 'NO' AND @fth =0 AND @fta= 0 THEN 1
						ELSE - 1
						END
				WHEN 177 THEN    
					CASE 
						WHEN (@betteam = N'1') AND ((@fth -@hth) -(@fta - @hta))>0 THEN 1
						WHEN (@betteam = N'2') AND ((@fth -@hth) -(@fta - @hta))<0 THEN 1
						WHEN (@betteam = N'x') AND ((@fth -@hth) -(@fta - @hta))=0 THEN 1
						ELSE - 1
						END
				WHEN 178 THEN 
					CASE @betteam 
						WHEN N'o' THEN ((@fth + @fta) - (@hth + @hta)) - @hdp1 
						WHEN N'u' THEN @hdp1 - ((@fth + @fta) - (@hth + @hta)) 
						END
				WHEN 179 THEN 
					CASE 
						WHEN @betteam LIKE 'G[0-3]' AND (@hth + @hta) = CAST(RIGHT(@betteam,1)AS TINYINT) THEN 1 
						WHEN @betteam ='G4' AND (@hth + @hta) >=CAST(RIGHT(@betteam,1)AS TINYINT) THEN 1 
						ELSE -1
						END 
				WHEN 181 THEN 
					CASE 
						 WHEN @betteam LIKE 'G[0-2]' AND (@hth = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 WHEN @betteam ='G3' AND (@hth >=CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 ELSE - 1 
						 END 
				WHEN 182 THEN 
					CASE 
						 WHEN @betteam LIKE 'G[0-2]' AND (@hta = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 WHEN @betteam ='G3' AND (@hta >=CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						 ELSE - 1 
						 END 
				WHEN 183 THEN 
					CASE 
						WHEN @betteam =N'h' THEN (@hdp2 - @hdp1) + ((@fth - @hth) - @livehomescore) - ((@fta - @hta) - @liveawayscore)
						WHEN @betteam =N'a' THEN (@hdp1 - @hdp2) - ((@fth - @hth) - @livehomescore) + ((@fta - @hta) - @liveawayscore)
						END
				WHEN 184 THEN 
					CASE WHEN @betteam =N'o' AND ((@fth + @fta - @hth - @hta) &1) = 1 THEN 1 
						 WHEN @betteam =N'e' AND ((@fth + @fta - @hth - @hta) &1) = 0 THEN 1 
						 ELSE - 1 
						 END 
				WHEN 185 THEN -- Draw No Bet
					CASE 
						WHEN ((@fth -@hth) -(@fta - @hta)) = 0 THEN 0
						WHEN @betteam = 'h' AND ((@fth -@hth) -(@fta - @hta)) > 0 THEN 1
						WHEN @betteam = 'a' AND ((@fth -@hth) -(@fta - @hta)) < 0 THEN 1
						ELSE - 1
						END
				WHEN 186 THEN -- Double Chance
					CASE 
						WHEN @betteam = 'HD' AND ((@fth -@hth) -(@fta - @hta)) >= 0 THEN 1
						WHEN @betteam = 'DA' AND ((@fth -@hth) -(@fta - @hta)) <= 0 THEN 1
						WHEN @betteam = 'HA' AND ((@fth -@hth) -(@fta - @hta)) <> 0 THEN 1
						ELSE - 1
						END
				WHEN 187 THEN
					CASE 
						WHEN @betteam LIKE 'G[0-1]' AND ((@fth + @fta) - (@hth + @hta)) = CAST(RIGHT(@betteam,1)AS TINYINT) THEN 1
						WHEN @betteam ='G2'AND ((@fth + @fta) - (@hth + @hta)) >=CAST(RIGHT(@betteam,1)AS TINYINT) THEN 1
						ELSE - 1
						END
				WHEN 188 THEN 
					CASE 
						WHEN @betteam = 'Y' AND @hth > 0 AND @hta > 0 THEN 1 
						WHEN @betteam = 'N' AND (@hth = 0 OR @hta = 0) THEN 1 
						ELSE - 1
						END
				WHEN 189 THEN    
					CASE 
						WHEN @betteam ='y' AND (@hth + @hta - 1.5) > 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)>0 THEN 1 
						WHEN @betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)<=0) THEN 1 
						ELSE -1 
						END  
				WHEN 190 THEN -- Both Halves Under 1.5 Yes/No  [190]
					CASE 
						WHEN @betteam ='y' AND (@hth + @hta - 1.5) < 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)<0 THEN 1  
						WHEN @betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)>=0) THEN 1 
						ELSE -1 
					END    
				WHEN 191 THEN 
					CASE 
						WHEN (@hth - @hta) = 0 THEN 0
						WHEN @betteam = 'h' AND (@hth - @hta) > 0 THEN 1
						WHEN @betteam = 'a' AND (@hth - @hta) < 0 THEN 1
						ELSE -1
						END
				WHEN 401 THEN --Home Team Over/Under
					CASE
						WHEN @betteam = 'o' THEN @fth - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @fth
						ELSE -1 END
				WHEN 461 THEN --Home Team Over/Under (dec)
					CASE
						WHEN @betteam = 'o' THEN @fth - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @fth
						ELSE -1 END
				WHEN 402 THEN --Away Team Over/Under
					CASE
						WHEN @betteam = 'o' THEN @fta - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @fta
						ELSE -1 END
				WHEN 462 THEN --Away Team Over/Under (dec)
					CASE
						WHEN @betteam = 'o' THEN @fta - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @fta
						ELSE -1 END
				WHEN 403 THEN --1H Home Team Over/Under
					CASE
						WHEN @betteam = 'o' THEN @hth - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @hth
						ELSE -1 END
				WHEN 463 THEN --1H Home Team Over/Under (dec)
					CASE
						WHEN @betteam = 'o' THEN @hth - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @hth
						ELSE -1 END
				WHEN 404 THEN --1H Away Team Over/Under
					CASE
						WHEN @betteam = 'o' THEN @hta - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @hta
						ELSE -1 END
				WHEN 464 THEN --1H Away Team Over/Under (dec)
					CASE
						WHEN @betteam = 'o' THEN @hta - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @hta
						ELSE -1 END
				WHEN 405 THEN --2H Correct Score
					CASE
						WHEN @betteam = CAST((@fth - @hth) AS NVARCHAR(6)) + ':' + CAST((@fta - @hta) AS NVARCHAR(6)) THEN 1
						WHEN @betteam = 'AOS' --Any Other Scores
							AND CHARINDEX(CAST((@fth - @hth) AS NVARCHAR(6)) + ':' + CAST((@fta - @hta) AS NVARCHAR(6)), @transdesc) = 0 THEN 1
						ELSE -1    END
				WHEN 406 THEN --Exact Total Goals
					CASE 
						WHEN @betteam LIKE 'G[0-5]' AND ((@fth + @fta) = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						WHEN @betteam ='G6' AND ((@fth + @fta) >=CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						ELSE -1 
						END 
				WHEN 407 THEN --Exact Home Team Goals
					CASE 
						WHEN @betteam LIKE 'G[0-2]' AND (@fth = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						WHEN @betteam ='G3' AND (@fth >= CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						ELSE - 1 
						END 
				WHEN 408 THEN --Winning Margin    
					CASE 
						WHEN @betteam = 'H1' AND (@fth - @fta) = 1 THEN 1
						WHEN @betteam = 'H2' AND (@fth - @fta) = 2 THEN 1 
						WHEN @betteam = 'H3' AND (@fth - @fta) >= 3 THEN 1
						WHEN @betteam = 'D' AND (@fth - @fta) = 0 AND (@fth + @fta) <> 0 THEN 1
						WHEN @betteam = 'A1' AND (@fth - @fta) = -1 THEN 1 
						WHEN @betteam = 'A2' AND (@fth - @fta) = -2 THEN 1 
						WHEN @betteam = 'A3' AND (@fth - @fta) <= -3 THEN 1 
						WHEN @betteam = 'NG' AND @fth = 0 AND @fta = 0 THEN 1
						ELSE - 1
						END
				WHEN 409 THEN --Exact Away Team Goals
					CASE 
						WHEN @betteam LIKE 'G[0-2]' AND (@fta = CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						WHEN @betteam ='G3' AND (@fta >=CAST(RIGHT(@betteam,1)AS TINYINT)) THEN 1 
						ELSE - 1 
						END 
				WHEN 410 THEN --1H Double Chance    
					CASE 
						WHEN @betteam = '1x' AND (@hth - @hta) >= 0 THEN 1
						WHEN @betteam = '12' AND (@hth - @hta) <> 0 THEN 1 
						WHEN @betteam = '2x' AND (@hth - @hta) <= 0 THEN 1
						ELSE - 1                    
						END         
				WHEN 411 THEN --1H Draw No Bet
					CASE 
						WHEN (@hth - @hta) = 0 THEN 0
						WHEN @betteam = 'h' AND (@hth - @hta) > 0 THEN 1
						WHEN @betteam = 'a' AND (@hth - @hta) < 0 THEN 1
						ELSE -1
						END
				WHEN 412 THEN --Exact 1st Half Goal
					CASE 
						WHEN @betteam <> '3-over' AND CAST(@betteam AS INT) = (@hth + @hta) THEN 1
						WHEN @betteam = '3-over' AND (@hth + @hta) >= 3 THEN 1
						ELSE -1
						END
				WHEN 413 THEN --Correct Score (aos)
					CASE 
						WHEN @betteam = CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR) THEN 1
						WHEN @betteam = 'AOS'
							AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), @transdesc) = 0 THEN 1
						ELSE -1
						END
				WHEN 414 THEN --1H Correct Score (aos)
					CASE 
						WHEN @betteam = CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR) THEN 1
						WHEN @betteam = 'AOS'
							AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), @transdesc) = 0 THEN 1
						ELSE -1
						END
				WHEN 415 THEN    
					CASE 
						WHEN @betteam = 'HH' AND @FirstGoal='H' AND (@fth - @fta) >0 THEN 1 
						WHEN @betteam = 'DH' AND @FirstGoal='H' AND (@fth - @fta) =0 THEN 1
						WHEN @betteam = 'AH' AND @FirstGoal='H' AND (@fth - @fta) <0 THEN 1
						WHEN @betteam = 'HA' AND @FirstGoal='A' AND (@fth - @fta) >0 THEN 1
						WHEN @betteam = 'DA' AND @FirstGoal='A' AND (@fth - @fta) =0 THEN 1
						WHEN @betteam = 'AA' AND @FirstGoal='A' AND (@fth - @fta) <0 THEN 1
						WHEN @betteam = 'NO' AND @fth =0 AND @fta= 0 THEN 1
						ELSE - 1
						END
				WHEN 416 THEN -- Half Time/Full Time Correct Score (own)
					CASE 
						WHEN CHARINDEX('AOS',@betteam) = 0 THEN CASE
																	WHEN @betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) THEN 1
																	ELSE -1
																END
						WHEN CHARINDEX('AOS/AOS',@betteam) > 0 THEN CASE
																		WHEN CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),ip.ExcludingHTChoice) = 0 AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),ip.ExcludingFTChoice) = 0 THEN 1
																		ELSE -1
																	END
						WHEN CHARINDEX('/AOS',@betteam) > 0 THEN CASE
																	WHEN @betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/AOS' AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),ip.ExcludingFTChoice) = 0 THEN 1
																	ELSE -1
																END
						WHEN CHARINDEX('AOS/',@betteam) > 0 THEN CASE
																	WHEN @betteam = 'AOS/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) AND CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),ip.ExcludingHTChoice) = 0 THEN 1
																	ELSE -1
																END
						ELSE -1
					END
				WHEN 417 THEN
					CASE
						WHEN @betteam = CASE 
											WHEN @fth > 0 AND @fta > 0 THEN CASE
																				WHEN @fth > @fta THEN 'YH'
																				WHEN @fth < @fta THEN 'YA'
																				ELSE 'YD'
																			END
											ELSE CASE 
													WHEN @fth > @fta THEN 'NH'
													WHEN @fth < @fta THEN 'NA'
													ELSE 'ND'
												 END
										END THEN 1
						ELSE - 1
					END
				WHEN 418 THEN
					CASE
						WHEN @betteam = CASE 
											WHEN @fth + @fta > @hdp1 THEN CASE 
																			WHEN @fth > 0 AND @fta > 0 THEN 'Y'
																			ELSE 'N'
																		 END + 'O'
											WHEN @fth + @fta < @hdp1 THEN CASE 
																			WHEN @fth > 0 AND @fta > 0 THEN 'Y'
																			ELSE 'N'
																		 END + 'U'
											ELSE NULL
										END THEN 1
						ELSE -1
					END
				WHEN 419 THEN
					CASE
						WHEN @betteam = CASE
											WHEN @hth + @hta > 0 THEN '1H'
											WHEN @fth + @fta - (@hth + @hta) > 0 THEN '2H'
											ELSE 'N'
									   END THEN 1
						ELSE -1
					END
				WHEN 420 THEN
					CASE
						WHEN @betteam = CASE
											WHEN @hth > 0 THEN '1H'
											WHEN @fth - @hth > 0 THEN '2H'
											ELSE 'N'
										END THEN 1
						ELSE -1
					END
				WHEN 421 THEN
					CASE
						WHEN @betteam = CASE 
											WHEN @hta > 0 THEN '1H'
											WHEN @fta - @hta > 0 THEN '2H'
											ELSE 'N'
										END THEN 1
						ELSE -1
					END        
				WHEN 422 THEN
					CASE
						WHEN @betteam = CASE 
											WHEN (@home_firstteam2goals > 0 AND @away_firstteam2goals = 0) OR (@home_firstteam2goals <> 0 AND @home_firstteam2goals - @away_firstteam2goals < 0) THEN 'H'
											WHEN (@away_firstteam2goals > 0 AND @home_firstteam2goals = 0) OR (@away_firstteam2goals <> 0 AND @away_firstteam2goals - @home_firstteam2goals < 0) THEN 'A'
											ELSE 'N'
										END THEN 1
						ELSE -1
					END
				WHEN 423 THEN
					CASE
						WHEN @betteam = CASE
											WHEN (@home_firstteam3goals > 0 AND @away_firstteam3goals = 0) OR (@home_firstteam3goals <> 0 AND @home_firstteam3goals - @away_firstteam3goals < 0) THEN 'H'
											WHEN (@away_firstteam3goals > 0 AND @home_firstteam3goals = 0) OR (@away_firstteam3goals <> 0 AND @away_firstteam3goals - @home_firstteam3goals < 0) THEN 'A'
											ELSE 'N'
									   END THEN 1
						ELSE -1
					END
				--WHEN 424 THEN
				--	CASE 
				--		WHEN @betteam = @FirstGoalMethod THEN 1
				--		ELSE -1
				--	END	
				WHEN 425 THEN
					CASE
						WHEN @betteam = @WinFromBehind THEN 1
						ELSE -1
					END
				WHEN 426 THEN
					CASE
						WHEN @betteam = CASE 
											WHEN @hth - @hta = 1 THEN 'H1'
											WHEN @hth - @hta >= 2 THEN 'H2+'
											WHEN @hth - @hta = -1 THEN 'A1'
											WHEN @hth - @hta <= -2 THEN 'A2+'
											WHEN @hth + @hta = 0 THEN 'NG'
											WHEN @hth - @hta = 0 THEN 'D'
											ELSE NULL
									   END THEN 1
						ELSE -1
					END
				WHEN 427 THEN 
					CASE 
						WHEN @betteam = 'Y' AND @hth > 0 AND @hta > 0 THEN 1 
						WHEN @betteam = 'N' AND (@hth = 0 OR @hta = 0) THEN 1 
						ELSE - 1
						END
				WHEN 428 THEN 
					CASE 
						WHEN @betteam =N'o' AND ((@fth + @fta - @hth - @hta) &1) = 1 THEN 1 
						WHEN @betteam =N'e' AND ((@fth + @fta - @hth - @hta) &1) = 0 THEN 1 
						ELSE - 1 
					END 
				WHEN 429 THEN
					CASE
						WHEN @betteam = CASE 
											WHEN @fth - @hth + @fta - @hta >=3 THEN '3-Over'
											ELSE CAST((@fth - @hth + @fta - @hta) AS NVARCHAR(10)) 
									   END THEN 1
						ELSE -1
					END
				WHEN 430 THEN    
					CASE 
						WHEN (@betteam = N'1') AND ((@fth -@hth) -(@fta - @hta))>0 THEN 1
						WHEN (@betteam = N'2') AND ((@fth -@hth) -(@fta - @hta))<0 THEN 1
						WHEN (@betteam = N'x') AND ((@fth -@hth) -(@fta - @hta))=0 THEN 1
						ELSE - 1
						END
				WHEN 431 THEN -- Double Chance
					CASE 
						WHEN @betteam = 'HD' AND ((@fth -@hth) -(@fta - @hta)) >= 0 THEN 1
						WHEN @betteam = 'DA' AND ((@fth -@hth) -(@fta - @hta)) <= 0 THEN 1
						WHEN @betteam = 'HA' AND ((@fth -@hth) -(@fta - @hta)) <> 0 THEN 1
						ELSE - 1
						END
				WHEN 432 THEN -- Draw No Bet
					CASE 
						WHEN ((@fth -@hth) -(@fta - @hta)) = 0 THEN 0
						WHEN @betteam = 'h' AND ((@fth -@hth) -(@fta - @hta)) > 0 THEN 1
						WHEN @betteam = 'a' AND ((@fth -@hth) -(@fta - @hta)) < 0 THEN 1
						ELSE - 1
						END
				WHEN 433 THEN -- 2nd Half Both Teams To Score
					CASE 
						WHEN @betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
						WHEN @betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
						ELSE -1
						END
				WHEN 434 THEN    
					CASE 
						WHEN @betteam ='y' AND (@hth + @hta - 1.5) > 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)>0 THEN 1 
						WHEN @betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)<=0) THEN 1 
						ELSE -1 
						END 
				WHEN 435 THEN -- Both Halves Under 1.5 Yes/No  [190]
					CASE 
						WHEN @betteam ='y' AND (@hth + @hta - 1.5) < 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)<0 THEN 1  
						WHEN @betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)>=0) THEN 1 
						ELSE -1 
					END    
				WHEN 436 THEN -- Home To Score In Both Halves 
					CASE 
						WHEN @betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
						WHEN @betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
						ELSE -1
						END
				WHEN 437 THEN -- Away To Score In Both Halves 
					CASE 
						WHEN @betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
						WHEN @betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
						ELSE -1
						END
				WHEN 438 THEN -- Home To Win Both Halves
					CASE 
						WHEN @betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
						WHEN @betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
						ELSE -1
						END 
				WHEN 439 THEN -- Away To Win Both Halves 
					CASE 
						WHEN @betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
						WHEN @betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
						ELSE -1
						END 
				WHEN 440 THEN -- Home To Win Either Half 
					CASE 
						WHEN @betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
						WHEN @betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
						ELSE -1
						END
				WHEN 441 THEN -- Away To Win Either Half
					CASE 
						WHEN @betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
						WHEN @betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
						ELSE -1
						END
				WHEN 442 THEN -- Highest Scoring Half
					CASE 
						WHEN @betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
						WHEN @betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
						WHEN @betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
						ELSE -1
						END
				WHEN 443 THEN -- Highest Scoring Half Home Team
					CASE 
						WHEN @betteam = '1h' AND @hth > (@fth - @hth) THEN 1
						WHEN @betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
						WHEN @betteam = '2h' AND @hth < (@fth - @hth) THEN 1
						ELSE -1
						END 
				WHEN 444 THEN -- Highest Scoring Half Away Team
					CASE 
						WHEN @betteam = '1h' AND @hta > (@fta - @hta) THEN 1
						WHEN @betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
						WHEN @betteam = '2h' AND @hta < (@fta - @hta) THEN 1
						ELSE -1
						END
				WHEN 445 THEN
					CASE 
						WHEN @betteam = CASE
											WHEN @hth > 0 AND @hta > 0 THEN CASE
																					WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'YY'
																					ELSE 'YN'
																			END
											ELSE CASE 
														WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'NY'
														ELSE 'NN'
												 END
									   END THEN 1
						ELSE -1
					END 
				WHEN 446 THEN
					CASE
						WHEN @betteam = CASE
											WHEN @hth > 0 THEN CASE 
																	WHEN @fth - @hth > 0 THEN 'YY'
																	ELSE 'YN'
															   END
											ELSE CASE
														WHEN @fth - @hth > 0 THEN 'NY'
														ELSE 'NN'
												 END
									  END THEN 1
						ELSE -1
					END
				WHEN 447 THEN
					CASE
						WHEN @betteam = CASE
											WHEN @hta > 0 THEN CASE 
																	WHEN @fta - @hta > 0 THEN 'YY'
																	ELSE 'YN'
															   END
											ELSE CASE
														WHEN @fta - @hta > 0 THEN 'NY'
														ELSE 'NN'
												 END
									  END THEN 1
						ELSE -1
					END
				WHEN 501 THEN --Match Winner
					CASE 
						WHEN @betteam = 'h' AND @fth > @fta THEN 1
						WHEN @betteam = 'a' AND @fth < @fta THEN 1
						WHEN @fth = @fta THEN 0
						ELSE -1
						END
				-- Tennis New bet types         
				WHEN 153 THEN -- Match Games Handicap
					CASE @betteam 
						WHEN N'h' THEN (@hdp2 - @hdp1) + (@TotalGameHomeMatch - @livehomescore) - (@TotalGameAwayMatch - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (@TotalGameHomeMatch - @livehomescore) + (@TotalGameAwayMatch - @liveawayscore)
						END 
				WHEN 154 THEN -- Set x Winner
					CASE @betteam 
						WHEN N'h' THEN (ip.TotalGameHomeSetx - ip.TotalGameAwaySetx)
						WHEN N'a' THEN (ip.TotalGameAwaySetx - ip.TotalGameHomeSetx)
						END 
				WHEN 155 THEN -- Set x Game Handicap
					CASE @betteam
						WHEN N'h' THEN (@hdp2 - @hdp1) + (ip.TotalGameHomeSetx - @livehomescore) - (ip.TotalGameAwaySetx - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (ip.TotalGameHomeSetx - @livehomescore) + (ip.TotalGameAwaySetx - @liveawayscore)
						END
				WHEN 156 THEN --Set x Total Games Over/Under 
					CASE @betteam 
						WHEN N'o' THEN (ip.TotalGameHomeSetx + ip.TotalGameAwaySetx) - @hdp1 
						WHEN N'u' THEN @hdp1 - (ip.TotalGameHomeSetx + ip.TotalGameAwaySetx) 
						END
				-- Tennis Sporting Solution 
				WHEN 1301 THEN -- Match Winner 
					CASE @betteam
						WHEN N'h' THEN (@hdp2 - @hdp1) + (@fth - @livehomescore) - (@fta - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (@fth - @livehomescore) + (@fta - @liveawayscore)
						END
				WHEN 1302 THEN -- Match Correct Score 
					CASE 
						WHEN @betteam = (CAST(@fth AS VARCHAR(4)) + CAST(@fta AS VARCHAR(4))) THEN 1
						ELSE - 1
						END
				WHEN 1303 THEN -- Set Handicap 
					CASE @betteam
						WHEN N'h' THEN (@hdp2 - @hdp1) + (@fth - @livehomescore) - (@fta - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (@fth - @livehomescore) + (@fta - @liveawayscore)
						END
				WHEN 1305 THEN -- Match Total Games Odd/Even
					CASE WHEN @betteam = N'h' AND (@TotalGameHomeMatch + @TotalGameAwayMatch)%2 = 1 THEN 1 
						 WHEN @betteam = N'a' AND (@TotalGameHomeMatch + @TotalGameAwayMatch)%2 = 0 THEN 1 
						 ELSE - 1 
						 END 
				WHEN 1306 THEN -- Match Total Games Over/Under - 1306
					CASE @betteam 
						WHEN N'h' THEN  (@TotalGameHomeMatch + @TotalGameAwayMatch) - @hdp1 
						WHEN N'a' THEN  @hdp1 - (@TotalGameHomeMatch + @TotalGameAwayMatch) 
						END 
				WHEN 1308 THEN  -- Match Games Handicap - 1308
					CASE @betteam 
						WHEN N'h' THEN (@hdp2 - @hdp1) + (@TotalGameHomeMatch - @livehomescore) - (@TotalGameAwayMatch - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (@TotalGameHomeMatch - @livehomescore) + (@TotalGameAwayMatch - @liveawayscore)
						END 
				WHEN 1311 THEN -- Set x Winner - 1311
					CASE @betteam 
						WHEN N'h' THEN (ip.TotalGameHomeSetx - ip.TotalGameAwaySetx)
						WHEN N'a' THEN (ip.TotalGameAwaySetx - ip.TotalGameHomeSetx)
						END 
				WHEN 1312 THEN --Set x Total Games Over/Under - 1312
					CASE @betteam 
						WHEN N'o' THEN (ip.TotalGameHomeSetx + ip.TotalGameAwaySetx) - @hdp1 
						WHEN N'u' THEN @hdp1 - (ip.TotalGameHomeSetx + ip.TotalGameAwaySetx) 
						END
				WHEN 1316 THEN -- Set x Game Handicap
					CASE @betteam
						WHEN N'h' THEN (@hdp2 - @hdp1) + (ip.TotalGameHomeSetx - @livehomescore) - (ip.TotalGameAwaySetx - @liveawayscore)
						WHEN N'a' THEN (@hdp1 - @hdp2) - (ip.TotalGameHomeSetx - @livehomescore) + (ip.TotalGameAwaySetx - @liveawayscore)
						END
				WHEN 1317 THEN -- Set x Correct Score
					CASE 
						WHEN @betteam = (CASE WHEN ip.TotalGameHomeSetx > 7 AND (ip.TotalGameHomeSetx - ip.TotalGameAwaySetx)>=2 THEN 'haos'
											 WHEN ip.TotalGameAwaySetx > 7 AND (ip.TotalGameAwaySetx - ip.TotalGameHomeSetx)>=2 THEN 'aaos'
											 ELSE (CAST(ip.TotalGameHomeSetx AS VARCHAR(4)) + CAST(ip.TotalGameAwaySetx AS VARCHAR(4))) 
											 END) THEN 1
						ELSE - 1
						END
				WHEN 1318 THEN -- Set x Total Games Odd/Even
					CASE WHEN @betteam = N'o' AND (ip.TotalGameHomeSetx + ip.TotalGameAwaySetx)%2 = 1 THEN 1 
						 WHEN @betteam = N'e' AND (ip.TotalGameHomeSetx + ip.TotalGameAwaySetx)%2 = 0 THEN 1 
						 ELSE - 1 
						 END 
				WHEN 1324 THEN -- Set x Game y Winner 
					CASE WHEN @betteam =N'h' AND CHARINDEX(SUBSTRING(CAST(@betcheck AS VARCHAR(10)),2,4),@SetxGameyHomeWON)>0 THEN 1 
						 WHEN @betteam =N'a' AND CHARINDEX(SUBSTRING(CAST(@betcheck AS VARCHAR(10)),2,4),@SetxGameyAwayWON)>0 THEN 1   
						 WHEN CHARINDEX(SUBSTRING(CAST(@betcheck AS VARCHAR(10)),2,4),@SetxGameyDRAW)>0 THEN 0 
						 WHEN CHARINDEX(SUBSTRING(CAST(@betcheck AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 0
						 ELSE -1 END        
				WHEN 14 THEN 
					CASE WHEN (@betteam = (CASE 
												WHEN @FGLG1 = 'N' THEN '0:0'
												WHEN @FGLG1 = 'H' THEN '1:1'
												WHEN @FGLG1 = 'A' THEN '2:1'
												ELSE ''
											END) 
							OR @betteam =(CASE 
											WHEN @FGLG2 = 'N' THEN '0:0'
											WHEN @FGLG2 = 'H' THEN '1:2'
											WHEN @FGLG2 = 'A' THEN '2:2'
											ELSE ''
										END) 
								) THEN 1
								
						ELSE - 1
					END
				WHEN 127 THEN 
					CASE 
						WHEN (@betteam = @HT_FGLG1 OR @betteam = @HT_FGLG2) THEN 1
						ELSE - 1
					END
				
					
				WHEN 601 THEN -- FT Winning Margin 14 Way
					CASE 
						WHEN @betteam = 'H1-2' AND (@fth - @fta) BETWEEN 1 AND 2 THEN 1
						WHEN @betteam = 'H3-6' AND (@fth - @fta) BETWEEN 3 AND 6 THEN 1
						WHEN @betteam = 'H7-9' AND (@fth - @fta) BETWEEN 7 AND 9 THEN 1
						WHEN @betteam = 'H10-13' AND (@fth - @fta) BETWEEN 10 AND 13 THEN 1
						WHEN @betteam = 'H14-16' AND (@fth - @fta) BETWEEN 14 AND 16 THEN 1
						WHEN @betteam = 'H17-20' AND (@fth - @fta) BETWEEN 17 AND 20 THEN 1
						WHEN @betteam = 'H21+' AND (@fth - @fta) >= 21 THEN 1
						WHEN @betteam = 'A1-2' AND (@fth - @fta) BETWEEN -2 AND -1 THEN 1
						WHEN @betteam = 'A3-6' AND (@fth - @fta) BETWEEN -6 AND -3 THEN 1
						WHEN @betteam = 'A7-9' AND (@fth - @fta) BETWEEN -9 AND -7 THEN 1
						WHEN @betteam = 'A10-13' AND (@fth - @fta) BETWEEN -13 AND -10 THEN 1
						WHEN @betteam = 'A14-16' AND (@fth - @fta) BETWEEN -16 AND -14 THEN 1
						WHEN @betteam = 'A17-20' AND (@fth - @fta) BETWEEN -20 AND -17 THEN 1
						WHEN @betteam = 'A21+' AND (@fth - @fta) <= -21 THEN 1
						ELSE -1
					END 
				WHEN 602 THEN -- FT Winning Margin 12 Way
					CASE
						WHEN @betteam = 'H1-5' AND (@fth - @fta) BETWEEN 1 AND 5 THEN 1
						WHEN @betteam = 'H6-10' AND (@fth - @fta) BETWEEN 6 AND 10 THEN 1
						WHEN @betteam = 'H11-15' AND (@fth - @fta) BETWEEN 11 AND 15 THEN 1
						WHEN @betteam = 'H16-20' AND (@fth - @fta) BETWEEN 16 AND 20 THEN 1
						WHEN @betteam = 'H21-25' AND (@fth - @fta) BETWEEN 21 AND 25 THEN 1
						WHEN @betteam = 'H26+' AND (@fth - @fta) >= 26 THEN 1
						WHEN @betteam = 'A1-5' AND (@fth - @fta) BETWEEN -5 AND -1 THEN 1
						WHEN @betteam = 'A6-10' AND (@fth - @fta) BETWEEN -10 AND -6 THEN 1
						WHEN @betteam = 'A11-15' AND (@fth - @fta) BETWEEN -15 AND -11 THEN 1
						WHEN @betteam = 'A16-20' AND (@fth - @fta) BETWEEN -20 AND -16 THEN 1
						WHEN @betteam = 'A21-25' AND (@fth - @fta) BETWEEN -25 AND -21 THEN 1
						WHEN @betteam = 'A26+' AND (@fth - @fta) <= -26 THEN 1	
						ELSE -1
					END
				WHEN 603 THEN -- FT Which team to score the highest quarter
					CASE 
						WHEN @FTHighestQuarter = 'N' THEN 0
						WHEN @betteam = @FTHighestQuarter THEN 1 
						ELSE -1 
					END
				WHEN 604 THEN -- FT Which team to score the first basket
					CASE
						WHEN @betteam = @HomeValue THEN 1 
						ELSE -1 
					END
				WHEN 605 THEN -- FT Which team to score the last basket 	
					CASE
						WHEN @betteam = @HomeValue THEN 1 
						ELSE -1 
					END
				WHEN 606 THEN -- 1H Race to YY
					CASE 
						WHEN @HomeValue = 'N' THEN 0
						WHEN @betteam = @HomeValue THEN 1
						ELSE - 1
					END
				WHEN 607 THEN -- 2H Race to YY
					CASE 
						WHEN @HomeValue = 'N' THEN 0 
						WHEN @betteam = @HomeValue THEN 1
						ELSE -1 
					END
				WHEN 608 THEN -- 1H Winning Margin 12 Way
					CASE
						WHEN (@hth - @hta) BETWEEN 1 AND 5 AND @betteam = 'H1-5' THEN 1
						WHEN (@hth - @hta) BETWEEN 6 AND 10 AND @betteam = 'H6-10' THEN 1
						WHEN (@hth - @hta) BETWEEN 11 AND 15 AND @betteam = 'H11-15' THEN 1 
						WHEN (@hth - @hta) BETWEEN 16 AND 20 AND @betteam = 'H16-20' THEN 1
						WHEN (@hth - @hta) BETWEEN 21 AND 25 AND @betteam = 'H21-25' THEN 1 
						WHEN (@hth - @hta) >= 26 AND @betteam = 'H26+' THEN 1
						WHEN (@hth - @hta) = 0 AND @betteam = 'D' THEN 1
						WHEN (@hth - @hta) BETWEEN -5 AND -1 AND @betteam = 'A1-5' THEN 1
						WHEN (@hth - @hta) BETWEEN -10 AND -6 AND @betteam = 'A6-10' THEN 1
						WHEN (@hth - @hta) BETWEEN -15 AND -11 AND @betteam = 'A11-15' THEN 1
						WHEN (@hth - @hta) BETWEEN -20 AND -16 AND @betteam = 'A16-20' THEN 1
						WHEN (@hth - @hta) BETWEEN -25 AND -21 AND @betteam = 'A21-25' THEN 1
						WHEN (@hth - @hta) <= -26 AND @betteam = 'A26+' THEN 1
						ELSE -1
					END
				WHEN 609 THEN -- Quarter X Handicap
					CASE 
						WHEN @betteam = 'h' THEN (@QXHome - @hdp1) - (@QXAway - @hdp2)
						WHEN @betteam = 'a' THEN (@QXAway - @hdp2) - (@QXHome - @hdp1)
						ELSE -1
					END
				WHEN 610 THEN -- Quarter X Over Under
					CASE 
						WHEN @betteam = 'o' THEN @QXHome + @QXAway - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - (@QXHome + @QXAway) 
						ELSE -1
					END
				WHEN 611 THEN -- Quarter X Odd Even
					CASE 
						WHEN @betteam = 'o' AND (@QXHome + @QXAway) % 2 = 1 THEN 1
						WHEN @betteam = 'e' AND (@QXHome + @QXAway) % 2 = 0 THEN 1
						ELSE -1
					END
				WHEN 612 THEN -- Quarter X Moneyline
					CASE 
						WHEN @betteam = 'h' THEN (@QXHome - @QXAway)
						WHEN @betteam = 'a' THEN (@QXAway - @QXHome)
						ELSE -1
					END
				WHEN 613 THEN -- Quarter X Race to YY
					CASE 
						WHEN @HomeValue = 'N' THEN 0
						WHEN @betteam = @HomeValue THEN 1
						ELSE -1
					END
				WHEN 614 THEN -- Quarter X Winning Margin 7 Way
					CASE	
						WHEN @betteam = 'H1-4' AND (@QXHome - @QXAway) BETWEEN 1 AND 4 THEN 1
						WHEN @betteam = 'H5-8' AND (@QXHome - @QXAway) BETWEEN 5 AND 8 THEN 1
						WHEN @betteam = 'H9+' AND (@QXHome - @QXAway) >= 9 THEN 1
						WHEN @betteam = 'D' AND (@QXHome - @QXAway) = 0 THEN 1
						WHEN @betteam = 'A1-4' AND (@QXAway - @QXHome) BETWEEN 1 AND 4 THEN 1
						WHEN @betteam = 'A5-8' AND (@QXAway - @QXHome) BETWEEN 5 AND 8 THEN 1
						WHEN @betteam = 'A9+' AND (@QXAway - @QXHome) >= 9 THEN 1
						ELSE -1
					END
				WHEN 615 THEN -- Quarter X Home Team Over Under
					CASE
						WHEN @betteam = 'o' THEN @QXHome - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @QXHome
						ELSE -1
					END
				WHEN 616 THEN -- Quarter X Away Team Over Under
					CASE
						WHEN @betteam = 'o' THEN @QXAway - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @QXAway
						ELSE -1
					END
				WHEN 617 THEN -- Quarter X Which team to score the last basket
					CASE
						WHEN @HomeValue = 'N' THEN 0
						WHEN @betteam = @HomeValue THEN 1
						ELSE -1
					END
				
				-- 453: 1H 3-Way Handicap
				WHEN 453 THEN 
							CASE
								WHEN @betteam = '1' AND ((@hth - @hdp1) - (@hta - @hdp2)) > 0  THEN 1
								WHEN @betteam = '2' AND ((@hth - @hdp1) - (@hta - @hdp2)) < 0  THEN 1
								WHEN @betteam = 'x' AND ((@hth - @hdp1) - (@hta - @hdp2)) = 0  THEN 1
								ELSE - 1
							END								
				
				--456:	1H Both Teams To Score / Result
				WHEN 456 THEN 
							CASE
								WHEN @betteam = (CASE 
													WHEN @hth > 0 AND @hta > 0 THEN CASE 
																						WHEN @hth > @hta THEN 'YH'
																						WHEN @hth < @hta THEN 'YA'
																						ELSE 'YD'
																					END
													ELSE CASE 
															WHEN @hth > @hta THEN 'NH'
															WHEN @hth < @hta THEN 'NA'
															ELSE 'ND'
														 END
													END) THEN 1
                                ELSE -1
                            END
                -- 457: 1H Both Teams To Score / Total Goals
                WHEN 457 THEN 
							CASE
								WHEN @betteam = (CASE WHEN @hth > 0 AND @hta > 0 THEN 'Y' ELSE 'N' END
												+  CASE 
														WHEN @hth + @hta > @hdp1 THEN  'O'
														WHEN @hth + @hta < @hdp1 THEN	'U'
														ELSE NULL 
													END )
												THEN 1
                                 ELSE -1
                             END
                 -- 459:	1H Asian 1X2
                 WHEN 459 THEN 
							CASE
									WHEN @betteam = '1' AND @hth - @livehomescore > @hta - @liveawayscore THEN 1
									WHEN @betteam = '2' AND @hth - @livehomescore < @hta - @liveawayscore THEN 1
									WHEN @betteam = 'X' AND @hth - @livehomescore = @hta - @liveawayscore THEN 1
									ELSE -1
								END
				
				-- 458: FT	Asia 1X2
                 WHEN 458 THEN 
							CASE
									WHEN @betteam = '1' AND @fth - @livehomescore > @fta - @liveawayscore THEN 1
									WHEN @betteam = '2' AND @fth - @livehomescore < @fta - @liveawayscore THEN 1
									WHEN @betteam = 'X' AND @fth - @livehomescore = @fta - @liveawayscore THEN 1
									ELSE -1
								END
				--448: Last Team To Score								
				WHEN 448 THEN 
					CASE WHEN (@betteam =(CASE 
											WHEN @FGLG2 = 'N' THEN 'NG'
											ELSE @FGLG2
										END) 
								) THEN 1
						ELSE - 1
					END
				--449:	Double Chance & Total Goals
				WHEN 449 THEN 
							CASE 
								WHEN @betteam = '1XO' AND @ScoreDiff >= 0 AND @totalgoal - @hdp1 > 0 THEN 1
								WHEN @betteam = '1XU' AND @ScoreDiff >= 0 AND @totalgoal - @hdp1 < 0 THEN 1
								WHEN @betteam = '12O' AND @ScoreDiff <> 0 AND @totalgoal - @hdp1 > 0 THEN 1
								WHEN @betteam = '12U' AND @ScoreDiff <> 0 AND @totalgoal - @hdp1 < 0 THEN 1
								WHEN @betteam = '2XO' AND @ScoreDiff <= 0 AND @totalgoal - @hdp1 > 0 THEN 1
								WHEN @betteam = '2XU' AND @ScoreDiff <= 0 AND @totalgoal - @hdp1 < 0 THEN 1
								ELSE -1 
							END
				--450: Odd/Even & Total Goals
				WHEN 450 THEN	
							CASE 
								WHEN @betteam = 'OO' AND @oddeven = 1 AND @totalgoal > @hdp1 THEN 1
								WHEN @betteam = 'OU' AND @oddeven = 1 AND @totalgoal < @hdp1 THEN 1
								WHEN @betteam = 'EO' AND @oddeven = 0 AND @totalgoal > @hdp1 THEN 1
								WHEN @betteam = 'EU' AND @oddeven = 0 AND @totalgoal < @hdp1 THEN 1
								ELSE -1
							 END
				--451: Both Teams To Score / Double Chance
				WHEN 451 THEN 
							CASE
								WHEN @betteam = 'Y1X' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff >= 0 THEN 1
								WHEN @betteam = 'Y12' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff <> 0 THEN 1
								WHEN @betteam = 'Y2X' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff <= 0 THEN 1
								WHEN @betteam = 'N1X' AND (@fth = 0  OR @fta = 0)  AND @ScoreDiff >= 0 THEN 1
								WHEN @betteam = 'N12' AND (@fth = 0  OR @fta = 0)  AND @ScoreDiff <> 0 THEN 1
								WHEN @betteam = 'N2X' AND (@fth = 0  OR @fta = 0)  AND @ScoreDiff <= 0 THEN 1
								ELSE -1
							END				 	
				--452: Highest Scoring Half (2 Way)
				WHEN 452 THEN
							CASE
								WHEN @betteam = '1H' AND @totalht > @totalgoal_2H THEN 1
								WHEN @betteam = '2H' AND @totalht < @totalgoal_2H THEN 1
								WHEN @totalht = @totalgoal_2H THEN 0
								ELSE -1
							END
				--460: Which Team Will Win By 5+ Goals
				WHEN 460 THEN CASE
								WHEN @betteam = 'H' AND @ScoreDiff >= 5  THEN 1
								WHEN @betteam = 'A' AND @ScoreDiff <= -5 THEN 1
								ELSE -1
							END	 														 						
				--454: Double Chance & First Team To Score	
                WHEN 454 THEN CASE
								WHEN @betteam = '1XH' AND @ScoreDiff >= 0 AND @FGLG1 = 'H' THEN 1
								WHEN @betteam = '12H' AND @ScoreDiff <> 0 AND @FGLG1 = 'H' THEN 1
								WHEN @betteam = '2XH' AND @ScoreDiff <= 0 AND @FGLG1 = 'H' THEN 1
								
								WHEN @betteam = '1XA' AND @ScoreDiff >= 0 AND @FGLG1 = 'A' THEN 1
								WHEN @betteam = '12A' AND @ScoreDiff <> 0 AND @FGLG1 = 'A' THEN 1
								WHEN @betteam = '2XA' AND @ScoreDiff <= 0 AND @FGLG1 = 'A' THEN 1
								WHEN @betteam = 'NG'  AND @FGLG1 = 'N' THEN 1
								ELSE -1
							END
				
				-- #112885 - PH4
				WHEN 467 THEN CASE WHEN -- HT/FT Exact Total Goal
										(CASE WHEN @totalht IN (0,1,2,3) AND @totalgoal >= 7 
											THEN 'G' + CAST(@totalht AS VARCHAR(5)) + '/G7+'
										WHEN @totalht = 4 AND @totalgoal >= 8 
											THEN 'G4/G8+'
										WHEN @totalht = 5 AND @totalgoal >= 9 
											THEN 'G5/G9+'  
										WHEN @totalht = 6 AND @totalgoal >= 10 
											THEN 'G6/G10+'
										WHEN @totalht >= 7 AND @totalgoal >= 7 
											THEN 'G7+/G7+'
										ELSE 'G' + CAST(@totalht AS VARCHAR(5)) + '/G' + CAST(@totalgoal AS VARCHAR(5))
									END) = @betteam THEN 1 
								ELSE -1
							END 	
				-- 470: Corners Odd/Even (own)
				WHEN 470 THEN 
                            CASE WHEN @betteam =N'o' AND ((@fth + @fta) % 2) = 1 THEN 1 
                                    WHEN @betteam =N'e' AND ((@fth + @fta) % 2) = 0 THEN 1 
                                    ELSE - 1 
                             END

				-- 471: 1H Corners Odd/Even (own)
				WHEN 471 THEN 
                            CASE WHEN @betteam =N'o' AND ((@hth + @hta) % 2) = 1 THEN 1 
                                    WHEN @betteam =N'e' AND ((@hth + @hta) % 2) = 0 THEN 1 
                                    ELSE - 1 
                             END

				-- 472: 2H Corners Odd/Even
				WHEN 472 THEN 
                            CASE WHEN @betteam =N'o' AND ((@fth + @fta - @hth - @hta) % 2) = 1 THEN 1 
                                    WHEN @betteam =N'e' AND ((@fth + @fta - @hth - @hta) % 2) = 0 THEN 1 
                                    ELSE - 1 
                             END 
				-- Total Corners
				WHEN 473 THEN 
							CASE WHEN @betteam = '0-5' and @totalgoal <= 5 THEN 1
								WHEN @betteam = '6-8' and @totalgoal in (6,7,8) THEN 1
								WHEN @betteam = '9-11' and @totalgoal in (9,10,11) THEN 1
								WHEN @betteam = '12-14' and @totalgoal in (12,13,14) THEN 1
								WHEN @betteam = '15+' and @totalgoal >= 15 THEN 1
								ELSE -1 
							END
				-- 1H Total Corners
				WHEN 474 THEN 
							CASE WHEN @betteam = '0-2' and @totalgoal <= 2 THEN 1
								WHEN @betteam = '3-4' and @totalgoal in (3,4) THEN 1
								WHEN @betteam = '5-6' and @totalgoal in (5,6) THEN 1
								WHEN @betteam = '7+' and @totalgoal >= 7 THEN 1
								ELSE -1 
							END
				-- Alternative Corners
				WHEN 475 THEN 
							CASE WHEN @betteam = 'o' AND @totalgoal > @hdp1 THEN 1
										WHEN @betteam = 'u' AND @totalgoal < @hdp1 THEN 1
										WHEN @betteam = 'e' AND @totalgoal = @hdp1 THEN 1
										ELSE -1
									END
				-- 1H Alternative Corners
				WHEN 476 THEN 
							CASE WHEN @betteam = 'o' AND @totalht > @hdp1 THEN 1
								WHEN @betteam = 'u' AND @totalht < @hdp1 THEN 1
								WHEN @betteam = 'e' AND @totalht = @hdp1 THEN 1
								ELSE -1
							END
				-- Corner 3-way handicap
				WHEN 477 THEN 
					CASE 
						WHEN @betteam = '1' AND (@hdp2 - @hdp1 + @fth - @fta) > 0 THEN 1
						WHEN @betteam = '2' AND (@hdp1 - @hdp2 + @fta - @fth) > 0 THEN 1
						WHEN @betteam = 'x' AND ((@hdp1 - @hdp2) - (@fth - @fta)) = 0 THEN 1
						ELSE - 1
						END
				-- 478: 1H Corner 3-Way Handicap
				WHEN 478 THEN 
							CASE
								WHEN @betteam = '1' AND ((@hth - @hdp1) - (@hta - @hdp2)) > 0  THEN 1
								WHEN @betteam = '2' AND ((@hth - @hdp1) - (@hta - @hdp2)) < 0  THEN 1
								WHEN @betteam = 'x' AND ((@hth - @hdp1) - (@hta - @hdp2)) = 0  THEN 1
								ELSE - 1
							END	
				-- 482: Home Team Corners Over/Under
				WHEN 482 THEN 
					CASE
						WHEN @betteam = 'o' THEN @fth - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @fth
						ELSE -1 
					END
				-- 483: Away Team Corners Over/Under
				WHEN 483 THEN 
					CASE
						WHEN @betteam = 'o' THEN @fta - @hdp1
						WHEN @betteam = 'u' THEN @hdp1 - @fta
						ELSE -1 
					END
				-- 484: 1H Home Team Corners Over/Under
				WHEN 484 THEN 
                    CASE
                        WHEN @betteam = 'o' THEN @hth - @hdp1
                        WHEN @betteam = 'u' THEN @hdp1 - @hth
                        ELSE -1 
					END
				-- 485: --1H Away Team Corners Over/Under
				WHEN 485 THEN 
                    CASE
                        WHEN @betteam = 'o' THEN @hta - @hdp1
                        WHEN @betteam = 'u' THEN @hdp1 - @hta
                        ELSE -1 
					END
				-- Corners Race
				WHEN 486 THEN CASE 
								WHEN CHARINDEX(CAST(CAST(@hdp1 AS INT) AS VARCHAR) + @betteam, @ResultCornerRace) > 0 THEN 1
								WHEN @betteam = 'N' AND @NeitherRaceTo <= @hdp1 THEN 1
								ELSE -1
							END
				-- 1H Corners Race
				WHEN 487 THEN CASE 
								WHEN CHARINDEX(CAST(CAST(@hdp1 AS INT) AS VARCHAR) + @betteam, @ResultCornerRace1H) > 0 THEN 1
								WHEN @betteam = 'N' AND @NeitherRaceTo1H <= @hdp1 THEN 1
								ELSE -1
							END
				-- First Corner
				WHEN 488 THEN CASE
								WHEN @betteam = @FirstGoal THEN 1
								WHEN @FirstGoal = '' THEN 0
								ELSE -1
							END
				-- 1H First Corner
				WHEN 489 THEN CASE
								WHEN @betteam = @FirstGoal THEN 1
								WHEN @FirstGoal = '' THEN 0
								ELSE -1
							END
				-- 2H First Corner
				WHEN 490 THEN CASE
								WHEN @betteam = @FirstGoal2H  THEN 1
								WHEN @FirstGoal2H = '' THEN 0
								ELSE -1
							END
				-- Last Corner
				WHEN 491 THEN CASE
								WHEN @betteam = @LastGoal THEN 1
								WHEN @LastGoal = '' THEN 0
								ELSE -1
							END
				-- 1H Last Corner
				WHEN 492 THEN CASE
								WHEN @betteam = @LastGoal1H THEN 1
								WHEN @LastGoal1H = '' THEN 0
								ELSE -1
							END
				
				-- HT/FT Total Corners
				WHEN 493 THEN CASE WHEN 
									(
									CASE 
										WHEN @betteam = 'AOS' AND CHARINDEX(CAST((@hth + @hta) AS VARCHAR(5)) + '/' + CAST((@fth + @fta) AS VARCHAR(5)), @transdesc) = 0 THEN 'AOS'
										WHEN (@hth + @hta) = 0 AND (@fth + @fta) >= 8 THEN '0/8+'
										WHEN (@hth + @hta) = 1 AND (@fth + @fta) >= 9 THEN '1/9+'  
										WHEN (@hth + @hta) = 2 AND (@fth + @fta) >= 10 THEN '2/10+'
										WHEN (@hth + @hta) = 3 AND (@fth + @fta) >= 11 THEN '3/11+'
										WHEN (@hth + @hta) = 4 AND (@fth + @fta) >= 12 THEN '4/12+'
										WHEN (@hth + @hta) = 5 AND (@fth + @fta) >= 13 THEN '5/13+'
										WHEN (@hth + @hta) = 6 AND (@fth + @fta) >= 14 THEN '6/14+'
										WHEN (@hth + @hta) IN (7,8,9) AND (@fth + @fta) >= 15 THEN CAST((@hth + @hta) AS VARCHAR(5)) + '/15+'
										ELSE CAST((@hth + @hta) AS VARCHAR(5)) + '/' + CAST((@fth + @fta) AS VARCHAR(5))
								END) = @betteam THEN 1 
								ELSE -1
							END
				-- 1H Correct Corners
				WHEN 494 THEN CASE WHEN 
									(
									CASE 
										WHEN @betteam = 'AOS' AND CHARINDEX(CAST(@hth AS VARCHAR(5)) + '-' + CAST(@hta AS VARCHAR(5)), @transdesc) = 0 THEN 'AOS'
										ELSE CAST(@hth AS VARCHAR(5)) + '-' + CAST(@hta AS VARCHAR(5))
									END) = @betteam THEN 1 
									ELSE -1
								END
				-- 2H Correct Corners
				WHEN 495 THEN CASE WHEN 
									(
									CASE 
										WHEN @betteam = 'AOS' AND CHARINDEX(CAST((@fth - @hth) AS VARCHAR(5)) + '-' + CAST((@fta - @hta) AS VARCHAR(5)), @transdesc) = 0 THEN 'AOS'
										ELSE CAST((@fth - @hth) AS VARCHAR(5)) + '-' + CAST((@fta - @hta) AS VARCHAR(5))
									END) = @betteam THEN 1 
									ELSE -1
								END
				-- 496: Corner Highest Scoring Half
				WHEN 496 THEN 
								CASE 
								WHEN @betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
								WHEN @betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
								WHEN @betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
								ELSE -1
								END
				-- 497: Corner Highest Scoring Half (2-Way)
				WHEN 497 THEN 
								CASE 
								WHEN @betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
								WHEN @betteam IN ('1h','2h') AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 0
								WHEN @betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
								ELSE -1
								END
				ELSE NULL -- Not support @bettype
			END AS modds
	) AS odds
)
GO