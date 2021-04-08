/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_GoalSequenceSel] @MatchId INT
AS
/*
	Created: 20210408@Kathy
	Task: Fast market - Select goal time
	DB: DBPRO.BODB02
	
	Revisions:
			- 20210406@Kathy: New bettype 229 [Readmine:#152748]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	;WITH cteBetOption
	AS (
		SELECT	ISNULL(MAX(CASE WHEN ResourceId LIKE '%H' THEN HomeValue END),REPLICATE('0', 50)) AS BetOptionHome1st
				,ISNULL(MAX(CASE WHEN ResourceId LIKE '%H' THEN AwayValue END),REPLICATE('0', 50)) AS BetOptionHome2nd
				,ISNULL(MAX(CASE WHEN ResourceId LIKE '%A' THEN HomeValue END),REPLICATE('0', 50)) AS BetOptionAway1st
				,ISNULL(MAX(CASE WHEN ResourceId LIKE '%A' THEN AwayValue END),REPLICATE('0', 50)) AS BetOptionAway2nd
		FROM	dbo.ResultDetail r WITH(NOLOCK)
		WHERE	r.MatchId = @MatchId
				AND ResourceId IN ('22901H', '22901A')
	)
	SELECT rs.Position, rs.HomeScore, rs.AwayScore
	FROM cteBetOption	
		CROSS APPLY (
			SELECT	f.Position, f.HomeScore, f.AwayScore
			FROM (
				SELECT	fh.pos AS Position, fh.ResultStatus AS HomeScore, fa.ResultStatus AS AwayScore
				FROM	dbo.f_Set_GetChars(BetOptionHome1st) fh
					INNER JOIN dbo.f_Set_GetChars(BetOptionAway1st) fa
						on fh.pos = fa.pos
				WHERE	fh.pos < 46 
			) f

			UNION ALL

			SELECT	f.Position, f.HomeScore, f.AwayScore
			FROM(
				SELECT	fh.pos + 46 AS Position, fh.ResultStatus AS HomeScore, fa.ResultStatus AS AwayScore
				FROM	dbo.f_Set_GetChars(BetOptionHome2nd) fh
					INNER JOIN dbo.f_Set_GetChars(BetOptionAway2nd) fa
						ON fh.pos = fa.pos
				WHERE	fh.pos < 45 
			)f
	) rs
END
GO
