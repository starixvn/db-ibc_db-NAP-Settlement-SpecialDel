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

	CREATE TABLE #tmpRefResource_Cricket ( RefId VARCHAR(20) ,ResourceId  VARCHAR(20), Resource_en NVARCHAR(50), Resource_ch NVARCHAR(50),	Resource_cs NVARCHAR(50) )

	--76 rows
	INSERT INTO  #tmpRefResource_Cricket ( RefId, ResourceId, Resource_en, Resource_ch, Resource_cs)		
	VALUES('ResourceCricket'	,'9400'		,N'Super Over Winner'									,N'超級輪獲勝者盤	'						,N'超级轮获胜者盘	'						)			
		 ,('ResourceCricket'	,'9401'		,N'Toss Winner'											,N'贏得拋硬幣盤'							,N'赢得抛硬币盘'							)
		 ,('ResourceCricket'	,'9442'		,N'Highest Opening Partnership'							,N'搭檔開場最高得分盤'					,N'搭档开场最高得分盘'					)		
		 ,('ResourceCricket'	,'9443'		,N'Highest Score in Over 1'								,N'第一輪最高得分盤'					    ,N'第一轮最高得分盘'						)		
		 ,('ResourceCricket'	,'9446'		,N'Match Fours'											,N'比賽一擊四分盤'						,N'比赛一击四分盘'						)
		 ,('ResourceCricket'	,'9447'		,N'Match Sixes'											,N'比賽一擊六分盤'						,N'比赛一击六分盘	'						)
		 ,('ResourceCricket'	,'9449'		,N'Match Wickets'										,N'比賽三柱門得分盤'						,N'比赛三柱门得分盘'						)
		 ,('ResourceCricket'	,'9450'		,N'Match Extras'										,N'比賽附加分盤'							,N'比赛附加分盘'							)
		 ,('ResourceCricket'	,'9452'		,N'Highest Individual Score'							,N'個人最高得分盤	'						,N'个人最高得分盘	'						)
		 ,('ResourceCricket'	,'9453'		,N'Highest Over Score'									,N'賽輪最高得分盤'						,N'赛轮最高得分盘'						)
		 ,('ResourceCricket'	,'9615'		,N'Match Run Outs'										,N'最多追殺出局數盤'						,N'最多追杀出局数盘'						)
		 ,('ResourceCricket'	,'9451'		,N'Match Dot Balls'										,N'比賽未得分投球數盤'					,N'比赛未得分投球数盘	'					)	
		 ,('ResourceCricket'	,'9484'		,N'Home @G Over @X Runs'								,N'主隊@G第 @X 輪準確跑位得分盤'			,N'主队@G第 @X 轮准确跑位得分盘'			)						
		 ,('ResourceCricket'	,'9485'		,N'Away @G Over @X Runs'								,N'客隊@G第 @X 輪準確跑位得分盤'			,N'客队@G第 @X 轮准确跑位得分盘'			)						
		 ,('ResourceCricket'	,'9490'		,N'Home @G Over @X Ball @Y Runs'						,N'主隊@G第 @X 輪第 @Y 球準確跑位得分盤'	,N'主队@G第 @X 轮第 @Y 球准确跑位得分盘'	)										
		 ,('ResourceCricket'	,'9491'		,N'Away @G Over @X Ball @Y Runs'						,N'客隊@G第 @X 輪第 @Y 球準確跑位得分盤'	,N'客队@G第 @X 轮第 @Y 球准确跑位得分盘'	)										
		 ,('ResourceCricket'	,'9422'		,N'Home @G Over @X Ball @Y'								,N'主隊@G第 @X 輪第 @Y 球得分盤'			,N'主队@G第 @X 轮第 @Y 球得分盘'			)						
		 ,('ResourceCricket'	,'9423'		,N'Away @G Over @X Ball @Y'								,N'客隊@G第 @X 輪第 @Y 球得分盤'			,N'客队@G第 @X 轮第 @Y 球得分盘'			)						
		 ,('ResourceCricket'	,'9410'		,N'Home @G Group 1-@X'									,N'主隊@G組合1-@X 跑位盤'					,N'主队@G组合1-@X 跑位盘'					)		
		 ,('ResourceCricket'	,'9411'		,N'Away @G Group 1-@X'									,N'客隊@G組合1-@X 跑位盤'					,N'客队@G组合1-@X 跑位盘'					)		
		 ,('ResourceCricket'	,'9428'		,N'Home @G Fall of Wicket @X'							,N'主隊@G第 @X 三柱門擊倒盤'				,N'主队@G第 @X 三柱门击倒盘'				)			
		 ,('ResourceCricket'	,'9429'		,N'Away @G Fall of Wicket @X'							,N'客隊@G第 @X 三柱門擊倒盤'				,N'客队@G第 @X 三柱门击倒盘'				)				
		 ,('ResourceCricket'	,'9434'		,N'Home @G Wicket @X Method of Dismissal'				,N'主隊@G第 @X 三柱門出局方式盤'			,N'主队@G第 @X 三柱门出局方式盘'			)						
		 ,('ResourceCricket'	,'9435'		,N'Away @G Wicket @X Method of Dismissal'				,N'客隊@G第 @X 三柱門出局方式盤'			,N'客队@G第 @X 三柱门出局方式盘'			)						
		 ,('ResourceCricket'	,'9454'		,N'Home @M Inns Fours'									,N'主隊@M一擊四分盤'						,N'主队@M一击四分盘'						)
		 ,('ResourceCricket'	,'9455'		,N'Away @M Inns Fours'									,N'客隊@M一擊四分盤'						,N'客队@M一击四分盘'						)
		 ,('ResourceCricket'	,'9460'		,N'Home @M Inns Sixes'									,N'主隊@M一擊六分盤'						,N'主队@M一击六分盘'						)
		 ,('ResourceCricket'	,'9461'		,N'Away @M Inns Sixes'									,N'客隊@M一擊六分盤'						,N'客队@M一击六分盘'						)
		 ,('ResourceCricket'	,'9708'		,N'Highest Individual Score'							,N'個人最高得分盤'						,N'个人最高得分盘	'						)
		 ,('ResourceCricket'	,'9709'		,N'1st Inns Highest Over Score'							,N'首局賽輪最高得分盤'					,N'首局赛轮最高得分盘'					)	
		 ,('ResourceCricket'	,'9680'		,N'Home @G Batsman Runs'								,N'主隊@G擊球手跑位得分盤'				,N'主队@G击球手跑位得分盘'				)			
		 ,('ResourceCricket'	,'9690'		,N'Away @G Batsman Runs'								,N'客隊@G擊球手跑位得分盤'				,N'客队@G击球手跑位得分盘'				)			
		 ,('ResourceCricket'	,'9662'		,N'Home @G Next Man Out'								,N'主隊@G下一出局盤'						,N'主队@G下一出局盘'						)
		 ,('ResourceCricket'	,'9663'		,N'Away @G Next Man Out'								,N'客隊@G下一出局盤'						,N'客队@G下一出局盘'						)
		 ,('ResourceCricket'	,'9676'		,N'Home @G Player Runs'									,N'主隊@G球員得分盤'						,N'主队@G球员得分盘'						)
		 ,('ResourceCricket'	,'9686'		,N'Away @G Player Runs'									,N'客隊@G球員得分盤'						,N'客队@G球员得分盘'						)
		 ,('ResourceCricket'	,'9668'		,N'Home @G Prematch Top Batsman'						,N'主隊@G賽前最佳擊球手盤'				,N'主队@G赛前最佳击球手盘'				)				
		 ,('ResourceCricket'	,'9671'		,N'Away @G Prematch Top Batsman'						,N'客隊@G首局賽前最佳擊球手盤'				,N'客队@G首局赛前最佳击球手盘'				)				
		 ,('ResourceCricket'	,'9650'		,N'Home @G Top Batsman'									,N'主隊@G最佳擊球手'						,N'主队@G最佳击球手'						)
		 ,('ResourceCricket'	,'9651'		,N'Away @G Top Batsman'									,N'客隊@G最佳擊球手'						,N'客队@G最佳击球手'						)
		 ,('ResourceCricket'	,'9672'		,N'Home @G Prematch Top Bowler'							,N'主隊@G賽前最佳投球手盤'				,N'主队@G赛前最佳投球手盘'				)				
		 ,('ResourceCricket'	,'9675'		,N'Away @G Prematch Top Bowler'							,N'客隊@G首局賽前最佳投球手盤'				,N'客队@G首局赛前最佳投球手盘'				)				
		 ,('ResourceCricket'	,'9656'		,N'Home @G Top Bowler'									,N'主隊@G最佳投球手'						,N'主队@G最佳投球手'						)
		 ,('ResourceCricket'	,'9657'		,N'Away @G Top Bowler'									,N'客隊@G最佳投球手'						,N'客队@G最佳投球手'						)
		 ,('ResourceCricket'	,'9636'		,N'Home @G Wicket @X Method of Dismissal'				,N'主隊@G第 @X 三柱門出局方式盤'			,N'主队@G第 @X 三柱门出局方式盘'			)						
		 ,('ResourceCricket'	,'9637'		,N'Away @G Wicket @X Method of Dismissal'				,N'客隊@G第 @X 三柱門出局方式盤'			,N'客队@G第 @X 三柱门出局方式盘'			)						
		 ,('ResourceCricket'	,'9616'		,N'Home @G Over @X Delivery @Y Runs'					,N'主隊@G第 @X 輪第 @Y 投球盤'			,N'主队@G第 @X 轮第 @Y 投球盘'			)				
		 ,('ResourceCricket'	,'9617'		,N'Away @G Over @X Delivery @Y Runs'					,N'客隊@G第 @X 輪第 @Y 投球盤'			,N'客队@G第 @X 轮第 @Y 投球盘'			)					
		 ,('ResourceCricket'	,'9624'		,N'Will there be a Boundary Fours in Home @G Over @X?'	,N'主隊@G是否在第 @X 輪有邊界四分球'		,N'主队@G是否在第 @X 轮有边界四分球'		)								
		 ,('ResourceCricket'	,'9625'		,N'Will there be a Boundary Fours in Away @G Over @X?'	,N'客隊@G是否在第 @X 輪有邊界四分球'		,N'客队@G是否在第 @X 轮有边界四分球'		)								
		 ,('ResourceCricket'	,'9630'		,N'Will there be a Boundary Sixes in Home @G Over @X?'	,N'主隊@G是否在第 @X 輪有邊界六分球'		,N'主队@G是否在第 @X 轮有边界六分球'		)								
		 ,('ResourceCricket'	,'9631'		,N'Will there be a Boundary Sixes in Away @G Over @X?'	,N'客隊@G是否在第 @X 輪有邊界六分球'		,N'客队@G是否在第 @X 轮有边界六分球'		)								
		 ,('ResourceCricket'	,'9730'		,N'Home @G Batsman Sixes'								,N'主隊@G擊球手一擊六分盤'				,N'主队@G击球手一击六分盘'				)				
		 ,('ResourceCricket'	,'9731'		,N'Away @G Batsman Sixes'								,N'客隊@G擊球手一擊六分盤'				,N'客队@G击球手一击六分盘'				)				
		 ,('ResourceCricket'	,'9736'		,N'Home @G Batsman Fours'								,N'主隊@G擊球手一擊四分盤'				,N'主队@G击球手一击四分盘'				)				
		 ,('ResourceCricket'	,'9737'		,N'Away @G Batsman Fours'								,N'客隊@G擊球手一擊四分盤'				,N'客队@G击球手一击四分盘'				)				
		 ,('ResourceCricket'	,'00'		,N'Match Winner'										,N'比賽獲勝者'							,N'比赛获胜者'							)
		 ,('ResourceCricket'	,'A1'		,N'Away @M Inns Runs'									,N'客隊@M跑位盤'							,N'客队@M跑位盘'							)
		 ,('ResourceCricket'	,'A2'		,N'Away @M Inns  Runs'									,N'客隊@M跑位盤'							,N'客队@M跑位盘'							)
		 ,('ResourceCricket'	,'H1'		,N'Home @M Inns  Runs'									,N'主隊@M跑位盤'							,N'主队@M跑位盘'							)
		 ,('ResourceCricket'	,'H2'		,N'Home @M Inns Runs'									,N'主隊@M跑位盤'							,N'主队@M跑位盘'							)
		 ,('ResourceCricket'	,'M0'		,N''													,N'賽局'									,N'赛局'									)
		 ,('ResourceCricket'	,'M1'		,N'1st'													,N'首局'									,N'首局'									)
		 ,('ResourceCricket'	,'M2'		,N'2nd'													,N'次局'									,N'次局'									)
		 ,('ResourceCricket'	,'G1'		,N'1st Inns'											,N'首局'									,N'首局'									)
		 ,('ResourceCricket'	,'G2'		,N'2nd Inns'											,N' 次局'								,N'次局'									)
		 ,('ResultSettlement'	,'c'		,N'Caught'												,N'接球出局'								,N'接球出局'								)
		 ,('ResultSettlement'	,'nc'		,N'Not Caught'											,N'非接球出局'							,N'非接球出局'							)
		 ,('ResultSettlement'	,'None'		,N'None'												,N'無'									,N'无'									)
		 ,('ResultSettlement'	,'N'		,N'No'													,N'否'									,N'否'									)
		 ,('ResultSettlement'	,'Y'		,N'Yes'													,N'是'									,N'是'									)
		 ,('ResultSettlement'	,'B'		,N'Bowled'												,N'投殺'									,N'投杀'									)
		 ,('ResultSettlement'	,'lbw'		,N'LBW'													,N'觸身'									,N'触身'									)
		 ,('ResultSettlement'	,'OT'		,N'Other'												,N'其他'									,N'其他'									)
		 ,('ResultSettlement'	,'ro'		,N'Run Out'												,N'追殺'									,N'追杀'									)
		 ,('ResultSettlement'	,'S'		,N'Stumped'												,N'擊殺'									,N'击杀'									)																																		

	INSERT INTO RefResource
	(
		RefId
		,ResourceId
		,Resource_en, Resource_ch, Resource_cs
	)
	SELECT tmp.RefId
		,tmp.ResourceId
		,tmp.Resource_en, tmp.Resource_ch, tmp.Resource_cs
	FROM #tmpRefResource_Cricket tmp
		LEFT JOIN RefResource r WITH(NOLOCK) 
			ON tmp.RefId = r.RefId
				AND tmp.ResourceId = r.ResourceId
	WHERE r.RefId IS NULL

	---Check data
	--76 rows
	SELECT * FROM RefResource WITH(NOLOCK)
	WHERE RefId IN ('ResourceCricket', 'ResultSettlement')

END
 