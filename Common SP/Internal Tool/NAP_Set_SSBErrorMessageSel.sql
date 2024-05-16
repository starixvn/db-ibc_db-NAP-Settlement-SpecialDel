/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SSBErrorMessageSel
	@MatchId INT = 0
	,@Mode VARCHAR(20) = 'single'
AS
/*
	Created by: 20211111@Kathy
	Task: Get all ssb error message [Redmine:#164162]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20211111@Kathy: Get all ssb error message [Redmine:#164162]
		- 20220913@Louisa: Get more info [RedmineId:#177711]
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]
		- 20230208@Louisa: get ErrorMessage by VARCHAR(max) [RedmineId:#179505]
		- 20240514@Kathy: parlay settlement [RedmineId:#204985]

	Param's Explanation:
		@Mode = 'single', 'parlay'

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @checktime DATETIME2
			,@ServerName VARCHAR(100)

	DECLARE @tmpErrorMessage TABLE (MatchId INT, SessionId BIGINT, ErrorMessage VARCHAR(max), CreatedTime DATETIME2 )

	SET @checktime = DATEADD(HOUR,-6,SYSDATETIME())
	SET @ServerName = @@SERVERNAME

	;WITH cteErrorMessage
	AS(
		SELECT	SessionId, MessageType, ErrorMessage, MIN(Starttime) AS CreatedTime, MAX(MatchId) AS MatchId
		FROM	dbo.SSB_SettlementLogs WITH(NOLOCK)
		WHERE	ISNULL(ErrorMessage,'') <> ''
				AND Resolved = 0
				AND StartTime > @checktime 
				AND SiteDBGroupId = 0
		GROUP BY SessionId
				,MessageType
				, ErrorMessage
	)
	INSERT INTO @tmpErrorMessage(SessionId, ErrorMessage, CreatedTime, MatchId )
	SELECT	c.SessionId
			,(SELECT s.ErrorMessage + ' \n ' FROM cteErrorMessage s WHERE s.SessionId = c.SessionId FOR XML PATH('')) AS ErrorMessage
			,MIN(c.CreatedTime)
			,MAX(MatchId) AS MatchId
	FROM	cteErrorMessage c
	WHERE	1 = CASE 
					WHEN @Mode = 'single' AND MessageType NOT LIKE 'parlaybet%' THEN 1
					WHEN @Mode = 'parlay' AND MessageType LIKE 'parlaybet%' THEN 1
					ELSE 0
				END
	GROUP BY c.SessionId

	IF @@ROWCOUNT > 0 AND @Mode = 'single'
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
			,st.SportName
			,t.ErrorMessage
			,CASE 
				WHEN @Mode = 'single' THEN s.TotalSettlementProcessing 
				WHEN @Mode = 'parlay' THEN p.TotalParlaySettlementProcessing 
				ELSE 0
			END AS TotalSettlementProcessing
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN @tmpErrorMessage t
			ON m.matchid = t.MatchId
		OUTER APPLY(
			SELECT	COUNT(1) AS TotalSettlementProcessing
			FROM	dbo.SettlementProcessing p WITH(NOLOCK)
			WHERE	p.SessionId = t.SessionId
					AND @Mode = 'single'
		)s
		OUTER APPLY(
			SELECT	COUNT(1) AS TotalParlaySettlementProcessing
			FROM	dbo.ParlaySettlementProcessing p WITH(NOLOCK)
			WHERE	p.SessionId = t.SessionId
					AND @Mode = 'parlay'
		)p
		INNER JOIN dbo.team h WITH(NOLOCK)
			ON h.teamid = m.homeid
		INNER JOIN dbo.team a WITH(NOLOCK)
			ON a.teamid = m.awayid
		INNER JOIN dbo.Sports st WITH(NOLOCK)
			ON st.SportType = m.sporttype
	
END
GO