/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchLockingSel
	@MatchId INT = 0
AS
/*
	Created by: 20210506@Kathy
	Task: Get all matches being locked [Redmine:#151475]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210506@Kathy: Get all matches being locked [Redmine:#151475]
		- 20220913@Louisa: Get more info [RedmineId:#177711]
		- 20220923@Kathy: correct rule get match locked

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @fromdatetime DATETIME
			,@ServerName VARCHAR(100) 

	SET @fromdatetime = DATEADD(MINUTE, -5, GETDATE())
	SET @ServerName	= @@SERVERNAME

	DECLARE @tmpLockedMatch TABLE (MatchId INT, KeyId INT, MarketId VARCHAR(20), CreatedDateTime DATETIME)

	INSERT INTO @tmpLockedMatch(MatchId, KeyId, MarketId, CreatedDateTime)
	SELECT	hi.KeyValue, hi.KeyID, CASE WHEN hi.KeyID = 5 THEN hi.KeyValue2 ELSE '' END, hi.CreatedDateTime
	FROM	dbo.TempVariableNumberHistory hi WITH(NOLOCK)
	WHERE	hi.Action = 'I'
			AND hi.CreatedDateTime <= @fromdatetime
			AND (@MatchId = 0 OR hi.KeyValue = @MatchId )
			AND NOT EXISTS (SELECT TOP 1 1 
							FROM	dbo.TempVariableNumberHistory hd WITH(NOLOCK) 
							WHERE	hd.KeyID = hi.KeyID 
									AND hd.KeyValue = hi.KeyValue 
									AND hd.KeyValue2 = hi.KeyValue2 
									AND hd.Action = 'D' 
									AND hd.CreatedDateTime >= hi.CreatedDateTime
							)
	
	SELECT @ServerName AS ServerName
		,t.MatchId
		,st.SportName
		,h.teamname AS HomeTeam
		,a.teamname AS AwayTeam
		,l.leaguename
		,t.CreatedDateTime
		,st.SportName
		,CASE WHEN s.execTime < t.CreatedDateTime THEN s.Action END AS Action
		,sm.Message
		,CASE WHEN s.execTime < t.CreatedDateTime THEN s.IsCalculating END AS IsCalculating
		,t.KeyId
		,t.MarketId
		,CASE WHEN s.execTime > t.CreatedDateTime THEN CAST(s.execTime AS VARCHAR(30)) + ', ' + s.Action + ': failed' END AS Remark
	FROM	@tmpLockedMatch t
		CROSS APPLY (
			SELECT	m.homeid, m.awayid, m.leagueid
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.matchid = t.matchid
			UNION ALL
			SELECT	o.teamid, 0 AS awayId, o.leagueid
			FROM	dbo.outright o WITH(NOLOCK)
			WHERE	o.orid = t.MatchId
					AND t.KeyId = 2
			UNION ALL
			SELECT	0 AS homeid, 0 AS awayId, r.LeagueID
			FROM	dbo.VSRaceInfo r WITH(NOLOCK)
			WHERE	r.EventID = t.MatchId
					AND t.KeyId = 4
		)m
		INNER JOIN dbo.league l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		LEFT JOIN dbo.team h WITH(NOLOCK)
			ON m.homeid = h.teamid
		LEFT JOIN dbo.team a WITH(NOLOCK)
			ON m.awayid = a.teamid
		INNER JOIN dbo.Sports st WITH(NOLOCK)
			ON st.SportType = l.sporttype
		OUTER APPLY (
			SELECT	s.IsCalculating, s.Action, s.matchid, s.execTime
			FROM	(
				SELECT	TOP 1 s.IsCalculating, s.Action, s.matchid, s.execTime
				FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
				WHERE	s.matchid = t.MatchId
						AND s.IsCalculating IN (1,3) -- running, failed
						AND t.KeyId NOT BETWEEN 2 AND 5
				UNION ALL 
				SELECT	TOP 1 s3rd.IsCalculating, s3rd.Action, s3rd.matchid, s3rd.execTime
				FROM	dbo.Single_Calculate_Queue_3rd s3rd WITH(NOLOCK)
				WHERE	s3rd.matchid = t.MatchId
						AND s3rd.IsCalculating IN (1,3) -- running, failed
						AND t.KeyId = 5
				ORDER BY execTime DESC
			)s
		)s
		OUTER APPLY (
			SELECT	TOP 1 sm.Message
			FROM	dbo.Settled_Message sm WITH(NOLOCK)
			WHERE	sm.MatchId = s.MatchId
					AND sm.Action = s.Action
					AND sm.Starttime > t.CreatedDateTime
			ORDER BY Starttime DESC
		)sm

END
GO