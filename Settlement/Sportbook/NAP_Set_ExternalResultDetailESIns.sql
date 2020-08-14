/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
<<<<<<< 138656-Settlemet-ApplyKeyscoreSOPESSports-Phase2
ALTER PROCEDURE NAP_Set_ExternalResultDetailESIns
(
	 @MatchId INT   
	,@UserId INT 
	,@OutsideSources VARCHAR(MAX)
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
=======
ALTER PROCEDURE NAP_Set_ExternalResultDetailESIns_xtest
(
	 @MatchId INT   
	,@UserId INT = 148 -- default system
	,@OutsideSources VARCHAR(MAX)
>>>>>>> local
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
<<<<<<< 138656-Settlemet-ApplyKeyscoreSOPESSports-Phase2
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

=======
							<Source SourceId= "1002"  ResourceId = "M1" Home="2" Away="3"/>
							<Source SourceId= "1001" ResourceId = "M1" Home="2" Away="3"/>
							<Source SourceId= "1005" ResourceId = "M3" Home="2" Away=""/>
						</OutsideSources>'
*/

BEGIN
	DECLARE @MatchId3rd INT =0
	DECLARE @GameType TINYINT
	DECLARE @GameTypeVarchar VARCHAR(2)
	DECLARE @handle INT
>>>>>>> local
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
<<<<<<< 138656-Settlemet-ApplyKeyscoreSOPESSports-Phase2

	SELECT @LeagueId = m.LeaguePatternID FROM match m WITH(NOLOCK)  where m.matchid = @MatchId
		
	BEGIN TRY
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
					
					EXEC [dbo].[NAP_Set_OutsideSourceByLeagueIns]
						@LeagueId		= @LeagueId
						,@PGIdSources	= '<PGIds><PGId PGId ="0"  OrderNo="1"/></PGIds>'
						,@ErrCode		=	@ErrCode			
						,@ErrMsg		=	@ErrMsg
					
					
				END

				INSERT INTO dbo.ProviderExternalResultDetailES 	(
					MatchId3rd
					,MatchId
=======
	
	IF ISNULL(@OutsideSources, '') <>''
		BEGIN
			EXEC sp_xml_preparedocument @handle OUTPUT, @OutsideSources

			INSERT INTO @tmpExternalResultDetailES ( SourceId , ResourceId  , HomeValue , AwayValue)
			SELECT SourceId , ResourceId  , Home , Away
			FROM OPENXML (@handle, 'OutsideSources/Source', 1) WITH (
															 		SourceId SMALLINT
															 		, ResourceId VARCHAR(20)
															 		, Home	VARCHAR(50) 
															 		, Away	VARCHAR(50)
																)

			IF NOT EXISTS (SELECT TOP 1 1 FROM ProviderGameTypeMapping pgm WHERE pgm.GameType = @GameType AND SourceId = 1001)
			BEGIN
				SET @GameTypeVarchar =  CAST(@GameType AS varchar(2))

				EXEC [dbo].[NAP_Set_ProviderGameTypeMapping] 
							 @SourceId	 = 1001
							,@SourceName ='Screenshot'
							,@Remark	 = 'n/a'
							,@IsActive	 = 1
							,@GameTypes  = 	@GameTypeVarchar
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
>>>>>>> local
					,SourceId
					,ResourceId
					,HomeValue
					,AwayValue
<<<<<<< 138656-Settlemet-ApplyKeyscoreSOPESSports-Phase2
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
=======
					,@UserId
					,@UserId
			FROM @tmpExternalResultDetailES
														
		END
>>>>>>> local

END
GO