/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Parlay_SDT_CalModds_GoalRecord] (
	@bettype 			SMALLINT
	, @betteam 			VARCHAR(50)
	, @GoalRecord		VARCHAR(50) = NULL
	, @goalsequenceHT	VARCHAR(50) = NULL 
	, @goalsequenceFT	VARCHAR(50) = NULL
	, @ht_fg 			VARCHAR(10) = NULL
	, @ht_lg 			VARCHAR(10) = NULL
	, @ft_fg 			VARCHAR(10) = NULL
	, @ft_lg 			VARCHAR(10) = NULL
	, @hdp1				SMALLMONEY	= NULL
	, @ResultCornerRace	VARCHAR(200) = NULL
	, @NeitherRaceTo	TINYINT		= NULL
	, @ResultCornerRace1H	VARCHAR(200) = NULL
	, @NeitherRaceTo1H	TINYINT		= NULL
	, @betcheck NVARCHAR(50)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
    Created:20161129@Bobby
    Task: Implement SDT Parlay bettypes - Modds Calculation
    DB: DBTXN/bodb02
    Revisions:
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20190626@Kathy: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190718@Sol: Relocate bettype 22 From early settlement to Main settlement [Redmine:#115232]
	
    Parameters Explanation:  
    
*/

RETURN (
	SELECT ods.modds
		, CASE 
			WHEN ods.modds >= 0.5 THEN 112 --WON
			WHEN ods.modds <= - 0.5 THEN 113 --LOSE
			ELSE 0
		END AS StatusId
	FROM (
		SELECT t1.modds
		FROM ( 
			-- Input parrams definition
			SELECT 
				CASE 
					WHEN (CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) > 0 AND CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) = 0) OR (CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) <> 0 AND CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) - CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) < 0) THEN 'H'
					WHEN (CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) > 0 AND CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) = 0) OR (CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) <> 0 AND CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) - CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) < 0) THEN 'A'
					ELSE 'N'
				END AS [betteam422]
				,CASE
					WHEN (CASE WHEN CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) > 0 THEN CHARINDEX('H',@GoalRecord, CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) + 1) ELSE 0 END > 0 AND CASE WHEN CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) > 0 THEN CHARINDEX('A',@GoalRecord, CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) + 1) ELSE 0 END = 0) OR (CASE WHEN CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) > 0 THEN CHARINDEX('H',@GoalRecord, CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) + 1) ELSE 0 END <> 0 AND CASE WHEN CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) > 0 THEN CHARINDEX('H',@GoalRecord, CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) + 1) ELSE 0 END - CASE WHEN CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) > 0 THEN CHARINDEX('A',@GoalRecord, CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) + 1) ELSE 0 END < 0) THEN 'H'
					WHEN (CASE WHEN CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) > 0 THEN CHARINDEX('A',@GoalRecord, CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) + 1) ELSE 0 END > 0 AND CASE WHEN CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) > 0 THEN CHARINDEX('H',@GoalRecord, CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) + 1) ELSE 0 END = 0) OR (CASE WHEN CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) > 0 THEN CHARINDEX('A',@GoalRecord, CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) + 1) ELSE 0 END <> 0 AND CASE WHEN CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) > 0 THEN CHARINDEX('A',@GoalRecord, CHARINDEX('A',@GoalRecord,(CHARINDEX('A',@GoalRecord)+1)) + 1) ELSE 0 END - CASE WHEN CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) > 0 THEN CHARINDEX('H',@GoalRecord, CHARINDEX('H',@GoalRecord,(CHARINDEX('H',@GoalRecord)+1)) + 1) ELSE 0 END < 0) THEN 'A'
					ELSE 'N'
				END AS [betteam423]
				,LEFT(REPLACE(@GoalRecord,';',''),1) AS FirstGoal
				, CASE 
					WHEN CHARINDEX(';', @goalsequenceFT) > 0 THEN SUBSTRING(@goalsequenceFT, CHARINDEX(';', @goalsequenceFT)+1,1) 
					ELSE LEFT(@goalsequenceFT,1) 
				END AS FirstGoal2h 
				, RIGHT(REPLACE(@goalsequenceFT,';',''),1) AS LastGoal
				, RIGHT(@goalsequenceHT,1) AS LastGoal1H
		) AS ip
		CROSS APPLY (
			-- Modds calculation
			SELECT 
				CASE
					WHEN @bettype = 14 THEN 
						CASE 
							WHEN RIGHT(@betteam, 1) IN ('0','1') AND @ft_fg IN ('H','A') THEN 
								CASE
									WHEN RIGHT(@betteam, 1) = '0' AND @betteam = '0:0'  AND @ft_fg = 'N' THEN NULL
									WHEN RIGHT(@betteam, 1) = '1' AND (@betteam = (CASE 
																						WHEN @ft_fg = 'H' THEN '1:1'
																						WHEN @ft_fg = 'A' THEN '2:1'
																						ELSE ''
																					END))  THEN 1
									ELSE -1		
								END		
							ELSE NULL
						END
					
					WHEN @bettype = 127 THEN 
						CASE 
							WHEN RIGHT(@betteam, 1) IN ('0','1') AND @ht_fg IN ('1:1','2:1') 
								THEN CASE
										WHEN RIGHT(@betteam, 1) = '0' AND @betteam = '0:0'  AND @ht_fg = '0:0' THEN NULL
										WHEN RIGHT(@betteam, 1) = '1' AND @betteam = @ht_fg THEN 1
										ELSE -1		
									END		
							ELSE NULL
						END		
													
					--#172,415
					WHEN @bettype IN (172,415) THEN
						CASE 
							WHEN @ft_fg IN ('H','A') THEN	-- Result And First Team To Score & (3rd)
								CASE
									WHEN RIGHT(@betteam,1) = 'H' AND @ft_fg = 'A' THEN -1
									WHEN RIGHT(@betteam,1) = 'A' AND @ft_fg = 'H' THEN -1 
									WHEN @betteam = 'NO' THEN -1 
									ELSE NULL
								END
							ELSE NULL
						END												
					--#422
					WHEN @bettype IN (422) THEN 
						CASE
							WHEN ip.betteam422 IN ('H', 'A') THEN 
								CASE 
									WHEN @betteam = ip.betteam422 THEN 1
									ELSE -1
								END
							ELSE NULL
						END
					--#423
					WHEN @bettype IN (423) THEN 
						CASE
							WHEN ip.betteam423 IN ('H', 'A') THEN 
								CASE 
									WHEN @betteam = ip.betteam423 THEN 1
									ELSE -1
								END
							ELSE NULL
						END
					--454: Double Chance & First Team To Score
					WHEN @bettype = 454 THEN
						CASE
							WHEN @ft_fg IN ('H','A') THEN	-- Result And First Team To Score & (3rd)
								CASE
									WHEN RIGHT(@betteam,1) = 'H' AND @ft_fg = 'A' THEN -1
									WHEN RIGHT(@betteam,1) = 'A' AND @ft_fg = 'H' THEN -1
									WHEN @betteam = 'NG' THEN -1 
									ELSE NULL
								END
							ELSE NULL
							
						END	
					--448: Last Team To Score
					WHEN @bettype = 448 THEN CASE WHEN @ft_fg IN ('H','A') AND @betteam = 'NG' THEN -1 ELSE NULL END
					
					-- Corners Race
					WHEN @bettype = 486 THEN CASE 
									WHEN @betteam IN ('H', 'A')
										THEN CASE 
												WHEN CHARINDEX(CAST(CAST(@hdp1 AS INT) AS VARCHAR) + @betteam, @ResultCornerRace) > 0 THEN 1
												WHEN CHARINDEX(CAST(CAST(@hdp1 AS INT) AS VARCHAR) 
														+ CASE WHEN @betteam = 'H' THEN 'A' ELSE 'H' END, @ResultCornerRace) > 0 THEN -1
												ELSE NULL
											END
									WHEN @betteam = 'N' AND @NeitherRaceTo < @hdp1 THEN -1
									ELSE NULL
								END
					-- 1H Corners Race
					WHEN @bettype = 487 THEN CASE 
									WHEN @betteam IN ('H', 'A')
										THEN CASE
												WHEN CHARINDEX(CAST(CAST(@hdp1 AS INT) AS VARCHAR) + @betteam, @ResultCornerRace1H) > 0 THEN 1 
												WHEN CHARINDEX(CAST(CAST(@hdp1 AS INT) AS VARCHAR) 
													+ CASE WHEN @betteam = 'H' THEN 'A' ELSE 'H' END, @ResultCornerRace1H) > 0 THEN 1 
												ELSE NULL
												END
									WHEN @betteam = 'N' AND @NeitherRaceTo1H < @hdp1 THEN -1
									ELSE NULL
								END
					-- First Corner, 1H First Corner
					WHEN @bettype IN(488, 489) THEN CASE
									WHEN ip.FirstGoal IN ('H', 'A') THEN CASE
																			WHEN ip.FirstGoal = @betteam THEN 1
																			ELSE -1
																		END
									ELSE NULL
								END
					-- 2H First Corner
					WHEN @bettype = 490 THEN CASE
									WHEN ip.FirstGoal2H IN ('H', 'A') THEN CASE
																			WHEN ip.FirstGoal2H = @betteam THEN 1
																			ELSE -1
																		END
									ELSE NULL
								END
					-- 1H Last Corner
					WHEN @bettype = 492 THEN CASE
									WHEN ip.LastGoal1H IN ('H', 'A') THEN CASE
																			WHEN ip.LastGoal1H = @betteam THEN 1
																			ELSE -1
																		END
									ELSE NULL
								END
					WHEN @bettype = 22 
							THEN CASE
								WHEN @betteam = '1' AND SUBSTRING(REPLACE(ISNULL(@goalsequenceFT, ''),';',''), CAST(RIGHT(@betcheck,2) AS INT),1) = 'H' THEN 1
								WHEN @betteam = '2' AND SUBSTRING(REPLACE(ISNULL(@goalsequenceFT, ''),';',''), CAST(RIGHT(@betcheck,2) AS INT),1) = 'A' THEN 1
								WHEN @betteam = 'X' AND SUBSTRING(REPLACE(ISNULL(@goalsequenceFT, ''),';',''), CAST(RIGHT(@betcheck,2) AS INT),1) = '' THEN NULL
								ELSE -1
							END
					---------------------------------------
					ELSE NULL -- else non-supported bettype
			END AS modds
		) AS t1
	) AS ods
)
GO