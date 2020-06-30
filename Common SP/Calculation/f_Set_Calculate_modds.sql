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
		- 20200428@Kathy: PHAIO 5 - Add new penalty bettype[Redmine:#132805]
		- 20200625@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		
*/
RETURN
(
   SELECT  CASE
			WHEN @pfID IN (1, 10) THEN --Handicap
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
			
			WHEN @pfID = 9088 THEN -- Correct Map Score
				CASE WHEN @betteam = @HomeValue + ':' + @AwayValue THEN 1
					 ELSE -1
				END
			WHEN @pfID = 376 THEN ROUND(dbo.PRODUCT( 
						CASE WHEN SUBSTRING(@HomeValue, ps.rn, 1) = 'N' THEN 1
							 WHEN SUBSTRING(@betteam, ps.rn, 1) = '-' THEN 1
							 WHEN SUBSTRING(@HomeValue, ps.rn, 1) = SUBSTRING(@betteam, ps.rn, 1) then ps.odds
							 ELSE 0
						END),2)
			WHEN @pfID IN (401, 402) THEN -- Home/Away Team Over/Under
				CASE WHEN @betteam = 'o' THEN tbl.fm
					 WHEN @betteam = 'u' THEN - tbl.fm
					 ELSE -1
				END
			WHEN @pfID = 601 THEN
				CASE WHEN @betteam = 'H1-2' AND fm BETWEEN 1 AND 2 THEN 1
					 WHEN @betteam = 'H3-6' AND fm BETWEEN 3 AND 6 THEN 1
					 WHEN @betteam = 'H7-9' AND fm BETWEEN 7 AND 9 THEN 1
					 WHEN @betteam = 'H10-13' AND fm BETWEEN 10 AND 13 THEN 1
					 WHEN @betteam = 'H14-16' AND fm BETWEEN 14 AND 16 THEN 1
					 WHEN @betteam = 'H17-20' AND fm BETWEEN 17 AND 20 THEN 1
					 WHEN @betteam = 'H21+' AND fm >= 21 THEN 1
					 WHEN @betteam = 'A1-2' AND fm BETWEEN -2 AND -1 THEN 1
					 WHEN @betteam = 'A3-6' AND fm BETWEEN -6 AND -3 THEN 1
					 WHEN @betteam = 'A7-9' AND fm BETWEEN -9 AND -7 THEN 1
					 WHEN @betteam = 'A10-13' AND fm BETWEEN -13 AND -10 THEN 1
					 WHEN @betteam = 'A14-16' AND fm BETWEEN -16 AND -14 THEN 1
					 WHEN @betteam = 'A17-20' AND fm BETWEEN -20 AND -17 THEN 1
					 WHEN @betteam = 'A21+' AND fm <= -21 THEN 1
					 ELSE -1
				END		
			WHEN @pfID = 602 THEN
				CASE WHEN @betteam = 'H1-5' AND fm BETWEEN 1 AND 5 THEN 1
					WHEN @betteam = 'H6-10' AND fm BETWEEN 6 AND 10 THEN 1
					WHEN @betteam = 'H11-15' AND fm BETWEEN 11 AND 15 THEN 1
					WHEN @betteam = 'H16-20' AND fm BETWEEN 16 AND 20 THEN 1
					WHEN @betteam = 'H21-25' AND fm BETWEEN 21 AND 25 THEN 1
					WHEN @betteam = 'H26+' AND fm >= 26 THEN 1
					WHEN @betteam = 'A1-5' AND fm BETWEEN -5 AND -1 THEN 1
					WHEN @betteam = 'A6-10' AND fm BETWEEN -10 AND -6 THEN 1
					WHEN @betteam = 'A11-15' AND fm BETWEEN -15 AND -11 THEN 1
					WHEN @betteam = 'A16-20' AND fm BETWEEN -20 AND -16 THEN 1
					WHEN @betteam = 'A21-25' AND fm BETWEEN -25 AND -21 THEN 1
					WHEN @betteam = 'A26+' AND fm <= -26 THEN 1	
					ELSE -1
				END
			WHEN @pfID = 608 THEN
				CASE WHEN @betteam = 'H1-5' AND fm BETWEEN 1 AND 5 THEN 1
					WHEN @betteam = 'H6-10' AND fm BETWEEN 6 AND 10 THEN 1
					WHEN @betteam = 'H11-15' AND fm BETWEEN 11 AND 15 THEN 1
					WHEN @betteam = 'H16-20' AND fm BETWEEN 16 AND 20 THEN 1
					WHEN @betteam = 'H21-25' AND fm BETWEEN 21 AND 25 THEN 1
					WHEN @betteam = 'H26+' AND fm >= 26 THEN 1
					WHEN @betteam = 'D' AND fm = 0 THEN 1
					WHEN @betteam = 'A1-5' AND fm BETWEEN -5 AND -1 THEN 1
					WHEN @betteam = 'A6-10' AND fm BETWEEN -10 AND -6 THEN 1
					WHEN @betteam = 'A11-15' AND fm BETWEEN -15 AND -11 THEN 1
					WHEN @betteam = 'A16-20' AND fm BETWEEN -20 AND -16 THEN 1
					WHEN @betteam = 'A21-25' AND fm BETWEEN -25 AND -21 THEN 1
					WHEN @betteam = 'A26+' AND fm <= -26 THEN 1
					ELSE -1
					END 
			WHEN @pfID = 614 THEN
				CASE 
					WHEN @betteam = 'H1-4' AND fm BETWEEN 1 AND 4 THEN 1
					WHEN @betteam = 'H5-8' AND fm BETWEEN 5 AND 8 THEN 1
					WHEN @betteam = 'H9+' AND fm >= 9 THEN 1
					WHEN @betteam = 'D' AND fm = 0 THEN 1
					WHEN @betteam = 'A1-4' AND fm BETWEEN -4 AND -1 THEN 1
					WHEN @betteam = 'A5-8' AND fm BETWEEN -8 AND -5 THEN 1
					WHEN @betteam = 'A9+' AND fm <= -9 THEN 1
					ELSE -1
					END
			ELSE -1 
		END AS modds
   FROM
	(
		SELECT (CASE 
					WHEN @pfID = 1 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1 - @LiveHomeScore) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2 - @LiveAwayScore)
					WHEN @pfID = 10 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2) -- not use livescore
					WHEN @pfID = 2 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)) % 2
					WHEN @pfID = 3 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @hdp1)
					WHEN @pfID IN (20,711, 608, 614) THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 101 THEN (CAST(@HomeValue AS SMALLMONEY) * 60 + CAST(@AwayValue AS SMALLMONEY)) - (@hdp1 * 60)
					
					--Happy5
					WHEN @pfID = 8101 THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID = 8102 THEN CAST(@HomeValue AS SMALLMONEY) % 2
					WHEN @pfID = 8103 THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID IN (8104, 601, 602) THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 8105 THEN CAST(@HomeValue AS SMALLMONEY)

					--PHAIO 5
					WHEN @pfID IN (391, 601, 602) THEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID IN (387, 386) THEN CAST(@HomeValue AS SMALLMONEY) - @hdp1
					WHEN @pfID = 401 THEN CAST(@HomeValue AS SMALLMONEY) - @hdp1
					WHEN @pfID = 402 THEN CAST(@AwayValue AS SMALLMONEY) - @hdp1
					ELSE -1 END)
			AS fm
	) tbl
	OUTER APPLY -- bettype 376: input betcheck into @AwayValue
	(
		SELECT	ROW_NUMBER () OVER (ORDER BY(SELECT NULL)) AS rn
				,CAST(CASE WHEN f.val = '' THEN CAST(1 AS SMALLMONEY) ELSE f.val END AS SMALLMONEY) AS odds
		FROM	dbo.f_SplitString(@AwayValue, ',') f
		WHERE	@pfID = 376
				AND ISNULL(@AwayValue,'') <> ''
	) ps
	GROUP BY tbl.fm

)
GO