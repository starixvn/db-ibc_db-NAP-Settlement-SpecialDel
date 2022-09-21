/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SSBErrorMessageSel
	@MatchId INT = 0
AS
/*
	Created by: 20211111@Kathy
	Task: Get all ssb error message [Redmine:#164162]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20211111@Kathy: Get all ssb error message [Redmine:#164162]
		- 20220913@Louisa: Get more info [RedmineId:#177711]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @checktime DATETIME2
			,@ServerName VARCHAR(100)

	DECLARE @tmpErrorMessage TABLE (MatchId INT, SessionId BIGINT, ErrorMessage VARCHAR(200), CreatedTime DATETIME2)

	SET @checktime = DATEADD(HOUR,-6,SYSDATETIME())
	SET @ServerName = @@SERVERNAME

	;WITH cteErrorMessage
	AS(
		SELECT	SessionId, ErrorMessage, MIN(Starttime) AS CreatedTime
		FROM	dbo.SSB_SettlementLogs WITH(NOLOCK)
		WHERE	ISNULL(ErrorMessage,'') <> ''
				AND Resolved = 0
				AND StartTime > @checktime 
		GROUP BY SessionId, ErrorMessage
	)
	INSERT INTO @tmpErrorMessage(SessionId, ErrorMessage, CreatedTime)
	SELECT	c.SessionId
			,(SELECT s.ErrorMessage + ' \n ' FROM cteErrorMessage s WHERE s.SessionId = c.SessionId FOR XML PATH('')) AS ErrorMessage
			,MIN(c.CreatedTime)
	FROM	cteErrorMessage c
	GROUP BY c.SessionId

	IF @@ROWCOUNT > 0
	BEGIN
		IF ISNULL(@MatchId,0) = 0
			UPDATE	t 
				SET MatchId = s.MatchId
			FROM	@tmpErrorMessage t
				INNER JOIN dbo.Settlement_SettledSession s WITH(NOLOCK)
					ON t.SessionId = s.SessionId
		ELSE
			UPDATE	t 
				SET MatchId = s.MatchId
			FROM	@tmpErrorMessage t
				INNER JOIN dbo.Settlement_SettledSession s WITH(NOLOCK)
					ON t.SessionId = s.SessionId
			WHERE	s.MatchId = @MatchId
	END

	SELECT	@ServerName AS ServerName
			,m.MatchId
			,t.SessionId
			,t.CreatedTime
			,h.teamname AS HomeTeam
			,a.teamname AS AwayTeam
			,s.SportName
			,t.ErrorMessage
			,ISNULL(p.TotalSettlementProcessing,0) AS TotalSettlementProcessing
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN @tmpErrorMessage t
			ON m.matchid = t.MatchId
		OUTER APPLY(
			SELECT	COUNT(1) AS TotalSettlementProcessing
			FROM	dbo.SettlementProcessing p WITH(NOLOCK)
			WHERE	p.SessionId = t.SessionId
		)p
		INNER JOIN dbo.team h WITH(NOLOCK)
			ON h.teamid = m.homeid
		INNER JOIN dbo.team a WITH(NOLOCK)
			ON a.teamid = m.awayid
		INNER JOIN dbo.Sports s WITH(NOLOCK)
			ON s.SportType = m.sporttype
	
END
GO