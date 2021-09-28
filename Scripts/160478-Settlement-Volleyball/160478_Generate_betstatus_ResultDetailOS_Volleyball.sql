
/* 
	Created by: 20210922@Louisa
    Task: Settle by profile for Volleyball [Redmine:#160478]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210922@Louisa: Generate Result from betstatus to ResultDetailOS for Volleyball [Redmine:#160478]
*/

USE bodb02

GO

---------1. Prepare

	IF OBJECT_ID('tempdb..#tmpMatchVolleyball') IS NOT NULL
	DROP TABLE #tmpMatchVolleyball

	CREATE TABLE #tmpMatchVolleyball ( MatchId INT, eventstatus	NVARCHAR(100), betstatus NVARCHAR(100), finalhomescore INT, finalawayscore INT )

	IF OBJECT_ID('tempdb..#tmpBetStatus') IS NOT NULL
	DROP TABLE #tmpBetStatus

	CREATE TABLE #tmpBetStatus ( Id INT, charIdx INT, MatchId INT, val VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50)	)
	
	IF OBJECT_ID('tempdb..#tmpResultDetail') IS NOT NULL
	DROP TABLE #tmpResultDetail

	CREATE TABLE #tmpResultDetail ( MatchId INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultStatusID TINYINT, SettlementStatusID TINYINT	)
	
	-- match exists scores in table match
	INSERT INTO #tmpMatchVolleyball ( MatchId, eventstatus, betstatus, finalhomescore, finalawayscore )
	SELECT   m.MatchId,  m.eventstatus,  m.betstatus,  m.finalhomescore,  m.finalawayscore 
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.sporttype = 6 --Volleyball
		AND	( ISNULL(m.betstatus,'') <> ''  OR ISNULL(m.finalhomescore, '') <> '')

	-- Generate ResourceId 0101 ~ 0105 from betsatus
	INSERT INTO #tmpBetStatus ( Id, charIdx, MatchId, val )
	SELECT ROW_NUMBER() OVER(PARTITION BY MatchId ORDER BY MatchId )
			, CHARINDEX('-', val) 
			, m.MatchId 
			,f.val  
	FROM #tmpMatchVolleyball m
		CROSS APPLY ( SELECT val FROM dbo.f_SplitString( m.betstatus, ',') ) f
	WHERE ISNULL(m.betstatus,'') <> ''
		AND m.betstatus NOT LIKE '%Refund%'
	OPTION (MAXRECURSION 0)

	
	UPDATE #tmpBetStatus
	SET  HomeValue = CASE WHEN charIdx = 0 THEN ''		-- Prevent wrong data like betstatus = '0-0,1-0,,,2-1'
						  ELSE LEFT (val, charIdx-1) END 
		,AwayValue = CASE WHEN charIdx = 0 THEN '' 
						  ELSE RIGHT ( val , len(val)-charIdx ) END
		
	
	INSERT INTO #tmpResultDetail (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID )
	SELECT DISTINCT 
		 m.Matchid
		,'010' + CAST(b.Id AS VARCHAR(1) )
		, b.HomeValue
		, b.AwayValue
		, CASE  m.eventstatus WHEN 'running' THEN 3 --confirmed
							  ELSE 5				-- calculated
							  END AS ResultStatusID
		, CASE  m.eventstatus WHEN 'running' THEN 0 --running
							  ELSE 4				-- calculated
							  END AS SettlementStatusID
	FROM #tmpMatchVolleyball m
		INNER JOIN #tmpBetStatus b ON m.MatchId = b.MatchId

	---- Generate score Full Time
	UNION ALL
	SELECT 
		m.Matchid
		,'00' AS ResourceID
		, CAST( m.FinalHomeScore AS VARCHAR(50) )
		, CAST( m.FinalAwayScore AS VARCHAR(50) )
		, CASE  m.eventstatus WHEN 'running' THEN 3 --confirmed
							  ELSE 5				-- calculated
							  END AS ResultStatusID
		, CASE  m.eventstatus WHEN 'running' THEN 0 --running
							  ELSE CASE WHEN m.betstatus LIKE '%Refund%' THEN 1 --Refund All
										ELSE 4				-- calculated 
										END 
							  END AS SettlementStatusID
	FROM #tmpMatchVolleyball m
	WHERE ISNULL(m.finalhomescore,'') IS NOT NULL


---------2. INSERT INTO ResultDetailOS IF NOT EXISTS

	INSERT INTO dbo.ResultDetailOS
	(
		MatchID
		,ResourceID
		,HomeValue
		,AwayValue
		,ResultStatusID
		,SettlementStatusID
		,CreateBy
		,LastModifyBy
		,LastModifyDate
	)
	SELECT tmp.MatchID
		,tmp.ResourceID
		,tmp.HomeValue
		,tmp.AwayValue
		,tmp.ResultStatusID
		,tmp.SettlementStatusID
		,8 AS CreateBy
		,8 AS LastModifyBy
		,GETDATE() AS LastModifyDate
	FROM #tmpResultDetail tmp
		LEFT JOIN dbo.ResultDetailOS r WITH(NOLOCK)
			ON tmp.MatchId = r.MatchID
			AND tmp.ResourceId = r.ResourceID
	WHERE r.MatchID IS NULL

