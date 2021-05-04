/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_ExternalResultDetailOSIns_UAT2
(
	 @MatchId INT   
	,@UserId INT 
	,@OutsideSources	VARCHAR(MAX)
	,@Sources			VARCHAR(MAX) =''
	,@IP				varchar(15)	 =''
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

		If it's Final Result, SourceId= ""
*/

BEGIN
	SET NOCOUNT ON

	DECLARE  @Sporttype	TINYINT
			,@LeagueId	INT
			,@handle	INT
			,@ActionID  INT = 81016 ---Save Score
			,@Remark	VARCHAR(MAX)
			,@xmlSources XML 
			,@xmlOutsideSources XML

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

				IF (@Sporttype = 50)
				BEGIN

				END

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

					END


				IF NOT EXISTS (	SELECT TOP 1 1 FROM ProviderLeagueMappingOutsideSource plmo WITH(NOLOCK) 
													INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)  ON plmo.PGId  = pgm.PGId
												WHERE pgm.SourceId		= 1001	
													AND pgm.GameType	= 0
													AND plmo.LeagueId	= @LeagueId
													AND @Sporttype <> 50 )
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
												+ CASE l1.SourceId 
								  						WHEN 0 THEN ''
								  						ELSE CAST( l1.SourceId AS varchar(5)	)
												  END	+'('+ l1.HomeValue + '-'+ l1.AwayValue + ')'
								  
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