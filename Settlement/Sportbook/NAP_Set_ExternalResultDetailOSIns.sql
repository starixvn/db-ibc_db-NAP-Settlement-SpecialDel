/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ExternalResultDetailOSIns
(
	 @MatchId INT   
	,@UserId INT 
	,@OutsideSources	VARCHAR(MAX)
	,@Sources			VARCHAR(MAX) =''
	,@IP				varchar(15)	 =''
	,@IsTrader			BIT			 = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
)
AS 
/*
    Created by: 20210305@Louisa
    Task: Insert OutsideSource result [Readmine:#150425]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20210305@Louisa: SOP for Tennis [Readmine:#150425]
		- 20210504@Louisa: Save Cricket results [Redmine:#154472]
		- 20210506@Louisa: SOP for Cricket [Redmine:#153915]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20220629@Louisa: Volleyball AIO [Redmineid:#173862]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]

	Param's Explanation:
		@OutsideSources : any scores(OutsideSource) have changed by user

		@Sources		: record all scores to write log

		@OutsideSources	VARCHAR(MAX)	 =
						'<Sources>
							<Source SourceId= "1001"  ResourceId = "01" HomeValue="2" AwayValue="3"/>
							<Source SourceId= "1002"  ResourceId = "02" HomeValue="2" AwayValue="4"/>
						</Sources>'

		@Sources VARCHAR(MAX)	 =
						'<Sources>
								<Source SourceId= ""	 ResourceId = "01" HomeValue="2" AwayValue="3"/>
								<Source SourceId= "100"  ResourceId = "01" HomeValue="2" AwayValue="3"/>
								<Source SourceId= "25"   ResourceId = "01" HomeValue="2" AwayValue="3"/>
								<Source SourceId= "1001" ResourceId = "01" HomeValue="2" AwayValue="3"/>
								<Source SourceId= "1002" ResourceId = "01" HomeValue="2" AwayValue="4"/>
						</Sources>

		@IsTrader: 1-Trader
				   0-Keyscore

		If it's Final Result, SourceId= ""
*/

