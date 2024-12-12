/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailOSSel]
	@MatchId3rd INT = 0
	,@SourceId SMALLINT
	,@MatchId	INT = 0
	,@IsInhouse	BIT = 0
	,@IsLive	BIT = 0
AS
/*
    Created by: 20200818@Louisa
    Task: get result for LSports Redmine:#139627]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200818@Louisa: get result for LSports Redmine:#139627]
		- 20200825@Louisa: allow get result by InHouse MatchId (request from TW )
		- 20210818@Louisa: Add more Option [Redmine:#159307]
		- 20241212@Aries: Support to add a parameter to the new Live column for Provider Tables [Redmine:#215143]
		
	Param's explanation:
		@SourceId	: LSport = 25
		@MatchId	: Inhouse MatchId
		@IsInhouse = 0: Query by @MatchId3rd
		@IsInhouse = 1: Query by @MatchId
*/
BEGIN
	SET NOCOUNT ON
	
	;WITH cteLatestId
	AS(
		SELECT	ROW_NUMBER() OVER (PARTITION BY p.ResourceId, p.MatchId ORDER BY p.CreateDate DESC) AS rn
				,p.MatchId
				,p.ResourceId
				,p.HomeValue
				,p.AwayValue
				,p.CreateDate
				,p.CreateBy
				,p.LastModifyDate
				,p.LastModifyBy
		FROM	dbo.ProviderExternalResultDetailOS p WITH(NOLOCK)
		WHERE	p.SourceId = @SourceId
			AND ( 
					( p.MatchId3rd = @MatchId3rd AND @IsInhouse = 0 )
					OR ( p.MatchId = @MatchId AND @IsInhouse = 1 )
				)
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

