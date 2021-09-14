/*<info serverAlias="DBPRO-bodb02 " executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ResultDetailSel]
	@matchidList 		   VARCHAR(MAX)
AS
/*
    Created by: 20200827@Louisa
    Task: get Result
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200827@Louisa: get Result [Redmine:#139979]
		- 20200914@Louisa: Return result for multisports [Redmine:#139979]
		- 20201202@Louisa: Integrate with SBO for 8 sports:3,4,6,8,9,18,24,25 [Redmine:#146239]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192] 
		- 20210906@Louisa: Settle by profile for Volleyball, Squash, Sepak Takraw [Redmine:#160478]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpResultDetail TABLE 
	(
		Matchid		INT
		,SourceId	SMALLINT
		,SourceName	varchar(50)
		,ResourceId VARCHAR(20)
		,HomeValue	VARCHAR(50)
		,AwayValue  VARCHAR(50)
		,ResultStatusID TINYINT
		,SettlementStatusID TINYINT
	)

	--- Generate ResultDetail from Betsatus
	DECLARE @tmpBetStatus TABLE 
	(	
		Id			INT
		,charIdx	INT 
		,MatchId	INT
		,val		VARCHAR(20)
		,HomeValue  VARCHAR(20)
		,AwayValue  VARCHAR(20)
	)
	 
    CREATE TABLE #tblMatchID 
	(	MatchId				VARCHAR(20)
		,SportType			INT
		,ResultTable		TINYINT
		,ExternalResultTable TINYINT
		,betstatus			NVARCHAR(100)
		,FinalHomeScore	INT
		,FinalAwayScore	INT
	)

	DECLARE @tmpExternalResult TABLE 
	(
		 rn			 INT
		,TopSourceId SMALLINT
		,Matchid	 INT
		,SourceId	 SMALLINT
		,ResourceId  VARCHAR(20)
		,HomeValue	 VARCHAR(50)
		,AwayValue   VARCHAR(50)
	)

	INSERT INTO #tblMatchID (MatchId, SportType, ResultTable, ExternalResultTable)
	SELECT f.Val
		  ,m.sporttype
		  ,r.ResultTable
		  ,CASE WHEN m.sporttype =  1 OR ISNULL(r.IsAppliedSOP,0) = 1THEN 0 -- not get data from ProviderExternalResultXX if sports applied S.O.P
				ELSE r.ExternalResultTable
				END
	FROM dbo.f_SplitString(@matchidList, ',') f
		INNER JOIN Match m WITH(NOLOCK)
			ON m.matchid = f.val
	LEFT JOIN dbo.SettlementResultTableSetting r WITH(NOLOCK)
		ON r.Sporttype = m.SportType
	OPTION (maxrecursion 0)


	------  GET EXTERNAL Result
	
	IF EXISTS( SELECT TOP 1 1 FROM #tblMatchID m WHERE ExternalResultTable = 1 ) ---ProviderExternalResultDetail
	INSERT INTO @tmpExternalResult ( rn, TopSourceId, Matchid, SourceId, ResourceId, HomeValue, AwayValue  )
	SELECT	ROW_NUMBER() OVER (PARTITION BY ex.MatchId, ex.ResourceId ORDER BY ex.SourceId, ex.CreateDate DESC ) AS rn
			,DENSE_RANK() OVER (PARTITION BY ex.MatchId ORDER BY ex.SourceId ) AS TopSourceId
			,ex.matchid
			,ex.SourceId
			,ex.ResourceId
			,ex.HomeValue
			,ex.AwayValue
	FROM	dbo.ProviderExternalResultDetail ex WITH(NOLOCK)
		INNER JOIN #tblMatchID m 
			ON ex.MatchId = m.MatchId
	WHERE ExternalResultTable = 1

	IF EXISTS( SELECT TOP 1 1 FROM #tblMatchID m WHERE ExternalResultTable = 2  ) ---ProviderExternalResultDetailOS
	INSERT INTO @tmpExternalResult ( rn, TopSourceId, Matchid, SourceId, ResourceId, HomeValue, AwayValue  )
	SELECT	ROW_NUMBER() OVER (PARTITION BY ex.MatchId, ex.ResourceId ORDER BY ex.SourceId, ex.CreateDate DESC ) AS rn
			,DENSE_RANK() OVER (PARTITION BY ex.MatchId ORDER BY ex.SourceId ) AS TopSourceId
			,ex.matchid
			,ex.SourceId
			,ex.ResourceId
			,ex.HomeValue
			,ex.AwayValue
	FROM	dbo.ProviderExternalResultDetailOS ex WITH(NOLOCK)
		INNER JOIN #tblMatchID m 
			ON ex.MatchId = m.MatchId
	WHERE ExternalResultTable = 2


	INSERT INTO @tmpResultDetail ( Matchid, SourceId, SourceName, ResourceId, HomeValue, AwayValue )
	SELECT  ex.matchid		
			,ex.SourceId
			,p.SourceName
			,ex.ResourceId 
			,ex.HomeValue 
			,ex.AwayValue 
	FROM	@tmpExternalResult ex
		INNER JOIN dbo.ProviderInfo p WITH(NOLOCK)
			ON ex.SourceId = p.SourceId
	WHERE	ex.rn = 1
		AND ex.TopSourceId = 1

	---- (SBO): Soccer
	IF EXISTS (SELECT TOP 1 1 FROM #tblMatchID m WHERE m.SportType = 1 )
	BEGIN
		;WITH  cteLatestSBO
		AS(
			SELECT	ROW_NUMBER() OVER (PARTITION BY r.MatchId, r.SourceId, r.TypeId ORDER BY r.CreatedDate DESC) AS rn
					,r.matchid
					,r.TypeId
					,r.HomeValue
					,r.AwayValue
			FROM bodb02.dbo.ProviderResultDetail r WITH(NOLOCK)
			WHERE MatchID IN  (SELECT m.MatchId FROM #tblMatchID m WHERE SportType = 1 )
				AND  r.SourceId  = 1
				AND r.TypeId IN (1,2)
		)

		INSERT INTO @tmpResultDetail (Matchid, SourceId, SourceName, ResourceId, HomeValue, AwayValue)
		SELECT l.MatchId
			,1
			,'SBO'
			,CASE l.TypeId 
				WHEN 1 THEN '01'
				WHEN 2 THEN '00'
			END
			,l.HomeValue
			,l.AwayValue
		FROM cteLatestSBO l
		WHERE	rn = 1
	END

	------/END  GET EXTERNAL Result

	------ GET Settled Result

	IF EXISTS ( SELECT TOP  1 1 FROM #tblMatchID m WHERE m.ResultTable = 1 )
	BEGIN
		INSERT INTO @tmpResultDetail (Matchid, SourceId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID )
    		SELECT    rs.MatchId
					, 0
					, rs.ResourceId
					, rs.HomeValue
					, rs.AwayValue
					, rs.ResultStatusID
					, rs.SettlementStatusID
			FROM    dbo.[ResultDetail] rs WITH (NOLOCK)
				INNER JOIN #tblMatchID m 
					ON rs.MatchId = m.MatchId  
    		WHERE m.ResultTable = 1
    			AND EXISTS (SELECT 1 
    						FROM #tblMatchID m
							CROSS APPLY dbo.f_Set_MajorRound(m.SportType) f	
    						WHERE rs.ResourceID = f.ResourceID)
	END

	IF EXISTS ( SELECT TOP  1 1 FROM #tblMatchID m WHERE m.ResultTable = 2 )
    BEGIN		
		INSERT INTO @tmpResultDetail (Matchid, SourceId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID )
        SELECT    rs.MatchId
				, 0
                , rs.ResourceId
                , rs.HomeValue
                , rs.AwayValue
                , rs.ResultStatusID
                , rs.SettlementStatusID
        FROM    dbo.[ResultDetailOS] rs WITH (NOLOCK)
			INNER JOIN #tblMatchID m 
				ON rs.MatchId = m.MatchId 
    	WHERE m.ResultTable = 2
    		AND EXISTS (SELECT 1 
    					FROM #tblMatchID m
						CROSS APPLY dbo.f_Set_MajorRound(m.SportType) f	
    					WHERE rs.ResourceID = f.ResourceID)
		
		IF EXISTS (	SELECT TOP 1 1 FROM #tblMatchID m WHERE sporttype IN ( 6, 30, 48 ) )
		BEGIN
			INSERT INTO @tmpBetStatus ( Id, charIdx, MatchId, val )
			SELECT ROW_NUMBER() OVER(PARTITION BY MatchId ORDER BY MatchId )
					, CHARINDEX('-', val) 
					, m.MatchId 
					,f.val  
			FROM #tblMatchID m
				CROSS APPLY ( SELECT val FROM dbo.f_SplitString( m.betstatus, ',') ) f 
			WHERE m.SportType IN ( 6, 30, 48 )
				AND ISNULL(m.betstatus,'') <> ''
				AND m.betstatus NOT LIKE '%Refund%' 
				AND m.FinalAwayScore IS NOT NULL
				AND NOT EXISTS( SELECT TOP 1 r.MatchId FROM @tmpResultDetail r 
								WHERE r.Matchid = m.MatchId
								AND r.SourceId = 0
								AND r.HomeValue IS NOT NULL
								)
			OPTION (MAXRECURSION 0)

			UPDATE @tmpBetStatus
			SET  HomeValue = CASE WHEN charIdx = 0 THEN '' ELSE LEFT (val, charIdx-1) END
			,AwayValue = CASE WHEN charIdx = 0 THEN '' ELSE RIGHT ( val , len(val)-charIdx ) END

			INSERT INTO @tmpResultDetail (Matchid, SourceId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID )
			SELECT DISTINCT m.Matchid
				, 0
				,CASE WHEN ISNULL(charIdx,0) = 0 THEN NULL
						ELSE '010' + CAST(tmp.Id AS VARCHAR(1) )		
						END AS ResourceID
				, tmp.HomeValue
				, tmp.AwayValue
				, NULL AS ResultStatusID
				, NULL AS SettlementStatusID
			FROM #tblMatchID m
				INNER JOIN @tmpBetStatus tmp ON m.MatchId = tmp.MatchId
			WHERE tmp.Id <=5

			UNION ALL
			SELECT DISTINCT m.Matchid
				, 0
				,'00' AS ResourceID
				, m.FinalHomeScore
				, m.FinalAwayScore
				, NULL AS ResultStatusID
				, NULL AS SettlementStatusID
			FROM #tblMatchID m
			WHERE m.SportType IN ( 6, 30, 48 )
				AND m.FinalHomeScore IS NOT NULL
				AND NOT EXISTS( SELECT TOP 1 r.MatchId FROM @tmpResultDetail r 
								WHERE r.Matchid = m.MatchId
								AND r.ResourceId = 0
								AND r.SourceId = 0
								AND r.HomeValue IS NOT NULL
								)

		END
	END

    IF EXISTS (SELECT TOP 1 1 FROM #tblMatchID m WHERE m.ResultTable = 3)
    BEGIN
		INSERT INTO @tmpResultDetail (Matchid, SourceId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID )
        SELECT    rs.MatchId
				, 0
                , rs.ResourceId
                , rs.HomeValue
                , rs.AwayValue
                , rs.ResultStatusID
                , rs.SettlementStatusID
        FROM    dbo.[ResultDetailES] rs WITH (NOLOCK)
    		INNER JOIN #tblMatchID m ON rs.MatchID = m.MatchId
    	WHERE m.ResultTable = 3
    		AND EXISTS (SELECT 1 
    					FROM #tblMatchID m
						CROSS APPLY dbo.f_Set_MajorRound(m.SportType) f	
    					WHERE rs.ResourceID = f.ResourceID)
	END
	
	------/END  GET Settled Result

	DROP TABLE #tblMatchID

	SELECT 
		Matchid		
		,SourceId	
		,SourceName	
		,ResourceId 
		,HomeValue	
		,AwayValue
		,ResultStatusID
		,SettlementStatusID
	FROM @tmpResultDetail ORDER BY MatchID, SourceId, ResourceId

END