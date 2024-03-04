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

	DECLARE @ArchiveData TABLE ( ProviderExternalId BIGINT, MatchId INT,SourceId SMALLINT,ResourceId VARCHAR(20),HomeValue  VARCHAR(50),AwayValue  VARCHAR(50),CreateDate DATETIME	)

	SET @Decompress_JsonInfo = CAST(DECOMPRESS(@JsonInfo) AS NVARCHAR(MAX))

		INSERT INTO @ArchiveData  ( ProviderExternalId, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate )
		SELECT id, m , s, rs, h, a, cd
		FROM OPENJSON(@Decompress_JsonInfo)
		WITH ( id BIGINT, m INT, s SMALLINT, rs VARCHAR(20), h VARCHAR(50), a VARCHAR(50), cd DATETIME )

		SELECT @MaxArchiveValue = (SELECT CONVERT(VARCHAR(50), MAX(ProviderExternalId) ) FROM @ArchiveData	)

		IF @TableName = 'ProviderExternalResultDetail'
		BEGIN
			INSERT INTO ProviderExternalResultDetail_BK( ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate)
			SELECT ProviderExternalId, MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate FROM @ArchiveData
		END

		ELSE IF @TableName = 'ProviderExternalResultDetailES'
		BEGIN
			INSERT INTO ProviderExternalResultDetailES_BK (ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate)
			SELECT ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate FROM @ArchiveData
		END

		ELSE IF @TableName = 'ProviderExternalResultDetailOS'
		BEGIN
			INSERT INTO ProviderExternalResultDetailOS_BK (ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate)
			SELECT ProviderExternalId,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateDate FROM @ArchiveData
		END

		UPDATE Settlement_ArchiveSetting WITH(ROWLOCK,UPDLOCK)
		SET ArchiveValue =  @MaxArchiveValue
			,ArchiveTime = GETDATE()
		WHERE ArchiveName = @TableName


		SELECT @ErrCode  = @@ERROR
				,@ErrMsg =  CAST(ERROR_MESSAGE() AS NVARCHAR(500) )



END  
GO

