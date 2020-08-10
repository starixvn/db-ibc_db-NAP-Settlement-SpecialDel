/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailESIns]
	@MatchId3rd INT
	,@MatchId INT = 0
	,@SourceId SMALLINT
	,@Resources VARCHAR(MAX)
	,@UserId INT = 148 -- default system
AS
/*
	Creator: 20200713@Kathy
	Task: Insert result from providers
	DB: DBPRO/bodb02
	Revisions:
		- 20200713@Kathy: Insert result from providers  [Redmine:#136931]
		
	Param's Explanation:
		@Resources:
			<Resources>
				<Resource Id = "M1" Home="" Away=""/>
				<Resource Id = "M2" Home="" Away=""/>
			</Resources>

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xmlResources XML

	SET @xmlResources = CAST(@Resources AS XML)	

	INSERT INTO dbo.ProviderExternalResultDetailES (
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