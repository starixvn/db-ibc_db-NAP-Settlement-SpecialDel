/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ProviderExternalResultDetailESLatestInfoSel
	@MatchId INT
AS
/*
    Created by: 20200721@Kathy
    Task: get provider result [Redmine:#136931]
    DB: DBPRO/BODB02  
    
    Revisions:            
		- 20200721@Kathy: get provider result [Redmine:#136931]
		- 20200810@Louisa: get OutsideSource result [Redmine:#138656]

	Param's Explanation:
		If not exists SourceId = 1001 ==> Add dummy values
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT
	DECLARE @LeagueId INT
	DECLARE @GameType TINYINT

	DECLARE @tmpLatestResult AS TABLE (ProviderExternalId INT)
	DECLARE @tmpProviderExternalResult AS TABLE (SourceId INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OrderNo INT)

	SET @SportType = 43

	SELECT @LeagueId = m.LeagueId FROM dbo.Match m WITH(NOLOCK) WHERE m.MatchId = @MatchId
	SELECT @GameType = l.OverTimeSession FROM dbo.League l WITH(NOLOCK) WHERE l.leagueid = @LeagueId
	
	;WITH cteLatestId
	AS(
		SELECT	ROW_NUMBER() OVER (PARTITION BY p.SourceId, p.ResourceId ORDER BY p.CreateDate DESC) AS rn
				,p.ProviderExternalId
		FROM	dbo.ProviderExternalResultDetailES p WITH(NOLOCK)
		WHERE	p.MatchId = @MatchId
	)
	INSERT INTO @tmpLatestResult (ProviderExternalId)
	SELECT ProviderExternalId
	FROM cteLatestId
	WHERE rn = 1

	;WITH cteSourceId (SourceId, OrderNo)
	AS(
		SELECT  pgm.SourceId, ISNULL(plmo.OrderNo, pgm.OrderNo) AS OrderNo
		FROM  ProviderGameTypeMapping pgm WITH(NOLOCK)
		OUTER APPLY(
					SELECT plmo.OrderNo, plmo.PGId FROM ProviderLeagueMappingOutsideSource plmo WITH(NOLOCK)
					WHERE plmo.PGId = pgm.PGId AND plmo.LeagueId  = @LeagueId
					) plmo
		WHERE (pgm.SourceId <= 1001 OR  plmo.PGId  IS NOT NULL) 
			AND GameType = @GameType
			AND pgm.isActive = 1
	)

	INSERT INTO @tmpProviderExternalResult(SourceId, ResourceId, HomeValue, AwayValue, OrderNo)
	SELECT	perde.SourceId, perde.ResourceId, perde.HomeValue, perde.AwayValue, ct.OrderNo
	FROM	@tmpLatestResult l
		INNER JOIN dbo.ProviderExternalResultDetailES perde WITH(NOLOCK)
			ON l.ProviderExternalId = perde.ProviderExternalId
		INNER JOIN cteSourceId ct 
			ON ct.SourceId = perde.SourceId

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpProviderExternalResult per WHERE per.SourceId = 1001)
		BEGIN
			INSERT INTO @tmpProviderExternalResult (SourceId, ResourceId, HomeValue, AwayValue, OrderNo)
			VALUES (1001,'M1','','', 1)
		END
			
	SELECT	t.SourceId
			,pi.SourceName
			,pi.Remark
			,t.ResourceId
			,t.HomeValue
			,t.AwayValue
			,t.OrderNo
	FROM	@tmpProviderExternalResult t
		INNER JOIN dbo.f_Set_MajorRound(@SportType) fsmr
			ON t.ResourceId = fsmr.ResourceId
		INNER JOIN ProviderInfo pi 
			ON t.SourceId = pi.SourceId
END
GO