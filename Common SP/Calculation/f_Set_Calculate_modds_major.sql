/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Calculate_modds_major] (
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
/*	Created: 20201123@Kathy
	Task: cal modds
	DB: DBTXN/bodb02
	Revisions:	
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210730@Kathy: Apply Settlement by Profile for minor bettype of soccer [Redmine:#158477]
		
*/
RETURN
(
   SELECT  CASE
			WHEN @pfID IN (1,20) THEN --Handicap
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
					 
			WHEN @pfID IN (2, 136, 138) THEN --Odd/even
			   CASE WHEN @betteam IN ('h', 'o') AND fm = 1 THEN 1
					WHEN @betteam IN ('a', 'e') AND fm = 0 THEN 1
					ELSE -1 END				
			WHEN @pfID IN (3, 388, 389) THEN --Over/under
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
			WHEN @pfid = 4 THEN
				CASE 
					WHEN @betteam = @HomeValue + ':' + @AwayValue THEN 1
					WHEN @betteam = '5:0' AND fm >= 5 THEN 1
					WHEN @betteam = '0:5' AND fm <= - 5 THEN 1
					ELSE - 1
				END				
			WHEN @pfid = 6 THEN
				CASE 
					WHEN @betteam = '0-1' AND fm <= 1 THEN 1
					WHEN @betteam = '2-3' AND fm BETWEEN 2 AND 3 THEN 1
					WHEN @betteam = '4-6' AND fm BETWEEN 4 AND 6 THEN 1
					WHEN @betteam IN ('4-over', '4&over') AND fm >= 4 THEN 1
					WHEN @betteam IN ('7-over', '7&over') AND fm >= 7 THEN 1
					ELSE -1
				END
			WHEN @pfid = 13 THEN
				CASE 
					WHEN @betteam = 'hy' AND CAST(@AwayValue AS INT) = 0 THEN 1
					WHEN @betteam = 'hn' AND CAST(@AwayValue AS INT) > 0 THEN 1
					WHEN @betteam = 'ay' AND CAST(@HomeValue AS INT) = 0 THEN 1
					WHEN @betteam = 'an' AND CAST(@HomeValue AS INT) > 0 THEN 1
					ELSE -1
				END
			WHEN @pfid = 14 THEN
			CASE 
				WHEN @betteam = @HomeValue OR @betteam = @AwayValue THEN 1
				ELSE -1
			END
			WHEN @pfid = 16 THEN
				CASE
					WHEN @betteam = @HomeValue THEN 1
					ELSE - 1
				END
		
			WHEN @pfID = 22 THEN
				CASE
					WHEN @betteam = '1' AND SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = 'H' THEN 1
					WHEN @betteam = '2' AND SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = 'A' THEN 1
					WHEN @betteam = 'X' AND SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = '' THEN 1
					ELSE -1
				end
			WHEN @pfID = 24 THEN
				CASE 
					WHEN tbl.fm >= 0 AND @betteam = '1x' THEN 1
					WHEN tbl.fm <= 0 AND @betteam = '2x' THEN 1
					WHEN tbl.fm <> 0 AND @betteam = '12' THEN 1
					ELSE -1
					END
			WHEN @pfID = 25 THEN
				CASE 
					WHEN tbl.fm = 0 THEN 0
					WHEN tbl.fm < 0 AND @betteam = 'a' THEN 1
					WHEN tbl.fm > 0 AND @betteam = 'h' THEN 1
					ELSE -1
					END
			WHEN @pfID = 26 THEN
				CASE 
					WHEN @betteam = 'b' AND CAST(@HomeValue AS INT) > 0 AND CAST(@AwayValue AS INT) > 0 THEN 1
					WHEN @betteam = 'o' AND ((CAST(@HomeValue AS INT) > 0 AND CAST(@AwayValue AS INT) = 0) 
							OR (CAST(@HomeValue AS INT) = 0 AND CAST(@AwayValue AS INT) > 0) 
						) THEN 1
					WHEN @betteam = 'n' AND CAST(@HomeValue AS INT) = 0 AND CAST(@AwayValue AS INT) = 0 THEN 1
					ELSE -1
				END		
			WHEN @pfID = 27 THEN
				CASE 
					WHEN @betteam = 'h' AND (CAST(@HomeValue AS INT) > CAST(@AwayValue AS INT) AND CAST(@AwayValue AS INT) = 0) THEN 1
					WHEN @betteam = 'a' AND (CAST(@AwayValue AS INT) > CAST(@HomeValue AS INT) AND CAST(@HomeValue AS INT) = 0) THEN 1
					ELSE -1
				END
			WHEN @pfID = 28 THEN
				CASE 
					WHEN @betteam = '1' AND (@hdp2 - @hdp1 + fm) > 0 THEN 1
					WHEN @betteam = '2' AND (@hdp1 - @hdp2 - fm) > 0 THEN 1
					WHEN @betteam = 'x' AND (@hdp1 - @hdp2 - fm ) = 0 THEN 1
					ELSE -1
				END		
			WHEN @pfID = 30 THEN
				CASE 
					WHEN @betteam = '4:0' AND CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT) >= 4 THEN 1
					WHEN @betteam = '0:4' AND CAST(@AwayValue AS INT) - CAST(@HomeValue AS INT) >= 4 THEN 1
					WHEN @betteam = @HomeValue + ':' + @AwayValue THEN 1
					ELSE -1
				END		
			WHEN @pfID = 121 THEN
				CASE 
					WHEN fm > 0 THEN 0
					WHEN @betteam = 'x' AND fm = 0 THEN 1
					WHEN @betteam = 'a' AND fm < 0 THEN 1
					ELSE -1
				END	
			WHEN @pfID = 122 THEN
				CASE 
					WHEN fm < 0 THEN 0
					WHEN @betteam = 'x' AND fm = 0 THEN 1
					WHEN @betteam = 'h' AND fm > 0 THEN 1
					ELSE -1
				END	
			WHEN @pfID = 123 THEN
				CASE 
					WHEN @betteam = 'a' AND fm <> 0 THEN 1
					WHEN @betteam = 'h' AND fm = 0 THEN 1
					ELSE -1
				END						
			WHEN @pfID = 129 THEN
				CASE 
					WHEN @betteam = '5&over' THEN CASE WHEN fm >=5 THEN 1 ELSE -1 END
					WHEN @betteam = CAST(CAST(fm AS INT) AS VARCHAR) THEN 1
					ELSE -1
				END				
			WHEN @pfID = 130 THEN
				CASE 
					WHEN @betteam = '7&over' THEN CASE WHEN fm >=7 THEN 1 ELSE -1 END
					WHEN @betteam = CAST(CAST(fm AS INT) AS VARCHAR) THEN 1
					ELSE -1
				END				
			WHEN @pfID IN (131, 132) THEN
				CASE 
					WHEN @betteam = '0-1' AND fm <=1 THEN 1
					WHEN @betteam = '2-3' AND fm BETWEEN 2 AND 3 THEN 1
					WHEN @betteam = '4&over' AND fm >= 4 THEN 1
					ELSE -1
				END		
			
			WHEN @pfID = 143 THEN
				CASE 
					WHEN @betteam = 'ho' AND @HomeValue > 0 THEN @AwayValue - @hdp1
					WHEN @betteam = 'hu' AND @HomeValue > 0 THEN @hdp1 - @AwayValue
					WHEN @betteam = 'ao' AND @HomeValue < 0 THEN @AwayValue - @hdp1
					WHEN @betteam = 'au' AND @HomeValue < 0 THEN @hdp1 - @AwayValue
					WHEN @betteam = 'do' AND @HomeValue = 0 THEN @AwayValue - @hdp1
					WHEN @betteam = 'du' AND @HomeValue = 0 THEN @hdp1 - @AwayValue    
					ELSE -1
				END		
			WHEN @pfID = 145 THEN
				CASE 
					WHEN @betteam = 'y' AND (@HomeValue > 0) AND (@AwayValue > 0) THEN 1
					WHEN @betteam = 'n' AND ((@HomeValue = 0) OR (@AwayValue = 0)) THEN 1
					ELSE -1
				END	
			WHEN @pfid = 165 THEN
				CASE 
					WHEN @betteam = @HomeValue + ':' + @AwayValue THEN 1					
					ELSE - 1
				END
			WHEN @pfid = 170 THEN
				CASE 
					WHEN @betteam = 'b' AND (CAST(@HomeValue AS INT) > 0 AND CAST(@AwayValue AS INT) > 0) THEN 1	
					WHEN @betteam = 'n' AND (CAST(@HomeValue AS INT) = 0 AND CAST(@AwayValue AS INT) = 0) THEN 1
					WHEN @betteam = 'h' AND (CAST(@HomeValue AS INT) > 0 AND CAST(@AwayValue AS INT) = 0) THEN 1	
					WHEN @betteam = 'a' AND (CAST(@HomeValue AS INT) = 0 AND CAST(@AwayValue AS INT) > 0) THEN 1
					ELSE - 1
				END
			WHEN @pfID = 171 THEN
				CASE
					WHEN @betteam = 'h1' AND fm = 1 THEN 1 
					WHEN @betteam = 'h2' AND fm = 2 THEN 1 
					WHEN @betteam = 'h3' AND fm >= 3 THEN 1 
					WHEN @betteam = 'd' AND fm = 0 THEN 1
					WHEN @betteam = 'a1' AND fm = -1 THEN 1 
					WHEN @betteam = 'a2' AND fm = -2 THEN 1 
					WHEN @betteam = 'a3' AND fm <= -3 THEN 1 
					ELSE -1
				END
			WHEN @pfID = 179 THEN
				CASE
					WHEN @betteam LIKE 'G[0-3]' AND fm = CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					WHEN @betteam ='G4' AND fm >=CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					ELSE -1
				END
			WHEN @pfID = 186 THEN
				CASE
					WHEN @betteam = 'HD' AND CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT) >= 0 THEN 1 
					WHEN @betteam = 'DA' AND CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT) <= 0 THEN 1
					WHEN @betteam = 'HA' AND CAST(@HomeValue AS INT) - CAST(@AwayValue AS INT) <> 0 THEN 1
					ELSE -1
				END
			WHEN @pfID = 187 THEN
				CASE
					WHEN @betteam LIKE 'G[0-1]' AND fm = CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					WHEN @betteam ='G2' AND fm >=CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					ELSE -1
				END
			WHEN @pfID = 392 THEN
				CASE
					WHEN @betteam NOT IN ('HAOS', 'AAOS') AND @betteam = @HomeValue + '-' + @AwayValue THEN 1
					WHEN @betteam IN ('HAOS') AND CAST(@HomeValue AS INT) > CAST(@AwayValue AS INT)
							AND CHARINDEX(@HomeValue + '-' + @AwayValue, @Transdesc) = 0 THEN 1
					WHEN @betteam IN ('AAOS') AND CAST(@HomeValue AS INT) < CAST(@AwayValue AS INT) 
							AND CHARINDEX(@HomeValue + '-' + @AwayValue, @Transdesc) = 0 THEN 1
					ELSE -1
				END
			WHEN @pfID = 399 THEN
				CASE
					WHEN @betteam <> 'AOS' AND @betteam = @HomeValue + '-' + @AwayValue THEN 1
					WHEN @betteam = 'AOS' AND CHARINDEX(@HomeValue + '-' + @AwayValue, @Transdesc) = 0 THEN 1
					ELSE -1
				END
			WHEN @pfID = 405 THEN
				CASE 
					WHEN @betteam = @HomeValue THEN 1
					WHEN @betteam = 'AOS' --Any Other Scores
							AND CHARINDEX(@HomeValue, @transdesc) = 0 THEN 1
					ELSE -1
				END
			WHEN @pfID = 406 THEN
				CASE
					WHEN @betteam LIKE 'G[0-5]' AND fm = CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					WHEN @betteam ='G6' AND fm >=CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					ELSE -1
				END
			WHEN @pfID IN (407,409) THEN
				CASE
					WHEN @betteam LIKE 'G[0-2]' AND fm = CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					WHEN @betteam ='G3' AND fm >=CAST(RIGHT(@betteam,1)AS SMALLMONEY) THEN 1 
					ELSE -1
				END
			WHEN @pfID = 408 THEN
				CASE
					WHEN @betteam = 'h1' AND fm = 1 THEN 1 
					WHEN @betteam = 'h2' AND fm = 2 THEN 1 
					WHEN @betteam = 'h3' AND fm >= 3 THEN 1 
					WHEN @betteam = 'd' AND fm = 0 AND CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) <> 0 THEN 1
					WHEN @betteam = 'NG' AND fm = 0 AND CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) = 0 THEN 1 --No Goal
					WHEN @betteam = 'a1' AND fm = -1 THEN 1 
					WHEN @betteam = 'a2' AND fm = -2 THEN 1 
					WHEN @betteam = 'a3' AND fm <= -3 THEN 1 
					ELSE -1
				END
			WHEN @pfID = 412 THEN
				CASE 
					WHEN @betteam = CAST((CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT)) AS VARCHAR) THEN 1
					WHEN @betteam = '3-over' AND fm >= 3 THEN 1
					ELSE -1
				END
			WHEN @pfID = 416 THEN
				CASE
					WHEN CHARINDEX('AOS',@betteam) = 0 THEN CASE
																WHEN @betteam = @HomeValue + '/' + @AwayValue THEN 1
																ELSE -1
															END
					WHEN CHARINDEX('AOS/AOS',@betteam) > 0 THEN CASE
																	WHEN CHARINDEX(@HomeValue,tbl.ExcludingHTChoice) = 0 AND CHARINDEX(@AwayValue,tbl.ExcludingFTChoice) = 0 THEN 1
																	ELSE -1
																END
					WHEN CHARINDEX('/AOS',@betteam) > 0 THEN CASE
																WHEN @betteam = @HomeValue + '/AOS' AND CHARINDEX(@AwayValue,tbl.ExcludingFTChoice) = 0 THEN 1
																ELSE -1
															END
					WHEN CHARINDEX('AOS/',@betteam) > 0 THEN CASE
																WHEN @betteam = 'AOS/' + @AwayValue AND CHARINDEX(@HomeValue,tbl.ExcludingHTChoice) = 0 THEN 1
																ELSE -1
															END
					ELSE -1
				END				
			WHEN @pfID = 418 THEN
				CASE 
					WHEN CAST(@HomeValue AS INT) > 0 AND CAST(@AwayValue AS INT) > 0 
						THEN CASE	
								WHEN @betteam = 'YO' AND CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) > @hdp1 THEN 1
								WHEN @betteam = 'YU' AND CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) < @hdp1 THEN 1
								ELSE -1
							END
					ELSE CASE
							WHEN @betteam = 'NO' AND CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) > @hdp1 THEN 1
							WHEN @betteam = 'NU' AND CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) < @hdp1 THEN 1
							ELSE - 1
						END
				END
			WHEN @pfID = 429 THEN
				CASE 
					WHEN @betteam = '3-over' THEN CASE WHEN fm >= 3 THEN 1 ELSE -1 END
					WHEN @betteam = CAST(CAST(fm AS INT) AS VARCHAR(10)) THEN 1
					ELSE - 1
				END
			WHEN @pfID = 449 THEN
				CASE 
					WHEN @betteam = '1XO' AND @AwayValue >= 0 AND @HomeValue - @hdp1 > 0 THEN 1
					WHEN @betteam = '1XU' AND @AwayValue >= 0 AND @HomeValue - @hdp1 < 0 THEN 1
					WHEN @betteam = '12O' AND @AwayValue <> 0 AND @HomeValue - @hdp1 > 0 THEN 1
					WHEN @betteam = '12U' AND @AwayValue <> 0 AND @HomeValue - @hdp1 < 0 THEN 1
					WHEN @betteam = '2XO' AND @AwayValue <= 0 AND @HomeValue - @hdp1 > 0 THEN 1
					WHEN @betteam = '2XU' AND @AwayValue <= 0 AND @HomeValue - @hdp1 < 0 THEN 1
					ELSE -1
				END
			WHEN @pfID = 450 THEN	
				CASE 
					WHEN @betteam = 'OO' AND @AwayValue = 1 AND @HomeValue > @hdp1 THEN 1
					WHEN @betteam = 'OU' AND @AwayValue = 1 AND @HomeValue < @hdp1 THEN 1
					WHEN @betteam = 'EO' AND @AwayValue = 0 AND @HomeValue > @hdp1 THEN 1
					WHEN @betteam = 'EU' AND @AwayValue = 0 AND @HomeValue < @hdp1 THEN 1
					ELSE -1
				END	
			WHEN @pfID = 451 THEN
				CASE
					WHEN @betteam = 'Y1X' AND (CAST(@HomeValue AS INT) > 0  AND CAST(@AwayValue AS INT) > 0) AND fm >= 0 THEN 1
					WHEN @betteam = 'Y12' AND (CAST(@HomeValue AS INT) > 0  AND CAST(@AwayValue AS INT) > 0) AND fm <> 0 THEN 1
					WHEN @betteam = 'Y2X' AND (CAST(@HomeValue AS INT) > 0  AND CAST(@AwayValue AS INT) > 0) AND fm <= 0 THEN 1

					WHEN @betteam = 'N1X' AND (CAST(@HomeValue AS INT) = 0  OR CAST(@AwayValue AS INT) = 0) AND fm >= 0 THEN 1
					WHEN @betteam = 'N12' AND (CAST(@HomeValue AS INT) = 0  OR CAST(@AwayValue AS INT) = 0) AND fm <> 0 THEN 1
					WHEN @betteam = 'N2X' AND (CAST(@HomeValue AS INT) = 0  OR CAST(@AwayValue AS INT) = 0) AND fm <= 0 THEN 1
					ELSE -1
				END 
			WHEN @pfID = 452 THEN	
				CASE 
					WHEN @betteam = '1H' AND @HomeValue > @AwayValue THEN 1
					WHEN @betteam = '2H' AND @HomeValue < @AwayValue THEN 1
					WHEN @HomeValue = @AwayValue THEN 0
					ELSE -1
				END		
			WHEN @pfID = 453 THEN 
				CASE
					WHEN @betteam = '1' AND ((@HomeValue - @hdp1) - (@AwayValue - @hdp2)) > 0  THEN 1
					WHEN @betteam = '2' AND ((@HomeValue - @hdp1) - (@AwayValue - @hdp2)) < 0  THEN 1
					WHEN @betteam = 'x' AND ((@HomeValue - @hdp1) - (@AwayValue - @hdp2)) = 0  THEN 1
					ELSE - 1
				END
			WHEN @pfID = 454 THEN -- Double Chance/First Team To Score
				CASE
					WHEN @betteam = '1XH' AND @AwayValue >= 0 AND @HomeValue = 'H' THEN 1
					WHEN @betteam = '12H' AND @AwayValue <> 0 AND @HomeValue = 'H' THEN 1
					WHEN @betteam = '2XH' AND @AwayValue <= 0 AND @HomeValue = 'H' THEN 1
					WHEN @betteam = '1XA' AND @AwayValue >= 0 AND @HomeValue = 'A' THEN 1
					WHEN @betteam = '12A' AND @AwayValue <> 0 AND @HomeValue = 'A' THEN 1
					WHEN @betteam = '2XA' AND @AwayValue <= 0 AND @HomeValue = 'A' THEN 1
					WHEN @betteam = 'NG' AND @AwayValue = 0 AND @HomeValue = 'N' THEN 1
					ELSE - 1
				END
			WHEN @pfID = 457 THEN 
				CASE
					WHEN @betteam = 'YO' AND @HomeValue > 0 AND  @AwayValue > 0  AND fm > @hdp1 THEN 1
					WHEN @betteam = 'YU' AND @HomeValue > 0 AND  @AwayValue > 0  AND fm < @hdp1 THEN 1
					WHEN @betteam = 'NO' AND (@HomeValue = 0 OR  @AwayValue = 0) AND fm > @hdp1 THEN 1
					WHEN @betteam = 'NU' AND (@HomeValue = 0 OR  @AwayValue = 0) AND fm < @hdp1 THEN 1
					ELSE -1
				END
			WHEN @pfID = 458 THEN 
				CASE
					WHEN @betteam = '1' AND @HomeValue - @LiveHomeScore > @AwayValue - @LiveAwayScore THEN 1
					WHEN @betteam = '2' AND @HomeValue - @LiveHomeScore < @AwayValue - @LiveAwayScore THEN 1
					WHEN @betteam = 'X' AND @HomeValue - @LiveHomeScore = @AwayValue - @LiveAwayScore THEN 1
					ELSE -1
				END
			WHEN @pfID = 460 THEN 
				CASE
					WHEN @betteam = 'H' AND fm >= 5  THEN 1
					WHEN @betteam = 'A' AND fm <= -5 THEN 1
					ELSE -1
				END	 
			WHEN @pfID = 468 THEN -1 -- Always set lose for pfid
			WHEN @pfID = 473 THEN 
				CASE 
					WHEN @betteam = '0-5' and fm <= 5 THEN 1
					WHEN @betteam = '6-8' and fm in (6,7,8) THEN 1
					WHEN @betteam = '9-11' and fm in (9,10,11) THEN 1
					WHEN @betteam = '12-14' and fm in (12,13,14) THEN 1
					WHEN @betteam = '15+' and fm >= 15 THEN 1
					ELSE -1 
				END
			WHEN @pfID = 474 THEN 
				CASE 
					WHEN @betteam = '0-2' and fm <= 2 THEN 1
					WHEN @betteam = '3-4' and fm in (3,4) THEN 1
					WHEN @betteam = '5-6' and fm in (5,6) THEN 1
					WHEN @betteam = '7+' and fm >= 7 THEN 1
					ELSE -1 
				END
			WHEN @pfID = 475 THEN 
				CASE 
					WHEN @betteam = 'o' AND fm > @hdp1 THEN 1
					WHEN @betteam = 'u' AND fm < @hdp1 THEN 1
					WHEN @betteam = 'e' AND fm = @hdp1 THEN 1
					ELSE -1
				END
			WHEN @pfID = 488 THEN 
				CASE 
					WHEN @betteam = @HomeValue THEN 1
					WHEN @HomeValue = '' THEN 0
					ELSE -1
				END
			
			WHEN @pfID = 493 THEN 
				CASE 
					WHEN @betteam = 'AOS'
						THEN CASE
								WHEN CHARINDEX(@HomeValue, @Transdesc) = 0 THEN 1 ELSE -1 END
					WHEN @betteam = @HomeValue THEN 1
					ELSE - 1
				END
			WHEN @pfID = 494 THEN 
				CASE 
					WHEN @betteam = 'AOS' 
						THEN CASE
								WHEN CHARINDEX(@HomeValue + '-' + @AwayValue, @Transdesc) = 0 THEN 1
								ELSE -1
							END
					WHEN @betteam = @HomeValue + '-' + @AwayValue THEN 1
					ELSE -1
					END
			WHEN @pfID = 497 THEN 
				CASE 
					WHEN @betteam IN ('1h', '2h') AND @HomeValue = 'tie' THEN 0
					WHEN @betteam = @HomeValue THEN 1
					ELSE -1
					END
			WHEN @pfID = 486 THEN 
				CASE
					WHEN CHARINDEX(';' + CAST(CAST(@hdp1 AS INT) AS VARCHAR) + @betteam + ';', ';' + @HomeValue) > 0 THEN 1
					WHEN @betteam = 'N' AND @AwayValue <= @hdp1 THEN 1
					ELSE -1
				END
			WHEN @pfID = 5 THEN
				CASE 
					WHEN tbl.fm > 0 AND @betteam = '1' THEN 1
					WHEN tbl.fm = 0 AND @betteam = 'x' THEN 1
					WHEN tbl.fm < 0 AND @betteam = '2' THEN 1
					ELSE -1
					END
			ELSE -1
		END AS modds
   FROM
	(
		SELECT (CASE 
					WHEN @pfID = 1 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1 - @LiveHomeScore) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2 - @LiveAwayScore)
					WHEN @pfID = 20 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2)
					WHEN @pfID = 2 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)) % 2
					WHEN @pfID = 136 THEN CAST(@HomeValue AS SMALLMONEY) % 2
					WHEN @pfID = 138 THEN CAST(@AwayValue AS SMALLMONEY) % 2
					WHEN @pfID = 3 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @hdp1)
					WHEN @pfID IN (5, 408, 4, 24, 25, 28, 121, 122, 123, 171, 451, 460) THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)					
					WHEN @pfID IN (131, 407) THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID IN (132, 409) THEN CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID IN (6, 129, 130, 159, 179, 187, 412, 406, 429, 457, 473, 474, 475) THEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID IN (388) THEN CAST(@AwayValue AS SMALLMONEY) - @hdp1
					WHEN @pfID IN (389) THEN CAST(@HomeValue AS SMALLMONEY) - @hdp1
					ELSE -1 END)
			AS fm
			,MAX(CASE WHEN @pfID = 416 THEN SUBSTRING(@transdesc,0, CHARINDEX('/',@transdesc)) ELSE NULL END) AS ExcludingHTChoice
			,MAX(CASE WHEN @pfID = 416 THEN SUBSTRING(@transdesc,CHARINDEX('/',@transdesc)+1,LEN(@transdesc)) ELSE NULL END) AS ExcludingFTChoice
	) tbl

	

)
GO