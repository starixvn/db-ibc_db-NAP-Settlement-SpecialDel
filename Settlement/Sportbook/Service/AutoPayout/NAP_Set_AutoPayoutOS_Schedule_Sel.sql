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
		- 20210915@Louisa: Checking invalid result of Virtual Cricket [Redmine:#161640]
		- 20211006@Louisa: Get results after 90 seconds - [Redmine:#162808]
		- 20211206@Louisa: Enhancemant [Redmine:#165659]
*/
BEGIN
	
	SET NOCOUNT ON

	DECLARE @checkTime DATETIME =  CAST( DATEADD(SECOND, -30, GETDATE() ) AS DATETIME)

	IF OBJECT_ID('tempdb..#MatchInfo') IS NOT NULL
	DROP TABLE #MatchInfo

	CREATE TABLE #MatchInfo (
		MatchId			INT
		,leagueid		INT
		,ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,StatusId		TINYINT
		,MinStatusId	TINYINT
	)

	INSERT INTO #MatchInfo  ( MatchId, leagueid, ResourceId, HomeValue,	AwayValue, StatusId, MinStatusId ) 
	SELECT m.matchid
			,m.leagueid
			, r.ResourceId
			, r.HomeValue
			, r.AwayValue
			, os.StatusId
			, MIN( ISNULL(os.StatusId,99)) OVER(PARTITION BY m.MatchId)	 AS MinStatusId
	FROM dbo.ResultDetailOS r WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON r.MatchID = m.matchid
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		OUTER APPLY (	SELECT os.MatchId, os.ResourceId,  os.StatusId
						FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
						WHERE os.MatchId = r.matchid
							AND os.ResourceId = r.ResourceID 
					) os			
	WHERE m.sporttype = @Sporttype
		AND ISNULL(m.AutoSetting,0) & 17 = 1	--Turn on bit[1] and turn off bit[5]
		AND l.LeagueGroupID = 42				--Virtual Cricket
	 	AND r.ResultStatusID = 3
		AND ISNULL(r.ResultSetting,0) & 1  = 0
		AND ISNULL(m.SettlementStatus,0) & 87 = 0
		AND 1 =  CASE WHEN ISNULL(r.HomeValue,'') = '' AND ISNULL(r.AwayValue,'') = '' THEN 0
				 ELSE 1 END
		AND r.CreateDate <= @checkTime

	SELECT m.matchid
		, m.leagueid
		, m.ResourceId
		, m.HomeValue
		, m.AwayValue
	FROM #MatchInfo m
	WHERE m.StatusId IS NULL	--- has not been Auto Settled
		AND m.MinStatusId <> 1	--- match not in process

END
GO



