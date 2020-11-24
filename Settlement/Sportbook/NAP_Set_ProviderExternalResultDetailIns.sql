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

	SET @xmlResources = CAST(@Resources AS XML)	

	INSERT INTO dbo.ProviderExternalResultDetail (
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
			,T.C.value('@Id', 'VARCHAR(20)') AS ResouceId
			,T.C.value('@Home', 'VARCHAR(50)') AS HomeValue
			,T.C.value('@Away', 'VARCHAR(50)') AS AwayValue
			,@UserId
			,@UserId
	FROM	@xmlResources.nodes('/Resources/Resource') AS T(C)

END
GO



