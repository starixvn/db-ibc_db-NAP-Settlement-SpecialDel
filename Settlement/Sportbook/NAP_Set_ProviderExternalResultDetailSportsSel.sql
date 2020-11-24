/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ProviderExternalResultDetailSportsSel
	@MatchId3rd INT = 0
	,@SourceId SMALLINT
	,@Sporttype SMALLINT	
	,@MatchId	INT = 0
	,@IsInhouse	BIT = 0
AS
/*
    Created by: 20201110@Louisa
    Task: get provider result - 13 Sports: 1,2,3,4,5,6,8,9,18,19,24,25,43 [Redmine:#144486]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20201110@Louisa: get provider result - 13 Sports: 1,2,3,4,5,6,8,9,18,19,24,25,43 [Redmine:#144486]
		- 20201118@Louisa: allow query by In-house MatchId
		
*/
BEGIN
	
	SELECT @Sporttype  = ISNULL( @Sporttype, 0 )

	IF @Sporttype  IN ( 5,9 ) ---- Tennis, Badminton
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailOSSel
			@MatchId3rd	= @MatchId3rd
			,@SourceId	= @SourceId
			,@MatchId	= @MatchId
			,@IsInhouse	= @IsInhouse
	END

	ELSE IF @Sporttype = 43 ---- E-Sports
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailESSel
			@MatchId3rd	= @MatchId3rd
			,@SourceId	= @SourceId
	END

	ELSE IF @Sporttype IN ( 1,2,3,4,6,8,18,19,24,25 ) ----Soccer + Others
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailSel
			@MatchId3rd	= @MatchId3rd
			,@SourceId	= @SourceId
			,@MatchId	= @MatchId
			,@IsInhouse	= @IsInhouse
	END

	ELSE
		RETURN

END
GO