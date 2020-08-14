/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ExternalResultDetailESIns
(
	 @MatchId INT   
	,@UserId INT 
	,@OutsideSources VARCHAR(MAX)
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
)
AS 
/*
    Created by: 20200810@Louisa
    Task: Insert OutsideSource result [Redmine:#138656]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200810@Louisa: Insert OutsideSource result [Redmine:#138656]

	Param's Explanation:
		@OutsideSources	VARCHAR(MAX)	 =
						'<OutsideSources>
							<Source SourceId= "1002"  ResourceId = "M1" HomeValue="2" AwayValue="3"/>
							<Source SourceId= "1001" ResourceId = "M1" HomeValue="2" AwayValue="3"/>
							<Source SourceId= "1005" ResourceId = "M3" HomeValue="2" AwayValue=""/>
						</OutsideSources>'
		@MatchId3rd: 0 - Result of OutsideSource
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId3rd INT = 0
	DECLARE @GameType TINYINT
	DECLARE @LeagueId	INT
	DECLARE @handle INT

	DECLARE @tmpExternalResultDetailES TABLE (
												SourceId SMALLINT
												, ResourceId VARCHAR(20)
												, HomeValue	VARCHAR(50)
												, AwayValue	VARCHAR(50)
											)

	SELECT @GameType =  l.OverTimeSession 
						FROM dbo.Match m WITH(NOLOCK) 
							INNER JOIN dbo.League l WITH(NOLOCK)
								ON l.leagueid  =m.leagueid
						WHERE m.MatchId = @MatchId

	SELECT @LeagueId = m.leagueid FROM match m WITH(NOLOCK)  where m.matchid = @MatchId
		
	BEGIN TRY
		IF ISNULL(@OutsideSources, '') <>''
			BEGIN
				EXEC sp_xml_preparedocument @handle OUTPUT, @OutsideSources

				INSERT INTO @tmpExternalResultDetailES ( SourceId , ResourceId  , HomeValue , AwayValue)
				SELECT SourceId , ResourceId  , HomeValue , AwayValue
				FROM OPENXML (@handle, 'OutsideSources/Source', 1) WITH (
															 			SourceId SMALLINT
															 			, ResourceId VARCHAR(20)
															 			, HomeValue	VARCHAR(50) 
															 			, AwayValue	VARCHAR(50)
																	)

				IF NOT EXISTS (	SELECT TOP 1 1 FROM ProviderLeagueMappingOutsideSource plmo WITH(NOLOCK) 
													INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)  ON plmo.PGId  =pgm.PGId
												WHERE pgm.SourceId  =1001	AND pgm.GameType = @GameType)
				BEGIN				
					EXEC dbo.NAP_Set_OutsideSourceByLeagueIns
						@LeagueId		= @LeagueId
						,@PGIdSources	= '<PGIds><PGId PGId ="0"  OrderNo="1"/></PGIds>'
						,@ErrCode		=	@ErrCode			
						,@ErrMsg		=	@ErrMsg			
				END

			INSERT INTO dbo.ProviderExternalResultDetailES 	(
				MatchId3rd
				,MatchId
				,SourceId
				,ResourceId
				,HomeValue
				,AwayValue
				,CreateBy
				,LastModifyBy
			)
			SELECT @MatchId3rd
				,@MatchId
				,SourceId
				,ResourceId
				,HomeValue
				,AwayValue
				,@UserId
				,@UserId
			FROM @tmpExternalResultDetailES														
			END
	END TRY

	BEGIN CATCH
		SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
         RETURN
	END CATCH

END
GO