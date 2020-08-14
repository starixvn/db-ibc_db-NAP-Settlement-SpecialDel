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
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT

	DECLARE @tmpLatestResult AS TABLE (ProviderExternalId INT)
	DECLARE @tmpProviderExternalResult AS TABLE (SourceId INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))

	SET @SportType = 43
	
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

	INSERT INTO @tmpProviderExternalResult(SourceId, ResourceId, HomeValue, AwayValue)
	SELECT	perde.SourceId, perde.ResourceId, perde.HomeValue, perde.AwayValue
	FROM	@tmpLatestResult l
		INNER JOIN dbo.ProviderExternalResultDetailES perde WITH(NOLOCK)
			ON l.ProviderExternalId = perde.ProviderExternalId
	
	SELECT	t.SourceId
			,t.ResourceId
			,t.HomeValue
			,t.AwayValue
	FROM	@tmpProviderExternalResult t
		INNER JOIN dbo.f_Set_MajorRound(@SportType) fsmr
			ON t.ResourceId = fsmr.ResourceId
END
GO