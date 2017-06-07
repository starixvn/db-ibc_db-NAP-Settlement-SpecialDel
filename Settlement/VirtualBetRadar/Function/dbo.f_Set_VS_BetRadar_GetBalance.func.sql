/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" selecters="vnteam" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Set_VS_BetRadar_GetBalance] (
	@Matchid 		INT
	,@SportType 	SMALLINT
	,@VSType 		TINYINT = 2 -- BetRadar VS
)
RETURNS TABLE
AS

/*
    Created: 20161129@Bobby
    Task: 77720 - Implement BetRadar VS League & Nation 
    DB: DBTXN/bodb02
    Revisions:
		- 20160606@Bobby: Initialize
    
	Params Explanation:    
		-@VSType:TINYINT
			+ 2: BetRadar
*/

RETURN (
	WITH CTE_Bettypes AS 
	(
		SELECT f.bettype 
		FROM dbo.f_Set_VS_BetRadar_GetBettypes() AS f
		WHERE f.sportType = @sportType
			AND 1 = CASE 
						WHEN @VSType = 2 AND @sportType BETWEEN 190 AND 199 THEN 1 -- BetRadar VS
						ELSE 0
					END
					
	)
	SELECT b.custid
		,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM dbo.bettrans b WITH (ROWLOCK)
	WHERE b.matchid = @matchid 
		AND EXISTS (
			SELECT 1 FROM CTE_Bettypes AS cte
			WHERE cte.bettype = b.bettype
		)
		
	GROUP BY b.custid
)
GO
