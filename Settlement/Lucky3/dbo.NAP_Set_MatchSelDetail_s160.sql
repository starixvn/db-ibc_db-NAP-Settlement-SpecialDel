/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchSelDetail_s160
	@MatchId		INT
AS
/*
	Created by: Kathy
	Date: 20170426
	Task: Lucky 3 - Settlement 
	DB: DBPRO.BODB02
	
	Revisions:
		20170426@Kathy: Lucky 3 - Settlement  [Redmine:#77170]
		
	Param's Explanation:	
				
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	m.matchid
			,m.leagueid
			,m.kickofftime
			,m.matchcode
			,b.FirstBall
			,b.SecondBall
			,b.ThirdBall
	FROM	dbo.match m WITH (ROWLOCK)
		LEFT JOIN (
			SELECT Matchid, FirstBall, SecondBall, ThirdBall
			FROM (
				SELECT	b.Matchid
						,CASE WHEN b.Seq = 1 THEN 'FirstBall'
							WHEN b.Seq = 2 THEN 'SecondBall'
							when b.Seq = 3 THEN 'ThirdBall'
						END AS seq 
						,Number
				FROM	dbo.bingoBall b WITH(ROWLOCK)
			)AS s
			PIVOT (
				MAX(s.Number)
				FOR seq IN (FirstBall, SecondBall, ThirdBall)
			) AS pvt
		) b
			ON	m.matchid = b.Matchid
	WHERE	m.sporttype = 160
			AND m.Matchid = @MatchId
END

GO