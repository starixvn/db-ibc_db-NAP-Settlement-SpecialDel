/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderGameTypeMapping]
	@SourceId		SMALLINT
	,@SourceName	VARCHAR(50)		= NULL 
	,@Remark		NVARCHAR(1000)	= NULL
	,@IsActive		BIT				= NULL
	,@GameTypes		VARCHAR(MAX)	= NULL

AS
/*
	Creator: 20200713@Kathy 
	Task: Mapping between provider and game type [Redmine:#136931]
	DB: DBPRO/bodb02
	Revisions:
		- 20200713@Kathy: Mapping between provider and game type [Redmine:#136931]
		
	Param's Explanation:
		@GameTypes: 
			<GameTypes>
				<GameType Id= "1" Remark="Dota2" IsActive="1" />
				<GameType Id= "2" Remark="LOL" IsActive="1" />
			</GameTypes>

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xmlGameTypes XML
	DECLARE @tmpGameType TABLE (GameType TINYINT, Remark NVARCHAR(1000), IsActive BIT)

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.ProviderInfo pi WITH(NOLOCK) WHERE SourceId = @SourceId)
		INSERT INTO dbo.ProviderInfo (SourceId, SourceName, Remark, IsActive) VALUES (@SourceId, @SourceName, @Remark, @IsActive)
	ELSE
		UPDATE dbo.ProviderInfo WITH(ROWLOCK, UPDLOCK)
			SET SourceName = COALESCE(@SourceName, SourceName)
				,Remark = COALESCE(@Remark, Remark)
				,IsActive = COALESCE(@IsActive, isActive)
		WHERE	SourceId = @SourceId
	
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
		USING (SELECT GameType, Remark, IsActive FROM cteSource WHERE rn = 1) AS Source
			ON	TARGET.GameType = SOURCE.GameType
				AND Target.SourceId = @SourceId
		WHEN MATCHED THEN
			UPDATE SET Target.Remark = Source.Remark
						,Target.isActive = Source.IsActive
		WHEN NOT MATCHED BY TARGET THEN
			INSERT(SourceId, GameType, Remark, IsActive) VALUES (@SourceId, SOURCE.GameType, SOURCE.Remark, SOURCE.IsActive);
		
	END
END
GO
