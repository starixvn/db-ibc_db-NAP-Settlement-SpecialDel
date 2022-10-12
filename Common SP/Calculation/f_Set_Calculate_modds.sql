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
		,@Transdesc		NVARCHAR(1000)
		,@betcheck		NVARCHAR(50)
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
		- 20200710@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20210121@Kathy: Cricket AIO [Redmine:#148870]
		- 20210126@Louisa: Cricket AIO - Early bettype [Redmine:#148870]
		- 20210810@Kathy: Incorporate Bitcoin  [Redmine:#159714]
		- 20210107@Louisa: E-Sports Phase 4 [Redmine:#166330]
		- 20220128@Louisa: Cricket AIO Phase 2 [Redmine:#166335]
		- 20220328@Louisa: Add more result for bettype 9133 [Redmine:#170532]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220629@Louisa: Volleyball AIO ( 27 bettype ) [Redmineid:#173862]
		- 20221011@Louisa: Arithmetic OverFLow when  settle bettype 9115,9116,9117,9118,9119,9120 [Redmine:#178978]
*/
RETURN
(
   SELECT  CASE
			WHEN @pfID IN (1, 10, 9116, 3904) THEN --Handicap
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
					
			WHEN @pfID IN (3, 387, 386, 9117, 9118, 9119, 9128, 9096, 3905) THEN --Over/under
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

			WHEN @pfID =  3915 THEN
				CASE 
					WHEN fm = 99 THEN 0
					WHEN @betteam = 'h' AND fm > 0 THEN 1
					WHEN @betteam = 'a' AND fm < 0 THEN 1
					WHEN @betteam = 'd' AND fm = 0 THEN 1
					ELSE -1 END
			
			WHEN @pfID = 100 THEN --betteam = homevalue (home/away/none/draw)
			   CASE WHEN @betteam IN ('h', 'a', 'c', 'nc', 'm', 'nm', 't', 'b', 'nb', 'nt', 'o' ) AND @betteam = @HomeValue THEN 1
					WHEN @HomeValue IN ('n', 'd') THEN 0
					ELSE -1 END

			WHEN @pfID = 9636 THEN
				CASE WHEN @betteam IN ('c', 'b', 'lbw', 'ro', 's', 'ot') AND @betteam = @HomeValue THEN 1
					 ELSE -1 END
					
			WHEN @pfID IN ( 101, 9090, 9448 ) THEN --Over/Under 
			   CASE WHEN @betteam IN ('h', 'o') AND fm > 0 THEN 1
					WHEN @betteam IN ('a', 'u') AND fm < 0 THEN 1
					WHEN fm = 0 THEN 0
					ELSE -1 END
					
			WHEN @pfID = 102 THEN --betteam = homevalue (yes/no)
			   CASE WHEN @betteam IN ('y', 'n') AND  @betteam = @HomeValue THEN 1
					WHEN @HomeValue = 'NONE' THEN 0
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
			
			WHEN @pfID = 3911 THEN
				CASE WHEN @betteam = 'H2'    AND fm = 2 THEN 1
					 WHEN @betteam = 'H3-4'  AND ( 3 <= fm AND fm <= 4 ) THEN 1
					 WHEN @betteam = 'H5-7'  AND ( 5 <= fm AND fm <= 7 ) THEN 1
					 WHEN @betteam = 'H8-11' AND ( 8 <= fm AND fm <= 11 ) THEN 1
					 WHEN @betteam = 'H12+'  AND fm > 11 THEN 1
					 WHEN @betteam = 'A2'    AND fm = (-2)		THEN 1
					 WHEN @betteam = 'A3-4'  AND ( -4 <= fm AND fm <=  -3 )	THEN 1
					 WHEN @betteam = 'A5-7'  AND ( -7 <= fm AND fm <= -5 ) THEN 1
					 WHEN @betteam = 'A8-11' AND ( -11 <= fm AND fm <=  -8 )	THEN 1
					 WHEN @betteam = 'A12+'  AND fm < (-11)	THEN 1
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
			
			-- 501
			WHEN @pfID = 501 THEN 
				CASE 
					WHEN (@betteam = 'h' AND fm > 0) OR (@betteam = 'a' AND fm < 0) THEN 1
					WHEN fm = 0 THEN 0
					ELSE -1
				END
			WHEN @pfID = 9088 THEN -- Correct Map Score
				CASE WHEN @betteam = @HomeValue + ':' + @AwayValue THEN 1
					 ELSE -1
				END

			WHEN @pfID = 3900 THEN -- Correct Map Score
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
			WHEN @pfID BETWEEN 618 AND 620 THEN
				CASE
					WHEN RIGHT(CAST(tbl.fm AS INT),1) = @betteam THEN 1
					ELSE -1
					END
			WHEN @pfID = 5 THEN
				CASE 
					WHEN tbl.fm > 0 AND @betteam = '1' THEN 1
					WHEN tbl.fm = 0 AND @betteam = 'x' THEN 1
					WHEN tbl.fm < 0 AND @betteam = '2' THEN 1
					ELSE -1
					END
			WHEN @pfID = 24 THEN
				CASE
					WHEN tbl.fm >= 0 AND @betteam = 'hd' THEN 1
					WHEN tbl.fm <= 0 AND @betteam = 'da' THEN 1
					WHEN tbl.fm <> 0 AND @betteam = 'ha' THEN 1
					ELSE -1
					END
			WHEN @pfID = 633 THEN
				CASE
					WHEN CASE
							WHEN CAST(@HomeValue AS INT) > 0 THEN 'h'
							WHEN CAST(@HomeValue AS INT) = 0 THEN 'd'
							WHEN CAST(@HomeValue AS INT) < 0 THEN 'a'
							ELSE ''
						END +
							CASE
								WHEN CAST(@AwayValue AS INT) > 0 THEN 'h'
								WHEN CAST(@AwayValue AS INT) = 0 THEN 'd'
								WHEN CAST(@AwayValue AS INT) < 0 THEN 'a'
								ELSE ''
							END = @betteam THEN 1
					ELSE -1
					END
			WHEN @pfID = 635 THEN
				CASE
					WHEN @betteam = 'h' AND (CAST(@HomeValue AS INT) > 0 
					AND CAST(@AwayValue AS INT) = 0) THEN 1
					WHEN @betteam = 'a' AND (CAST(@HomeValue AS INT) = 0 
					AND CAST(@AwayValue AS INT) > 0) THEN 1 
					ELSE -1
				END
			WHEN @pfID = 640 THEN
				CASE
					WHEN @betteam = '0' AND CAST(@HomeValue AS INT) = 0 THEN 1
					WHEN @betteam = '1' AND CAST(@HomeValue AS INT) > 0 THEN 1
					ELSE -1
				END
			WHEN @pfID = 642 THEN
				CASE
					WHEN @betteam = 'h12' AND CHARINDEX('q1h', @HomeValue) > 0 AND CHARINDEX('q2h', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'h13' AND CHARINDEX('q1h', @HomeValue) > 0 AND CHARINDEX('q3h', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'h14' AND CHARINDEX('q1h', @HomeValue) > 0 AND CHARINDEX('q4h', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'h23' AND CHARINDEX('q2h', @HomeValue) > 0 AND CHARINDEX('q3h', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'h24' AND CHARINDEX('q2h', @HomeValue) > 0 AND CHARINDEX('q4h', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'h34' AND CHARINDEX('q3h', @HomeValue) > 0 AND CHARINDEX('q4h', @HomeValue) > 0 THEN 1

					WHEN @betteam = 'a12' AND CHARINDEX('q1a', @HomeValue) > 0 AND CHARINDEX('q2a', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'a13' AND CHARINDEX('q1a', @HomeValue) > 0 AND CHARINDEX('q3a', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'a14' AND CHARINDEX('q1a', @HomeValue) > 0 AND CHARINDEX('q4a', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'a23' AND CHARINDEX('q2a', @HomeValue) > 0 AND CHARINDEX('q3a', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'a24' AND CHARINDEX('q2a', @HomeValue) > 0 AND CHARINDEX('q4a', @HomeValue) > 0 THEN 1
					WHEN @betteam = 'a34' AND CHARINDEX('q3a', @HomeValue) > 0 AND CHARINDEX('q4a', @HomeValue) > 0 THEN 1
					
					WHEN @betteam = 'aos12' 
						AND (CHARINDEX('q1d', @HomeValue) > 0 
								OR CHARINDEX('q2d', @HomeValue) > 0
								OR (CHARINDEX('q1a', @HomeValue) > 0 AND CHARINDEX('q2h', @HomeValue) > 0)
								OR (CHARINDEX('q1h', @HomeValue) > 0 AND CHARINDEX('q2a', @HomeValue) > 0)
						) THEN 1
					WHEN @betteam = 'aos13' 
						AND (CHARINDEX('q1d', @HomeValue) > 0 
								OR CHARINDEX('q3d', @HomeValue) > 0
								OR (CHARINDEX('q1a', @HomeValue) > 0 AND CHARINDEX('q3h', @HomeValue) > 0)
								OR (CHARINDEX('q1h', @HomeValue) > 0 AND CHARINDEX('q3a', @HomeValue) > 0)
						) THEN 1
					WHEN @betteam = 'aos14' 
						AND (CHARINDEX('q1d', @HomeValue) > 0 
								OR CHARINDEX('q4d', @HomeValue) > 0
								OR (CHARINDEX('q1a', @HomeValue) > 0 AND CHARINDEX('q4h', @HomeValue) > 0)
								OR (CHARINDEX('q1h', @HomeValue) > 0 AND CHARINDEX('q4a', @HomeValue) > 0)
						) THEN 1
					WHEN @betteam = 'aos23' 
						AND (CHARINDEX('q2d', @HomeValue) > 0 
								OR CHARINDEX('q3d', @HomeValue) > 0
								OR (CHARINDEX('q2a', @HomeValue) > 0 AND CHARINDEX('q3h', @HomeValue) > 0)
								OR (CHARINDEX('q2h', @HomeValue) > 0 AND CHARINDEX('q3a', @HomeValue) > 0)
						) THEN 1
					WHEN @betteam = 'aos24' 
						AND (CHARINDEX('q2d', @HomeValue) > 0 
								OR CHARINDEX('q4d', @HomeValue) > 0
								OR (CHARINDEX('q2a', @HomeValue) > 0 AND CHARINDEX('q4h', @HomeValue) > 0)
								OR (CHARINDEX('q2h', @HomeValue) > 0 AND CHARINDEX('q4a', @HomeValue) > 0)
						) THEN 1
					WHEN @betteam = 'aos34' 
						AND (CHARINDEX('q3d', @HomeValue) > 0 
								OR CHARINDEX('q4d', @HomeValue) > 0
								OR (CHARINDEX('q3a', @HomeValue) > 0 AND CHARINDEX('q4h', @HomeValue) > 0)
								OR (CHARINDEX('q3h', @HomeValue) > 0 AND CHARINDEX('q4a', @HomeValue) > 0)
						) THEN 1
					ELSE -1
				END
			WHEN @pfID = 644 THEN -- --WHEN @pfID = 644 THEN @HomeValue + ':' + @AwayValue
				CASE
					WHEN @betteam = @HomeValue + ':' + @AwayValue  THEN 1
					WHEN @betteam = 'aos' AND CHARINDEX(@HomeValue + ':' + @AwayValue, @Transdesc) = 0 THEN 1
					ELSE -1
				END	

			WHEN @pfID = 3910 THEN
				CASE
					WHEN @betteam <> 'aos' AND @betteam = @HomeValue + ':' + @AwayValue  THEN 1
					WHEN @betteam = 'aos' AND ISNULL(td.IsExistScore,0) = 0 THEN 1
					ELSE -1
				END	
			WHEN @pfID = 646 THEN
				CASE
					WHEN @betteam = 'ho' AND (CAST(@HomeValue AS INT) + @hdp2 - CAST(@AwayValue AS INT)) > 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) > 0 THEN 1
					WHEN @betteam = 'hu' AND (CAST(@HomeValue AS INT) + @hdp2 - CAST(@AwayValue AS INT)) > 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) < 0 THEN 1
					WHEN @betteam = 'ao' AND (CAST(@HomeValue AS INT) + @hdp2 - CAST(@AwayValue AS INT)) < 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) > 0 THEN 1
					WHEN @betteam = 'au' AND (CAST(@HomeValue AS INT) + @hdp2 - CAST(@AwayValue AS INT)) < 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) < 0 THEN 1
					ELSE -1
				END

			WHEN @pfID = 3913 THEN
				CASE
					WHEN @betteam = 'ho' AND (CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT)) > 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) > 0 THEN 1
					WHEN @betteam = 'hu' AND (CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT)) > 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) < 0 THEN 1
					WHEN @betteam = 'ao' AND (CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT)) < 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) > 0 THEN 1
					WHEN @betteam = 'au' AND (CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT)) < 0 AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) < 0 THEN 1
					ELSE -1
				END

			WHEN @pfID = 9538 THEN
				CASE
					WHEN fm > 0 AND @betteam IN ('1b', 'xl', '2l') THEN 1
					WHEN fm = 0 AND @betteam IN ('xb', '1l', '2l') THEN 1
					WHEN fm < 0 AND @betteam IN ('2b', '1l', 'xl') THEN 1
					ELSE -1
				END
			WHEN @pfID = 9539 THEN
				CASE
					WHEN fm > 0 AND @betteam IN ('HB', 'AL') THEN 1
					WHEN fm = 0								 THEN 0
					WHEN fm < 0 AND @betteam IN ('AB', 'HL') THEN 1
					ELSE -1
				END
			WHEN @pfID IN ( 9541, 9606 ) THEN
				CASE
					WHEN fm < @hdp1 
						THEN CASE
								WHEN @betteam = 'n' THEN 1
								ELSE -1
							END
					WHEN fm >= @hdp2
						THEN CASE
								WHEN @betteam = 'y' THEN 1
								ELSE -1
							END
					ELSE -1
				END
			WHEN @pfID = 9490 THEN
				CASE 
					WHEN @betteam = 'AO' THEN
											CASE 
												WHEN @pfID = 9490 AND fm > 4 THEN 1
												ELSE -1
											END
					WHEN @betteam = @HomeValue  THEN 1
					ELSE -1					 
				END

			WHEN @pfID IN (9484, 9486) THEN
				CASE WHEN @betteam = '0' THEN
											CASE WHEN @pfid = 9484 AND @HomeValue < @hdp1 THEN 1
												 WHEN @pfid = 9486 AND @HomeValue = @hdp1 THEN 1
												 ELSE -1
											END
					 WHEN @betteam IN ( '1', '2', '3', '4', '5', '6') AND @HomeValue = @hdp1 THEN 1
					 WHEN @betteam = '7' AND @HomeValue > @hdp1 THEN 1
					 ELSE -1
				END

			WHEN @pfID = 9540 THEN 
				CASE 
					WHEN @betteam IN ( 'HB', 'AL' ) AND @HomeValue = 'H' THEN 1
					WHEN @betteam IN ( 'AB', 'HL' ) AND @HomeValue = 'A' THEN 1
					ELSE -1
				END
			WHEN @pfId = 7901 THEN --Bitcoin and Cricket
				CASE
					WHEN fm = 0 THEN 0
					WHEN @betteam = 'o' AND fm > 0 THEN 1
					WHEN @betteam = 'u' AND fm < 0  THEN 1
					ELSE - 1
				END 			
			WHEN @pfID = 9650 THEN
				CASE 
					WHEN CHARINDEX(@betteam, @HomeValue) > 0 THEN 1 
					ELSE -1
				END
			WHEN @pfID = 9662 THEN --betteam = homevalue
			   CASE WHEN @betteam = @HomeValue THEN 1
					WHEN @HomeValue IN ('n', 'd') THEN 0
					ELSE -1 END
			ELSE -1 
		END AS modds
		,CASE 
			WHEN @pfID = 9650 THEN LEN(@HomeValue ) - LEN(REPLACE(@HomeValue, ',','')) + 1
			ELSE NULL
		END AS DeadHeat
   FROM
	(
		SELECT (CASE 
					WHEN @pfID = 1 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1 - @LiveHomeScore) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2 - @LiveAwayScore)
					WHEN @pfID = 10 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2) -- not use livescore
					WHEN @pfID = 3904 THEN CASE WHEN @HomeValue = 'N' THEN 0
												ELSE (CAST(@HomeValue AS SMALLMONEY) - @hdp1) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2)
										   END
					WHEN @pfID = 9116 THEN (CAST(@HomeValue AS MONEY) - @hdp1 * 1000) - (CAST(@AwayValue AS MONEY) - @hdp2 * 1000)
					WHEN @pfID = 2 THEN (CAST(@HomeValue AS MONEY) + CAST(@AwayValue AS MONEY)) % 2
					
					--Over/Under
					WHEN @pfID IN (3, 9448) THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @hdp1)
					WHEN @pfID = 3905 THEN CASE WHEN @HomeValue = 'N' THEN 0
													ELSE (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @hdp1)
												END
					WHEN @pfID = 9117 THEN (CAST(@HomeValue AS MONEY) + CAST(@AwayValue AS MONEY) - @hdp1 * 1000)
					WHEN @pfID = 9118 THEN CAST(@HomeValue AS MONEY) - @hdp1 * 1000
					WHEN @pfID = 9119 THEN CAST(@AwayValue AS MONEY) - @hdp1 * 1000
					
					WHEN @pfID IN (20,711, 608, 614, 5, 24, 3911) THEN CAST(@HomeValue AS MONEY) - CAST(@AwayValue AS MONEY)

					WHEN @pfID = 3915 THEN CASE WHEN @HomeValue = 'N' THEN 99
												ELSE CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
											END

					WHEN @pfID = 101 THEN (CAST(@HomeValue AS SMALLMONEY) * 60 + CAST(@AwayValue AS SMALLMONEY)) - (@hdp1 * 60)

					WHEN @pfId = 9090 THEN 
										CASE WHEN LEFT(@HomeValue,1) = '-' THEN -(ABS(CAST(@HomeValue AS SMALLMONEY)) * 60 + CAST(@AwayValue AS SMALLMONEY)) - (@hdp1 * 60)
											 ELSE (CAST(@HomeValue AS SMALLMONEY) * 60 + CAST(@AwayValue AS SMALLMONEY)) - (@hdp1 * 60)
										END
					--Happy5
					WHEN @pfID IN (8101, 619, 9490, 9541, 9484, 9486) THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID = 8102 THEN CAST(@HomeValue AS SMALLMONEY) % 2
					WHEN @pfID = 8103 THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID IN (8104, 601, 602, 501, 9538, 9539) THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 8105 THEN CAST(@HomeValue AS SMALLMONEY)

					WHEN @pfID = 620 THEN CAST(@AwayValue AS SMALLMONEY)
					--PHAIO 5
					WHEN @pfID IN (391, 618) THEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID IN (387, 386, 7901) THEN CAST(@HomeValue AS SMALLMONEY) - @hdp1
					WHEN @pfID IN (401, 9128) THEN CAST(@HomeValue AS SMALLMONEY) - @hdp1
					WHEN @pfID IN (402,9096) THEN CAST(@AwayValue AS SMALLMONEY) - @hdp1

					--CricketAIO
					WHEN @pfID = 9606 THEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)

					ELSE -1 END)
			AS fm
	) tbl

	OUTER APPLY -- bettype 376: input betcheck into @AwayValue
	(
		SELECT	ROW_NUMBER () OVER (ORDER BY(SELECT NULL)) AS rn
				,CAST(CASE WHEN f.[value] = '' THEN CAST(1 AS SMALLMONEY) ELSE f.[value] END AS SMALLMONEY) AS odds
		FROM	STRING_SPLIT(@AwayValue, ',') f
		WHERE	@pfID = 376
				AND ISNULL(@AwayValue,'') <> ''
	) ps
	OUTER APPLY
	(	
		SELECT	TOP 1 1 AS IsExistScore
		FROM	STRING_SPLIT(@TransDesc, ',') t
		WHERE	@pfID = 3910 
				AND t.value = @HomeValue + ':' + @AwayValue
	)td
	GROUP BY tbl.fm, td.IsExistScore

)
GO
