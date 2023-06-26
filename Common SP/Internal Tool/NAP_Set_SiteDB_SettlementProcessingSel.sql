/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SettlementProcessingSel
	@matchId INT = 0
AS
/*
	Created by: 20221122@Louisa
	Task: Tool support after release Scaleout [RedmineId:#180746]
	DB: DBCTG-bodb02,SBSETTLE-bodb02
	
	Revisions:
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]
		- 20230208@Louisa: support queue 3rd [RedmineId:#179505]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @checktime DATETIME2
			,@ServerName VARCHAR(100)

	DECLARE @tmpSSB_SettlementLogs TABLE ( SessionId BIGINT, ErrorMessage VARCHAR(max), CreatedTime DATETIME2, SiteDBGroupId SMALLINT )

	SET @checktime = DATEADD(HOUR,-6,SYSDATETIME())
	SET @ServerName = @@SERVERNAME

	;WITH cteErrorMessage
	AS(
		SELECT	SessionId, ErrorMessage, Starttime, SiteDBGroupId
		FROM	dbo.SSB_SettlementLogs WITH(NOLOCK)
		WHERE	ISNULL(ErrorMessage,'') <> ''
				AND Resolved = 0
				AND SessionId > 0
				AND StartTime > @checktime 
				AND SiteDBGroupId > 0
	)
	
	INSERT INTO @tmpSSB_SettlementLogs ( SessionId, ErrorMessage, CreatedTime, SiteDBGroupId)
	SELECT	l.SessionId
			,(SELECT s.ErrorMessage + ' \n ' FROM cteErrorMessage s WHERE s.SessionId = l.SessionId FOR XML PATH('')) AS ErrorMessage	
			,MIN(l.Starttime) AS CreatedTime
			,ISNULL(l.SiteDBGroupId,0) AS SiteDBGroupId
	FROM	dbo.SSB_SettlementLogs l WITH(NOLOCK)
	WHERE	ISNULL(l.ErrorMessage,'') <> ''
				AND l.Resolved = 0
				AND l.SessionId > 0
				AND l.StartTime > @checktime 
				AND SiteDBGroupId > 0	
	GROUP BY SessionId
			,SiteDBGroupId

	SELECT	DISTINCT @ServerName AS ServerName
			,t.SiteDBGroupId
			,b.matchId
			,t.SessionId
			,b.HomeTeam 
			,b.AwayTeam 
			,t.CreatedTime
			,t.ErrorMessage
	FROM	@tmpSSB_SettlementLogs t
		INNER JOIN dbo.SiteDB_SettlementProcessing p WITH(NOLOCK)
			ON	t.SessionId = p.SessionId
				AND t.SiteDBGroupId = p.SiteDBGroupId
		CROSS APPLY (
						SELECT	 TOP 1 
								b.matchid
								,h.teamname AS HomeTeam
								,a.teamname AS AwayTeam
						FROM OPENJSON (CAST(DECOMPRESS(TransInfo) AS NVARCHAR(MAX) ) ) WITH( t  VARCHAR(20) ) 
							INNER JOIN dbo.bettrans b WITH(NOLOCK)
								ON b.transid = t
							INNER JOIN dbo.match m WITH(NOLOCK)
								ON m.matchid = b.matchid
							INNER JOIN dbo.team h WITH(NOLOCK)
								ON h.teamid = m.homeid
							INNER JOIN dbo.team a WITH(NOLOCK)
								ON a.teamid = m.awayid
						WHERE  @matchid = 0 OR b.matchid = @matchid
						)  AS b
	WHERE p.StatusId IN ( 1, 3)
	
END
GO