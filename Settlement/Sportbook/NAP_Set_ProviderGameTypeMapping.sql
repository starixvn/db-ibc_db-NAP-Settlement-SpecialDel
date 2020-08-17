/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="2"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderGameTypeMapping]
	@SourceId		SMALLINT		= 0
	,@SourceName	VARCHAR(50)		= NULL 
	,@Remark		NVARCHAR(1000)	= NULL
	,@IsActive		BIT				= NULL
	,@GameTypes		VARCHAR(MAX)	= NULL
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(200)	= ''	OUTPUT	

AS
/*
	Creator: 20200713@Kathy 
	Task: Mapping between provider and game type [Redmine:#136931]
	DB: DBPRO/bodb02

	Revisions:
		- 20200713@Kathy: Mapping between provider and game type [Redmine:#136931]
		- 20200806@Louisa: Mapping between OutsideSource and game type [Redmine:#138656]
		
	Param's Explanation:
		@SourceId : 0 -  New Outside Source ==> New SourceID = Max(SourceID) + 1 from ProviderInfo
				    1001 - Screenshot
		@IsActive : 0 - Inactive   1 - Active

		@GameTypes: 
			<GameTypes>
				<GameType Id= "1" Remark="Dota2" IsActive="1" />
				<GameType Id= "2" Remark="LOL" IsActive="1" />
			</GameTypes>
		If it's OutsideSource, Remark=""

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xmlGameTypes XML
	DECLARE @tmpGameType TABLE (GameType TINYINT, Remark NVARCHAR(1000), IsActive BIT)
	DECLARE @MaxSourceID SMALLINT
	DECLARE @GameType TINYINT

	BEGIN TRY
	IF (@SourceId = 0 )
		BEGIN

			SELECT @MaxSourceID = Max(SourceID) + 1 from ProviderInfo
			IF @MaxSourceID <= 1001
			SET @MaxSourceID = 1001 + 1
			
			IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.ProviderInfo pi WITH(NOLOCK) WHERE pi.SourceId = @MaxSourceID)
				INSERT INTO dbo.ProviderInfo (SourceId, SourceName, Remark, IsActive) 
				VALUES (@MaxSourceID, @SourceName, @Remark, 1)

			SELECT @SourceId  = @MaxSourceID

		END
	
	ELSE
		BEGIN
			IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.ProviderInfo pi WITH(NOLOCK) WHERE SourceId = @SourceId)
				INSERT INTO dbo.ProviderInfo (SourceId, SourceName, Remark, IsActive) VALUES (@SourceId, @SourceName, @Remark, @IsActive)
			ELSE
				UPDATE dbo.ProviderInfo WITH(ROWLOCK, UPDLOCK)
					SET SourceName = COALESCE(@SourceName, SourceName)
						,Remark = COALESCE(@Remark, Remark)
						,IsActive = COALESCE(@IsActive, isActive)
				WHERE	SourceId = @SourceId
		END
	
	IF ISNULL(@GameTypes, '') <> ''
		BEGIN
			SET @xmlGameTypes = CAST(@GameTypes AS XML)
		
			INSERT INTO @tmpGameType(GameType, Remark, IsActive)
			SELECT	T.C.value('@Id', 'TINYINT') AS GameType
					,T.C.value('@Remark', 'NVARCHAR(1000)') AS Remark
					,T.C.value('@IsActive', 'BIT') AS IsActive
			FROM	@xmlGameTypes.nodes('/GameTypes/GameType') AS T(C)
		
			;WITH cteSource
			AS (
				SELECT	ROW_NUMBER() OVER (PARTITION BY GameType ORDER BY (SELECT NULL)) AS rn
						,GameType
						,Remark
						,IsActive
				FROM	@tmpGameType
			)
			MERGE dbo.ProviderGameTypeMapping AS Target
			USING (SELECT GameType, Remark, IsActive FROM cteSource WHERE rn = 1) AS SOURCE
				ON	TARGET.GameType = SOURCE.GameType
					AND Target.SourceId = @SourceId
			WHEN MATCHED THEN
				UPDATE SET Target.Remark = SOURCE.Remark
							,Target.isActive = SOURCE.IsActive
			WHEN NOT MATCHED BY TARGET THEN
				INSERT(SourceId, GameType, Remark, IsActive) VALUES (@SourceId, SOURCE.GameType, SOURCE.Remark, SOURCE.IsActive);
		
		END

	END TRY

	BEGIN CATCH
		SELECT @ErrCode	= ERROR_NUMBER()
				, @ErrMsg 	= @ErrMsg + ISNULL(ERROR_MESSAGE(),'')
	END CATCH
END
GO
