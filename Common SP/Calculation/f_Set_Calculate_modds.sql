/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Calculate_modds] (
		@pfID			SMALLINT
		,@betteam 		NVARCHAR(10)
		,@hdp1			SMALLMONEY
		,@hdp2			SMALLMONEY
		,@HomeValue 	VARCHAR(50)
		,@AwayValue 	VARCHAR(50)
		,@LiveHomeScore SMALLINT
		,@LiveAwayScore SMALLINT
		)
RETURNS TABLE
AS  
/*	Created: 20180801@Vicky
	Task: cal modds
	DB: DBTXN/bodb02
	Revisions:	
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20190620@Kathy: PH AIO Phase4 [Redmine:#109584]
		- 20190924@Sol: Incorporate BMAIO - New formular for 711, 712, 713, 714 [Redmine:#120324]
		- 20190924@Tiara: BMAIO - Badminton All In One [Redmine: #120324]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200415@Sol: e-Sports - Incorporate New Correct Score Bet Type - new settle profile [Redmine:#132401]
		
*/
RETURN
(
   SELECT  CASE
			WHEN @pfID = 1 THEN --Handicap
			   CASE  WHEN @betteam = 'h' THEN
			   				CASE WHEN fm > 0.25 THEN 1
					 			 WHEN fm = 0.25 THEN 0.25
					 			 WHEN fm = 0	THEN 0
					 			 WHEN fm = -0.25 THEN -0.25
					 			 ELSE -1
					 			 END
					 WHEN @betteam = 'a' THEN
					 		CASE WHEN fm = 0.25 THEN -0.25
					 			 WHEN fm = 0	THEN 0
					 			 WHEN fm = -0.25 THEN 0.25
					 			 WHEN fm < -0.25 THEN 1
					 			 ELSE -1
					 			 END
					 ELSE -1 END
					 
			WHEN @pfID = 2 THEN --Odd/even
			   CASE WHEN @betteam IN ('h', 'o') AND fm = 1 THEN 1
					WHEN @betteam IN ('a', 'e') AND fm = 0 THEN 1
					ELSE -1 END
					
			WHEN @pfID IN (3, 387, 386) THEN --Over/under
			   CASE WHEN @betteam IN ('h', 'o') THEN
			   				CASE WHEN fm > 0.25 THEN 1
								 WHEN fm = 0.25 THEN 0.25
								 WHEN fm = 0	THEN 0
								 WHEN fm = -0.25 THEN -0.25
								 ELSE -1
								 END
					WHEN @betteam IN ('a', 'u') THEN
							CASE WHEN fm = 0.25 THEN -0.25
								 WHEN fm = 0	THEN 0
								 WHEN fm = -0.25 THEN 0.25
								 WHEN fm < -0.25 THEN 1
								 ELSE -1
								 END
					ELSE -1 END
					
			WHEN @pfID = 20 THEN --Moneyline
			   CASE WHEN @betteam = 'h' AND fm > 0 THEN 1
					WHEN @betteam = 'a' AND fm < 0 THEN 1
					WHEN fm = 0 THEN 0
					ELSE -1 END
						
			WHEN @pfID = 100 THEN --betteam = homevalue (home/away/none/draw)
			   CASE WHEN @betteam IN ('h', 'a') AND @betteam = @HomeValue THEN 1
					WHEN @HomeValue IN ('n', 'd') THEN 0
					ELSE -1 END
					
			WHEN @pfID = 101 THEN --Duration Over/Under 
			   CASE WHEN @betteam IN ('h', 'o') AND fm > 0 THEN 1
					WHEN @betteam IN ('a', 'u') AND fm < 0 THEN 1
					WHEN fm = 0 THEN 0
					ELSE -1 END
					
			WHEN @pfID = 102 THEN --betteam = homevalue (yes/no)
			   CASE WHEN @betteam IN ('y', 'n') AND  @betteam = @HomeValue THEN 1
					ELSE -1 END
					
			WHEN @pfID IN (424, 385, 384) THEN --betteam = homevalue
			   CASE WHEN @betteam = @HomeValue THEN 1
					ELSE -1 END
			
			WHEN @pfID = 479 THEN 
			   CASE WHEN @betteam = 'Y' AND (@HomeValue > 0 OR (@HomeValue = 0 AND @AwayValue > 0)) AND @HomeValue < @hdp1 THEN 1
					WHEN @betteam = 'N' AND ((@HomeValue = 0 AND @AwayValue = 0) OR @HomeValue >= @hdp1) THEN 1
					ELSE -1 END

			----Happy5
			WHEN @pfID = 8101 THEN
			   CASE WHEN @betteam = 'b' AND fm >= 53 THEN 1
			   		WHEN @betteam = 's' AND fm < 53 THEN 1
					ELSE -1 END
					
			WHEN @pfID = 8102 THEN
			   CASE WHEN @betteam = 'o' AND fm = 1 THEN 1
			   		WHEN @betteam = 'e' AND fm = 0 THEN 1
					ELSE -1 END
					
			WHEN @pfID = 8103 THEN
			   CASE WHEN @betteam = 'sp' AND fm >= 15 AND fm <= 33 THEN 1
			   		WHEN @betteam = 'su' AND fm >= 34 AND fm <= 52 THEN 1
			   		WHEN @betteam = 'au' AND fm >= 53 AND fm <= 71 THEN 1
			   		WHEN @betteam = 'wi' AND fm >= 72 AND fm <= 90 THEN 1
					ELSE -1 END
					
			WHEN @pfID = 8104 THEN 
			   CASE WHEN @betteam = 'mo' AND fm > 0 THEN 1
			   		WHEN @betteam = 'me' AND fm < 0 THEN 1
					ELSE -1 END
					
			WHEN @pfID = 8105 THEN
			   CASE WHEN @betteam = 'bo' AND fm >= 53 AND fm % 2 = 1 THEN 1
			   		WHEN @betteam = 'be' AND fm >= 53 AND fm % 2 = 0 THEN 1
			   		WHEN @betteam = 'so' AND fm < 53  AND fm % 2 = 1 THEN 1
			   		WHEN @betteam = 'se' AND fm < 53  AND fm % 2 = 0 THEN 1
					ELSE -1 END
				
			WHEN @pfID = 38 THEN
				CASE WHEN @HomeValue = 'WON' THEN 1
			   		 WHEN @HomeValue = 'LOSE' THEN -1
			   		 ELSE -1 END
			
			--Incorporate BMAIO
			WHEN @pfID = 711 THEN --Game X Winning Margin
				CASE WHEN @betteam = 'H1-2' AND ( 1 <= fm AND fm <= 2) THEN 1
					WHEN @betteam = 'H3-5' AND ( 3 <= fm AND fm <=  5) THEN 1
					WHEN @betteam = 'H6-8' AND ( 6 <= fm AND fm <=  8) THEN 1
					WHEN @betteam = 'H9+' AND ( 9 <= fm ) THEN 1
					WHEN @betteam = 'A1-2' AND (-2 <= fm AND fm <= -1) THEN 1
					WHEN @betteam = 'A3-5' AND (-5 <= fm AND fm <= -3) THEN 1
					WHEN @betteam = 'A6-8' AND (-8 <= fm AND fm <= -6) THEN 1
					WHEN @betteam = 'A9+' AND (-9 >= fm) THEN 1
				ELSE -1 END

			WHEN @pfID = 714 THEN --Game X Extra Points
				CASE WHEN @betteam = 'Y' AND (@HomeValue >= 20 AND @AwayValue >= 20) THEN 1
					WHEN @betteam = 'N' AND (@HomeValue = 21 AND @AwayValue < 20) THEN 1
					WHEN @betteam = 'N' AND (@HomeValue < 20 AND @AwayValue = 21) THEN 1
					ELSE -1 
				END
				
			----Badminton AIO - Match Correct Score 703
			WHEN @pfID = 703 THEN --Match Correct Score 
				CASE WHEN @betteam ='0-2' AND @HomeValue = 0 THEN 1
					 WHEN @betteam ='1-2' AND @HomeValue = 1 THEN 1
			   		 WHEN @betteam ='2-1' AND @AwayValue = 1 THEN 1
			   		 WHEN @betteam ='2-0' AND @AwayValue = 0 THEN 1
			   		 ELSE -1 END

			WHEN @pfID = 391 THEN -- Penalty Shootout Exact Total Goals (First 10)
				CASE WHEN @betteam = 'G4' AND (0 <= fm AND fm <= 4) THEN 1
					WHEN @betteam = 'G5' AND (fm = 5) THEN 1
					WHEN @betteam = 'G6' AND (fm = 6) THEN 1
					WHEN @betteam = 'G7' AND (fm = 7) THEN 1
					WHEN @betteam = 'G8' AND (fm = 8) THEN 1
					WHEN @betteam = 'G9+' AND (9 <= fm) THEN 1
					ELSE -1 
				END
			   		
			WHEN @pfID = 391 THEN --Penalty Shootout Exact Total Goals (First 10)
				CASE WHEN @betteam = 'G4' AND (1 <= fm AND fm <= 4) THEN 1
					WHEN @betteam = 'G5' AND (fm = 5) THEN 1
					WHEN @betteam = 'G6' AND (fm = 6) THEN 1
					WHEN @betteam = 'G7' AND (fm = 7) THEN 1
					WHEN @betteam = 'G8' AND (fm = 8) THEN 1
					WHEN @betteam = 'G9+' AND (9 <= fm) THEN 1
					ELSE -1 
				END

			WHEN @pfID = 383 THEN -- Penalty Shootout Woodwork - Round X
				CASE WHEN @betteam = 'H' AND @HomeValue = 'H' THEN 1
					 WHEN @betteam = 'A' AND @AwayValue = 'H' THEN 1
					 ELSE -1
				END
			
			WHEN @pfID = 4 THEN -- Correct Score
				CASE WHEN @betteam = @HomeValue + ':' + @AwayValue THEN 1
					 ELSE -1
				END

			ELSE -1 
		END AS modds
   FROM
	(
		SELECT (CASE 
					WHEN @pfID = 1 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1 - @LiveHomeScore) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2 - @LiveAwayScore)
					WHEN @pfID = 2 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)) % 2
					WHEN @pfID = 3 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @hdp1)
					WHEN @pfID IN (20,711) THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 101 THEN (CAST(@HomeValue AS SMALLMONEY) * 60 + CAST(@AwayValue AS SMALLMONEY)) - (@hdp1 * 60)
					
					--Happy5
					WHEN @pfID = 8101 THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID = 8102 THEN CAST(@HomeValue AS SMALLMONEY) % 2
					WHEN @pfID = 8103 THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID = 8104 THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 8105 THEN CAST(@HomeValue AS SMALLMONEY)

					--PHAIO 5
					WHEN @pfID = 391 THEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID IN (387, 386) THEN CAST(@HomeValue AS SMALLMONEY) - @hdp1
					
					ELSE -1 END)
			AS fm
	) tbl
)
GO