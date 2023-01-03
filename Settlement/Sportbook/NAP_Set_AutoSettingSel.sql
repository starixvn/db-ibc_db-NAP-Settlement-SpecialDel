/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoSettingSel
	@LeagueId	INT = 0
	,@MatchId 	INT = 0
AS
/*	Creator: 20230110@Kathy
	Task: Auto setting
	DB: DBPRO/BODB02
	
	Revisions:
		- 20230103@Kathy: get auto setting of match/league [Redmine:#181718]    

*/
BEGIN
	SET NOCOUNT ON
	
	IF @MatchId <> 0
		SELECT	ISNULL(m.AutoSetting, l.AutoSetting) AS AutoSetting
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
		WHERE	m.matchid = @MatchId
	ELSE
		SELECT	l.AutoSetting
		FROM	dbo.League l WITH(NOLOCK)
		WHERE	l.leagueid = @LeagueId
	
END
GO