BEGIN
	SET NOCOUNT ON

	DECLARE  @Sporttype	TINYINT
			,@LeagueId	INT
			,@handle	INT
			,@ActionID  INT
			,@Remark	VARCHAR(MAX)
			,@xmlSources XML 
			,@xmlOutsideSources XML
			,@ExternalResultTable TINYINT = 0

	DECLARE @tmpAllResult TABLE (
									SourceId SMALLINT
									, ResourceId VARCHAR(20)
									, HomeValue	VARCHAR(50)
									, AwayValue	VARCHAR(50)
									, IsChanged BIT
								)

	SELECT @Sporttype = m.sporttype
		  ,@LeagueId  = m.leagueid
	FROM dbo.Match m WITH(NOLOCK)
	WHERE m.MatchId = @MatchId

	SELECT @ExternalResultTable = r.ExternalResultTable
	FROM dbo.SettlementResultTableSetting r WITH(NOLOCK)
	WHERE r.Sporttype = @SportType
		AND IsAppliedSOP = 1
		
	IF @SportType = 8
		SELECT @ExternalResultTable = 2

	SELECT @ActionID =  CASE WHEN ISNULL(@IsTrader,0) = 1 THEN 81027 ELSE 81016 END
	
	BEGIN TRY
		IF ISNULL(@Sources,'') <> '' -- record all scores to write log
		BEGIN
				
			SET @xmlSources = CAST(@Sources AS XML)

			INSERT INTO @tmpAllResult ( SourceId, ResourceId, HomeValue, AwayValue, IsChanged)
			SELECT	 T.C.value('@SourceId', 'SMALLINT')		AS SourceId
					,T.C.value('@ResourceId', 'VARCHAR(20)')AS ResourceId
					,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
					,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
					,0										AS IsChanged
			FROM	@xmlSources.nodes('/Sources/Source') AS T(C)

			IF ISNULL( @OutsideSources, '' ) <> '' --- OutsideSources score have changed by user
			BEGIN
				SET @xmlOutsideSources = CAST (@OutsideSources AS XML)

				INSERT INTO @tmpAllResult  ( SourceId, ResourceId, HomeValue, AwayValue, IsChanged) 
				SELECT	 T.C.value('@SourceId', 'SMALLINT')		AS SourceId
				,T.C.value('@ResourceId', 'VARCHAR(20)')AS ResourceId
				,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
				,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
				,1										AS IsChanged
				FROM	@xmlOutsideSources.nodes('/Sources/Source') AS T(C)

				IF @ExternalResultTable = 2
				BEGIN
					INSERT INTO dbo.ProviderExternalResultDetailOS 	(
						MatchId3rd
						,MatchId
						,SourceId
						,ResourceId
						,HomeValue
						,AwayValue
						,CreateBy
						,LastModifyBy
					)
					SELECT 0
						,@MatchId
						,r.SourceId
						,r.ResourceId
						,r.HomeValue
						,r.AwayValue
						,@UserId
						,@UserId
					FROM @tmpAllResult	 r	
					WHERE r.IsChanged = 1
						AND r.SourceId  <> 100 ----[Redmine:#153915]
				END

				IF @ExternalResultTable = 1
				BEGIN
					INSERT INTO dbo.ProviderExternalResultDetail	(
								MatchId3rd
								,MatchId
								,SourceId
								,ResourceId
								,HomeValue
								,AwayValue
								,CreateBy
								,LastModifyBy
							)
							SELECT 0
								,@MatchId
								,r.SourceId
								,r.ResourceId
								,r.HomeValue
								,r.AwayValue
								,@UserId
								,@UserId
							FROM @tmpAllResult	 r	
							WHERE r.IsChanged = 1
				END

				----This block code supports Keyscore save data by themself until they can get data from Admin Site and Weverdat ----[Redmine:#153915]
				IF @Sporttype = 50 
				BEGIN
					
					IF EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetailOS r WITH(ROWLOCK)
								INNER JOIN @tmpAllResult tmp 
									ON r.MatchID = @MatchId AND  r.ResourceID = tmp.ResourceId
								WHERE r.ResultStatusId IN ( 2, 5 )
									AND tmp.SourceId = 100
									AND tmp.IsChanged = 1
								)
					BEGIN
						SELECT @ErrCode	 = 1001051
								,@ErrMsg = 'WARNING! Cannot continue due to selected results are settled.'
						RETURN
					END	

					MERGE dbo.ResultDetailOS TARGET
					USING (
							SELECT  r.ResourceId, r.HomeValue, r.AwayValue
							FROM    @tmpAllResult r
							WHERE r.SourceId = 100
							AND r.IsChanged = 1
						) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid							
					WHEN MATCHED  AND ResultStatusID NOT IN ( 2, 5 ) THEN 
							UPDATE SET HomeValue		= SOURCE.HomeValue
										,AwayValue      = SOURCE.AwayValue
										,ResultStatusId	= 3
										,LastModifyDate = GETDATE()
										,LastModifyBy   = @UserId
					WHEN NOT MATCHED BY TARGET THEN
						INSERT (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
						VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, 3, 0, GETDATE(), GETDATE(), @UserId, @UserId);


					INSERT INTO dbo.ProviderExternalResultDetailOS 	(
						MatchId3rd
						,MatchId
						,SourceId
						,ResourceId
						,HomeValue
						,AwayValue
						,CreateBy
						,LastModifyBy
					)
					SELECT 0
						,@MatchId
						,r.SourceId
						,r.ResourceId
						,r.HomeValue
						,r.AwayValue
						,@UserId
						,@UserId
					FROM @tmpAllResult	 r
					WHERE r.SourceId = 100
							AND r.IsChanged = 1
				END
				-----------------------------------------------------------------------------------------------------------------------------
			END


			IF NOT EXISTS (	SELECT TOP 1 1 FROM ProviderLeagueMappingOutsideSource plmo WITH(NOLOCK) 
												INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)  ON plmo.PGId  = pgm.PGId
											WHERE pgm.SourceId		= 1001	
												AND pgm.GameType	= 0
												AND plmo.LeagueId	= @LeagueId
												AND pgm.sporttype   = @Sporttype )
				BEGIN				
					EXEC dbo.NAP_Set_OutsideSourceByLeagueIns --- Init Source 1001 and mapping with GameType and League if 1001 does not exists
						@LeagueId		= @LeagueId
						,@PGIdSources	= '<PGIds><PGId PGId ="0"  OrderNo="1"/></PGIds>'
						,@ErrCode		=	@ErrCode			
						,@ErrMsg		=	@ErrMsg			
				END

		END

			
			;WITH cte_Log ( Result ) AS 
				(
					SELECT DISTINCT CASE ResourceId WHEN '00' THEN 'Z' ELSE ResourceId END -- to order FullTime at the last
							+ STUFF(
									 (
										 SELECT '' 
												+ CASE  WHEN l1.SourceId = 0 THEN ''
														WHEN l1.SourceId = 100 AND @IsTrader = 1 THEN ''
								  						ELSE CAST( l1.SourceId AS VARCHAR(5)	)
												  END	
												+ '('
												+ CASE WHEN l1.HomeValue = '' AND  l1.AwayValue = '' THEN '-'
													   WHEN l1.AwayValue = '' AND @Sporttype = 50 THEN l1.HomeValue
													   ELSE  l1.HomeValue + '-'+ l1.AwayValue 
													END
												+ ')'
								  
										 FROM @tmpAllResult as l1 
										 WHERE l1.ResourceId = l2.ResourceId
											AND  l1.IsChanged = 0
										 FOR XML PATH ('')
									 )
									 , 1, 0, ''
								   )
					FROM @tmpAllResult  l2
					WHERE l2.IsChanged = 0
				)

			SELECT @Remark = (SELECT TOP 1 REPLACE ( 
													 STUFF (  (SELECT  ',<br/>' + Result FROM cte_Log   FOR XML PATH, type).value('.','varchar(max)') , 1 , 6, ''  ) 
													 , 'Z','FT'
													)   FROM cte_Log )
				
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@userid				= @UserId
				,@matchid			= @MatchId
				,@actionid			= @ActionID
				,@finalhomescore	= NULL
				,@finalawayscore	= NULL
				,@hthomescore		= NULL
				,@htawayscore		= NULL
				,@GoalRecord		= NULL
				,@Remark			= @Remark
				,@ip				= @IP

	END TRY

	BEGIN CATCH
		SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
         RETURN
	END CATCH

END
GO