/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoPayoutOS_Schedule_Sel
	@Sporttype SMALLINT = 0
AS
/*
	Creator: 20210729@Louisa
	Task: Auto Settle Cricket [Redmine:#154586]
	DB: DBPRO/bodb02
	Revisions:
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]

*/
BEGIN
	
	SET NOCOUNT ON

	IF OBJECT_ID('tempdb..#MatchInfo') IS NOT NULL
	DROP TABLE #MatchInfo

	CREATE TABLE #MatchInfo (
		MatchId		INT
		,ResourceId	VARCHAR(20)
		,HomeValue	VARCHAR(50)
		,AwayValue	VARCHAR(50)
		,StatusId	TINYINT
	)

	INSERT INTO #MatchInfo  ( MatchId	,ResourceId	,HomeValue	,AwayValue	,StatusId	) 
	SELECT m.matchid
			, r.ResourceId
			, r.HomeValue
			, r.AwayValue
			, os.StatusId
	FROM dbo.ResultDetailOS r WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON r.MatchID = m.matchid
		INNER JOIn dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		OUTER APPLY (	SELECT os.MatchId, ISNULL( os.StatusId , 2) AS StatusId
						FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
						WHERE os.MatchId = r.matchid
							AND os.ResourceId = r.ResourceID 
					) os			
	WHERE m.sporttype = 50 --Cricket
		AND ISNULL(m.AutoSetting,0) & 1 = 1
		AND ISNULL(m.AutoSetting,0) & 16 = 0
		AND l.LeagueGroupID = 42 --Virtual Cricket
	 	AND r.ResultStatusID = 3
		AND ISNULL(r.ResultSetting,0) & 1  = 0
		AND ISNULL(m.SettlementStatus,0) & 87 = 0



	DELETE
	FROM #MatchInfo
	WHERE StatusId IS NOT NULL

	SELECT m.matchid
		, m.ResourceId
		, m.HomeValue
		, m.AwayValue
	FROM #MatchInfo m

END
GO



