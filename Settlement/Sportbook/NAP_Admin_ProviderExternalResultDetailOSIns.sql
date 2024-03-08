/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_ProviderExternalResultDetailOSIns]
	 @MatchId INT = 0
	,@SourceId SMALLINT
	,@Resources VARCHAR(MAX)
	,@UserId INT = 148 -- default system
AS
/*
	Creator: 20240308@201836
	Task: Direct Ice Hockey [Redmine:#201836]
	DB: DBPRO/bodb02
	Revisions:
		- 20240308@Aries: Direct Ice Hockey [Redmine:#201836]
		
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

	SET @xmlResources = CAST(@Resources AS XML)	

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
	SELECT	 0
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
