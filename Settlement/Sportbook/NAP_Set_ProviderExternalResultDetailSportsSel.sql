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
		- 20210504@Louisa: Intergration Result for Cricket - Weverdat [Redmine:#154493]
		- 20210730@Louisa: Intergration L-Sports [Redmine:#159307]
		- 20210805@Louisa: Default for Other sports [Redmine:#159307]
		- 20211223@Louisa: mapping between in-house and external match [Redmine:#166449]
		- 20220222@Louisa : Task: Integrate result for Soccer Corner matches [Redmine:#168854]
*/
BEGIN
	
	SELECT @Sporttype  = ISNULL( @Sporttype, 0 )

	DECLARE @ExternalResultTable TINYINT
	
	SELECT  @ExternalResultTable = CASE WHEN ss.Sporttype = 8 THEN 2 ELSE sS.ExternalResultTable END
	FROM dbo.SettlementResultTableSetting ss WITH(NOLOCK)
	WHERE ss.Sporttype = @Sporttype

	IF @ExternalResultTable = 1
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailSel
			@MatchId3rd	= @MatchId3rd
			,@SourceId	= @SourceId
			,@MatchId	= @MatchId
			,@IsInhouse	= @IsInhouse
	END

	ELSE IF @ExternalResultTable = 3 ---- ESports
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailESSel
			@MatchId3rd	= @MatchId3rd
			,@SourceId	= @SourceId
	END

	ELSE
		EXEC dbo.NAP_Set_ProviderExternalResultDetailOSSel
			@MatchId3rd	= @MatchId3rd
			,@SourceId	= @SourceId
			,@MatchId	= @MatchId
			,@IsInhouse	= @IsInhouse

END
GO