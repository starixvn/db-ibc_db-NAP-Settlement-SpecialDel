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
		
*/
RETURN
(
   SELECT  CASE
			WHEN @pfID IN (1) THEN --Handicap
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
					
			WHEN @pfID IN (3) THEN --Over/under
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
			WHEN @pfID = 407 THEN
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
			
			WHEN @pfID = 5 THEN
				CASE 
					WHEN tbl.fm > 0 AND @betteam = '1' THEN 1
					WHEN tbl.fm = 0 AND @betteam = 'x' THEN 1
					WHEN tbl.fm < 0 AND @betteam = '2' THEN 1
					ELSE -1
					END
			WHEN @pfID IN (468, 469) THEN
				CASE 
					WHEN o.odds > 0 THEN 1
					WHEN o.odds < 0 THEN -1
					WHEN o.odds = 0 THEN 0
					ELSE - 1
				END
			ELSE -1
		END AS modds
   FROM
	(
		SELECT (CASE 
					WHEN @pfID = 1 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1 - @LiveHomeScore) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2 - @LiveAwayScore)
					WHEN @pfID = 2 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)) % 2
					WHEN @pfID = 3 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @hdp1)
					WHEN @pfID IN (5, 408, 4) THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)					
					WHEN @pfID IN (407) THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID IN (6, 412, 406) THEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 468 
						THEN CASE	
								WHEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY) - (@LiveHomeScore - @LiveAwayScore) > @hdp1 THEN @hdp1
								WHEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY) - (@LiveHomeScore - @LiveAwayScore) < @hdp1 - @hdp2 + 1 THEN @hdp1 - @hdp2 + 1
								ELSE CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY) - (@LiveHomeScore - @LiveAwayScore)
							END
					WHEN @pfID = 469
						THEN CASE
								WHEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) > @hdp1 THEN @hdp1
								WHEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) < @hdp1 - @hdp2 + 1 THEN @hdp1 - @hdp2 + 1
								ELSE CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)
							END
					ELSE -1 END
					)
			AS fm
			,MAX(CASE WHEN @pfID = 416 THEN SUBSTRING(@transdesc,0, CHARINDEX('/',@transdesc)) ELSE NULL END) AS ExcludingHTChoice
			,MAX(CASE WHEN @pfID = 416 THEN SUBSTRING(@transdesc,CHARINDEX('/',@transdesc)+1,LEN(@transdesc)) ELSE NULL END) AS ExcludingFTChoice
	) tbl
	OUTER APPLY
	(
		SELECT CHARINDEX(CAST(CAST(fm AS INT) AS VARCHAR(10)) + ':', @betcheck) + LEN(CAST(fm AS INT)) + 1 AS posOdds
		WHERE @pfID IN (468, 469)
	)po
	OUTER APPLY
	(
		SELECT SUBSTRING(@betcheck, po.posOdds, (CHARINDEX(',', @betcheck + ',', po.posOdds)) - po.posOdds) odds
		WHERE @pfID IN (468, 469)
	)o

	

)
GO