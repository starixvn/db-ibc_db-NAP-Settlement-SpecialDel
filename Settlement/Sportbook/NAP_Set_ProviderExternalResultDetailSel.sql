/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ProviderExternalResultDetailSel
	@MatchId3rd INT
	,@SourceId SMALLINT	
	,@MatchId	INT = 0
	,@IsInhouse	BIT = 0
	,@IsLive	BIT = 0
AS
/*
    Created by: 20201110@Louisa
    Task: get provider result - 10 Sports: 1,2,3,4,6,8,18,19,24,25 [Redmine:#144486]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20201110@Louisa: get provider result - 10 Sports: 1,2,3,4,6,8,18,19,24,25 [Redmine:#144486]
		- 20201118@Louisa: allow query by In-house MatchId
		- 20201124@Louisa: allow query by In-house MatchId or match 3rd (follow OS)
		- 20210818@Louisa: Add more Option [Redmine:#159307]
		- 20241212@Aries: Support to add a parameter to the new Live column for Provider Tables [Redmine:#215143]
		
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
		FROM	dbo.ProviderExternalResultDetail p WITH(NOLOCK)
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
	WHERE rn = 1

END
GO