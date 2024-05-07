/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailOSIns]
	@MatchId3rd INT
	,@MatchId INT = 0
	,@SourceId SMALLINT
	,@Resources VARCHAR(MAX)
	,@UserId INT = 148 -- default system
AS
/*
	Creator: 20200818@Louisa
	Task: Insert result for LSports by services [Redmine:#139627]
	DB: DBPRO/bodb02
	Revisions:
		- 20200818@Louisa: Insert result for LSports by services  [Redmine:#139627]
		- 20240508@Aries: Enhance duplicate feed results of providers for SportBook  [Redmine:#204796]
		
	Param's Explanation:
		@SourceId : 25-LSports
		@Resources:
			<Resources>
				  <Resource Id = "00" Home="4" Away="3"/>
				  <Resource Id = "01" Home="2" Away="3"/>
				  <Resource Id = "02" Home="6" Away="4"/>
			</Resources>

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xmlResources XML
	DECLARE @tmpResource TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))

	SET @xmlResources = CAST(@Resources AS XML)	

	INSERT INTO @tmpResource(ResourceId,HomeValue,AwayValue)
	SELECT   DISTINCT
			 T.C.value('@Id', 'VARCHAR(20)') AS ResourceId
			,T.C.value('@Home', 'VARCHAR(50)') AS HomeValue
			,T.C.value('@Away', 'VARCHAR(50)') AS AwayValue
	FROM  @xmlResources.nodes('/Resources/Resource') AS T(C)

	INSERT INTO dbo.ProviderExternalResultDetailOS (
		MatchId3rd
		,MatchId
		,SourceId
		,ResourceId
		,HomeValue
		,AwayValue
		,CreateBy
		,LastModifyBy
	)
	SELECT	@MatchId3rd
			,@MatchId
			,@SourceId
			,r.ResourceId
			,r.HomeValue
			,r.AwayValue
			,@UserId
			,@UserId
	FROM @tmpResource AS r
		OUTER APPLY(
			SELECT  TOP 1 
					p.ProviderExternalId
				   ,p.HomeValue
				   ,p.AwayValue
			FROM ProviderExternalResultDetailOS AS p WITH(NOLOCK)  
			WHERE p.MatchId3rd = @MatchId3rd 
				AND p.MatchId = @MatchId 
				AND p.SourceId =  @SourceId
				AND p.ResourceId =  r.ResourceId
			ORDER BY ProviderExternalId DESC
		) AS pr
	WHERE pr.ProviderExternalId IS NULL
		OR ISNULL(r.HomeValue,'') != ISNULL(pr.HomeValue,'') 
        OR ISNULL(r.AwayValue,'') != ISNULL(pr.AwayValue,'')

END
GO
