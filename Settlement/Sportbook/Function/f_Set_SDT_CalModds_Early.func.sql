/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_SDT_CalModds_Early] (
		@pfID			SMALLINT
		,@betteam 		NVARCHAR(10)
		,@hdp1			SMALLMONEY
		,@hdp2			SMALLMONEY
		,@HomeValue 	VARCHAR(50)
		,@AwayValue 	VARCHAR(50)
		,@LiveHomeScore SMALLINT
		,@LiveAwayScore SMALLINT
		,@homeRound		TINYINT
		,@awayRound		TINYINT
		)
RETURNS TABLE
AS  
/*	Created: 20191112@Sol
	Task: cal modds for early
	DB: DBTXN/bodb02
	Revisions:	
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		
*/
RETURN
(
   SELECT  CASE
			WHEN @pfID = 391 THEN -- Penalty Shootout Exact Total Goals (First 10)
				CASE 
					WHEN @betteam = 'G4' AND (0 <= fm AND fm <= 4) AND (0 <= MaxTotalScoreAvai AND MaxTotalScoreAvai <= 4) THEN 1
					WHEN @betteam = 'G9+' AND (9 <= fm) THEN 1
					WHEN RIGHT(REPLACE(@betteam,'+',''),1) BETWEEN fm AND MaxTotalScoreAvai THEN NULL
					ELSE -1 
				END
			WHEN @pfID IN (387, 386) THEN --Over/under
			   CASE WHEN @betteam = 'o' AND CurrScore - 0.25 >= @hdp1 THEN CurrScore - @hdp1
					WHEN @betteam = 'u' AND CurrScore - 0.25 >= @hdp1 THEN @hdp1 - CurrScore
					WHEN @betteam = 'o' AND fm <= @hdp1 - 0.25 THEN fm - @hdp1
					WHEN @betteam = 'u' AND fm <= @hdp1 - 0.25 THEN @hdp1 - fm
					ELSE NULL 
				END
			WHEN @pfID IN (385, 384) THEN --betteam = homevalue 
			   CASE WHEN @betteam = @HomeValue THEN 1
					WHEN @betteam IN ('1','B') AND @HomeValue = '1MNT' THEN -1
					WHEN @betteam IN ('1','N') AND @HomeValue = 'NT2S' THEN -1
					WHEN @betteam IN ('2','N') AND @HomeValue = '1SNT' THEN -1
					WHEN @betteam IN ('2','B') AND @HomeValue = 'NT2M' THEN -1
					ELSE NULL 
				END
			WHEN @pfID = 383 THEN -- Penalty Shootout Woodwork - Round X
				CASE WHEN @betteam = 'H' AND @HomeValue = 'H' THEN 1
					 WHEN @betteam = 'H' AND @HomeValue = 'N' THEN -1
					 WHEN @betteam = 'A' AND @AwayValue = 'H' THEN 1
					 WHEN @betteam = 'A' AND @AwayValue = 'N' THEN -1
					 ELSE NULL
				END
			   		
			ELSE NULL END AS modds
   FROM
	(
		SELECT (
					CASE 
						--PHAIO 5
						WHEN @pfID = 391 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY))
						WHEN @pfID = 387 THEN 5 - @homeRound + CAST(@HomeValue AS SMALLMONEY)
						WHEN @pfID = 386 THEN 5 - @awayRound + CAST(@HomeValue AS SMALLMONEY)

						ELSE -1 
					END
				) AS fm
				, (
					CASE 
						--PHAIO 5
						WHEN @pfID = 391 THEN (10 + CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - (@homeRound + @awayRound))
						ELSE -1 
					END
				) AS MaxTotalScoreAvai
				, (
					CASE 
						--PHAIO 5
						WHEN @pfID IN (387, 386) THEN CAST(@HomeValue AS SMALLMONEY)
						ELSE -1 
					END
				) AS CurrScore
	) tbl
)
GO 