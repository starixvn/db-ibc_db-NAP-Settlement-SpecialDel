/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ProviderExternalResultDetailSportsIns
(
@MatchId3rd	INT
,@MatchId	INT = 0
,@SourceId	SMALLINT
,@Resources	VARCHAR(MAX)
,@UserId	INT = 148
)
AS
/*
   Created by: 20201109@Louisa
    Task: Insert SBO result [Redmine:#144486]
    DB: DBPRO/BODB02 
    
    Revisions:   
		- 20201109@Louisa: Insert SBO result for 13 sports: 1,2,3,4,5,6,8,9,18,19,24,25,43 [Redmine:#144486]
		- 20201124@Louisa: Remove param @Sporttype
		- 20210504@Louisa: Intergration Result for Cricket - Weverdat [Redmine:#154493]
		- 20210730@Louisa: Intergration L-Sports [Redmine:#159307]

	Param's Explanation:
		@SourceId: 1  - SBO
				   25 - LSports

		@Resources:
			For Soccer:
				<Resources>
					<Resource Id = "01" Home="1" Away="0"/>
					<Resource Id = "00" Home="2" Away="1"/>
				</Resources>

*/
BEGIN
	
	DECLARE @Sporttype SMALLINT
	SELECT  @Sporttype = ISNULL(m.Sporttype,0) FROM dbo.match m WITH(NOLOCK) WHERE m.matchid  = @MatchId

	IF @Sporttype IN ( 5,9,50,7,14,16,26,28,45)
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailOSIns
		@MatchId3rd = @MatchId3rd
		,@MatchId	= @MatchId
		,@SourceId	= @SourceId
		,@Resources = @Resources
		,@UserId	= @UserId
	END

	ELSE IF @Sporttype = 43 ---E-Sports
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailESIns
		@MatchId3rd = @MatchId3rd
		,@MatchId	= @MatchId
		,@SourceId	= @SourceId
		,@Resources = @Resources
		,@UserId	= @UserId
	END

	ELSE IF @Sporttype IN (1,2,3,4,6,8,18,19,24,25) ---Soccer + (1,2,3,4,6,8,18,19,24,25)
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailIns
		@MatchId3rd = @MatchId3rd
		,@MatchId	= @MatchId
		,@SourceId	= @SourceId
		,@Resources = @Resources
		,@UserId	= @UserId
	END

	ELSE
		RETURN
	
END
GO

