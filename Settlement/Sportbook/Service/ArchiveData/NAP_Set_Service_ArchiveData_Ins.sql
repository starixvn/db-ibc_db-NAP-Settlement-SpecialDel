/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_Service_ArchiveData_Ins
	@TableName VARCHAR(50)
	,@JsonInfo VARBINARY(MAX)
	,@ErrCode  INT				= 0	OUTPUT
	,@ErrMsg NVARCHAR(500)		= '' OUTPUT
AS  
/* 
	 Creator: 20250606@Louisa 
	 Task: archive data to DB061 [Redmine:#229613] 
	     
	 Revisions:  
		- 20250606@Louisa: archive data to DB061 [Redmine:#229613]
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @Decompress_JsonInfo NVARCHAR(MAX)
			,@MaxArchiveValue	 VARCHAR(100)
			,@MaxCurrentValue	 INT

	DECLARE @ArchiveData TABLE ( ProviderExternalId BIGINT, MatchId3rd INT, MatchId INT,SourceId SMALLINT,ResourceId VARCHAR(20),HomeValue  VARCHAR(50),AwayValue  VARCHAR(50),CreateDate DATETIME, LastModifyDate DATETIME, CreateBy INT, LastModifyBy INT	,IsLive BIT	)

	SET @Decompress_JsonInfo = CAST(DECOMPRESS(@JsonInfo) AS NVARCHAR(MAX))

	BEGIN TRY
		INSERT INTO @ArchiveData  ( ProviderExternalId,MatchId3rd, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate,LastModifyDate, CreateBy, LastModifyBy,IsLive )
		SELECT id, m3rd, m , s, rs, h, a, cd,lmd, cb, lmb, il
		FROM OPENJSON(@Decompress_JsonInfo)
		WITH (id BIGINT, m3rd INT, m INT, s SMALLINT, rs VARCHAR(20), h VARCHAR(50), a VARCHAR(50), cd DATETIME, lmd DATETIME, cb INT, lmb INT, il BIT )

		SELECT @MaxArchiveValue = (SELECT CONVERT(VARCHAR(50), MAX(ProviderExternalId) ) FROM @ArchiveData	)

		IF @TableName = 'ProviderExternalResultDetail'
		BEGIN
			SELECT @MaxCurrentValue = ( SELECT MAX(ProviderExternalId) FROM ProviderExternalResultDetail_BK WITH(ROWLOCK) )

			INSERT INTO ProviderExternalResultDetail_BK ( ProviderExternalId,MatchId3rd, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate,LastModifyDate, CreateBy, LastModifyBy,IsLive)
			SELECT ProviderExternalId,MatchId3rd, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate,LastModifyDate, CreateBy, LastModifyBy,IsLive
			FROM @ArchiveData
			WHERE ProviderExternalId > ISNULL(@MaxCurrentValue,0)
		END

		ELSE IF @TableName = 'ProviderExternalResultDetailES'
		BEGIN
			SELECT @MaxCurrentValue = ( SELECT MAX(ProviderExternalId) FROM ProviderExternalResultDetailES_BK WITH(ROWLOCK) )

			INSERT INTO ProviderExternalResultDetailES_BK ( ProviderExternalId,MatchId3rd, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate,LastModifyDate, CreateBy, LastModifyBy,IsLive)
			SELECT ProviderExternalId,MatchId3rd, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate,LastModifyDate, CreateBy, LastModifyBy,IsLive
			FROM @ArchiveData
			WHERE ProviderExternalId > ISNULL(@MaxCurrentValue,0)
		END

		ELSE IF @TableName = 'ProviderExternalResultDetailOS'
		BEGIN
			SELECT @MaxCurrentValue = ( SELECT MAX(ProviderExternalId) FROM ProviderExternalResultDetailOS_BK WITH(ROWLOCK) )

			INSERT INTO ProviderExternalResultDetailOS_BK ( ProviderExternalId,MatchId3rd, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate,LastModifyDate, CreateBy, LastModifyBy,IsLive)
			SELECT ProviderExternalId,MatchId3rd, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate,LastModifyDate, CreateBy, LastModifyBy,IsLive
			FROM @ArchiveData
			WHERE ProviderExternalId > ISNULL(@MaxCurrentValue,0)
		END

		IF CAST(@MaxArchiveValue AS INT) > ISNULL(@MaxCurrentValue,0)
		BEGIN
			UPDATE Settlement_ArchiveSetting WITH(ROWLOCK,UPDLOCK)
			SET ArchiveValue =  @MaxArchiveValue
				,ArchiveTime = GETDATE()
			WHERE ArchiveName = @TableName
		END

	END TRY
	BEGIN CATCH
		SELECT @ErrCode  = @@ERROR
				,@ErrMsg =  CAST(ERROR_MESSAGE() AS NVARCHAR(500) )


	END CATCH

END  
GO
