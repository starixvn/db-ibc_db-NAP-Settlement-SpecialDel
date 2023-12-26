/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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


	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @ResultTable				TINYINT = 0
			,@ExternalResultTable		TINYINT = 0
			
	DECLARE @Resource TABLE (ResourceId	VARCHAR(20), PRIMARY KEY (ResourceId))
	DECLARE @Result TABLE (MatchId INT, SourceId SMALLINT,ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),SettlementStatusID TINYINT, ResultStatusID TINYINT, CreateDate DATETIME)

	SELECT @ResultTable	= r.ResultTable 
		  ,@ExternalResultTable = r.ExternalResultTable 
	FROM dbo.SettlementResultTableSetting r (NOLOCK)
	WHERE r.Sporttype = @Sporttype

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
	END
	ELSE IF @ResultTable = 2
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetailOS AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)		
	END
	ELSE IF @ResultTable = 3
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetailES AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)	
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
		  ,m.ResultStatusID
		  ,m.SettlementStatusID
		  ,m.CreateDate
	FROM @Result AS m
		LEFT JOIN ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = m.SourceId

END
GO




