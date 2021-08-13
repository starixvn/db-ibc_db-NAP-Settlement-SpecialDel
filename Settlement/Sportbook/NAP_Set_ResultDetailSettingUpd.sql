/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ResultDetailSettingUpd
	@MatchId	INT
	,@Type		TINYINT
	,@ResourceIds VARCHAR(MAX)  = ''
	,@IsEnabled BIT
	,@AdminId	INT
	,@IP		VARCHAR(20)	= ''

AS
/*
	Created by: 20201113@Louisa
	Task : Update Result Setting [Redmine:#135097]
	DB: DBPRO/bodb02

	Revisions:
		- 220201113@Louisa: Update Result Setting - Apply for Soccer, Basketball, Badminton, E-Sports[Redmine:#135097]
		- 20210201@Louisa: Cricket AIO - Early bettype [Redmine:#148870]
		- 20210811@Louisa: SOP Refund for Tennis, E-Sports [Redmine:#159270]
		
	Parameters Explanation:    
		@Type: TINYINT
			 1: Hold Result
			 2: Confirm Refund

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
								
	DECLARE @tmpResultDetail TABLE ( ResourceId	VARCHAR(20)	)

	SELECT	@ActionId = CASE	WHEN @Type = 1 THEN 81021
								WHEN @Type = 2 THEN 81032
								ELSE NULL
						 END
	SELECT @SportType = m.sporttype FROM dbo.Match m WITH(NOLOCK) WHERE m.matchid  = @MatchId

	IF @ActionId IS NULL OR ( @Type = 2 AND @SportType NOT IN ( 5, 43 ) )
	RETURN

	SELECT @ResultTable =  f.ResultTable FROM [dbo].[f_Set_SettingByProfile] (@Sporttype) f
							/*@ResultTable:
								 1: ResultDetail
								 2: ResultDetailOS
								 3: ResultDetailES
							*/

	INSERT INTO @tmpResultDetail ( ResourceId)
	SELECT DISTINCT
	sp.ResourceID
	FROM DBTXN.bodb02.dbo.SettlementSpecialBettypeProfile sp  WITH (NOLOCK)
		INNER JOIN f_SplitString(@ResourceIds,',') fs ON sp.ResourceID = fs.val
		AND sp.SportType  = @SportType
	OPTION (maxrecursion 0)

	IF @@ROWCOUNT> 0 
	BEGIN

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
										ELSE '' END
							+ 'result setting of MatchID = ' + CAST(@MatchId AS VARCHAR(20)) + ' with ResourceIDs = ' + @ResourceIds

		EXEC dbo.WriteLog_UserLog @UserID = @AdminId, @Doing = @LogData


		SELECT @Remark = CASE @Type WHEN 1 THEN 'Turn ' + CASE WHEN @IsEnabled = 1 THEN 'on ' ELSE 'off ' END + 'result hold: '
												+ CAST(@MatchId AS VARCHAR) + '(' + @ResourceIds + ')'

									WHEN 2 THEN 'NAP: Update Confirm-Refund ' + CASE @IsEnabled WHEN 0 THEN 'OFF ' ELSE  'ON ' END
												+ '(' + @ResourceIds + ')'
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
END
GO
