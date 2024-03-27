/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayoutOS_ResultSel
	 @MatchId			INT
	,@SportType			SMALLINT
	,@ResourceIds		VARCHAR(MAX)
	
AS
/*
	Creator: 20231002@Aries
	Task: Apply Auto Payout for Cricket by using TheSports Provider  [Redmine: #195768]
	DB: DBPRO/bodb02
	Revisions:
		- 20231002@Aries: Created [Redmine:#195768]
		- 20231205@Aries: Get only provider [Redmine: #195768]
		- 20231222@Louisa: Allow retry AutoPayout Cricket when score mismatch [Redmine: #198781]
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]


	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @ResultTable				TINYINT = 0
			,@ExternalResultTable		TINYINT = 0
			,@GameType					TINYINT  = 0
			
	DECLARE @Resource TABLE (ResourceId	VARCHAR(20), PRIMARY KEY (ResourceId))
	DECLARE @Result TABLE (MatchId INT, SourceId SMALLINT,ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),SettlementStatusID TINYINT, ResultStatusID TINYINT, CreateDate DATETIME)

	SELECT @ResultTable	= r.ResultTable 
		  ,@ExternalResultTable = r.ExternalResultTable 
	FROM dbo.SettlementResultTableSetting r (NOLOCK)
	WHERE r.Sporttype = @Sporttype

	SELECT @GameType =  CASE WHEN m.Sporttype= 43 THEN l.OverTimeSession ELSE 0 END
	FROM match AS m WITH(NOLOCK)
		INNER JOIN League l WITH(NOLOCK) ON m.LeagueId = l.LeagueId	
	WHERE m.MatchId	 = @MatchId	

	INSERT INTO @Resource(ResourceId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ResourceIds,',')

	IF @ResultTable = 1
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetail AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)	
			AND rd.ResultStatusID = 3			
	END
	ELSE IF @ResultTable = 2
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetailOS AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)	
			AND rd.ResultStatusID = 3
	END
	ELSE IF @ResultTable = 3
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetailES AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)
			AND rd.ResultStatusID = 3
	END

	IF @ExternalResultTable = 1
	BEGIN
		WITH CTE_Provider AS (
			SELECT MAX(p.ProviderExternalId) AS ProviderExternalId
			FROM ProviderExternalResultDetail AS p WITH(NOLOCK)
			WHERE  p.matchId = @MatchId
				AND p.ResourceId IN (SELECT r.ResourceID FROM @Resource AS r)
				AND p.SourceID < 1001 
				AND p.SourceID NOT IN (98,99,100)
			GROUP BY p.matchId,p.SourceId,p.ResourceId
		)
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,SourceId, CreateDate)
		SELECT rd.matchId,rd.ResourceId,rd.HomeValue,rd.AwayValue,rd.SourceId, rd.CreateDate
		FROM CTE_Provider AS cte	
			INNER JOIN ProviderExternalResultDetail AS rd WITH(NOLOCK) ON rd.ProviderExternalId = cte.ProviderExternalId
	END
	ELSE IF @ExternalResultTable = 2
	BEGIN
		WITH CTE_Provider AS (
			SELECT MAX(p.ProviderExternalId) AS ProviderExternalId
			FROM ProviderExternalResultDetailOS AS p WITH(NOLOCK)
			WHERE  p.matchId = @MatchId
				AND p.ResourceId IN (SELECT r.ResourceID FROM @Resource AS r)
				AND p.SourceID < 1001 
				AND p.SourceID NOT IN (98,99,100)
			GROUP BY p.matchId,p.SourceId,p.ResourceId
		)
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,SourceId, CreateDate)
		SELECT rd.matchId,rd.ResourceId,rd.HomeValue,rd.AwayValue,rd.SourceId,rd.CreateDate
		FROM CTE_Provider AS cte	
			INNER JOIN ProviderExternalResultDetailOS AS rd WITH(NOLOCK) ON rd.ProviderExternalId = cte.ProviderExternalId
	END
	ELSE IF @ExternalResultTable = 3
	BEGIN
		WITH CTE_Provider AS (
			SELECT MAX(p.ProviderExternalId) AS ProviderExternalId
			FROM ProviderExternalResultDetailES AS p WITH(NOLOCK)
			WHERE  p.matchId = @MatchId
				AND p.ResourceId IN (SELECT r.ResourceID FROM @Resource AS r)
				AND p.SourceID < 1001 
				AND p.SourceID NOT IN (98,99,100)
			GROUP BY p.matchId,p.SourceId,p.ResourceId
		)
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,SourceId,CreateDate)
		SELECT rd.matchId,rd.ResourceId,rd.HomeValue,rd.AwayValue,rd.SourceId,rd.CreateDate
		FROM CTE_Provider AS cte	
			INNER JOIN ProviderExternalResultDetailES AS rd WITH(NOLOCK) ON rd.ProviderExternalId = cte.ProviderExternalId
	END

	SELECT m.matchId
		  ,m.SourceId
		  ,p.SourceName
		  ,m.ResourceId
		  ,m.HomeValue
		  ,m.AwayValue
		  ,m.CreateDate
		  ,ss.HasAwayValue
	FROM @Result AS m
		CROSS APPLY (SELECT TOP 1 HasAwayValue
				     FROM SettlementSpecialBettypeProfile AS s WITH(NOLOCK)
					 WHERE s.ResourceID = m.ResourceID
						AND s.SportType = @SportType
		) AS ss
		LEFT JOIN ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = m.SourceId
		OUTER APPLY (SELECT TOP 1 1 AS IsMapped
					 FROM dbo.ProviderGameTypeMapping AS p WITH(NOLOCK)
					 WHERE p.sporttype = @SportType
						AND p.SourceId = m.SourceID
						AND p.isActive = 1
						AND p.GameType = @GameType) AS pm
	WHERE pm.IsMapped IS NOT NULL
		OR m.SourceId IS NULL
		
END
GO




