/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROC dbo.NAP_Set_ProviderResultDetailOutrightIns
(
	@Leagueid	INT	
	,@SourceId	SMALLINT	
	,@Resources	VARCHAR(MAX)	
	,@UserId	INT	= 148
)
AS
/*
    Created by: 20250820@Hughie
    Task: Save screenshot score button [Redmine:#232955]
    DB: DBPRO/BODB02 
    
    Revisions:   
		- 20250820@Hughie: Created [Redmine:#232955]

	Param's Explanation:
		@SourceId: 1 - SBO
					1001 - screenshot

		@Resources:
			For Soccer:
				<Resources>
					<Resource Orid = "123456" Teamid="101" Result="WON"/>
					<Resource Orid = "123457" Teamid="102" Result="LOSE"/>
				</Resources>
		
*/
BEGIN

SET NOCOUNT ON

	DECLARE @xmlResources XML
	DECLARE @tmpResource TABLE (Orid INT, Teamid INT, Result VARCHAR(10))

	SET @xmlResources = CAST(@Resources AS XML)	

	INSERT INTO @tmpResource(Orid, Teamid, Result)
	SELECT   DISTINCT
			 T.C.value('@Orid', 'INT') AS Orid
			,T.C.value('@Teamid', 'INT') AS Teamid
			,T.C.value('@Result', 'VARCHAR(10)') AS Result
	FROM  @xmlResources.nodes('/Resources/Resource') AS T(C)

	INSERT INTO dbo.ProviderResultDetailOutright (
		Orid
		,SourceId
		,Leagueid
		,Teamid
		,Result
		,CreatedBy
		,CreatedDate
	)
	SELECT	r.Orid
			,@SourceId
			,@Leagueid
			,r.Teamid
			,r.Result
			,@UserId
			,GETDATE()
	FROM @tmpResource AS r
		OUTER APPLY(
			SELECT  TOP 1 
					p.ProviderId
				   ,P.Leagueid
				   ,p.Teamid
				   ,p.Result
			FROM ProviderResultDetailOutright AS p WITH(NOLOCK)  
			WHERE p.Leagueid = @Leagueid 
				AND p.Teamid = Teamid 
				AND p.SourceId =  @SourceId
			ORDER BY ProviderId DESC
		) AS pr
	WHERE pr.ProviderId IS NULL
		OR ISNULL(r.Result,'') != ISNULL(pr.Result,'') 
END
GO

