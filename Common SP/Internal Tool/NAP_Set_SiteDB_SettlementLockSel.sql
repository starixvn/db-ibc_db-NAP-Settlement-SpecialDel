/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SettlementLockSel
	@MatchId INT = 0
AS
/*
	Created by: 20221122@Louisa
	Task: Tool support after release Scaleout [RedmineId:#180746]
	DB: DBCTG-bodb02,SBSETTLE-bodb02
	
	Revisions:
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @checkLocktime DATETIME2
			,@ServerName VARCHAR(100) 

	SET @checkLocktime = DATEADD(MINUTE,-3,SYSDATETIME())
	SET @ServerName = @@SERVERNAME

	SELECT	@ServerName AS ServerName
			,l.MatchId 
			,l.SessionId 
			,l.SiteDBGroupId
			,h.teamname AS HomeTeam
			,a.teamname AS AwayTeam
	FROM	dbo.SiteDB_SettlementLock l WITH(NOLOCK)
		INNER JOIN 	dbo.match m WITH(NOLOCK)
			ON l.matchid = m.matchid
		INNER JOIN dbo.team h WITH(NOLOCK)
			ON h.teamid = m.homeid
		INNER JOIN dbo.team a WITH(NOLOCK)
			ON a.teamid = m.awayid
	WHERE	l.MatchId = CASE WHEN ISNULL(@MatchId,0) = 0 THEN l.MatchId ELSE @MatchId END
		AND l.CreatedTime <= @checkLocktime
END
GO