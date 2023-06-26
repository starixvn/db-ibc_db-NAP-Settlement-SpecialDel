/*<info serverAlias="SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchLockingReplicatedServerSel
	@MatchId INT = 0
AS
/*
	Created by: 20211111@Kathy
	Task: Get all matches being locked on replicated servers [Redmine:#164162]
	DB: SBSETTLE/bodb02
	
	Revisions:
		- 20211111@Kathy: Get all matches being locked on replicated servers [Redmine:#164162]
		- 20220913@Louisa: get more info [RedmineId:#177711]
		- 20220927@Louisa: get more info [RedmineId:#177711]
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]
		- 20230208@Louisa: support queue 3rd [RedmineId:#179505]
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @checktime DATETIME2
			,@ServerName VARCHAR(100) 

	DECLARE @tmpMatchLocked TABLE (MatchId INT, SessionId BIGINT)
	DECLARE @tmpErrorMessage TABLE (MessageId VARCHAR(128), MatchId INT, SessionId BIGINT, ErrorMessage VARCHAR(max), CreatedTime DATETIME2)
	DECLARE @tmpReturnTable TABLE 
	(	MatchId INT
		,SessionId BIGINT
		,MessageId VARCHAR(128)
		,ErrorMessage VARCHAR(max)
		,CreatedTime DATETIME2
		,HomeTeam NVARCHAR(200)
		,AwayTeam  NVARCHAR(200)
		,SportName  NVARCHAR(100)
		,TotalSettlementProcessing INT
	)

	SET @checktime = DATEADD(HOUR,-6,SYSDATETIME())
	SET @ServerName = @@SERVERNAME

	INSERT INTO @tmpMatchLocked(MatchId, SessionId)
	SELECT	MatchId, SessionId
	FROM	dbo.SettlementLock WITH(NOLOCK)
	WHERE	MatchId = CASE WHEN ISNULL(@MatchId,0) = 0 THEN MatchId ELSE @MatchId END

	IF @@ROWCOUNT <> 0
	BEGIN
		;WITH cteErrorMessage
		AS(
			SELECT	s.SessionId, s.ErrorMessage, MIN(s.Starttime) AS CreatedTime
			FROM	dbo.SSB_SettlementLogs s WITH(NOLOCK)
				INNER JOIN @tmpMatchLocked t
					ON s.SessionId = t.SessionId
			WHERE	ISNULL(s.ErrorMessage,'') <> ''
					AND s.Resolved = 0
					AND s.StartTime >= @checktime
					AND SiteDBGroupId = 0
			GROUP BY s.SessionId, s.ErrorMessage
		)
		INSERT INTO @tmpErrorMessage(SessionId, ErrorMessage, CreatedTime)
		SELECT	c.SessionId
				,(SELECT s.ErrorMessage + '\n' FROM cteErrorMessage s WHERE s.SessionId = c.SessionId FOR XML PATH('')) AS ErrorMessage
				,MIN(c.CreatedTime) AS CreatedTime
		FROM	cteErrorMessage c
		GROUP BY c.SessionId
	END

	;WITH cteErrorMessage
	AS (
		SELECT	s.SessionId, s.ErrorMessage, MIN(s.StartTime) AS CreatedTime
		FROM	dbo.SSB_SettlementLogs s WITH(NOLOCK)
		WHERE	SessionID IS NOT NULL
				AND ISNULL(ErrorMessage,'') <> ''
				AND Resolved = 0
				AND StartTime > @checktime
				AND NOT EXISTS (SELECT TOP 1 1 FROM @tmpMatchLocked t WHERE t.SessionId = s.SessionId)
				AND SiteDBGroupId = 0
		GROUP BY s.SessionId, s.ErrorMessage
	)
	INSERT INTO @tmpErrorMessage(SessionId, ErrorMessage, CreatedTime)
	SELECT	c.SessionId
			,(SELECT s.ErrorMessage + ' \n ' FROM cteErrorMessage s WHERE s.SessionId = c.SessionId FOR XML PATH('')) AS ErrorMessage
			,MIN(c.CreatedTime) AS CreatedTime
	FROM	cteErrorMessage c
	GROUP BY c.SessionId


	INSERT INTO  @tmpReturnTable
	(	MatchId 
		,MessageId
		,SessionId  
		,CreatedTime  
		,HomeTeam  
		,AwayTeam   
		,SportName  
		,ErrorMessage 
		,TotalSettlementProcessing  
	)
	SELECT	m.MatchId
			,e.MessageId
			,ISNULL(e.SessionId,t.SessionId) as SessionId
			,e.CreatedTime AS CreatedTime
			,h.teamname AS HomeTeam
			,a.teamname AS AwayTeam
			,s.SportName
			,e.ErrorMessage
			,ISNULL(p.TotalSettlementProcessing,0) AS TotalSettlementProcessing
	FROM	@tmpErrorMessage e
		FULL JOIN @tmpMatchLocked t
			ON e.SessionId = t.SessionId
		OUTER APPLY(
			SELECT	COUNT(1) AS TotalSettlementProcessing
			FROM	dbo.SettlementProcessing p WITH(NOLOCK)
			WHERE	p.SessionId = ISNULL(t.SessionId,e.SessionId)
		)p
		LEFT JOIN dbo.match m WITH(NOLOCK)
			ON t.MatchId = m.matchid
		LEFT JOIN dbo.team h WITH(NOLOCK)
			ON h.teamid = m.homeid
		LEFT JOIN dbo.team a WITH(NOLOCK)
			ON a.teamid = m.awayid
		LEFT JOIN dbo.Sports s WITH(NOLOCK)
			ON s.SportType = m.sporttype


	SELECT	@ServerName AS ServerName
			,MatchId 
			,SessionId 
			,MessageId 
			,ErrorMessage 
			,CreatedTime  
			,HomeTeam  
			,AwayTeam   
			,SportName  
			,TotalSettlementProcessing 
	FROM @tmpReturnTable
END
GO