/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Settlement_Result_Statistics_Esports
(
	@FromDate	DATETIME 
	,@ToDate	DATETIME 
	,@SportType	SMALLINT 
)
AS
/*
    Created: 20231208@Louisa
    Task : Internal report for ESports-result settle and Provider score [Redmine:#197548]
    DB: DBPRO/bodb02

    Revisions:
		-20231208@louisa: Init [Redmine:#197548]
*/
BEGIN
	SET NOCOUNT ON;

	--use #tmp_matchInfo, #tmp_ResultSettle from parent SPs

	DROP TABLE IF EXISTS  #tmp_ResultProvider
	DROP TABLE IF EXISTS  #tbl_ResourceESports

	CREATE TABLE #tmp_ResultProvider ( SourceID INT, MatchId INT, ResourceID VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	
	CREATE INDEX IDX_tmp_ResultProvider ON #tmp_ResultProvider(MatchID, ResourceID, SourceID)

	CREATE TABLE #tbl_ResourceESports
		(	ID INT IDENTITY(1,1)
			, ResourceName VARCHAR(200)
			, Prefix	VARCHAR(6)	
		)
	INSERT INTO #tbl_ResourceESports( ResourceName, Prefix) 
	VALUES   ('Full Time'										,'00'	)
			,('Map [X]'											,'M'	)
			,('Map [X] Dragons Score'							,'9028'	)
			,('Map [X] Barons Score'							,'9034'	)
			,('Map [X] Inhibitors Score'						,'9040'	)
			,('Map [X] Tyrants Score'							,'9046'	)
			,('Map [X] Overlords Score'							,'9052'	)
			,('Map [X] Duration'								,'9058'	)
			,('Map [X] Rounds Score'							,'9059'	)
			,('Map [X] Rounds Score (including Overtime)'		,'9074'	)
			,('Map [X] Total First Kills'						,'9065'	)
			,('Map [X] Total Kills Score'						,'9002'	)
			,('Map [X] Towers Score'							,'9008'	)
			,('Map [X] Roshans Score'							,'9012'	)
			,('Map [X] Barracks Score'							,'9018'	)
			,('Map [X] Turrets Score'							,'9024'	)
			,('Map [X] Clutches Score'							,'9066'	)
			,('Map [X] First Blood Time'						,'9090'	)
			,('Map [X] Total Kills at 10 Mins'					,'9091'	)
			,('Map [X] Total Kills at 20 Mins'					,'9093'	)
			,('Map [X] Lane With Most Turrets Destroyed'		,'9113'	)
			,('Map [X] First Turret Location'					,'9114'	)
			,('Map [X] Total Gold'								,'9115'	)
			,('Map [X] First Tyrant Time'						,'9121'	)
			,('Map [X] First Dark Tyrant'						,'9122'	)
			,('Map [X] First Overlord Time'						,'9123'	)
			,('Map [X] Will Storm Dragon Be Killed'				,'9124'	)
			,('Map [X] First Herald'							,'9125'	)
			,('Map [X] First Herald Time'						,'9126'	)
			,('Map [X] First Baron Time'						,'9127'	)
			,('Map [X] First Baron No. Players Buff'			,'9128'	)
			,('Map [X] First Inhibitor Time'					,'9129'	)
			,('Map [X] First Inhibitor Location'				,'9130'	)
			,('Map [X] First Dragon Time'						,'9131'	)
			,('Map [X] Will Elder Dragon Be Killed'				,'9132'	)
			,('Map [X] Will Any Aegis Be Snatched Yes/No'		,'9133'	)
			,('Map [X] First Tower Time'						,'9134'	)
			,('Map [X] First Tower Location'					,'9135'	)
			,('Map [X] First Roshan Time'						,'9136'	)
			,('Map [X] First Barrack Time'						,'9137'	)
			,('Map [X] First Barrack Location'					,'9138'	)
			,('Map [X] Total Bomb Detonations (excl. OT)'		,'9139'	)
			,('Map [X] Total Bomb Defuses (excl. OT)'			,'9140'	)
			,('Map [X] Lane With Most Turrets Destroyed (KOG)'	,'9141'	)	
			,('Map [X] First Turret Location (KOG)'				,'9142'	)
			,('Map [X] Round [Y] Winner'						,'9068'	)
			,('Map [X] Round [Y] Total Kills'					,'9069'	)
			,('Map [X] First to [Y] Kills Time'					,'9089'	)
			,('Map [X] [YS] Kill'								,'9101'	)
			,('Map [X] First Blood'								,'9006' )
			,('Map [X] First to [Y] Kills'						,'9007'	)
			,('Map [X] First Tier [Y] Tower'					,'9011'	)
			,('Map [X] 1st Roshan'								,'9015'	)
			,('Map [X] 2nd Roshan'								,'9016'	)
			,('Map [X] 3rd Roshan'								,'9017'	)
			,('Map [X] 1st Barrack'								,'9021'	)
			,('Map [X] 2nd Barrack'								,'9022'	)
			,('Map [X] 3rd Barrack'								,'9023'	)
			,('Map [X] First Tier [Y] Turret'					,'9027'	)
			,('Map [X] 1st Dragon'								,'9031'	)
			,('Map [X] 2nd Dragon'								,'9032'	)
			,('Map [X] 3rd Dragon'								,'9033'	)
			,('Map [X] 1st Baron'								,'9037'	)
			,('Map [X] 2nd Baron'								,'9038'	)
			,('Map [X] 3rd Baron'								,'9039'	)
			,('Map [X] 1st Inhibitor'							,'9043'	)
			,('Map [X] 2nd Inhibitor'							,'9044'	)
			,('Map [X] 3rd Inhibitor'							,'9045'	)
			,('Map [X] 1st Tyrant'								,'9049'	)
			,('Map [X] 2nd Tyrant'								,'9050'	)
			,('Map [X] 3rd Tyrant'								,'9051'	)
			,('Map [X] 1st Overlord'							,'9055'	)
			,('Map [X] 2nd Overlord'							,'9056'	)
			,('Map [X] 3rd Overlord'							,'9057'	)
			,('Map [X] First to [Y] Rounds'						,'9062'	)
			,('Map [X] First Half'								,'9063'	)
			,('Map [X] Second Half'								,'9064'	)
			,('Map [X] 16th Round'								,'9067'	)
			,('Map [X] Round [Y] First Kill'					,'9072'	)
			,('Map [X] Round [Y] Bomb Plant'					,'9073'	)
			,('Map [X] Final Round Bomb Plant'					,'9075'	)
			,('Map [X] Overtime'								,'9087'	)

	;WITH cte_ResultProvider ( SourceId, MatchId, ResourceID, HomeValue, AwayValue, rk) AS
	(
		SELECT pr.SourceId, pr.matchid, pr.ResourceId, pr.HomeValue, pr.AwayValue
				,ROW_NUMBER() OVER( PARTITION BY pr.SourceId, pr.matchid, pr.ResourceId ORDER BY pr.CreateDate DESC ) AS rk
		FROM ProviderExternalResultDetailES pr with(nolock)
			INNER JOIN	#tmp_matchInfo m  
				ON pr.matchid = m.matchid 
		WHERE pr.SourceId  IN ( 100, 16,23,30,22)
	  )
  
	INSERT INTO #tmp_ResultProvider ( MatchId, SourceId, ResourceID, HomeValue, AwayValue)
	SELECT  r.MatchId, SourceId, ResourceID, HomeValue, AwayValue
	FROM cte_ResultProvider r
	WHERE rk = 1

	--------------------------------------------------------------
	;WITH cte_ResultProviderT ( MatchId, ResourceID, HomeValue, AwayValue) AS
	(
		SELECT MatchId, ResourceID, HomeValue, AwayValue
		FROM #tmp_ResultProvider 
		WHERE SourceID = 100
	)
	,cte_ResultProviderP ( MatchId, ResourceID, HomeValue, AwayValue) AS
	(
		SELECT MatchId, ResourceID, HomeValue, AwayValue
		FROM #tmp_ResultProvider 
		WHERE SourceID = 16
	)
	,cte_ResultProviderGSK ( MatchId, ResourceID, HomeValue, AwayValue) AS
	(
		SELECT MatchId, ResourceID, HomeValue, AwayValue
		FROM #tmp_ResultProvider 
		WHERE SourceID = 22
	)
	,cte_ResultProviderG ( MatchId, ResourceID, HomeValue, AwayValue) AS
	(
		SELECT MatchId, ResourceID, HomeValue, AwayValue
		FROM #tmp_ResultProvider 
		WHERE SourceID = 23
	)
	,cte_ResultProviderA( MatchId, ResourceID, HomeValue, AwayValue) AS
	(
		SELECT MatchId, ResourceID, HomeValue, AwayValue
		FROM #tmp_ResultProvider 
		WHERE SourceID = 30
	)
	,cte_return AS 
	(
	SELECT r.eventdate,r.MatchId,  r.leaguename, r.GameSession,  r.ResourceID
		, CAST( CASE WHEN r.ResourceID LIKE 'M%' THEN SUBSTRING(r.ResourceID,2, 2) 
				ELSE SUBSTRING(r.ResourceID, 5, 2 ) 
				END
			AS TINYINT) AS X
		, CAST( SUBSTRING(r.ResourceID, 7, 2 ) AS TINYINT )AS Y
		,r.HomeName +' -vs- '+ r.AwayName as match
		, r.HomeValue, r.AwayValue 
	
		, CASE WHEN t.ResourceID IS NULL THEN 'no data' ELSE t.HomeValue END AS [HomeValue(Trader)] 
		, CASE WHEN t.ResourceID IS NULL THEN 'no data' ELSE t.AwayValue END AS [AwayValue(Trader)]
	
		, CASE WHEN p.ResourceID IS NULL THEN 'no data' ELSE p.HomeValue END AS [HomeValue(PandaScore)]
		, CASE WHEN p.ResourceID IS NULL THEN 'no data' ELSE p.AwayValue END AS [AwayValue(PandaScore)]

		, CASE WHEN gsk.ResourceID IS NULL THEN 'no data' ELSE gsk.HomeValue END AS [HomeValue(GameScorekeeper)]
		, CASE WHEN gsk.ResourceID IS NULL THEN 'no data' ELSE gsk.AwayValue END AS [AwayValue(GameScorekeeper)]

		, CASE WHEN g.ResourceID IS NULL THEN 'no data' ELSE g.HomeValue END AS [HomeValue(GRID)]
		, CASE WHEN g.ResourceID IS NULL THEN 'no data' ELSE g.AwayValue END AS [AwayValue(GRID)]

		, CASE WHEN a.ResourceID IS NULL THEN 'no data' ELSE a.HomeValue END AS [HomeValue(Abios)]
		, CASE WHEN a.ResourceID IS NULL THEN 'no data' ELSE a.AwayValue END AS [AwayValue(Abios)]
	FROM #tmp_ResultSettle r
		OUTER APPLY ( SELECT rs.ResourceId, rs.HomeValue, rs.AwayValue   
						FROM cte_ResultProviderT rs
						WHERE r.MatchId = rs.MatchId and r.ResourceID = rs.ResourceID
						) T
		OUTER APPLY ( SELECT rs.ResourceId, rs.HomeValue, rs.AwayValue   
						FROM cte_ResultProviderP rs
						WHERE r.MatchId = rs.MatchId and r.ResourceID = rs.ResourceID
						) P
		OUTER APPLY ( SELECT rs.ResourceId, rs.HomeValue, rs.AwayValue   
						FROM cte_ResultProviderGSK rs
						WHERE r.MatchId = rs.MatchId and r.ResourceID = rs.ResourceID
						) GSK
		OUTER APPLY ( SELECT rs.ResourceId, rs.HomeValue, rs.AwayValue   
						FROM cte_ResultProviderG rs
						WHERE r.MatchId = rs.MatchId and r.ResourceID = rs.ResourceID
						) G
		OUTER APPLY ( SELECT rs.ResourceId, rs.HomeValue, rs.AwayValue   
						FROM cte_ResultProviderA rs
						WHERE r.MatchId = rs.MatchId and r.ResourceID = rs.ResourceID
						) A
	)

	SELECT cte.EventDate,cte.MatchID,  cte.LeagueName
		,REPLACE(REPLACE(REPLACE(e.ResourceName, '[YS]', CAST( Y AS VARCHAR(2)) + CASE WHEN Y IN(1,11) THEN 'st '
															WHEN Y IN (2,12) THEN 'nd '
															WHEN Y IN (3,13) THEN 'rd'
															ELSE 'th'
															END
								)
						, '[X]', X
					  ), '[Y]' ,Y
			) AS ResourceName
		, Match
		, cte.HomeValue, cte.AwayValue 
		, [HomeValue(GameScorekeeper)]
		, [AwayValue(GameScorekeeper)]		
		, [HomeValue(GRID)]
		, [AwayValue(GRID)]

		, [HomeValue(Abios)]
		, [AwayValue(Abios)]
	FROM cte_return cte
		INNER JOIN #tbl_ResourceESports e ON cte.ResourceID LIKE e.Prefix +'%'

END
GO
 