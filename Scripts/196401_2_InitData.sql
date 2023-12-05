/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20231205@Louisa
	Task:  Result Amendment [Redmine:#196401]
	DB: DBPRO-bodb02

*/

USE bodb02
GO

BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #tmpRefResource_Cricket

	CREATE TABLE #tmpRefResource_Cricket ( RefId VARCHAR(20) ,ResourceId  VARCHAR(20), Resource_en NVARCHAR(50) )

	--75 rows
	INSERT INTO  #tmpRefResource_Cricket ( RefId, ResourceId, Resource_en)		
	VALUES   ('ResourceCricket'		,'9400'	,'Super Over Winner'						)
			,('ResourceCricket'		,'9401'	,'Toss Winner'								)
			,('ResourceCricket'		,'9442'	,'1st Inns Highest Opening Partnership'		)
			,('ResourceCricket'		,'9443'	,'1st Inns Highest Score in Over 1'			)
			,('ResourceCricket'		,'9446'	,'Match Fours'								)
			,('ResourceCricket'		,'9447'	,'Match Sixes'								)
			,('ResourceCricket'		,'9449'	,'Match Wickets'							)
			,('ResourceCricket'		,'9450'	,'Match Extras'								)
			,('ResourceCricket'		,'9452'	,'Highest Individual Score'					)
			,('ResourceCricket'		,'9453'	,'Highest Over Score'						)
			,('ResourceCricket'		,'9615'	,'Match Run Outs'							)
			,('ResourceCricket'		,'9451'	,'Match Dot Ball'							)
			,('ResourceCricket'		,'9484'	,'Home @G Over @X Runs'						)
			,('ResourceCricket'		,'9485'	,'Away @G Over @X Runs'						)
			,('ResourceCricket'		,'9490'	,'Home @G Over @X Ball @Y Exact Runs'		)
			,('ResourceCricket'		,'9491'	,'Away @G Over @X Ball @Y Exact Runs'		)
			,('ResourceCricket'		,'9422'	,'Home @G Over @X Ball @Y'					)
			,('ResourceCricket'		,'9423'	,'Away @G Over @X Ball @Y'					)
			,('ResourceCricket'		,'9410'	,'Home @G Group 1-@X'						)
			,('ResourceCricket'		,'9411'	,'Away @G Group 1-@X'						)
			,('ResourceCricket'		,'9428'	,'Home @G Fall of Wicket @X'				)
			,('ResourceCricket'		,'9429'	,'Away @G Fall of Wicket @X'				)
			,('ResourceCricket'		,'9434'	,'Home @G Wicket @X Method of Dismissal (2-way)'	)
			,('ResourceCricket'		,'9435'	,'Away @G Wicket @X Method of Dismissal (2-way)'	)
			,('ResourceCricket'		,'9454'	,'Home @G Fours'							)
			,('ResourceCricket'		,'9455'	,'Away @G Fours'							)
			,('ResourceCricket'		,'9460'	,'Home @G Sixes'							)
			,('ResourceCricket'		,'9461'	,'Away @G Sixes'							)
			,('ResourceCricket'		,'9708'	,'Highest Individual Score'					)
			,('ResourceCricket'		,'9709'	,'Highest Over Score'						)
			,('ResourceCricket'		,'9680'	,'Home @G Batsman Runs'						)
			,('ResourceCricket'		,'9690'	,'Away @G Batsman Runs'						)
			,('ResourceCricket'		,'9662'	,'Home @G Next Man Out'						)
			,('ResourceCricket'		,'9663'	,'Away @G Next Man Out'						)
			,('ResourceCricket'		,'9676'	,'Home @G Player Runs'						)
			,('ResourceCricket'		,'9686'	,'Away @G Player Runs'						)
			,('ResourceCricket'		,'9668'	,'Home @G Prematch Top Batsman'				)
			,('ResourceCricket'		,'9671'	,'Away @G Prematch Top Batsman'				)
			,('ResourceCricket'		,'9650'	,'Home @G Top Batsman'						)
			,('ResourceCricket'		,'9651'	,'Away @G Top Batsman'						)
			,('ResourceCricket'		,'9672'	,'Home @G Prematch Top Bowler'				)
			,('ResourceCricket'		,'9675'	,'Away @G Prematch Top Bowler'				)
			,('ResourceCricket'		,'9656'	,'Home @G Top Bowler'						)
			,('ResourceCricket'		,'9657'	,'Away @G Top Bowler'						)
			,('ResourceCricket'		,'9636'	,'Home @G Wicket @X Method of Dismissal (6-way)'		)
			,('ResourceCricket'		,'9637'	,'Away @G Wicket @X Method of Dismissal (6-way)'		)
			,('ResourceCricket'		,'9616'	,'Home @G Over @X Delivery @Y Runs'						)
			,('ResourceCricket'		,'9617'	,'Away @G Over @X Delivery @Y Runs'						)
			,('ResourceCricket'		,'9624'	,'Will there be a Boundary Fours in Home @G Over X?'	)
			,('ResourceCricket'		,'9625'	,'Will there be a Boundary Fours in Away @G Over X?'	)
			,('ResourceCricket'		,'9630'	,'Will there be a Boundary Sixes in Home @G Over X?'	)
			,('ResourceCricket'		,'9631'	,'Will there be a Boundary Sixes in Away @G Over X?'	)
			,('ResourceCricket'		,'9730'	,'Home @G Player Sixes'		)
			,('ResourceCricket'		,'9731'	,'Away @G Player Sixes'		)
			,('ResourceCricket'		,'9736'	,'Home @G Player Fours'		)
			,('ResourceCricket'		,'9737'	,'Away @G Player Fours'		)
			,('ResourceCricket'		,'00'	,'Match Winner'				)
			,('ResourceCricket'		,'A1'	,'Away @M Inns Runs'		)
			,('ResourceCricket'		,'A2'	,'Away @M Inns  Runs'		)
			,('ResourceCricket'		,'H1'	,'Home @M Inns  Runs'		)
			,('ResourceCricket'		,'H2'	,'Home @M Inns Runs'		)
			,('ResourceCricket'		,'G1'	,'1st Inns'					)
			,('ResourceCricket'		,'G2'	,'2nd Inns'					)
			,('ResourceCricket'		,'M1'	,'1st'						)
			,('ResourceCricket'		,'M2'	,'2nd'						)
			,('ResultSettlement'	,'c'	,'Caught'					)
			,('ResultSettlement'	,'nc'	,'Not Caught'				)
			,('ResultSettlement'	,'None'	,'None'						)
			,('ResultSettlement'	,'N'	,'No'						)
			,('ResultSettlement'	,'Y'	,'Yes'						)
			,('ResultSettlement'	,'B'	,'Bowled'					)
			,('ResultSettlement'	,'lbw'	,'LBW'						)
			,('ResultSettlement'	,'OT'	,'Other'					)
			,('ResultSettlement'	,'ro'	,'Run Out'					)
			,('ResultSettlement'	,'S'	,'Stumped'					)
	
	INSERT INTO RefResource
	(
		RefId
		,ResourceId
		,Resource_en
	)
	SELECT tmp.RefId
		,tmp.ResourceId
		,tmp.Resource_en
	FROM #tmpRefResource_Cricket tmp
		LEFT JOIN RefResource r WITH(NOLOCK) 
			ON tmp.RefId = r.RefId
				AND tmp.ResourceId = r.ResourceId
	WHERE r.RefId IS NULL

	---Check data
	--75 rows
	SELECT * FROM RefResource WITH(NOLOCK)
	WHERE RefId IN ('ResourceCricket', 'ResultSettlement')

END