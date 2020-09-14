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
    ---------------------------------------------------------------------------------------------
    CREATE TABLE #tblMatchID (MatchId VARCHAR(20), SportType INT)

	INSERT INTO #tblMatchID (MatchId, SportType)
	SELECT f.Val , m.sporttype
	FROM dbo.f_SplitString(@matchidList, ',') f
		INNER JOIN Match m 
			ON m.matchid = f.val
	OPTION (maxrecursion 0)
	
	---- Settled score: ESport
    IF EXISTS (SELECT TOP 1 1 FROM #tblMatchID m WHERE m.SportType = 43)
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
    	WHERE MatchID IN (SELECT m.MatchId FROM #tblMatchID m WHERE SportType = 43)
    		AND EXISTS (SELECT 1 
    					FROM dbo.f_Set_MajorRound(43) f 
    					WHERE rs.ResourceID = f.ResourceID)
	END
	
	---- Settled score: Badminton AIO
	IF EXISTS ( SELECT TOP  1 1 FROM #tblMatchID m WHERE m.SportType = 9 )
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
    	WHERE MatchID IN (SELECT m.MatchId FROM #tblMatchID m WHERE SportType = 9)
    		AND EXISTS (SELECT 1 
    					FROM dbo.f_Set_MajorRound(9) f 
    					WHERE rs.ResourceID = f.ResourceID)
	END
	
	DELETE FROM #tblMatchID WHERE SportType in (43,9)
	
	---- Settled score: Exclude Tennis and ESports
	INSERT INTO @tmpResultDetail (Matchid, SourceId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID )
    	SELECT    rs.MatchId
				, 0
                , rs.ResourceId
                , rs.HomeValue
                , rs.AwayValue
                , rs.ResultStatusID
                , rs.SettlementStatusID
        FROM    dbo.[ResultDetail] rs WITH (NOLOCK) 
    	WHERE MatchID IN (SELECT m.MatchId FROM #tblMatchID m)
    		AND EXISTS (SELECT 1 
    					FROM #tblMatchID m
						CROSS APPLY dbo.f_Set_MajorRound(m.SportType) f	
    					WHERE rs.ResourceID = f.ResourceID)

	---- Reference Score (LSports): Tennis
	IF EXISTS ( SELECT TOP  1 1 FROM #tblMatchID m WHERE m.SportType = 5 )
	BEGIN		
		;WITH  cteLatestId
		AS(
			SELECT	ROW_NUMBER() OVER (PARTITION BY p.ResourceId, p.MatchId ORDER BY p.CreateDate DESC) AS rn
					,p.matchid
					,p.SourceId
					,p.ResourceId
					,p.HomeValue
					,p.AwayValue
			FROM	dbo.ProviderExternalResultDetailOS p WITH(NOLOCK)
			WHERE MatchID IN  (SELECT m.MatchId FROM #tblMatchID m WHERE SportType = 5 )
				AND  p.SourceId  = 25
		)
		INSERT INTO @tmpResultDetail ( Matchid, SourceId, SourceName, ResourceId, HomeValue, AwayValue )
		SELECT matchid		
				,25
				,'LSports'
				,ResourceId 
				,HomeValue 
				,AwayValue 
		FROM	cteLatestId
		WHERE	rn = 1

	END

	---- Reference Score (SBO): Soccer
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
	END
	
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