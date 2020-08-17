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
		If not exist score for Top 4 OutsideSource: HomeValue=AwayValue=''
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT
	DECLARE @LeagueId INT
	DECLARE @GameType TINYINT

	DECLARE @tmpLatestResult AS TABLE (ProviderExternalId INT)
	DECLARE @tmpProviderExternalResult AS TABLE (SourceId INT,SourceName varchar(50) ,Remark nvarchar(1000), ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OrderNo INT)

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

	;WITH cteSourceId (SourceId,SourceName, Remark, OrderNo)
	AS(
		SELECT  pgm.SourceId, pi.SourceName, pi.Remark, ISNULL(plmo.OrderNo, pgm.OrderNo) AS OrderNo
		FROM  ProviderGameTypeMapping pgm WITH(NOLOCK)
		OUTER APPLY(
					SELECT plmo.OrderNo, plmo.PGId FROM ProviderLeagueMappingOutsideSource plmo WITH(NOLOCK)
					WHERE plmo.PGId = pgm.PGId AND plmo.LeagueId  = @LeagueId
					) plmo
		INNER JOIN ProviderInfo pi 
			ON pgm.SourceId = pi.SourceId
		WHERE (pgm.SourceId <= 1001 OR  plmo.PGId  IS NOT NULL) 
			AND GameType = @GameType
			AND pi.isActive = 1
			AND pgm.isActive = 1
	)

	INSERT INTO @tmpProviderExternalResult(SourceId,SourceName, Remark, ResourceId, HomeValue, AwayValue, OrderNo)
	SELECT	ct.SourceId, ct.SourceName, ct.Remark, ISNULL(perde.ResourceId,'00'), ISNULL(perde.HomeValue,'') , ISNULL(perde.AwayValue,''), ct.OrderNo
	FROM	@tmpLatestResult l
		INNER JOIN dbo.ProviderExternalResultDetailES perde WITH(NOLOCK)
			ON l.ProviderExternalId = perde.ProviderExternalId
		RIGHT JOIN cteSourceId ct 
			ON ct.SourceId = perde.SourceId

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpProviderExternalResult per WHERE per.SourceId = 1001)
		BEGIN
			INSERT INTO @tmpProviderExternalResult (SourceId, SourceName, Remark, ResourceId, HomeValue, AwayValue, OrderNo)
			VALUES (1001,'Screenshot','n/a','00','','', 1)
		END
			
	SELECT	t.SourceId
			,t.SourceName
			,t.Remark
			,t.ResourceId
			,t.HomeValue
			,t.AwayValue
			,t.OrderNo
	FROM	@tmpProviderExternalResult t
		INNER JOIN dbo.f_Set_MajorRound(@SportType) fsmr
			ON t.ResourceId = fsmr.ResourceId
END
GO