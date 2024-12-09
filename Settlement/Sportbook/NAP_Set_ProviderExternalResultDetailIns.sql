/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROC dbo.NAP_Set_ProviderExternalResultDetailIns
(
@MatchId3rd	INT	
,@MatchId	INT	= 0
,@SourceId	SMALLINT	
,@Resources	VARCHAR(MAX)	
,@UserId	INT	= 148
)
AS
/*
    Created by: 20201109@Louisa
    Task: Insert SBO result for 10 sports: 1,2,3,4,6,8,18,19,24,25 [Redmine:#144486]
    DB: DBPRO/BODB02 
    
    Revisions:   
		- 20201109@Louisa: Insert SBO result for 10 sports: 1,2,3,4,6,8,18,19,24,25 [Redmine:#144486]
		- 20240508@Aries: Enhance duplicate feed results of providers for SportBook  [Redmine:#204796]
		- 20241118@Aries: Fix an issue which is wrong settlement due to the lack of consistency when calculating Innnings [Redmine:#213767]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217] 

	Param's Explanation:
		@SourceId: 1 - SBO

		@Resources:
			For Soccer:
				<Resources>
					<Resource Id = "01" Home="1" Away="0"/>
					<Resource Id = "00" Home="2" Away="1"/>
				</Resources>
		
*/
BEGIN

SET NOCOUNT ON

	DECLARE @xmlResources XML
	DECLARE @tmpResource TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),IsLive BIT)

	SET @xmlResources = CAST(@Resources AS XML)	

	INSERT INTO @tmpResource(ResourceId,HomeValue,AwayValue,IsLive)
	SELECT   DISTINCT
			 T.C.value('@Id', 'VARCHAR(20)') AS ResourceId
			,T.C.value('@Home', 'VARCHAR(50)') AS HomeValue
			,T.C.value('@Away', 'VARCHAR(50)') AS AwayValue
			,ISNULL(T.C.value('@IsLive', 'BIT'),0) AS IsLive
	FROM  @xmlResources.nodes('/Resources/Resource') AS T(C)
	WHERE T.C.value('@Id', 'VARCHAR(20)') != ''

	INSERT INTO dbo.ProviderExternalResultDetail (
		MatchId3rd
		,MatchId
		,SourceId
		,ResourceId
		,HomeValue
		,AwayValue
		,CreateBy
		,LastModifyBy
		,IsLive
	)
	SELECT	@MatchId3rd
			,@MatchId
			,@SourceId
			,r.ResourceId
			,r.HomeValue
			,r.AwayValue
			,@UserId
			,@UserId
			,r.IsLive
	FROM @tmpResource AS r
		OUTER APPLY(
			SELECT  TOP 1 
					p.ProviderExternalId
				   ,p.HomeValue
				   ,p.AwayValue
				   ,p.IsLive
			FROM ProviderExternalResultDetail AS p WITH(NOLOCK)  
			WHERE p.MatchId3rd = @MatchId3rd 
				AND p.MatchId = @MatchId 
				AND p.SourceId =  @SourceId
				AND p.ResourceId =  r.ResourceId
			ORDER BY ProviderExternalId DESC
		) AS pr
	WHERE pr.ProviderExternalId IS NULL
		OR ISNULL(r.HomeValue,'') != ISNULL(pr.HomeValue,'') 
        OR ISNULL(r.AwayValue,'') != ISNULL(pr.AwayValue,'')
		OR ISNULL(r.IsLive,0) != ISNULL(pr.IsLive,0)

END
GO



