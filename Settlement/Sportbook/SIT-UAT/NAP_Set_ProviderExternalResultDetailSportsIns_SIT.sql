/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ProviderExternalResultDetailSportsIns_SIT
(
@MatchId3rd	INT = 0
,@MatchId	INT = 0
,@SourceId	SMALLINT
,@Resources	VARCHAR(MAX)
,@UserId	INT = 148
,@ErrCode	INT  = 0 OUTPUT	 
,@ErrMsg	NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created by: 20201206@Louisa
    Task: Support QC Insert data Test for SBO result [Redmine:#146239]
    DB: DBPRO/BODB02 
    
    Revisions:   
		- 20201206@Louisa: Support QC Insert data Test for SBO result [Redmine:#146239]

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
	
	DECLARE @Sporttype SMALLINT
	SELECT  @Sporttype = m.Sporttype FROM dbo.match m WITH(NOLOCK) WHERE m.matchid  = @MatchId

	IF  ISNULL(@Sporttype,0) = 0 
	BEGIN
		SELECT @ErrMsg = N'Invalid sport type or match'
	END

	BEGIN TRY
		IF @Sporttype IN ( 5,9) ---- Tennis, Badminton
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

		ELSE ---IF @Sporttype IN (1,2,3,4,6,8,18,19,24,25) 
		BEGIN
			EXEC dbo.NAP_Set_ProviderExternalResultDetailIns
			@MatchId3rd = @MatchId3rd
			,@MatchId	= @MatchId
			,@SourceId	= @SourceId
			,@Resources = @Resources
			,@UserId	= @UserId
		END

	END TRY

	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
		SELECT @ErrMsg = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
	END CATCH
END
GO

