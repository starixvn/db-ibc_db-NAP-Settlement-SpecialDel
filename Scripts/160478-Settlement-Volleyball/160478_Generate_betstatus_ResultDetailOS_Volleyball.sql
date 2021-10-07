/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
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
		AND m.eventstatus = 'completed'

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
		, 5	AS ResultStatusID	-- calculated
		, 4	AS SettlementStatusID -- calculated
	FROM #tmpMatchVolleyball m
		INNER JOIN #tmpBetStatus b ON m.MatchId = b.MatchId

	---- Generate score Full Time
	UNION ALL
	SELECT 
		m.Matchid
		,'00' AS ResourceID
		, CAST( m.FinalHomeScore AS VARCHAR(50) )
		, CAST( m.FinalAwayScore AS VARCHAR(50) )
		, 5 AS ResultStatusID	-- calculated
		, CASE WHEN m.betstatus LIKE '%Refund%' THEN 1 --Refund All
				ELSE 4	-- calculated 
				END 
				AS SettlementStatusID
	FROM #tmpMatchVolleyball m
	WHERE ISNULL(m.finalhomescore,'') IS NOT NULL


---------2. INSERT INTO ResultDetailOS IF NOT EXISTS
	BEGIN

		MERGE dbo.ResultDetailOS TARGET
			USING (
					SELECT  MatchID
							,ResourceID
							,HomeValue
							,AwayValue
							,ResultStatusID
							,SettlementStatusID
					FROM    #tmpResultDetail sr
					) AS SOURCE 
					 ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = SOURCE.MatchId
	   
			WHEN MATCHED THEN
				UPDATE SET HomeValue     = SOURCE.HomeValue
					,AwayValue           = SOURCE.AwayValue
					,ResultStatusID      = SOURCE.ResultStatusID
					,SettlementStatusID  = SOURCE.SettlementStatusID
					,LastModifyDate      = GETDATE()
					,LastModifyBy        = 8
	
			WHEN NOT MATCHED BY TARGET THEN
				INSERT 
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
				VALUES(	SOURCE.MatchID
						,SOURCE.ResourceID
						,SOURCE.HomeValue
						,SOURCE.AwayValue
						,SOURCE.ResultStatusID
						,SOURCE.SettlementStatusID
						,8
						,8
						,GETDATE()
						);

---------3. UPDATE wrong data from ResultDetailOS
		UPDATE r
		SET ResultStatusID = 5	-- calculated
			,SettlementStatusID = 1 --Refund All 
		FROM dbo.ResultDetailOS r
			INNER JOIN #tmpMatchVolleyball m ON r.MatchID = m.MatchID
		WHERE m.betstatus LIKE '%Refund%'


		END



