/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_SDT_modds] (
		@pfID			SMALLINT
		,@betteam 		NVARCHAR(10)
		,@hdp1			SMALLMONEY
		,@hdp2			SMALLMONEY
		,@hth 			INT
		,@hta			INT
		,@fth 			INT
		,@fta 			INT
		,@HomeValue		VARCHAR(2000)
		,@AwayValue		VARCHAR(2000)
		,@LiveHomeScore SMALLINT
		,@LiveAwayScore SMALLINT
		,@Transdesc		NVARCHAR(1000)
		,@betcheck		NVARCHAR(50)
		,@IsABANDONEDHT BIT
		)
RETURNS TABLE
AS  
/*	Created: 20211215@Kathy
	Task: SDT - cal modds
	DB: DBTXN/bodb02
	Revisions:	
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		
*/
RETURN
(
   SELECT	COALESCE(m1.modds1, m2.modds2, NULL) AS modds
			,CASE WHEN @pfID = 469 THEN o.odds ELSE NULL END AS ScoreBoxOdds
			,CASE WHEN @pfID = 469 THEN t.score ELSE NULL END AS ScoreBoxScore
   FROM
	(
		SELECT CAST((CASE 
					WHEN @pfID IN (3,6,130,144,165,159,397,408,419,449,450,467,473,475,493) THEN @fth + @fta 
					WHEN @pfID IN (8,126,129,140,143,179,189,190,412,426,442,445,457,452,474,476,496,497) THEN @hth + @hta
					WHEN @pfID IN (18,187,429) THEN (@fth + @fta) - (@hth + @hta)
					WHEN @pfID IN (131,161,389,420,446,451,399) THEN @fth
					WHEN @pfID IN (132,162,388,421,447) THEN @fta
					WHEN @pfID IN (141,147,149,181,403,436,438,440,443,456,494) THEN @hth
					WHEN @pfID IN (495) THEN @fth - @hth
					WHEN @pfID IN (142,148,150,182,404,437,439,441,444) THEN @hta
					WHEN @pfID IN (133) THEN @hth - @hta 
					WHEN @pfID IN (134) THEN @hta - @hth
					WHEN @pfID = 128 THEN (@hth + @hta) % 2
					WHEN @pfID = 469 
						THEN CASE 
								WHEN @fth + @fta > @hdp1 THEN @hdp1
								WHEN @fth + @fta < @hdp1 - @hdp2 + 1 THEN @hdp1 - @hdp2 + 1
								ELSE @fth + @fta 
							END
					ELSE NULL END) AS INT)
			AS score
			,CAST(CASE 
				WHEN @pfID IN (140,189,190,442,445,452,496,497) THEN (@fth + @fta) - (@hth + @hta) 
				WHEN @pfID IN (141,147,436,443) THEN @fth - @hth 
				WHEN @pfID IN (142,148,437,444,495) THEN @fta - @hta
				WHEN @pfID IN (149,421,438,440,456,447,494) THEN @hta 
				WHEN @pfID IN (150,420,439,441,446) THEN @hth
				WHEN @pfID IN (419,467,493) THEN @hth + @hta
				WHEN @pfID IN (451,399) THEN @fta 
				ELSE NULL
			END AS INT) AS score2
			,CASE
				WHEN @pfID = 152 
					THEN CASE
							WHEN @hth + @hta >= 4
								THEN '4+'
							ELSE CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10))
						END
				ELSE NULL
			END AS CS1H
			,CASE WHEN @pfID = 416 THEN SUBSTRING(@betteam,0,CHARINDEX('/',@betteam)) ELSE NULL END AS betteam1H
			,CASE WHEN @pfID = 416 THEN SUBSTRING(@betteam,CHARINDEX('/',@betteam)+1, LEN(@betteam)) ELSE NULL END AS betteamFT
			,CASE WHEN @pfID = 416 THEN SUBSTRING(@transdesc,0, CHARINDEX('/',@transdesc)) ELSE NULL END AS ExcludingHTChoice
			,CASE WHEN @pfID = 416 THEN SUBSTRING(@transdesc,CHARINDEX('/',@transdesc)+1,LEN(@transdesc)) ELSE NULL END AS ExcludingFTChoice
	)t
	OUTER APPLY
	(
		SELECT CHARINDEX(CAST(t.score AS VARCHAR(10)) + ':', @betcheck) + LEN(t.score) + 1 AS posOdds
		WHERE @pfID = 469
	)po
	OUTER APPLY
	(
		SELECT CAST(SUBSTRING(@betcheck, po.posOdds, (CHARINDEX(',', @betcheck + ',', po.posOdds)) - po.posOdds) AS MONEY) odds
		WHERE @pfID = 469
	)o
	OUTER APPLY (
		SELECT  CASE
			WHEN @pfID IN (3,8,18,388,389,403,404) THEN
				CASE 
					WHEN @betteam IN ('h', 'o') AND @hdp1 <= t.score - 0.25 THEN t.score - @hdp1 
					WHEN @betteam IN ('a', 'u') AND @hdp1 <= t.score - 0.25 THEN @hdp1 - t.score
					ELSE NULL
				END	
			WHEN @pfID = 4 THEN
				CASE 
					WHEN @betteam NOT IN ('0:5', '5:0') AND (@fth > LEFT(@betteam,1) OR @fta > RIGHT(@betteam,1)) THEN -1 
					ELSE NULL 
				END
			WHEN @pfID = 6 THEN
				CASE 
					WHEN @betteam IN ('7-over', '7&over') THEN CASE WHEN t.score >=7 THEN 1 ELSE NULL END
					WHEN t.score > RIGHT(@betteam,1) THEN -1
					ELSE NULL 
				END
			WHEN @pfID = 126 THEN
				CASE 
					WHEN @IsABANDONEDHT = 1 THEN
						CASE
							WHEN @betteam IN ('4-over', '4&over') THEN CASE WHEN t.score >=4 THEN 1 ELSE NULL END
							WHEN t.score > RIGHT(@betteam,1) THEN -1
							ELSE NULL 
						END
					ELSE NULL
				END
			WHEN @pfID = 13 THEN
				CASE
					WHEN @betteam = 'ay' AND @fth > 0  THEN -1
					WHEN @betteam = 'an' AND @fth > 0  THEN 1
					WHEN @betteam = 'hy' AND @fta > 0  THEN -1
					WHEN @betteam = 'hn' AND @fta > 0  THEN 1
					ELSE NULL
				END
			WHEN @pfID = 16 THEN
				CASE 
					WHEN @IsABANDONEDHT = 0 THEN 
						CASE
							WHEN @hth > @hta AND LEFT(@betteam,1) IN ('0','2') THEN -1
							WHEN @hth = @hta AND LEFT(@betteam,1) IN ('1','2') THEN -1
							WHEN @hth < @hta AND LEFT(@betteam,1) IN ('0','1') THEN -1
							ELSE NULL
						END
					ELSE NULL
				END	
			
			WHEN @pfID = 26 THEN
				CASE
					WHEN @betteam = 'b' AND @fth > 0 AND @fta > 0 THEN 1
					WHEN @betteam = 'o' AND @fth > 0 AND @fta > 0 THEN - 1
					WHEN @betteam = 'n' AND (@fth > 0 OR @fta > 0) THEN - 1
					ELSE NULL
				END
			WHEN @pfID = 27 THEN
				CASE 
					WHEN @betteam = 'a' AND @fth > 0 THEN - 1
					WHEN @betteam = 'h' AND @fta > 0 THEN - 1
					WHEN @fth > 0 AND @fta > 0 THEN - 1
					ELSE NULL
				END
			WHEN @pfID = 30 THEN
				CASE 
					WHEN @IsABANDONEDHT = 1 THEN
						CASE
							WHEN @betteam NOT IN ('0:4', '4:0') AND ((@hth > LEFT(@betteam,1) OR @hta > RIGHT(@betteam,1))) THEN -1
							ELSE NULL
						END
					ELSE NULL
				END
				
			WHEN @pfID = 128 THEN
				CASE 
					WHEN @IsABANDONEDHT = 0 THEN
						CASE
							WHEN @betteam IN ('oo', 'oe') AND t.score = 0 THEN - 1
							WHEN @betteam IN ('eo', 'ee') AND t.score = 1 THEN - 1
							ELSE NULL
						END
					ELSE NULL
				END
			WHEN @pfID = 129 THEN
				CASE 
					WHEN @IsABANDONEDHT = 1 THEN
						CASE
							WHEN @betteam IN ('5-over', '5&over') THEN CASE WHEN t.score >= 5 THEN 1 ELSE NULL END
							WHEN t.score > RIGHT(@betteam,1) THEN -1
							ELSE NULL
						END
					ELSE NULL
				END
			WHEN @pfID = 130  THEN
				CASE 
					WHEN @betteam IN ('7-over', '7&over') THEN CASE WHEN t.score >= 7 THEN 1 ELSE NULL END
					WHEN t.score > CAST(@betteam AS INT) THEN -1
					ELSE NULL
				END
			WHEN @pfID IN (131,132) THEN
				CASE 
					WHEN @betteam IN ('4-over', '4&over') THEN CASE WHEN t.score >= 4 THEN 1 ELSE NULL END
					WHEN t.score > RIGHT(@betteam,1) THEN -1
					ELSE NULL 
				END
			WHEN @pfID IN (133,134) THEN
				CASE 
					WHEN @IsABANDONEDHT = 0 THEN
						CASE
							WHEN @betteam = 'y' AND t.score <= 0 THEN -1
							WHEN @betteam = 'n' AND t.score <= 0 THEN 1
							ELSE NULL 
						END
					ELSE NULL
				END
			WHEN @pfID IN (140,141,142) THEN
				CASE
					WHEN @IsABANDONEDHT = 0 THEN
						CASE @betteam
							WHEN '1h' THEN
								CASE 
									WHEN t.score >= 0 AND t.score < t.score2 THEN -1
									WHEN t.score >= 0 AND t.score = t.score2 THEN -1
									ELSE NULL
								END
							WHEN '2h' THEN
								CASE 
									WHEN t.score >= 0 AND t.score < t.score2 THEN 1
									ELSE NULL
								END
							WHEN 'tie' THEN
								CASE 
									WHEN t.score >= 0 AND t.score < t.score2 THEN -1
									ELSE NULL
								END
							ELSE NULL
						END
					ELSE NULL
				END
			WHEN @pfID IN (143,144) THEN
				CASE 
					WHEN (@pfID = 143 AND @IsABANDONEDHT = 1) OR @pfID = 144 
						THEN CASE
								WHEN RIGHT(@betteam,1) ='u' AND @hdp1 <= t.score - 0.5 THEN @hdp1 - t.score
								ELSE NULL
							END
					ELSE NULL
				END
			WHEN @pfId = 145 THEN
					CASE 
						WHEN @IsABANDONEDHT = 1 AND @betteam = 'y' AND @hth > 0 AND @hta > 0 THEN 1
						WHEN @IsABANDONEDHT = 1 AND @betteam = 'n' AND @hth > 0 AND @hta > 0 THEN -1
						WHEN @IsABANDONEDHT = 0 AND @betteam = 'y' AND @fth > 0 AND @fta > 0 THEN 1
						WHEN @IsABANDONEDHT = 0 AND @betteam = 'n' AND @fth > 0 AND @fta > 0 THEN -1
						ELSE NULL
					END 
			WHEN @pfId = 146 AND @IsABANDONEDHT = 0 THEN
					CASE
						WHEN @betteam = 'y' AND @fth - @hth > 0 AND @fta - @hta > 0 THEN 1
						WHEN @betteam = 'n' AND @fth - @hth > 0 AND @fta - @hta > 0 THEN -1
						ELSE NULL
					END
			WHEN @pfID IN (147,148) AND @IsABANDONEDHT = 0 THEN
					CASE 
						WHEN @betteam = 'y' AND t.score = 0 THEN -1
						WHEN @betteam = 'n' AND t.score = 0 THEN 1
						WHEN @betteam = 'y' AND t.score > 0 AND t.score2 > 0 THEN 1
						WHEN @betteam = 'n' AND t.score > 0 AND t.score2 > 0 THEN -1
						ELSE NULL
					END
			WHEN @pfID IN (149,150) AND @IsABANDONEDHT = 0 THEN
				CASE 
					WHEN @betteam = 'y' AND t.score > t.score2 THEN 1
					WHEN @betteam = 'n' AND t.score > t.score2 THEN -1
					ELSE NULL
				END
			WHEN @pfID = 152 THEN
				CASE 
					WHEN @IsABANDONEDHT = 1 AND LEFT(@betteam,2) = '4+' AND (@hth + @hta) >= 4 THEN 1
					WHEN @IsABANDONEDHT = 1 AND LEFT(@betteam,2) <> '4+' AND (LEFT(LEFT(@betteam,3),1) < @hth OR RIGHT(LEFT(@betteam,3),1) < @hta) THEN -1					
					WHEN @IsABANDONEDHT = 0 AND @betteam = '4+/4+' AND ( @hth + @hta) >= 4 AND (@fth + @fta) >= 4 THEN 1
					WHEN @IsABANDONEDHT = 0 AND LEFT(@betteam,3) <> t.CS1H THEN -1        
					WHEN @IsABANDONEDHT = 0 AND RIGHT(@betteam,2) = '4+' AND (@fth + @fta) >= 4 THEN 1
					WHEN @IsABANDONEDHT = 0 AND RIGHT(@betteam,2) <>'4+' AND (LEFT(RIGHT(@betteam,3),1) < @fth OR RIGHT(RIGHT(@betteam,3),1) < @fta) THEN -1
					ELSE NULL
				END
			WHEN @pfID = 159 THEN
				CASE
					WHEN @betteam LIKE 'G[0-5]' THEN CASE WHEN t.score > CAST(RIGHT(@betteam,1) AS TINYINT) THEN -1 ELSE NULL END
					WHEN @betteam = 'G6' AND t.score >= 6 THEN 1 
					ELSE NULL
				END
			WHEN @pfID IN (161,162) THEN
				CASE
					WHEN @betteam LIKE 'G[0-2]' THEN CASE WHEN t.score > RIGHT(@betteam,1) THEN -1 ELSE NULL END
					WHEN @betteam ='G3' AND t.score >= 3 THEN 1 
					ELSE NULL
				END
			WHEN @pfID = 170 THEN
				CASE
					WHEN @betteam = 'b' AND @fth > 0 AND @fta > 0 THEN 1
					WHEN @betteam = 'n' AND (@fth > 0 OR @fta > 0) THEN -1
					WHEN @betteam = 'h' AND @fta > 0 THEN -1
					WHEN @betteam = 'a' AND @fth > 0 THEN -1
					ELSE NULL
				END				
			WHEN @pfID = 179 AND @IsABANDONEDHT = 1 THEN
				CASE
					WHEN @betteam LIKE 'G[0-3]' THEN CASE WHEN t.score > RIGHT(@betteam,1) THEN -1 ELSE NULL END
					WHEN @betteam ='G4' AND t.score >= 4 THEN 1 			
					ELSE NULL
				END
			WHEN @pfID IN (181,182) AND @IsABANDONEDHT = 1 THEN
				CASE
					WHEN @betteam LIKE 'G[0-2]' THEN CASE WHEN t.score > RIGHT(@betteam,1) THEN -1 ELSE NULL END
					WHEN @betteam ='G3' AND t.score >= 3 THEN 1 
					ELSE NULL
				END
			WHEN @pfID = 187 AND @IsABANDONEDHT = 0 THEN
				CASE
					WHEN @betteam LIKE 'G[0-1]' THEN CASE WHEN t.score > RIGHT(@betteam,1) THEN -1 ELSE NULL END
					WHEN @betteam ='G2' AND t.score >= 2 THEN 1 
					ELSE NULL
				END
			WHEN @pfID = 188 AND @IsABANDONEDHT = 1 THEN
				CASE 
					WHEN @betteam = 'n' AND (@hth > 0 AND @hta > 0) THEN -1
					WHEN @betteam = 'y' AND (@hth > 0 AND @hta > 0) THEN 1					
					ELSE NULL
				END
			WHEN @pfID = 189 AND @IsABANDONEDHT = 0 THEN 
				CASE
					WHEN @betteam = 'y' AND t.score < 1.5 THEN -1
					WHEN @betteam = 'n' AND t.score < 1.5 THEN 1
					WHEN @betteam = 'y' AND t.score > 1.5 AND t.score2 > 1.5 THEN 1
					WHEN @betteam = 'n' AND t.score > 1.5 AND t.score2 > 1.5 THEN -1
					ELSE NULL 
				END
			WHEN @pfID = 190 THEN 
				CASE 
					WHEN @IsABANDONEDHT = 1 THEN --1H
						CASE
							WHEN @betteam = 'y' AND t.score > 1.5 THEN -1
							WHEN @betteam = 'n' AND t.score > 1.5 THEN 1
							ELSE NULL
						END
					WHEN @IsABANDONEDHT = 0 THEN --2H
						CASE
							WHEN @betteam = 'y' AND t.score > 1.5 THEN -1
							WHEN @betteam = 'n' AND t.score > 1.5 THEN 1
							WHEN @betteam = 'y' AND t.score < 1.5 AND t.score2 > 1.5 THEN -1
							WHEN @betteam = 'n' AND t.score < 1.5 AND t.score2 > 1.5 THEN 1
							ELSE NULL
						END
					ELSE NULL
				END	
			
			WHEN @pfID = 405 AND @IsABANDONEDHT = 0 THEN 
				CASE 
					WHEN @betteam NOT IN ('AOS') THEN CASE WHEN ((@fth - @hth) > LEFT(@betteam,1) OR (@fta - @hta) > RIGHT(@betteam,1)) THEN -1 ELSE NULL END
					WHEN @betteam IN ('AOS') AND CHARINDEX(CAST((@fth - @hth) AS VARCHAR) + ':' + CAST((@fta - @hta) AS VARCHAR), @transdesc) = 0 THEN 1
					ELSE NULL
				END	
			WHEN @pfID IN (397,426) THEN
				CASE 
					WHEN (@pfID = 426 AND @IsABANDONEDHT = 1) OR @pfID = 397 
						THEN CASE
								WHEN @betteam = 'NG' AND t.score > 0 THEN -1
								ELSE NULL
							END
					ELSE NULL
				END
			WHEN @pfID = 412 AND @IsABANDONEDHT = 1 THEN
				CASE
					WHEN @betteam IN ('3-over') THEN CASE WHEN t.score >= 3 THEN 1 ELSE NULL END
					WHEN t.score > CAST(@betteam AS INT) THEN -1 
					ELSE NULL
				END
			WHEN @pfID = 413 THEN
				CASE
					WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), @transdesc) = 0 THEN 1 ELSE NULL END
					WHEN (@fth > LEFT(@betteam,1) OR @fta > RIGHT(@betteam,1)) THEN -1
					ELSE NULL
				END
			WHEN @pfID = 414 AND @IsABANDONEDHT = 1 THEN
				CASE
					WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), @transdesc) = 0 THEN 1 ELSE NULL END
					WHEN @betteam NOT IN ('AOS') AND (@hth > LEFT(@betteam,1) OR @hta > RIGHT(@betteam,1)) THEN -1
					ELSE NULL
				END
			WHEN @pfID = 416 THEN
				CASE
					WHEN @IsABANDONEDHT = 1 THEN --abandoned 1H
						CASE 
							WHEN t.betteam1H <> 'AOS' THEN 
								CASE
									WHEN CAST(LEFT(t.betteam1H,1) AS INT) < @hth OR CAST(RIGHT(t.betteam1H,1) AS INT) < @hta THEN -1
									ELSE NULL
								END
							ELSE
								CASE
									WHEN t.betteamFT = 'AOS' THEN CASE WHEN @hth > 4 OR @hta > 4 THEN 1 ELSE NULL END
									WHEN LEFT(t.betteamFT,1) < @hth OR RIGHT(t.betteamFT,1) < @hta THEN -1
									ELSE NULL
								END
						END
					ELSE CASE --abandoned 2H
							WHEN t.betteam1H <> 'AOS' THEN 
								CASE
									WHEN CAST(LEFT(t.betteam1H,1) AS INT) <> @hth OR CAST(RIGHT(t.betteam1H,1) AS INT) <> @hta THEN -1
									WHEN t.betteamFT <> 'AOS' THEN CASE WHEN LEFT(t.betteamFT,1) < @fth OR RIGHT(t.betteamFT,1) < @fta THEN -1 END
									WHEN CAST(LEFT(t.betteam1H,1) AS INT) = @hth 
										AND CAST(RIGHT(t.betteam1H,1) AS INT) = @hta 
										AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),t.ExcludingFTChoice) = 0 THEN 1
									ELSE NULL
								END
							ELSE 
								CASE 
									WHEN CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),t.ExcludingHTChoice) > 0 THEN -1
									WHEN t.betteamFT <> 'AOS' THEN CASE WHEN LEFT(t.betteamFT,1) < @fth OR RIGHT(t.betteamFT,1) < @fta THEN -1 END
									WHEN CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),t.ExcludingFTChoice) = 0 THEN 1
									ELSE NULL
								END
						END	
				END
			WHEN @pfID = 417 THEN
				CASE
					WHEN LEFT(@betteam,1) = 'N' THEN 
						CASE
							WHEN @fth > 0 AND @fta > 0 THEN -1
							WHEN @fth > @fta AND RIGHT(@betteam,1) IN ('A','D') THEN -1
							WHEN @fth < @fta AND RIGHT(@betteam,1) IN ('H','D') THEN -1
							ELSE NULL
						END
					ELSE NULL
					END
			WHEN @pfID = 418 THEN
				CASE 
					WHEN (@fth > 0 AND @fta > 0) THEN
						CASE 
							WHEN (@fth + @fta < @hdp1) THEN
								CASE
									WHEN LEFT(@betteam,1) = 'N' THEN -1
									ELSE NULL
								END
							WHEN (@fth + @fta > @hdp1) THEN
								CASE
									WHEN @betteam = 'YO' THEN 1
									WHEN @betteam = 'YU' THEN -1
									WHEN @betteam = 'NO' THEN -1
									WHEN @betteam = 'NU' THEN -1
									ELSE NULL
								END
							ELSE NULL
						END
					WHEN (@fth > 0 OR @fta > 0) AND (@fth + @fta > @hdp1) THEN 
						CASE
							WHEN RIGHT(@betteam,1) = 'U' THEN -1
							ELSE NULL
						END
					ELSE NULL
				END
			WHEN @pfID IN (419,420,421) THEN
				CASE    
					WHEN t.score > 0 THEN 
						CASE
							WHEN @betteam = '1H' AND t.score2 > 0 THEN 1
							WHEN @betteam = '2H' AND t.score2 = 0 THEN 1
							ELSE -1
						END
					WHEN @IsABANDONEDHT = 0 AND t.score = 0 THEN 
						CASE 
							WHEN @betteam = '1H' THEN -1
							ELSE NULL
						END                                                                                      
					ELSE NULL
				END
			
			WHEN @pfID = 429 AND @IsABANDONEDHT = 0 THEN
				CASE
					WHEN t.score > 0 
						THEN CASE
								WHEN @betteam IN ('3-over','3&over') THEN 
									CASE 
										WHEN t.score >= 3 THEN 1 
										ELSE NULL 
									END
								ELSE 
									CASE
										WHEN t.score > CAST(@betteam AS INT) THEN -1
										ELSE NULL
									END
								END
					ELSE NULL
				END
			WHEN @pfID = 433 AND @IsABANDONEDHT = 0 THEN
				CASE 
					WHEN @betteam = 'y' AND @fth - @hth > 0 AND @fta - @hta > 0 THEN 1
					WHEN @betteam = 'n' AND @fth - @hth > 0 AND @fta - @hta > 0 THEN -1
					ELSE NULL
				END
			WHEN @pfID IN (436,437) AND @IsABANDONEDHT = 0 THEN 
				CASE 
					WHEN @betteam = 'y' AND t.score = 0 THEN -1
					WHEN @betteam = 'n' AND t.score = 0 THEN 1
					WHEN @betteam = 'y' AND t.score > 0 AND t.score2 > 0 THEN 1
					WHEN @betteam = 'n' AND t.score > 0 AND t.score2 > 0 THEN -1
					ELSE NULL
				END
			WHEN @pfID IN (438,439) AND @IsABANDONEDHT = 0 THEN
				CASE 
					WHEN @betteam = 'y' AND t.score <= t.score2 THEN -1
					WHEN @betteam = 'n' AND t.score <= t.score2 THEN 1
					ELSE NULL
				END  
			WHEN @pfID IN (440,441) AND @IsABANDONEDHT = 0 THEN
				CASE 
					WHEN @betteam = 'y' AND t.score > t.score2 THEN 1
					WHEN @betteam = 'n' AND t.score > t.score2 THEN -1
					ELSE NULL
					END
			WHEN @pfID IN (442,443,444) AND @IsABANDONEDHT = 0 THEN
					CASE @betteam
						WHEN '1h' THEN
							CASE 
								WHEN t.score >= 0 AND t.score < t.score2 THEN -1
								WHEN t.score >= 0 AND t.score = t.score2 THEN -1
								ELSE NULL
							END
						WHEN '2h' THEN
							CASE 
								WHEN t.score >= 0 AND t.score < t.score2 THEN 1
								ELSE NULL
							END
						WHEN 'tie' THEN
							CASE 
								WHEN t.score >= 0 AND t.score < t.score2 THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
			WHEN @pfID = 445 THEN
				CASE 
					WHEN @IsABANDONEDHT = 1 THEN --abandoned 1H
						CASE 
							WHEN (@hth > 0 AND @hta > 0 AND LEFT(@betteam,1) = 'N') THEN -1 --both of teams have scored
							ELSE NULL
						END
					WHEN @IsABANDONEDHT = 0 THEN --abandoned 2H
						CASE 
							WHEN (t.score2 = 0 OR (t.score2 > 0 AND (@fth - @hth = 0 OR @fta - @hta= 0))) THEN  --not both teams haved score
								CASE 
									WHEN (t.score = 0 OR (t.score > 0 AND (@hth = 0 OR @hta = 0) )) THEN
										CASE 
											WHEN @betteam = 'YY' THEN -1
											WHEN @betteam = 'YN' THEN -1
											ELSE NULL
										END
									WHEN (@hth > 0 AND @hta > 0) THEN
										CASE
											WHEN @betteam = 'NY' THEN -1
											WHEN @betteam = 'NN' THEN -1
											ELSE NULL
										END
									ELSE NULL
								END
							WHEN (@fth - @hth > 0 AND @fta - @hta > 0) THEN --both teams have scored
								CASE
									WHEN (t.score = 0 OR (t.score) > 0 and (@hth = 0 OR @hta = 0)) THEN
										CASE
											WHEN @betteam = 'YY' THEN -1
											WHEN @betteam = 'YN' THEN -1
											WHEN @betteam = 'NY' THEN 1
											WHEN @betteam = 'NN' THEN -1
											ELSE NULL
										END
									WHEN (@hth > 0 AND @hta > 0) THEN 
										CASE
											WHEN @betteam = 'YY' THEN 1
											WHEN @betteam = 'YN' THEN -1
											WHEN @betteam = 'NY' THEN -1
											WHEN @betteam = 'NN' THEN -1
											ELSE NULL
										END    
									ELSE NULL 
								END
							ELSE NULL 
						END
					END
			WHEN @pfID IN (446,447) THEN --Home 1H to Score/ 2H To Score
				CASE 
					WHEN @IsABANDONEDHT = 1 THEN --1H
						CASE
							WHEN t.score2 > 0 AND LEFT(@betteam,1) = 'N' THEN -1
							ELSE NULL
						END
					WHEN @IsABANDONEDHT = 0 THEN --2H
						CASE
							WHEN t.score = 0 AND LEFT(@betteam,1) = 'Y' THEN -1
							WHEN t.score > 0 THEN
								CASE
									WHEN t.score2 = 0 AND LEFT(@betteam,1) = 'Y' THEN -1
									WHEN t.score2 = 0 AND @betteam = 'NN' THEN -1
									WHEN t.score2 = 0 AND @betteam = 'NY' THEN 1
									WHEN t.score = t.score2 AND LEFT(@betteam,1) = 'N' THEN -1
									WHEN t.score2 > 0 AND t.score - t.score2 > 0 THEN 
										CASE
											WHEN @betteam = 'YY' THEN 1
											ELSE -1
										END
									ELSE NULL
								END
							ELSE NULL
						END
					ELSE NULL
				END
			WHEN @pfID = 450 THEN 
				CASE 
					WHEN RIGHT(@betteam,1) = 'U' AND t.score > @hdp1 THEN -1
					ELSE NULL
				END
			WHEN @pfID IN (456,451) THEN 
				CASE
					WHEN LEFT(@betteam,1) = 'N' THEN CASE
														WHEN t.score > 0 AND t.score2 > 0 THEN -1
														ELSE NULL
													END
					ELSE NULL
				END		
			WHEN  @pfID = 457 THEN 
				CASE
					WHEN  LEFT(@betteam,1) = 'N' AND @hth > 0 AND @hta > 0 THEN -1
					WHEN  RIGHT(@betteam,1) = 'U' AND t.score > @hdp1 THEN -1
					WHEN @betteam ='YO' AND @hth > 0 AND @hta > 0 AND t.score > @hdp1 THEN 1
					ELSE NULL
				END
			WHEN @pfID = 449 THEN 
				CASE 
					WHEN RIGHT(@betteam,1) = 'U' AND t.score > @hdp1 THEN -1
					ELSE NULL
				END		                                                            
			WHEN @pfID = 452 AND @IsABANDONEDHT = 0 THEN 
				CASE
					WHEN @betteam = '1H' AND t.score < t.score2 THEN -1
					WHEN @betteam = '2H' AND t.score < t.score2 THEN 1
					ELSE NULL
				END	
			WHEN @pfID = 467 THEN 
					CASE WHEN @IsABANDONEDHT = 1 THEN -- suspended in HT 
							CASE 
								WHEN t.score2 >= 7 AND @betteam = 'G7+/G7+' THEN 1
								WHEN (SUBSTRING(@betteam, 2,1) < t.score2 AND SUBSTRING(@betteam, 2,1) < 7) THEN -1
								ELSE NULL
							END
						ELSE -- suspended in FT
							CASE 
								WHEN t.score2 >= 7 AND @betteam = 'G7+/G7+' THEN 1
								WHEN t.score2 = 0 AND t.score >= 7 AND @betteam = 'G0/G7+' THEN 1
								WHEN t.score2 = 1 AND t.score >= 7 AND @betteam = 'G1/G7+' THEN 1
								WHEN t.score2 = 2 AND t.score >= 7 AND @betteam = 'G2/G7+' THEN 1
								WHEN t.score2 = 3 AND t.score >= 7 AND @betteam = 'G3/G7+' THEN 1
								WHEN t.score2 = 4 AND t.score >= 8 AND @betteam = 'G4/G8+' THEN 1
								WHEN t.score2 = 5 AND t.score >= 9 AND @betteam = 'G5/G9+' THEN 1
								WHEN t.score2 = 6 AND t.score >= 10 AND @betteam = 'G6/G10+' THEN 1
								WHEN SUBSTRING(@betteam, 2,1) <> t.score2 THEN -1
								WHEN SUBSTRING(@betteam, 2,1) = t.score2 AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/G',@betteam) + 2, LEN(@betteam)),'+','') < t.score THEN -1
								WHEN SUBSTRING(@betteam, 2,1) = t.score2 AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/G',@betteam) + 2, LEN(@betteam)),'+','') >= t.score THEN NULL
								ELSE NULL
							END
					END
			WHEN @pfID = 473 THEN
				CASE 
					WHEN @betteam = '0-5' and t.score > 5 THEN -1
					WHEN @betteam = '6-8' and t.score > 8 THEN -1
					WHEN @betteam = '9-11' and t.score > 11 THEN -1
					WHEN @betteam = '12-14' and t.score > 14 THEN -1
					WHEN @betteam = '15+' and t.score >= 15 THEN 1
					ELSE NULL
				END		  				
			WHEN @pfID = 474 THEN
				CASE 
					WHEN @betteam = '0-2' and t.score > 2 THEN -1
					WHEN @betteam = '3-4' and t.score > 4 THEN -1
					WHEN @betteam = '5-6' and t.score > 6 THEN -1
					WHEN @betteam = '7+' and t.score >= 7 THEN 1
					ELSE NULL 
				END		
			WHEN @pfID IN (475,476) THEN 
				CASE 
					WHEN @betteam = 'o' AND t.score > @hdp1 THEN 1
					WHEN @betteam = 'u' AND t.score >= @hdp1 THEN -1
					WHEN @betteam = 'e' AND t.score > @hdp1 THEN -1
					ELSE NULL
				END
			
			WHEN @pfID = 493 THEN 
				CASE 
					WHEN @IsABANDONEDHT = 1 THEN -- suspended in HT 
						CASE 
							WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(
																			CASE WHEN t.score2 = 0 AND t.score >= 8 THEN '0/8+'
																				WHEN t.score2 = 1 AND t.score >= 9 THEN '1/9+'  
																				WHEN t.score2 = 2 AND t.score >= 10 THEN '2/10+'
																				WHEN t.score2 = 3 AND t.score >= 11 THEN '3/11+'
																				WHEN t.score2 = 4 AND t.score >= 12 THEN '4/12+'
																				WHEN t.score2 = 5 AND t.score >= 13 THEN '5/13+'
																				WHEN t.score2 = 6 AND t.score >= 14 THEN '6/14+'
																				WHEN t.score2 IN (7,8,9) AND t.score >= 15 THEN CAST(t.score2 AS VARCHAR(5)) + '/15+'
																			ELSE CAST(t.score2 AS VARCHAR(5)) + '/' + CAST(t.score AS VARCHAR(5))
																			END, @transdesc
																		) = 0 THEN 1
															ELSE NULL END
							WHEN @betteam <> 'AOS' AND LEFT(@betteam, 1) < t.score2 THEN -1
							ELSE NULL
						END
					WHEN @IsABANDONEDHT = 0 THEN -- suspended in FT
						CASE 
							WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(
																			CASE WHEN t.score2 = 0 AND t.score >= 8 THEN '0/8+'
																				WHEN t.score2 = 1 AND t.score >= 9 THEN '1/9+'  
																				WHEN t.score2 = 2 AND t.score >= 10 THEN '2/10+'
																				WHEN t.score2 = 3 AND t.score >= 11 THEN '3/11+'
																				WHEN t.score2 = 4 AND t.score >= 12 THEN '4/12+'
																				WHEN t.score2 = 5 AND t.score >= 13 THEN '5/13+'
																				WHEN t.score2 = 6 AND t.score >= 14 THEN '6/14+'
																				WHEN t.score2 IN (7,8,9) AND t.score >= 15 THEN CAST(t.score2 AS VARCHAR(5)) + '/15+'
																			ELSE CAST(t.score2 AS VARCHAR(5)) + '/' + CAST(t.score AS VARCHAR(5))
																			END, @transdesc
																		) = 0 THEN 1
															WHEN CHARINDEX(
																			CASE WHEN t.score2 = 0 AND t.score >= 8 THEN '0/8+'
																				WHEN t.score2 = 1 AND t.score >= 9 THEN '1/9+'  
																				WHEN t.score2 = 2 AND t.score >= 10 THEN '2/10+'
																				WHEN t.score2 = 3 AND t.score >= 11 THEN '3/11+'
																				WHEN t.score2 = 4 AND t.score >= 12 THEN '4/12+'
																				WHEN t.score2 = 5 AND t.score >= 13 THEN '5/13+'
																				WHEN t.score2 = 6 AND t.score >= 14 THEN '6/14+'
																				WHEN t.score2 IN (7,8,9) AND t.score >= 15 THEN CAST(t.score2 AS VARCHAR(5)) + '/15+'
																			ELSE CAST(t.score2 AS VARCHAR(5)) + '/' + CAST(t.score AS VARCHAR(5))
																			END, @transdesc
																		) > 0
																		AND 
																		CHARINDEX(
																			CASE WHEN t.score2 = 0 THEN '0/8+'
																				WHEN t.score2 = 1 THEN '1/9+'  
																				WHEN t.score2 = 2 THEN '2/10+'
																				WHEN t.score2 = 3 THEN '3/11+'
																				WHEN t.score2 = 4 THEN '4/12+'
																				WHEN t.score2 = 5 THEN '5/13+'
																				WHEN t.score2 = 6 THEN '6/14+'
																				WHEN t.score2 IN (7,8,9) THEN CAST(t.score2 AS VARCHAR(5)) + '/15+'
																			END, @transdesc
																		) > 0 THEN -1
															ELSE NULL END
							ELSE CASE WHEN t.score2 = 0 AND t.score >= 8 AND @betteam = '0/8+' THEN 1
										WHEN t.score2 = 1 AND t.score >= 9 AND @betteam = '1/9+' THEN 1
										WHEN t.score2 = 2 AND t.score >= 10 AND @betteam = '2/10+' THEN 1
										WHEN t.score2 = 3 AND t.score >= 11 AND @betteam = '3/11+' THEN 1
										WHEN t.score2 = 4 AND t.score >= 12 AND @betteam = '4/12+' THEN 1
										WHEN t.score2 = 5 AND t.score >= 13 AND @betteam = '5/13+' THEN 1
										WHEN t.score2 = 6 AND t.score >= 14 AND @betteam = '6/14+' THEN 1
										WHEN t.score2 = 7 AND t.score >= 15 AND @betteam = '7/15+' THEN 1
										WHEN t.score2 = 8 AND t.score >= 15 AND @betteam = '8/15+' THEN 1
										WHEN t.score2 = 9 AND t.score >= 15 AND @betteam = '9/15+' THEN 1
										WHEN LEFT(@betteam, 1) <> t.score2 THEN -1
										WHEN LEFT(@betteam, 1) = t.score2 AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/',@betteam) + 1, LEN(@betteam)),'+','') < t.score THEN -1
										WHEN LEFT(@betteam, 1) = t.score2 AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/',@betteam) + 1, LEN(@betteam)),'+','') >= t.score THEN NULL
										ELSE NULL
									END
						END
					END
			WHEN @pfID IN (399,494,495) THEN 
				CASE 
					WHEN (@pfID = 494 AND @IsABANDONEDHT = 1) OR (@pfID = 495 AND @IsABANDONEDHT = 0) OR @pfID = 399 THEN	
						CASE
							WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(t.score AS VARCHAR(5)) + '-' + CAST(t.score2 AS VARCHAR(5)), @transdesc) = 0 THEN 1 ELSE NULL END
							WHEN @betteam <> 'AOS' AND LEFT(@betteam, 1) >= t.score AND RIGHT(@betteam, 1) >= t.score2 THEN NULL
							ELSE -1
						END
					ELSE NULL
				END
			WHEN @pfID = 496 AND @IsABANDONEDHT = 0 THEN 
				CASE @betteam
					WHEN '1h' THEN
						CASE 
							WHEN t.score <= t.score2 THEN -1
							ELSE NULL
						END
					WHEN '2h' THEN
						CASE 
							WHEN t.score < t.score2 THEN 1
							ELSE NULL
						END
					WHEN 'tie' THEN
						CASE 
							WHEN t.score < t.score2 THEN -1
							ELSE NULL
						END
					ELSE NULL
				END
			WHEN @pfID = 497 AND @IsABANDONEDHT = 0 THEN 
				CASE @betteam
					WHEN '1h' THEN
						CASE 
							WHEN t.score < t.score2 THEN -1
							ELSE NULL
						END
					WHEN '2h' THEN
						CASE 
							WHEN t.score < t.score2 THEN 1
							ELSE NULL
						END
					ELSE NULL
				END
			WHEN @pfID = 392 THEN 
				CASE
					WHEN @betteam NOT IN ('HAOS', 'AAOS') AND (@fth > LEFT(@betteam,1) OR @fta > RIGHT(@betteam,1)) THEN -1
					ELSE NULL
				END
			ELSE NULL
		END AS modds1
	)m1
	OUTER APPLY(
		SELECT CASE
				WHEN @pfID = 22 THEN 
					CASE
						WHEN @betteam = '1' AND SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = 'H' THEN 1
						WHEN @betteam = '2' AND SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = 'A' THEN 1
						WHEN SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = '' THEN NULL
						ELSE -1
					END
				WHEN @pfID = 14 THEN 
					CASE 
						WHEN RIGHT(@betteam, 1) IN ('0','1') AND @HomeValue IN ('1:1','2:1') 
							THEN CASE
									WHEN RIGHT(@betteam, 1) = '0' AND @betteam = '0:0'  AND @HomeValue = '0:0' THEN NULL
									WHEN RIGHT(@betteam, 1) = '1' AND @betteam = @HomeValue THEN 1
									ELSE -1		
								END		
						ELSE NULL
					END	
				WHEN @pfID = 172 THEN
					CASE 
						WHEN @HomeValue IN ('H','A') THEN
							CASE
								WHEN RIGHT(@betteam,1) = 'H' AND @HomeValue = 'A' THEN -1
								WHEN RIGHT(@betteam,1) = 'A' AND @HomeValue = 'H' THEN -1 
								WHEN @betteam = 'NO' THEN -1 
								ELSE NULL
							END
						ELSE NULL
					END		
			WHEN @pfID = 396 THEN 
				CASE
					WHEN @betteam = '1' AND SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = 'H' THEN 1
					WHEN @betteam = '2' AND SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = 'A' THEN 1
					WHEN SUBSTRING(@HomeValue, CAST(RIGHT(@betcheck,2) AS INT),1) = '' THEN NULL
					ELSE -1
				END
			WHEN @pfID = 422 THEN 
				CASE
					WHEN @HomeValue IN ('H', 'A') THEN 
						CASE 
							WHEN @betteam = @HomeValue THEN 1
							ELSE -1
						END
					ELSE NULL
				END
			WHEN @pfID = 448 THEN 
				CASE 
					WHEN @HomeValue IN ('H','A') AND @betteam = 'NG' THEN -1 
					ELSE NULL 
				END		
			WHEN @pfID = 454 THEN
				CASE
					WHEN @HomeValue IN ('H','A') THEN
						CASE
							WHEN RIGHT(@betteam,1) = 'H' AND @HomeValue = 'A' THEN -1
							WHEN RIGHT(@betteam,1) = 'A' AND @HomeValue = 'H' THEN -1
							WHEN @betteam = 'NG' THEN -1 
							ELSE NULL
						END
					ELSE NULL
							
				END	
			WHEN @pfID = 486 THEN 
				CASE 
					WHEN @betteam IN ('H', 'A')
						THEN CASE 
								WHEN CHARINDEX(';' + CAST(CAST(@hdp1 AS INT) AS VARCHAR) + @betteam + ';', ';' + @HomeValue + ';') > 0 THEN 1
								WHEN CHARINDEX(';' + CAST(CAST(@hdp1 AS INT) AS VARCHAR) 
										+ CASE WHEN @betteam = 'H' THEN 'A' ELSE 'H' END + ';', ';' + @HomeValue + ';') > 0 THEN -1
								ELSE NULL
							END
					WHEN @betteam = 'N' AND @hdp1 < @AwayValue THEN -1
					ELSE NULL
				END
			WHEN @pfID = 488 OR (@pfID = 490 AND @IsABANDONEDHT = 0) THEN 
				CASE
					WHEN @HomeValue IN ('H', 'A') 
						THEN CASE
								WHEN @HomeValue = @betteam THEN 1
								ELSE -1
							END
					ELSE NULL
				END		
			WHEN @pfID = 469 THEN
				CASE 
					WHEN o.odds > 0 AND @betteam = 'o' THEN 1
					WHEN o.odds < 0 AND @betteam = 'u' THEN -1 
					ELSE NULL
				END
		ELSE NULL
		END as modds2
	)m2
)
GO
