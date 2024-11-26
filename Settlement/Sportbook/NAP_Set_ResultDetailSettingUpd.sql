/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		- 20230515@Aries: Apply Settle Instant for Basketball [Redmine:#184124]
		- 20230915@Louisa: Remove code WriteLog_UserLog [Redmine:#193920]
		- 20231002@Louisa: Integrate sporttype 58-Bandy [Redmine: #196041]
		- 20240510@Aries: Enhance SOP-Refund for Soccer's Early results [Redmine:#201462]
		- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100] 
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		- 20241111@Louisa: Refund SDT Baseball (Mercyrule) - [Redmine:#212365]
		
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
			,@Remark			VARCHAR(500)
			,@ResultTable		TINYINT	= 0
			,@ExternalResultTable TINYINT	= 0	
			,@handle			INT
			,@RemarkSDT			VARCHAR(500) = ''
			,@IsValidateSOPRefund BIT = 0
								
	DECLARE @tmpResultDetail TABLE ( ResourceId	VARCHAR(20)	)
	DECLARE @tmpResourcesWeb TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))

	SELECT	@ActionId = CASE	WHEN @Type = 1 THEN 81021
								WHEN @Type IN (2,3) THEN 81032
								ELSE NULL
						 END
	SELECT @SportType = m.sporttype FROM dbo.Match m WITH(NOLOCK) WHERE m.matchid  = @MatchId

	SELECT @ResultTable =  r.ResultTable 
			,@ExternalResultTable = r.ExternalResultTable
			,@IsValidateSOPRefund = ISNULL(r.Setting,0) & 1
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK) 
	WHERE r.Sporttype = @SportType
	/*@ResultTable:
			1: ResultDetail
			2: ResultDetailOS
			3: ResultDetailES
	*/
 
	IF @ActionId IS NULL OR ( @Type = 2 AND @IsValidateSOPRefund = 0 )
	RETURN

	IF @SportType IN (18,58) --get all ResourceID from web
	BEGIN
		INSERT INTO @tmpResultDetail ( ResourceId)
		SELECT DISTINCT	fs.value FROM STRING_SPLIT(@ResourceIds,',') fs
	END
	ELSE
	BEGIN ---get ResourceID has offer bettype
		;WITH cteResourceIds
		AS (
			SELECT	fs.value AS ResourceID
			FROM	STRING_SPLIT(@ResourceIds,',') fs
		)
		,cteResourceOffer
		AS (
			SELECT DISTINCT sp.ResourceID
			FROM	dbo.SettlementSpecialBettypeProfile sp  WITH (NOLOCK)
				INNER JOIN cteResourceIds fs  
					ON	sp.ResourceID = fs.ResourceID
						AND sp.SportType  = @SportType
			UNION 
			SELECT	ResourceID
			FROM	cteResourceIds
			WHERE	@SportType = 8
					AND ResourceID = '0109'
		)
		INSERT INTO @tmpResultDetail(ResourceId)
		SELECT	ResourceID
		FROM	cteResourceOffer
	END

	IF @Type = 3 OR ISNULL(@SelectedResources,'') != ''
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
            SELECT @RemarkSDT = STRING_AGG (ResourceId + '(' + HomeValue + '-' + AwayValue  + ')',', ')
			FROM @tmpResourcesWeb

			IF @ExternalResultTable = 1
			BEGIN
				DELETE p
				FROM dbo.ProviderExternalResultDetail AS p
				WHERE p.MatchId = @MatchId 
					AND p.SourceId = 99 -- Remove old confirm
					AND p.ResourceId IN  (SELECT r.ResourceId FROM @tmpResourcesWeb AS r)

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
			IF @ExternalResultTable = 2
			BEGIN
				DELETE p
				FROM dbo.ProviderExternalResultDetailOS AS p
				WHERE p.MatchId = @MatchId 
					AND p.SourceId = 99 -- Remove old confirm
					AND p.ResourceId IN  (SELECT r.ResourceId FROM @tmpResourcesWeb AS r)

				INSERT INTO dbo.ProviderExternalResultDetailOS (MatchId3rd,MatchId,SourceId,ResourceId,HomeValue,AwayValue,CreateBy,LastModifyBy)
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
		END
		ELSE
		BEGIN
			IF @ExternalResultTable = 1
			BEGIN
				SELECT @RemarkSDT = STRING_AGG (p.ResourceId + '(' + p.HomeValue + '-' + p.AwayValue  + ')',', ')
				FROM dbo.ProviderExternalResultDetail AS p
				WHERE p.MatchId = @MatchId
					AND p.SourceId = 99
					AND p.ResourceId IN  ( SELECT r.ResourceId FROM @tmpResourcesWeb AS r)

				DELETE p
				FROM dbo.ProviderExternalResultDetail AS p
				WHERE p.MatchId = @MatchId 
					AND p.SourceId = 99 -- Remove old confirm
					AND p.ResourceId IN  ( SELECT r.ResourceId FROM @tmpResourcesWeb AS r)
			END
			IF @ExternalResultTable = 2
			BEGIN
				SELECT @RemarkSDT = STRING_AGG (p.ResourceId + '(' + p.HomeValue + '-' + p.AwayValue  + ')',', ')
				FROM dbo.ProviderExternalResultDetailOS AS p
				WHERE p.MatchId = @MatchId
					AND p.SourceId = 99
					AND p.ResourceId IN  ( SELECT r.ResourceId FROM @tmpResourcesWeb AS r)

				DELETE p
				FROM dbo.ProviderExternalResultDetailOS AS p
				WHERE p.MatchId = @MatchId 
					AND p.SourceId = 99 -- Remove old confirm
					AND p.ResourceId IN  ( SELECT r.ResourceId FROM @tmpResourcesWeb AS r)
			END
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
	
	IF @Type IN (2,3) AND @SportType = 2 AND @IsEnabled = 1
	BEGIN 
		IF @SelectedResources IS NULL OR @SelectedResources = ''
		BEGIN
			SET @SelectedResources =   (SELECT [value] AS '@Id'
										FROM STRING_SPLIT(@ResourceIds,',') 
										FOR XML PATH('Resource'),root('Resources'))
		END
		EXEC dbo.NAP_Set_AutoPayoutResultUpd 
						@MatchId = @matchid
						,@TypeId = NULL
						,@StatusId = NULL 
						,@IsUndoMatch = 1 
						,@SportType = @SportType
						,@SelectedResources = @SelectedResources
						,@IsConfirm = 1
	END

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