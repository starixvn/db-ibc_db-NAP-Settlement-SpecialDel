/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ExternalResult_Ins
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
		- 20210519@Louisa: Support QC Insert data Test for Weverdat result [Redmine:#153915]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]

	Param's Explanation:
		@SourceId: 1 - SBO

		@Resources:
			For Soccer:
				<Resources>
					<Resource Id = "01" Home="1" Away="0"/>
					<Resource Id = "00" Home="2" Away="1"/>
				</Resources>

	Note: This SP provide to Web with version UAT3 (LOCAL, SIT, UAT)

*/
BEGIN
	
	DECLARE @Sporttype SMALLINT
			, @IsLeagueTest BIT 
			, @ExternalResultTable INT

	SELECT  @Sporttype = m.Sporttype 
			,@IsLeagueTest = ISNULL(l.isTest,0)
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK) 
			ON m.leagueid = l.leagueid
	WHERE m.matchid  = @MatchId

	IF  ISNULL(@Sporttype,100) > 99
	BEGIN
		SELECT @ErrCode = 1001053
			,@ErrMsg = N'Invalid sport type or match'
		RETURN
	END

	IF  @IsLeagueTest = 0 AND @@serverName NOT IN ( 'DB206', 'DB-60\DEVDBTRANS', 'TESTDBTRANS' ) 
	BEGIN
		SELECT @ErrCode = 1001054
			 ,@ErrMsg = N'The League does not belong league test'
		RETURN
	END

	SELECT @ExternalResultTable = case when ss.sporttype = 8 then 2 else ss.ExternalResultTable end
	FROM dbo.SettlementResultTableSetting ss WITH(NOLOCK)
	WHERE ss.Sporttype = @Sporttype

	BEGIN TRY
		IF @ExternalResultTable = 2
		BEGIN
			EXEC dbo.NAP_Set_ProviderExternalResultDetailOSIns
			@MatchId3rd = @MatchId3rd
			,@MatchId	= @MatchId
			,@SourceId	= @SourceId
			,@Resources = @Resources
			,@UserId	= @UserId
		END

		ELSE IF @ExternalResultTable = 3
		BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailESIns
			@MatchId3rd = @MatchId3rd
			,@MatchId	= @MatchId
			,@SourceId	= @SourceId
			,@Resources = @Resources
			,@UserId	= @UserId
		END

		ELSE
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