/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Settlement_Result_Statistics_Cricket
(
	@FromDate	DATETIME 
	,@ToDate	DATETIME 
	,@SportType	SMALLINT 
)
AS
/*
    Created: 20231208@Louisa
    Task : Internal report for Cricket-result settle and Provider score [Redmine:#197548]
    DB: DBPRO/bodb02

    Revisions:
		-20231208@louisa: Init [Redmine:#197548]
*/
BEGIN
	SET NOCOUNT ON;

	--use #tmp_matchInfo, #tmp_ResultSettle from parent SPs

	DROP TABLE IF EXISTS  #tmp_ResultProvider
	DROP TABLE IF EXISTS  #tbl_ResourceCricket

	CREATE TABLE #tmp_ResultProvider ( SourceID INT, MatchId INT, ResourceID VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	
	CREATE INDEX IDX_tmp_ResultProvider ON #tmp_ResultProvider(MatchID, ResourceID)

	CREATE TABLE #tbl_ResourceCricket
	(	ID INT IDENTITY(1,1)
		, ResourceName VARCHAR(200)
		, Prefix	VARCHAR(6)
		, Sufix		VARCHAR(20)
		, G_Range	VARCHAR(3) 	
	)

	DECLARE @tbl_ResourceFormat TABLE (	ResourceName  VARCHAR(200),Prefix VARCHAR(6),Sufix VARCHAR(20)	,G_Range VARCHAR(3)	, ResourceId VARCHAR(20))

	INSERT INTO #tbl_ResourceCricket( ResourceName, Prefix, Sufix, G_Range) --Resouce Name, like (	Prefix + replace(G--> [12]) + replace(X or Z--> '_')  + replcae(Y--> '_')	)
	VALUES   ('Match Winner'								, '00'		, ''			,0	)
			,('Away Innings 1'								, 'A1'		, ''			,0	)
			,('Away Innings 2'								, 'A2'		, ''			,0	)
			,('Home Innings 1'								, 'H1'		, ''			,0	)
			,('Home Innings 2'								, 'H2'		, ''			,0	)
		
			,('Super Over Winner'							, '9400'	,''				,0	)
			,('Toss Winner'									, '9401'	,''				,0	)
			,('Home [G0]Group 1-[X] Runs'					, '9410'	,'GXXX'			,2	) 
			,('Away [G0]Group 1-[X] Runs'					, '9411'	,'GXXX'			,2	) 
			,('Home [G0]Over [X] Ball [Y]'					, '9422'	,'GXXXYY'		,2	) 
			,('Away [G0]Over [X] Ball [Y]'					, '9423'	,'GXXXYY'		,2	) 
			,('Home [G0]Fall of Wicket [X]'					, '9428'	,'GXXX'			,2	) 
			,('Away [G0]Fall of Wicket [X]'					, '9429'	,'GXXX'			,2	) 
			,('Home [G0]Wicket [X] Method of Dismissal'		, '9434'	,'GXXX'			,2	)
			,('Away [G0]Wicket [X] Method of Dismissal'		, '9435'	,'GXXX'			,2	) 
			,('1st Inns Highest Opening Partnership'		, '9442'	, ''			,0	) --#170406-Changes on Result type [9442] Highest Opening Partnership: change display text to "1st Inns Highest Opening Partnership".
			,('1st Inns Highesst Score in Over 1'			, '9443'	, ''			,0	) --#170406-Changes on Result type [9443] Highest Opening Partnership: change display text to "1st Inns Highest Score in Over 1".
			,('Match Fours'									, '9446'	, ''			,0	)
			,('Match Sixes'									, '9447'	, ''			,0	)
			,('Match Wickets'								, '9449'	, ''			,0	)
			,('Match Extras'								, '9450'	, ''			,0	)
			,('Match Dot Balls'								, '9451'	, 'G'			,1	)
			,('Highest Individual Score'					, '9452'	, ''			,0	)
			,('Highest Over Score'							, '9453'	, ''			,0	)
			,('Home [G1]Fours'								, '9454'	, 'G'			,2	) 
			,('Away [G1]Fours'								, '9455'	, 'G'			,2	) 
			,('Home [G1]Sixes'								, '9460'	, 'G'			,2	)
			,('Away [G1]Sixes'								, '9461'	, 'G'			,2	)
			,('Home [G0]Over [X] Runs'						, '9484'	, 'GXXX'		,2	)
			,('Away [G0]Over [X] Runs'						, '9485'	, 'GXXX'		,2	) 
			,('Home [G0]Over [X] Ball [Y] Runs'				, '9490'	, 'GXXXYY'		,2	)
			,('Away [G0]Over [X] Ball [Y] Runs'				, '9491'	, 'GXXXYY'		,2	)
			,('Match Run Outs'								, '9615'	, 'G'			,1	)
			,('Home [G0]Over [X] Delivery [Y] Runs'			, '9616'	, 'GXXXYY'		,2	)	 
			,('Away [G0]Over [X] Delivery [Y] Runs'			, '9617'	, 'GXXXYY'		,2	)	 
			,('Home [G0]Over [X] Has Boundary Four?'		, '9624'	, 'GXXX'		,2	)	 
			,('Away [G0]Over [X] Has Boundary Four?'		, '9625'	, 'GXXX'		,2	)	 
			,('Home [G0]Over [X] Has Boundary Six?'			, '9630'	, 'GXXX'		,2	)	 
			,('Away [G0]Over [X] Has Boundary Six?'			, '9631'	, 'GXXX'		,2	)	 
			,('Home [G0]Wicket [X] Method of Dismissal (6-way)', '9636'	, 'GXXX'		,2	)	 
			,('Away [G0]Wicket [X] Method of Dismissal (6-way)', '9637'	, 'GXXX'		,2	)	 
			,('Home [G0]Top Batsman'						, '9650'	, 'G'	 		,2	)
			,('Away [G0]Top Batsman'						, '9651'	, 'G'	 		,2	)
			,('Home [G0]Top Bowler'							, '9656'	, 'G'	 		,2	)
			,('Away [G0]Top Bowler'							, '9657'	, 'G'	 		,2	)
			,('Home [G0]Next Man Out'						, '9662'	, 'GZZZ'		,2	)	 
			,('Away [G0]Next Man Out'						, '9663'	, 'GZZZ'		,2	)	 
			,('Home [G0]Prematch Top Batsman'				, '9668'	, 'G'	 		,2	)
			,('Away [G0]Prematch Top Batsman'				, '9671'	, 'G'	 		,2	)
			,('Home [G0]Prematch Top Bowler'				, '9672'	, 'G'	 		,2	)
			,('Away [G0]Prematch Top Bowler'				, '9675'	, 'G'	 		,2	)
			,('Home [G0]Player Runs'						, '9676'	, 'GZZZ'		,2	)	 
			,('Home [G0]Batsman Runs'						, '9680'	, 'GZZZ'		,2	)	 
			,('Away [G0]Player Runs'						, '9686'	, 'GZZZ'		,2	)	 
			,('Away [G0]Batman Runs'						, '9690'	, 'GZZZ'		,2	)	 
			,('[G0]Highest Individual Score'				, '9708'	, 'G'			,2	)	 
			,('[G0]Highest Over Score'						, '9709'	, 'G'			,2	)	 
			,('Home [G0]Batsman Sixes'						, '9730'	, 'GZZZ'		,2	)	 
			,('Away [G0]Batsman Sixes'						, '9731'	, 'GZZZ'		,2	)	 
			,('Home [G0]Batsman Fours'						, '9736'	, 'GZZZ'		,2	)	 
			,('Away [G0]Batsman Fours'						, '9737'	, 'GZZZ'		,2	)	 

	--61 rows
	INSERT INTO @tbl_ResourceFormat (ResourceName,Prefix,Sufix,G_Range, ResourceId )
	SELECT ResourceName,Prefix,Sufix,G_Range
			, Prefix 
			+ REPLACE(REPLACE(REPLACE(REPLACE(Sufix, 'G', CASE WHEN G_Range = 1 THEN '[1]' WHEN G_Range = 2 THEN '[12]' ELSE '' END), 'X', '_') ,'Z', '_') ,'Y', '_') AS ResourceId
	FROM #tbl_ResourceCricket

	;WITH cte_ResultProvider ( SourceId, MatchId, ResourceID, HomeValue, AwayValue, rk) AS
	(
	SELECT pr.SourceId, pr.matchid, pr.ResourceId, pr.HomeValue, pr.AwayValue
			,ROW_NUMBER() OVER( PARTITION BY pr.SourceId, pr.matchid, pr.ResourceId ORDER BY pr.CreateDate DESC ) AS rk
	FROM ProviderExternalResultDetailOS pr with(nolock)
		INNER JOIN	#tmp_matchInfo m  
			ON pr.matchid = m.matchid 
	WHERE pr.SourceId  IN ( 24, 32)
	  )
  
	INSERT INTO #tmp_ResultProvider ( SourceId, MatchId, ResourceID, HomeValue, AwayValue)
	SELECT  r.MatchId, SourceId, ResourceID, HomeValue, AwayValue
	FROM cte_ResultProvider r
	WHERE rk = 1

	--------------------------------------------------------------
	DROP TABLE IF EXISTS #tmp_ResultProviderW
	CREATE TABLE #tmp_ResultProviderW ( MatchId INT, ResourceID VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	
	INSERT INTO  #tmp_ResultProviderW (MatchId, ResourceID, HomeValue, AwayValue)
	SELECT MatchId, ResourceID, HomeValue, AwayValue
	FROM #tmp_ResultProvider 
	WHERE SourceID =  24

	DROP TABLE IF EXISTS #tmp_ResultProviderTS
	CREATE TABLE #tmp_ResultProviderTS ( MatchId INT, ResourceID VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )

	INSERT INTO  #tmp_ResultProviderTS(MatchId, ResourceID, HomeValue, AwayValue)
	SELECT MatchId, ResourceID, HomeValue, AwayValue
	FROM #tmp_ResultProvider 
	WHERE SourceID =  32

	;WITH cte_return AS 
	(
	SELECT r.eventdate,r.MatchId,  r.leaguename, r.GameSession,  r.ResourceID
		,CAST(SUBSTRING(r.ResourceID,5,1) AS TINYINT) AS G
		,CAST(SUBSTRING(r.ResourceID,6,3) AS TINYINT) AS X ---X OR Z
		,CAST(SUBSTRING(r.ResourceID,9,2) AS TINYINT) AS Y
		,r.HomeName +' -vs- '+ r.AwayName as match
		,r.HomeValue, r.AwayValue 
	
		, CASE WHEN w.ResourceID IS NULL THEN 'no data' ELSE W.HomeValue END AS [HomeValue(Weverdat)] 
		, CASE WHEN w.ResourceID IS NULL THEN 'no data' ELSE W.AwayValue END AS [AwayValue(Weverdat)]
	
		, CASE WHEN ts.ResourceID IS NULL THEN 'no data' ELSE TS.HomeValue END AS [HomeValue(TheSports)]
		, CASE WHEN ts.ResourceID IS NULL THEN 'no data' ELSE TS.AwayValue END AS [AwayValue(TheSports)]
	FROM #tmp_ResultSettle r
		OUTER APPLY ( SELECT rs.ResourceId, rs.HomeValue, rs.AwayValue   FROM #tmp_ResultProviderW rs
						WHERE r.MatchId = rs.MatchId and r.ResourceID = rs.ResourceID
						) W
		OUTER APPLY ( SELECT rs.ResourceId, rs.HomeValue, rs.AwayValue FROM #tmp_ResultProviderTS rs
						WHERE r.MatchId = rs.MatchId and r.ResourceID = rs.ResourceID
						) TS
	)

	SELECT cte.EventDate,cte.MatchID,  cte.LeagueName
		,REPLACE( REPLACE( REPLACE(REPLACE(r.ResourceName, '[X]',X) ,'[Y]',Y)
				  ,'[G0]'
				  ,CASE WHEN cte.GameSession IN(1,8) THEN CASE WHEN r.G_Range = 1 THEN '1st Inns '
														  WHEN r.G_Range = 2 THEN '2nd Inns '
														  ELSE ''
														  END
					ELSE ''
					END
				 )
				 ,'[G1]'
				 ,CASE WHEN cte.GameSession IN(1,8) THEN CASE WHEN r.G_Range = 1 THEN '1st Inns '
														  WHEN r.G_Range = 2 THEN '2nd Inns '
														  ELSE 'Inns '
														  END
					ELSE 'Inns '
					END
				)
		AS ResourceName
		, Match
		, cte.HomeValue, cte.AwayValue 
		, cte.[HomeValue(Weverdat)] 
		, cte.[AwayValue(Weverdat)]
		, cte.[HomeValue(TheSports)]
		, cte.[AwayValue(TheSports)]
	FROM cte_return cte
	INNER JOIN @tbl_ResourceFormat r
			ON cte.ResourceID LIKE r.ResourceId

END
GO
 