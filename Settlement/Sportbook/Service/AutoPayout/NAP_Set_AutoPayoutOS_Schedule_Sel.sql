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
		- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
*/
BEGIN
	
	SET NOCOUNT ON

	DECLARE @checkTime DATETIME =  CAST( DATEADD(SECOND, -30, GETDATE() ) AS DATETIME)

	IF OBJECT_ID('tempdb..#MatchInfo') IS NOT NULL
	DROP TABLE #MatchInfo

	CREATE TABLE #MatchInfo (
		MatchId			INT
		,leagueid		INT
		,SettlementStatus TINYINT
		,ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,StatusId		TINYINT
		,Ranking		INT
		,IsFinal BIT
	)


	IF @Sporttype =  50
	BEGIN
		INSERT INTO #MatchInfo  ( MatchId, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue, StatusId, Ranking ) 
		SELECT m.matchid
				, m.leagueid
				, m.SettlementStatus
				, r.ResourceId
				, r.HomeValue
				, r.AwayValue
				, os.StatusId
				, MIN( ISNULL(os.StatusId,99)) OVER(PARTITION BY m.MatchId)	 AS Ranking
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
	
		DELETE FROM #MatchInfo 
		WHERE StatusId IS NOT NULL  -- ResourceId already Auto Payout
			AND Ranking = 1			-- match is in progress

	END

	ELSE IF @Sporttype = 6
	BEGIN

		INSERT INTO #MatchInfo ( matchid, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue, Ranking, IsFinal )
		SELECT m.matchid, m.leagueid, m.SettlementStatus, r.ResourceId, r.HomeValue, r.AwayValue
				,ROW_NUMBER() OVER(PARTITION BY r.MatchId, r.ResourceId ORDER BY r.CreateDate DESC) AS Ranking
				,MAX(CASE WHEN r.ResourceId = '00' THEN 1 ELSE 0 END ) OVER(PARTITION BY r.MatchId ) AS IsFinal
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			INNER JOIN dbo.ProviderExternalResultDetail r WITH(NOLOCK)
				ON m.matchid = r.MatchId
			OUTER APPLY (	SELECT TOP 1 os.MatchId
							FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
							WHERE os.MatchId = m.matchid
								
						) os				
		WHERE m.sporttype = @Sporttype
			AND ISNULL(m.AutoSetting,0) & 17 = 1 ----Turn on bit[1] and turn off bit[5]
			AND ( ISNULL(m.ChildMatchType, 0 ) = 0 OR  ISNULL(m.ChildMatchType, 0 ) = 100 ) --exclude child match, allow hedge match
			AND m.eventstatus = 'running'
			AND ISNULL(l.IsDeleted,0) = 0
			AND ISNULL(m.IsDeleted,0) = 0
			AND r.SourceId = 1 --SBO
			AND os.MatchId IS NULL

		DELETE FROM #MatchInfo
		WHERE Ranking > 1
			OR IsFinal = 0

	END

	SELECT matchid
		, leagueid
		, SettlementStatus
		, ResourceId
		, HomeValue
		, AwayValue
	FROM #MatchInfo m

END
GO


 