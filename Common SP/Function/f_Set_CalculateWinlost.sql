/*<info serverAlias="DBACC-bodb02,DBWH-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_CalculateWinlost] (
	@bettype SMALLINT
	,@statuswinlost TINYINT
	,@actual_stake MONEY
	,@stake MONEY
	,@oddstype TINYINT
	,@odds SMALLMONEY
	,@oddsspread MONEY
	,@modds SMALLMONEY
)
RETURNS TABLE
AS

/*
    Created by: Kathy
	Date: 20220309
	Task: Calculate winlost

	Revisions:		
		- 20220309@Kathy: Calculate winlost [Redmine:#169300]
		- 20250303@Lani: [TVS]  Fix bug - Basketball - Integrate 6 new bet types: Recover Ticket - Winlost calculation is incorrect for Win/Lose 1/2 case [Redmine: #218916]


*/

RETURN (    
	SELECT CASE 
				WHEN @bettype IN (468, 469)
					THEN CASE
							WHEN @statuswinlost IN (2,4) THEN @actual_stake + @stake * c.odds
							WHEN @statuswinlost = 0 THEN @actual_stake 
						 END	
				ELSE
					CASE
						WHEN @statuswinlost = 2 
							THEN CASE 
									WHEN @oddstype = 6 AND @modds = 0 THEN @actual_stake + @stake * @odds * (@oddsspread/100) -- oddsspread > 0: WON
									ELSE @actual_stake + @stake * c.odds
								END
						WHEN @statuswinlost = 1 THEN @actual_stake + @stake * c.odds * 0.5
						WHEN @statuswinlost IN (0,6) THEN @actual_stake
						WHEN @statuswinlost = 3 THEN @actual_stake * 0.5
						WHEN @statuswinlost = 4 
							THEN CASE 
									WHEN @oddstype = 6  AND @modds = 0 THEN @actual_stake * (1 - ABS(@oddsspread/100))
									ELSE 0
								END
					END
			END	AS winlost
	FROM (
		SELECT CASE 
				WHEN @bettype IN (468,469) THEN @odds
				ELSE (CASE 
						WHEN @odds < 0 THEN 1 
	   					WHEN EXISTS (SELECT TOP 1 1 FROM dbo.f_TVS_OddsTypeBettypes() ot WHERE ot.BetType = @bettype AND ot.OddsType = 1) THEN @odds - 1 ----/*DECIMAL ONLY*/
						ELSE @odds 
					END)
				END AS odds
	) c
)
GO


