/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ProviderExternalResultDetailESSel
	@MatchId3rd INT
	,@SourceId SMALLINT
	,@IsLive	BIT = 0
AS
/*
    Created by: 20200723@Kathy
    Task: get provider result [Redmine:#136931]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200721@Kathy: get provider result [Redmine:#136931]
		- 20210818@Louisa: Add more Option [Redmine:#159307]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217] 
		- 20241212@Aries: Support to add a parameter to the new Live column for Provider Tables [Redmine:#215143]
		
*/
BEGIN
	SET NOCOUNT ON
	
	;WITH cteLatestId
	AS(
		SELECT	ROW_NUMBER() OVER (PARTITION BY p.ResourceId ,p.MatchId ORDER BY p.CreateDate DESC) AS rn
				,p.MatchId
				,p.ResourceId
				,p.HomeValue
				,p.AwayValue
				,p.CreateDate
				,p.CreateBy
				,p.LastModifyDate
				,p.LastModifyBy
		FROM	dbo.ProviderExternalResultDetailES p WITH(NOLOCK)
		WHERE	p.MatchId3rd = @MatchId3rd
				AND p.SourceId = @SourceId
				AND ISNULL(p.IsLive,0) = @IsLive
	)
	SELECT MatchId
		  ,ResourceId
		  ,HomeValue
		  ,AwayValue
		  ,CreateDate
		  ,CreateBy
		  ,LastModifyDate
		  ,LastModifyBy
	FROM	cteLatestId
	WHERE	rn = 1
END
GO