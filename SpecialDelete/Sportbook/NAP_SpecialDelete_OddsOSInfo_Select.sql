/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_OddsOSInfo_Select]
(	
	@MatchId INT = 0
	,@BetTypes VARCHAR(2000) = ''
)
AS 
/*	
	Created by: 20220228@Max
	Task: [TVS] Integrate new bet types of Cricket
	DB: DBPRO-bodb02
	
	Revisions:
		- 20220228@Max: Create new SP [Redmine: #168080]
		- 20220804@Max: TVS HotFix Filter Player Cricket [Redmine: #176290]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		- 20221221@July: [TVS] Update message template for Not Participate case [Redmine: #181628]
		- 20250829@Lani: [TVS] Basketball AIO - Integrate new bet types for Basketball Player Props [Redmine: #234941]
		
	Param's explanation:		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpBettype AS TABLE (bettype SMALLINT)
	DECLARE @Sporttype SMALLINT
	
	SET @Sporttype = (SELECT TOP 1 Sporttype FROM Match WITH (NOLOCK) WHERE MatchId = @MatchId)

	INSERT INTO @tmpBettype (bettype)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@BetTypes, ',')
	WHERE value <> ''

	CREATE TABLE #tblOddsOSInfo 
	(
		Oddsid INT,
		BettypeId SMALLINT,
		BetChoice VARCHAR(20),
		Oddsinfo VARCHAR(500),
		Performance	VARCHAR(50),
		PlayerId INT,
		PlayerName NVARCHAR(200),
		PlayNamesChineseTraditional NVARCHAR(200),
		PlayNamesChineseSimplified NVARCHAR(200)
	)

	IF @Sporttype = 50
	BEGIN
		INSERT INTO #tblOddsOSInfo (Oddsid, BettypeId, BetChoice, PlayerId, PlayerName)
		SELECT DISTINCT CASE WHEN t.bettype IN (9662, 9664, 9666, 9663, 9665, 9667) THEN o.oddsid ELSE NULL END AS oddsid
			, o.bettype AS BettypeId
			, os.betChoice
			, STUFF(os.OddsInfo, CHARINDEX(',', os.OddsInfo), LEN(os.OddsInfo), '') AS PlayerId
			, STUFF(os.OddsInfo, 1, CHARINDEX(',', os.OddsInfo), '') AS PlayerName
		FROM dbo.oddsOS o WITH (NOLOCK)
			INNER JOIN dbo.oddsOS_flex os WITH (NOLOCK) ON os.oddsid = o.oddsid
			INNER JOIN @tmpBettype t ON t.bettype = o.bettype
		WHERE o.matchid = @MatchId
			AND os.OddsInfo <> ''
	END
	ELSE
	BEGIN
		INSERT INTO #tblOddsOSInfo (Oddsid, BettypeId, BetChoice, PlayerId, PlayerName, Oddsinfo, Performance)
        SELECT DISTINCT o.oddsid
            , o.bettype AS BettypeId
            , os.betChoice
            , JSON_VALUE(os.OddsInfo, '$.pid') AS PlayerId
            , JSON_VALUE(os.OddsInfo, '$.pname') AS PLayerName
			, CASE WHEN o.bettype IN (675, 676, 678) THEN
						'have ' 
					   + SUBSTRING(pp.Point,0,IIF(CHARINDEX(',',pp.Point) > 0,CHARINDEX(',',pp.Point),LEN(pp.Point)+1))
					   + CASE WHEN pp.Performance = 'points' 
								THEN CASE WHEN tt.ExtraInfo = 'winner' THEN ' points and ' + t.teamname + ' to Win'
										  WHEN tt.ExtraInfo = 'over' THEN ' points and ' + t.teamname + ' Total Points Over ' + tt.ExtraValue
										  WHEN tt.ExtraInfo = 'handicap' THEN ' points and ' + t.teamname + tt.ExtraValue
										  WHEN tt.ExtraValue = 'winner,over' THEN ' points, ' + t.teamname + ' to Win and ' + t.teamname + ' Total Points Over ' + SUBSTRING(tt.ExtraValue,CHARINDEX(',',tt.ExtraValue)+1,LEN(tt.ExtraValue))
										  ELSE '' END
							  WHEN pp.Performance = 'three_points' 
								THEN CASE WHEN tt.ExtraInfo = 'winner' THEN ' three points field goals and ' + t.teamname + ' to Win'
										  WHEN tt.ExtraInfo = 'winner,over' THEN ' three points field goals, ' + t.teamname + ' to Win and ' + t.teamname + ' Total Points Over ' + SUBSTRING(tt.ExtraValue,CHARINDEX(',',tt.ExtraValue)+1,LEN(tt.ExtraValue))
									      ELSE '' END
							  WHEN pp.Performance = 'rebounds' THEN ' total rebounds and ' + t.teamname + ' to Win'
							  WHEN pp.Performance = 'assists' THEN ' assists and ' + t.teamname + ' to Win'
							  WHEN pp.Performance = 'points+assists' 
								THEN CASE WHEN tt.ExtraInfo = 'winner' THEN ' points and ' + SUBSTRING(pp.Point,CHARINDEX(',',pp.Point)+1,LEN(pp.Point)) + ' assists and ' + t.teamname + ' to Win'
										  WHEN tt.ExtraInfo = 'handicap' THEN ' points and ' + SUBSTRING(pp.Point,CHARINDEX(',',pp.Point)+1,LEN(pp.Point)) + ' assists and ' + t.teamname + ' ' + tt.ExtraValue
										  ELSE ' points and ' + SUBSTRING(pp.Point,CHARINDEX(',',pp.Point)+1,LEN(pp.Point)) + ' assists' END
							  WHEN pp.Performance = 'points+rebounds'
								THEN CASE WHEN tt.ExtraInfo = 'winner' THEN ' points and ' + SUBSTRING(pp.Point,CHARINDEX(',',pp.Point)+1,LEN(pp.Point)) + ' rebounds and ' + t.teamname + ' to Win'
										  WHEN tt.ExtraInfo = 'handicap' THEN ' points and ' + SUBSTRING(pp.Point,CHARINDEX(',',pp.Point)+1,LEN(pp.Point)) + ' rebounds and ' + t.teamname + ' ' + tt.ExtraValue
										  ELSE ' points and ' + SUBSTRING(pp.Point,CHARINDEX(',',pp.Point)+1,LEN(pp.Point)) + ' rebounds' END
							  WHEN pp.Performance = 'points+assists+rebounds'
								THEN CASE WHEN tt.ExtraInfo = 'winner' THEN ' points, ' + SUBSTRING(pp.Point, CHARINDEX(',', pp.Point) + 1, CHARINDEX(',', pp.Point, CHARINDEX(',', pp.Point) + 1) - CHARINDEX(',', pp.Point) - 1)
																			+ ' assists, ' + SUBSTRING(pp.Point, CHARINDEX(',', pp.Point, CHARINDEX(',', pp.Point) + 1) + 1, LEN(pp.Point)) + ' rebounds and ' + t.teamname + ' to Win'
										  WHEN tt.ExtraInfo = 'handicap' THEN ' points, ' + SUBSTRING(pp.Point, CHARINDEX(',', pp.Point) + 1, CHARINDEX(',', pp.Point, CHARINDEX(',', pp.Point) + 1) - CHARINDEX(',', pp.Point) - 1)
																			+ ' assists, ' + SUBSTRING(pp.Point, CHARINDEX(',', pp.Point, CHARINDEX(',', pp.Point) + 1) + 1, LEN(pp.Point)) + ' rebounds and ' + t.teamname + ' ' + tt.ExtraValue
										  ELSE ' points, ' + SUBSTRING(pp.Point, CHARINDEX(',', pp.Point) + 1, CHARINDEX(',', pp.Point, CHARINDEX(',', pp.Point) + 1) - CHARINDEX(',', pp.Point) - 1)
											 + ' assists and ' + SUBSTRING(pp.Point, CHARINDEX(',', pp.Point, CHARINDEX(',', pp.Point) + 1) + 1, LEN(pp.Point)) + ' rebounds' END
						ELSE NULL END
				   ELSE NULL
			  END
			, CASE WHEN o.bettype IN (675, 676) THEN pp.Performance ELSE NULL END AS Performance
        FROM dbo.odds AS o WITH (NOLOCK)
            INNER JOIN dbo.odds_flex AS os WITH (NOLOCK) ON o.oddsid = os.oddsid
            INNER JOIN @tmpBettype AS bt ON bt.bettype = o.bettype
			CROSS APPLY (
				SELECT JSON_VALUE(os.OddsInfo,'$.tid') AS TeamId
			) AS tm
			INNER JOIN dbo.team AS t ON tm.TeamId = t.teamid
			OUTER APPLY (
				SELECT STRING_AGG(JSON_VALUE(s.value,'$.t'),'+') AS Performance
					 , STRING_AGG(JSON_VALUE(s.value,'$.value'),',') AS Point
				FROM OPENJSON(os.OddsInfo,'$.s') AS s
			) AS pp
			OUTER APPLY (
				SELECT STRING_AGG(JSON_VALUE(r.value,'$.t'),',') AS ExtraInfo
					 , STRING_AGG(JSON_VALUE(r.value,'$.value'),',') AS ExtraValue
				FROM OPENJSON(os.OddsInfo,'$.r') AS r
			) AS tt
        WHERE o.matchid = @MatchId AND os.OddsInfo <> ''
	END

	UPDATE os
	SET os.PlayNamesChineseTraditional = t.teamnamec_uni,
		os.PlayNamesChineseSimplified = t.teamnamecn
	FROM #tblOddsOSInfo os
		INNER JOIN dbo.team t WITH(NOLOCK) ON os.PlayerId = t.teamid

	SELECT Oddsid, BettypeId, BetChoice, Oddsinfo, Performance, PlayerId, PlayerName, PlayNamesChineseTraditional, PlayNamesChineseSimplified
	FROM #tblOddsOSInfo

	DROP TABLE #tblOddsOSInfo
END

