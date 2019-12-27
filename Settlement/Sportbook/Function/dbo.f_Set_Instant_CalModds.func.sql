/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Instant_CalModds] (
	@bettype 			SMALLINT
	, @betteam 			VARCHAR(50)
	, @hdp1 			SMALLMONEY
	, @hdp2 			SMALLMONEY
	, @hScore1H			TINYINT
	, @aScore1H			TINYINT
	, @hScore2H			TINYINT
	, @aScore2H			TINYINT
	, @FGNG				VARCHAR(50) = NULL
	, @CalculationType	TINYINT
	, @ResultCorner		VARCHAR(300) = NULL
	, @NeitherRaceTo	TINYINT = NULL
	, @GoalRecord		VARCHAR(50) =  NULL
)
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created:20161129@Bobby
    Task: Implement IS - Modds Calculation
    DB: DBTXN/bodb02
    Revisions:
		- 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
		- 20191209@Max: Instant Settlement for Corner Bettype [Redmine:#124951]
		
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
			SELECT 
				CASE 
					WHEN @bettype IN(3, 475) THEN (@hScore1H + @aScore1H) + (@hScore2H + @aScore2H)
					WHEN @bettype IN(8, 476) THEN (@hScore1H + @aScore1H)
					WHEN @bettype IN (18, 178) THEN  (@hScore2H + @aScore2H)
					WHEN @bettype IN (401,461,482) THEN (@hScore1H + @hScore2H)
					WHEN @bettype IN (402,462,483) THEN (@aScore1H + @aScore2H)
					WHEN @bettype IN (403,463,484) THEN @hScore1H
					WHEN @bettype IN (404,464,485) THEN @aScore1H
					ELSE (@hScore1H + @aScore1H) + (@hScore2H + @aScore2H) -- as default bettype 3
				END AS TotalGoal
				, (@hScore1H + @aScore1H) AS TotalGoal1H
				, (@hScore2H + @aScore2H) AS TotalGoal2H
		) AS ip
		CROSS APPLY (
			SELECT 
				CASE
				--#3-8-18-178-401-402-403-404-461-462-463-464
				WHEN @bettype IN (3,8,18,178,401,402,403,404,461,462,463,464,482,483,484,485) AND ip.TotalGoal > 0 THEN 
					CASE 
						WHEN @betteam IN ('h', 'o') AND ip.TotalGoal - @hdp1 > 0.25 THEN 1
						WHEN @betteam IN ('a', 'u') AND ip.TotalGoal - @hdp1 > 0.25 THEN -1
						ELSE NULL
					END
				--#189-434
				WHEN @bettype IN (189,434) AND @CalculationType = 102 THEN 
					CASE
						WHEN @betteam = 'y' AND ip.TotalGoal1H < 1.5 THEN -1
						WHEN @betteam = 'n' AND ip.TotalGoal1H < 1.5 THEN 1
						WHEN @betteam = 'y' AND ip.TotalGoal1H > 1.5 AND ip.TotalGoal2H > 1.5 THEN 1
						WHEN @betteam = 'n' AND ip.TotalGoal1H > 1.5 AND ip.TotalGoal2H > 1.5 THEN -1
						ELSE NULL 
					END
				-- Bettype corner: 476,475
				WHEN @bettype IN (475,476) THEN
					CASE 
						WHEN @betteam = 'O'	 AND ip.TotalGoal - @hdp1 > 0 THEN  1
						WHEN @betteam = 'U'	 AND ip.TotalGoal - @hdp1 > 0 THEN -1
						WHEN @betteam = 'U'	 AND ip.TotalGoal - @hdp1 = 0 THEN -1
						WHEN @betteam = 'E'	 AND ip.TotalGoal - @hdp1 > 0 THEN -1
						ELSE NULL	
					END
				-- Bettype corner: 486,487 Corner Race
				WHEN @bettype IN (486, 487) THEN 
					CASE 
						WHEN @ResultCorner <> '' AND @hdp1 <= @NeitherRaceTo THEN
							CASE
								WHEN CHARINDEX(';' + CAST(CAST(@hdp1 AS INT) AS VARCHAR) + @betteam, ';' + @ResultCorner) > 0 THEN 1
								WHEN @betteam = 'N' THEN - 1
								ELSE -1
							END
						ELSE NULL
					END
				-- Bettype corner: 488,489
				WHEN @bettype IN (488,489) THEN
					CASE
						WHEN @GoalRecord <> ''THEN
							CASE
								WHEN @betteam =  LEFT(@GoalRecord,1) THEN 1
								ELSE -1
							END
						ELSE NULL
					END
				-- Bettype corner: 490
				WHEN @bettype IN (490) THEN
					CASE
						WHEN @GoalRecord <> '' AND SUBSTRING(@GoalRecord, CHARINDEX(';',@GoalRecord) + 1, 1) <> '' THEN
							CASE
								WHEN @betteam = SUBSTRING(@GoalRecord, CHARINDEX(';',@GoalRecord) + 1, 1) THEN 1
								ELSE -1
							END
						ELSE NULL
					END
				--#190-435
				WHEN @bettype IN (190,435) THEN 
					CASE 
						WHEN @CalculationType = 101	THEN --1H
							CASE
								WHEN @betteam = 'y' AND ip.TotalGoal1H > 1.5 THEN -1
								WHEN @betteam = 'n' AND ip.TotalGoal1H > 1.5 THEN 1
								ELSE NULL
							END
						WHEN @CalculationType = 102 THEN --2H
							CASE
								WHEN @betteam = 'y' THEN 
									CASE 
										WHEN ip.TotalGoal1H > 1.5 THEN -1 
										WHEN ip.TotalGoal1H < 1.5 AND ip.TotalGoal2H > 1.5 THEN -1 
										ELSE NULL
									END
										
								WHEN @betteam = 'n' THEN 
									CASE 
										WHEN ip.TotalGoal1H > 1.5 THEN 1
										WHEN ip.TotalGoal1H < 1.5 AND ip.TotalGoal2H > 1.5 THEN 1
										ELSE NULL
									END
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (14,127) THEN --FGNG
					CASE 
						WHEN RIGHT(@betteam, 1) IN ('0', '1' ) AND LEN(@FGNG) = 3 THEN
							CASE 
								WHEN (@betteam = @FGNG) THEN 1 
								ELSE -1 
							END
						ELSE NULL 
					END
				ELSE NULL
			END AS modds
		) AS t1
	) AS ods
)

GO