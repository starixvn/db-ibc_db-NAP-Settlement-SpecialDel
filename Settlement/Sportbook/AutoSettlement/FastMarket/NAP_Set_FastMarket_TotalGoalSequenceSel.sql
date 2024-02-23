/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_TotalGoalSequenceSel] @MatchId INT
AS
/*
	Created: 20240223@Aries
	Task: Fast Market - SABA Time Machine OU - Support to input value function [Readmine:#199719]
	DB: DBPRO.BODB02
	
	Revisions:
			- 20240223@Aries: Created [Readmine:#199719]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	;WITH cteBetOption
	AS (
		SELECT	 ISNULL(MAX(HomeValue),REPLICATE('0', 50)) AS BetOption1st
				,ISNULL(MAX(AwayValue),REPLICATE('0', 50)) AS BetOption2nd
		FROM	dbo.ResultDetail r WITH(NOLOCK)
		WHERE	r.MatchId = @MatchId
				AND ResourceId = '22801'
	)
	SELECT rs.Position, rs.TotalGoal
	FROM cteBetOption	
		CROSS APPLY (
			SELECT	f.Position, f.TotalGoal
			FROM (
				SELECT	f.pos AS Position, f.ResultStatus AS TotalGoal
				FROM	dbo.f_Set_GetChars(BetOption1st) f
				WHERE	f.pos < 46 
			) f

			UNION ALL

			SELECT	f.Position, f.TotalGoal
			FROM(
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS TotalGoal
				FROM	dbo.f_Set_GetChars(BetOption2nd) f
				WHERE	f.pos < 45 
			)f
	) rs
END
GO
