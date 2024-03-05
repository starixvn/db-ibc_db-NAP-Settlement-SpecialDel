/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE ArchiveService_Ins
	@TableName VARCHAR(50)
	,@JsonInfo VARBINARY(MAX)
	,@ErrCode  INT				= 0	OUTPUT
	,@ErrMsg NVARCHAR(500)		= '' OUTPUT
AS  
/* 
	 Creator:20240222@Louisa  
	 Task: Archive data for ProviderExternalResultDetailXX [Redmine:#201196] 
	     
	 Revisions:  
		- 20240222@Louisa: Initial [Redmine:#201196]
    
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @Decompress_JsonInfo NVARCHAR(MAX)
			,@MaxArchiveValue	 VARCHAR(100)
			,@MaxCurrentValue	 INT

	DECLARE @ArchiveData TABLE ( ProviderExternalId BIGINT, MatchId INT,SourceId SMALLINT,ResourceId VARCHAR(20),HomeValue  VARCHAR(50),AwayValue  VARCHAR(50),CreateDate DATETIME	)

	SET @Decompress_JsonInfo = CAST(DECOMPRESS(@JsonInfo) AS NVARCHAR(MAX))

	BEGIN TRY
		INSERT INTO @ArchiveData  ( ProviderExternalId, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate )
		SELECT id, m , s, rs, h, a, cd
		FROM OPENJSON(@Decompress_JsonInfo)
		WITH ( id BIGINT, m INT, s SMALLINT, rs VARCHAR(20), h VARCHAR(50), a VARCHAR(50), cd DATETIME )

		SELECT @MaxArchiveValue = (SELECT CONVERT(VARCHAR(50), MAX(ProviderExternalId) ) FROM @ArchiveData	)

		IF @TableName = 'ProviderExternalResultDetail'
		BEGIN
			SELECT @MaxCurrentValue = ( SELECT MAX(ProviderExternalId) FROM ProviderExternalResultDetail_BK WITH(ROWLOCK) )

			INSERT INTO ProviderExternalResultDetail_BK( ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate)
			SELECT ProviderExternalId, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate 
			FROM @ArchiveData
			WHERE ProviderExternalId > ISNULL(@MaxCurrentValue,0)
		END

		ELSE IF @TableName = 'ProviderExternalResultDetailES'
		BEGIN
			SELECT @MaxCurrentValue = ( SELECT MAX(ProviderExternalId) FROM ProviderExternalResultDetailES_BK WITH(ROWLOCK) )

			INSERT INTO ProviderExternalResultDetailES_BK (ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate)
			SELECT ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate 
			FROM @ArchiveData
			WHERE ProviderExternalId > ISNULL(@MaxCurrentValue,0)
		END

		ELSE IF @TableName = 'ProviderExternalResultDetailOS'
		BEGIN
			SELECT @MaxCurrentValue = ( SELECT MAX(ProviderExternalId) FROM ProviderExternalResultDetailOS_BK WITH(ROWLOCK) )

			INSERT INTO ProviderExternalResultDetailOS_BK (ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate)
			SELECT ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate 
			FROM @ArchiveData
			WHERE ProviderExternalId > ISNULL(@MaxCurrentValue,0)
		END

		IF CAST(@MaxArchiveValue AS INT) > @MaxCurrentValue
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

