/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ResultDetailSettingUpd
	@MatchId	INT
	,@Type		TINYINT
	,@ResourceIds VARCHAR(MAX)  = ''
	,@SelectedResources	VARCHAR(MAX)= NULL
	,@IsEnabled BIT
	,@AdminId	INT
	,@IP		VARCHAR(20)	= ''
	,@Is3x3		BIT	= 0

AS
/*
	Created by: 20201113@Louisa
	Task : Update Result Setting [Redmine:#135097]
	DB: DBPRO/bodb02

	Revisions:
		- 220201113@Louisa: Update Result Setting - Apply for Soccer, Basketball, Badminton, E-Sports[Redmine:#135097]
		- 20210201@Louisa: Cricket AIO - Early bettype [Redmine:#148870]
		- 20210811@Louisa: SOP Refund for Tennis, E-Sports [Redmine:#159270]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192] 
		- 20210906@Louisa: SOP Refund for Volleyball, Beach Volleyball [Redmine:#160478]
		- 20211025@Louisa: SOP Refund for Badminton, Basketball, Cricket [Redmine:#163574]
		- 20220509@Kathy: Change to use STRING_SPLIT on DBPRO [Redmine:#172461]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]

		  	
	Parameters Explanation:    
		@Type: TINYINT
			 1: Hold Result
			 2: Confirm Refund
			 3: Confirm Refund SDT

		@ResourceIds = '902401,904301,906301,905801,905701'

		@IsEnabled: 1-Turn on
					0: Turn off	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SportType			TINYINT  = 0
			,@ActionId			INT
			,@LogData			NVARCHAR(200) 
			,@Remark			VARCHAR(500)
			,@ResultTable		TINYINT	= 0	
			,@handle			INT
			,@RemarkSDT			VARCHAR(500) = ''
								
	DECLARE @tmpResultDetail TABLE ( ResourceId	VARCHAR(20)	)
	DECLARE @tmpResourcesWeb TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))

	SELECT	@ActionId = CASE	WHEN @Type = 1 THEN 81021
								WHEN @Type IN (2,3) THEN 81032
								ELSE NULL
						 END
	SELECT @SportType = m.sporttype FROM dbo.Match m WITH(NOLOCK) WHERE m.matchid  = @MatchId

	IF @ActionId IS NULL OR ( @Type = 2 AND @SportType NOT IN ( 5, 43, 6, 45, 9, 2, 50 ) )
	RETURN

	SELECT @ResultTable =  r.ResultTable 
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK) 
	WHERE r.Sporttype = @SportType
	/*@ResultTable:
			1: ResultDetail
			2: ResultDetailOS
			3: ResultDetailES
	*/

	INSERT INTO @tmpResultDetail ( ResourceId)
	SELECT DISTINCT
	sp.ResourceID
	FROM DBTXN.bodb02.dbo.SettlementSpecialBettypeProfile sp  WITH (NOLOCK)
		INNER JOIN STRING_SPLIT(@ResourceIds,',') fs ON sp.ResourceID = fs.value
		AND sp.SportType  = @SportType

	IF @Type = 3
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
		SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
		FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id VARCHAR(20),Home VARCHAR(50),Away VARCHAR(50)) AS tbl
		EXEC sp_xml_removedocument @handle

		IF EXISTS (SELECT 1 FROM @tmpResourcesWeb WHERE ResourceID = 'OT') AND NOT EXISTS (SELECT 1 FROM @tmpResultDetail WHERE ResourceID = 'OT')
		BEGIN
			INSERT INTO @tmpResultDetail(ResourceId)
			VALUES('OT')
		END

		IF @IsEnabled = 1
		BEGIN
			DELETE FROM dbo.ProviderExternalResultDetail WHERE MatchId = @MatchId AND SourceId = 99 -- Remove old confirm

			SELECT @RemarkSDT = STRING_AGG (ResourceId + '(' + HomeValue + '-' + AwayValue  + ')',', ')
			FROM @tmpResourcesWeb
			WHERE HomeValue != '' 
				AND AwayValue != ''

			INSERT INTO dbo.ProviderExternalResultDetail (MatchId3rd,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateBy,LastModifyBy)
			SELECT	 0 AS MatchId3rd
					,@MatchId AS MatchId
					,99 AS SourceId
					,ResourceId
					,HomeValue
					,AwayValue
					,@AdminId AS CreateBy
					,@AdminId AS LastModifyBy
			FROM @tmpResourcesWeb
		END
		ELSE
		BEGIN
			SELECT @RemarkSDT = STRING_AGG (ResourceId + '(' + HomeValue + '-' + AwayValue  + ')',', ')
			FROM dbo.ProviderExternalResultDetail
			WHERE MatchId = @MatchId
				AND SourceId = 99
				AND ISNULL(HomeValue,'') != '' 
				AND ISNULL(AwayValue,'') != ''

			DELETE FROM dbo.ProviderExternalResultDetail WHERE MatchId = @MatchId AND SourceId = 99
		END
	END

	IF @ResultTable = 1
	BEGIN

		MERGE dbo.ResultDetail WITH (UPDLOCK,ROWLOCK) TARGET
		USING (
				SELECT  r.ResourceId
				FROM	@tmpResultDetail r
				) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid
		WHEN MATCHED THEN
			UPDATE SET ResultSetting = CASE WHEN @IsEnabled  = 1 
					   						THEN ISNULL(ResultSetting,0) | POWER(2, @Type - 1)
					   						ELSE ISNULL(ResultSetting,0) & (~POWER(2, @Type - 1))
					   					END
		WHEN NOT MATCHED BY TARGET THEN 
		INSERT (MatchId
				,ResourceId
				,HomeValue
				,AwayValue
				,ResultStatusID		-- 1: running
				,SettlementStatusID --0: running
				,CreateDate
				,CreateBy
				,OtherInfo
				,ResultSetting)
		VALUES (@matchid, SOURCE.ResourceId, NULL, NULL, 1, 0, GETDATE(), @AdminId, NULL, POWER(2, @Type - 1));
	END

	IF @ResultTable = 2
	BEGIN
		MERGE dbo.ResultDetailOS WITH (UPDLOCK,ROWLOCK) TARGET
		USING (
				SELECT  r.ResourceId
				FROM	@tmpResultDetail r
				) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid
		WHEN MATCHED THEN
			UPDATE SET ResultSetting = CASE WHEN @IsEnabled  = 1 
					   						THEN ISNULL(ResultSetting,0) | POWER(2, @Type - 1)
					   						ELSE ISNULL(ResultSetting,0) & (~POWER(2, @Type - 1))
					   					END
		WHEN NOT MATCHED BY TARGET THEN 
		INSERT (MatchId
				,ResourceId
				,HomeValue
				,AwayValue
				,ResultStatusID -- 1: running
				,SettlementStatusID --0: running
				,CreateDate
				,CreateBy
				,OtherInfo
				,ResultSetting)
		VALUES (@matchid, SOURCE.ResourceId, NULL, NULL, 1, 0, GETDATE(), @AdminId, NULL, POWER(2, @Type - 1));
	END

	IF @ResultTable = 3
	BEGIN
		MERGE dbo.ResultDetailES WITH (UPDLOCK,ROWLOCK) TARGET
		USING (
				SELECT  r.ResourceId
				FROM	@tmpResultDetail r
				) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid
		WHEN MATCHED THEN
			UPDATE SET ResultSetting = CASE WHEN @IsEnabled  = 1 
					   						THEN ISNULL(ResultSetting,0) | POWER(2, @Type - 1)
					   						ELSE ISNULL(ResultSetting,0) & (~POWER(2, @Type - 1))
					   					END
		WHEN NOT MATCHED BY TARGET THEN 
		INSERT (MatchId
				,ResourceId
				,HomeValue
				,AwayValue
				,ResultStatusID -- 1: running
				,SettlementStatusID --0: running
				,CreateDate
				,CreateBy
				,OtherInfo
				,ResultSetting)
		VALUES (@matchid, SOURCE.ResourceId, NULL, NULL, 1, 0, GETDATE(), @AdminId, NULL, POWER(2, @Type - 1));
	END
	
	SELECT @LogData = 'Update ' + CASE @Type 
									WHEN 1 THEN 'hold ' 
									WHEN 2 THEN 'confirm Refund '
									WHEN 3 THEN 'confirm Refund SDT'
									ELSE '' END
						+ 'result setting of MatchID = ' + CAST(@MatchId AS VARCHAR(20)) + ' with ResourceIDs = ' + @ResourceIds

	EXEC dbo.WriteLog_UserLog @UserID = @AdminId, @Doing = @LogData


	SELECT @Remark = CASE @Type WHEN 1 THEN 'Turn ' + CASE WHEN @IsEnabled = 1 THEN 'on ' ELSE 'off ' END + 'result hold: '
											+ CAST(@MatchId AS VARCHAR) + '(' + @ResourceIds + ')'

								WHEN 2 THEN 'NAP: Update Confirm-Refund ' + CASE @IsEnabled WHEN 0 THEN 'OFF ' ELSE  'ON ' END
											+ '(' + @ResourceIds + ')'
								WHEN 3 THEN 'NAP: Update Confirm-Refund-SDT ' + CASE @IsEnabled WHEN 0 THEN 'OFF ' ELSE  'ON ' END
											+ ISNULL(@RemarkSDT,'')
											+ IIF(@Is3x3 = 1,' Is3x3','')
								ELSE '' END
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
			@UserID             = @AdminId
			,@Matchid           = @matchid
			,@ActionID			= @ActionID
			,@Remark            = @Remark
			,@IP                = @IP
	END TRY
	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

		EXEC DBTXN.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
			@UserID             = @AdminId
			,@Matchid           = @matchid
			,@ActionID          = @ActionID
			,@Remark            = @Remark
			,@IP                = @IP
	END CATCH


END

GO