/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE  NAP_mSite2_ProviderGameTypeMapping
	@SourceId		SMALLINT
	,@Sporttype		SMALLINT
	,@Remark		NVARCHAR(1000)	= NULL
	,@IsActive		BIT	 
	,@GameTypes		VARCHAR(MAX) 
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(200)	= ''	OUTPUT	

AS
/*
	Created by: 20250808@Louisa
	Task: mSite2-mapping Provider  [Redmine:#235224]
	Server: db061
	DB: DBPRO-bodb02

	Revision:
		20250808@Louisa: Create [Redmine:#235224]

	@GameTypes: use for E-Sports  @GameTypes = '1,2,3,99'
		1-Dota2
		2-LoL
*/
BEGIN
	BEGIN TRY
		DECLARE @tmpGameType TABLE (GameType TINYINT)

		INSERT INTO @tmpGameType(GameType) SELECT v.value FROM string_split(@GameTypes,',') v


		IF @IsActive = 0
		BEGIN
			UPDATE p
			SET p.isActive = 0
			FROM ProviderGameTypeMapping p WITH(ROWLOCK,UPDLOCK)
			INNER JOIN @tmpGameType g 
				ON @SourceId		= @SourceId
					AND @Sporttype  = @Sporttype	
					AND g.GameType	= p.GameType
		END
		ELSE
		BEGIN
			INSERT INTO ProviderGameTypeMapping (SourceId, GameType, Remark, IsActive, Sporttype) 
			SELECT @SourceId, g.GameType, @Remark, @IsActive, @Sporttype
			FROM @tmpGameType g
		END

	END TRY

	BEGIN CATCH
		SELECT @ErrCode	= ERROR_NUMBER()
				, @ErrMsg 	= @ErrMsg + ISNULL(ERROR_MESSAGE(),'')
	END CATCH

END
GO