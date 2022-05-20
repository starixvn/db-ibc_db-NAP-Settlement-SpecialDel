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
		- 20220512@Kathy: Improve performance [Redmine:#172386]
		- 20220512@Louisa: Auto settle for Badminton [Redmine:#171676]
*/
BEGIN
	
	SET NOCOUNT ON

	IF @Sporttype NOT IN ( 6, 9, 50 )
	RETURN

	DECLARE @checkTime DATETIME =  CAST( DATEADD(SECOND, -30, GETDATE() ) AS DATETIME)
			,@n INT
			,@ExternalResultTable TINYINT = 0

	DECLARE @tmpLatestResult TABLE (matchid INT, leagueid INT, SettlementStatus INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) , Ranking INT , IsFinal BIT )
	SET @n = 2147483647


	SELECT @ExternalResultTable = r.ExternalResultTable 
	FROM dbo.SettlementResultTableSetting r (NOLOCK)
	WHERE r.Sporttype = @Sporttype

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
	)


	IF @Sporttype =  50
	BEGIN
		INSERT INTO #MatchInfo  ( MatchId, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue)
		SELECT m.matchid
				, m.leagueid
				, m.SettlementStatus
				, r.ResourceId
				, r.HomeValue
				, r.AwayValue
		FROM dbo.match m WITH(NOLOCK)
			CROSS APPLY (
				SELECT TOP (@n) r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
				FROM	dbo.ResultDetailOS r WITH(NOLOCK)
				WHERE	r.MatchID = m.matchid
						AND r.ResultStatusID = 3
						AND ISNULL(r.ResultSetting,0) & 1  = 0
						AND 1 =  CASE WHEN ISNULL(r.HomeValue,'') = '' AND ISNULL(r.AwayValue,'') = '' THEN 0 ELSE 1 END
						AND r.CreateDate <= @checkTime
			) r
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			OUTER APPLY (	SELECT os.MatchId, os.ResourceId,  MIN(os.StatusId) AS MinStatusId
							FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
							WHERE os.MatchId = r.matchid
								AND os.ResourceId = r.ResourceID 
							GROUP BY os.MatchId, os.ResourceId
						) os			
		WHERE m.sporttype = @Sporttype
			AND ISNULL(m.AutoSetting,0) & 17 = 1	--Turn on bit[1] and turn off bit[5]
			AND l.LeagueGroupID = 42				--Virtual Cricket
			AND ISNULL(m.SettlementStatus,0) & 87 = 0
			AND os.MinStatusId IS NULL -- ResourceId has never been run before
			
	END

	ELSE
	BEGIN	
		IF @ExternalResultTable  = 1
		BEGIN
			INSERT INTO @tmpLatestResult (  matchid, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue, Ranking, IsFinal )
			SELECT m.matchid, m.leagueid, m.SettlementStatus, r.ResourceId, r.HomeValue, r.AwayValue
					,ROW_NUMBER() OVER(PARTITION BY r.MatchId, r.ResourceId ORDER BY r.CreateDate DESC) AS Ranking
					,MAX(CASE WHEN r.ResourceId = '00' THEN 1 ELSE 0 END ) OVER(PARTITION BY r.MatchId ) AS IsFinal
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
				INNER JOIN dbo.ProviderExternalResultDetail r WITH(NOLOCK)
					ON m.matchid = r.MatchId				
			WHERE m.sporttype = @Sporttype
				AND ISNULL(m.AutoSetting,0) & 17 = 1 ---Turn on bit[1] and turn off bit[5]
				AND m.eventstatus = 'running'
				AND ISNULL(m.IsDeleted,0) = 0
				AND r.SourceId = 1 --SBO
		END

		IF @ExternalResultTable = 2
		BEGIN
			INSERT INTO @tmpLatestResult (  matchid, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue, Ranking, IsFinal )
			SELECT m.matchid, m.leagueid, m.SettlementStatus, r.ResourceId, r.HomeValue, r.AwayValue
					,ROW_NUMBER() OVER(PARTITION BY r.MatchId, r.ResourceId ORDER BY r.CreateDate DESC) AS Ranking
					,MAX(CASE WHEN r.ResourceId = '00' THEN 1 ELSE 0 END ) OVER(PARTITION BY r.MatchId ) AS IsFinal
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
				INNER JOIN dbo.ProviderExternalResultDetailOS r WITH(NOLOCK)
					ON m.matchid = r.MatchId				
			WHERE m.sporttype = @Sporttype
				AND ISNULL(m.AutoSetting,0) & 17 = 1 ---Turn on bit[1] and turn off bit[5]
				AND m.eventstatus = 'running'
				AND ISNULL(m.IsDeleted,0) = 0
				AND r.SourceId = 1 --SBO
		END

		INSERT INTO #MatchInfo ( matchid, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue)
		SELECT r.matchid, r.leagueid, r.SettlementStatus, r.ResourceId, r.HomeValue, r.AwayValue				
		FROM @tmpLatestResult r
			OUTER APPLY (	SELECT TOP 1 os.MatchId
							FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
							WHERE os.MatchId = r.matchid			
						) os				
		WHERE Ranking = 1 --Latest
			AND r.IsFinal = 1 --exist FT
			AND os.MatchId IS NULL --not yet run Auto

	END

	SELECT matchid
		, @Sporttype AS sporttype
		, leagueid
		, SettlementStatus
		, ResourceId
		, HomeValue
		, AwayValue
	FROM #MatchInfo m

END
GO


 