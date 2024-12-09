/*<info serverAlias="DBPRO-bodb02 " executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		- 20220509@Kathy: Change to use STRING_SPLIT on DBPRO [Redmine:#172461]
		- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]
		
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
  
    CREATE TABLE #tblMatchID (MatchId VARCHAR(20), SportType INT, ResultTable TINYINT, ExternalResultTable TINYINT)

	INSERT INTO #tblMatchID (MatchId, SportType, ResultTable, ExternalResultTable)
	SELECT f.Value
		  ,m.sporttype
		  ,CASE WHEN m.sporttype = 8 THEN 2 ELSE r.ResultTable END AS ResultTable
		  ,CASE WHEN m.sporttype IN (1,8) OR ISNULL(r.IsAppliedSOP,0) = 1 THEN 0 -- not get data from ProviderExternalResultXX if sports applied S.O.P
				ELSE r.ExternalResultTable
				END
	FROM STRING_SPLIT(@matchidList, ',') f
		INNER JOIN Match m WITH(NOLOCK)
			ON m.matchid = f.value
		LEFT JOIN dbo.SettlementResultTableSetting r WITH(NOLOCK)
			ON r.Sporttype = m.SportType


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
		AND ISNULL(ex.IsLive,0) = 0

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
		AND ISNULL(ex.IsLive,0) = 0


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
			INNER JOIN #tblMatchID m 
				ON rs.MatchId = m.MatchId
    	WHERE m.ResultTable = 3
    		AND EXISTS (SELECT 1 
    					FROM dbo.f_Set_MajorRound(43) f 
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
