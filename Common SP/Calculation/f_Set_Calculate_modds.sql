/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
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
					
			WHEN @pfID = 3 THEN --Over/under
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
					
			ELSE -1 END AS modds
   FROM
	(
		SELECT (CASE 
					WHEN @pfID = 1 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1 - @LiveHomeScore) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2 - @LiveAwayScore)
					WHEN @pfID = 2 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)) % 2
					WHEN @pfID = 3 THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @hdp1)
					WHEN @pfID = 20 THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 101 THEN (CAST(@HomeValue AS SMALLMONEY) * 60 + CAST(@AwayValue AS SMALLMONEY)) - (@hdp1 * 60)
					
					--Happy5
					WHEN @pfID = 8101 THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID = 8102 THEN CAST(@HomeValue AS SMALLMONEY) % 2
					WHEN @pfID = 8103 THEN CAST(@HomeValue AS SMALLMONEY)
					WHEN @pfID = 8104 THEN CAST(@HomeValue AS SMALLMONEY) - CAST(@AwayValue AS SMALLMONEY)
					WHEN @pfID = 8105 THEN CAST(@HomeValue AS SMALLMONEY)
					
					ELSE -1 END)
			AS fm
	) tbl
)
GO 