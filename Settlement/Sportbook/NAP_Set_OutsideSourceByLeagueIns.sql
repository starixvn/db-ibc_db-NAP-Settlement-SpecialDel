/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROC [dbo].[NAP_Set_OutsideSourceByLeagueIns]
(
	 @LeagueId	INT
	,@PGIdSources VARCHAR(MAX)
	,@ErrCode	INT				= 0		OUTPUT
	,@ErrMsg	NVARCHAR(200)	= ''	OUTPUT
)
AS
/*
    Created by: 20200805@Louisa
    Task: SORT TOP 4 OutsideSource by LeagueId [Redmine:#138656]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200805@Louisa: SORT TOP 4 OutsideSource by LeagueId [Redmine:#138656]
		- 20210305@Louisa: SOP for Tennis [Readmine:#150425]

	Param explanation:
					PGId ="0" : The first time mapping for Screenshot and League
	@PGIdSources =  '<PGIds><PGId PGId ="0"  OrderNo="1"/>
 							 <PGId PGId ="45" OrderNo="2"/>
 							 <PGId PGId ="48" OrderNo="3"/>
 							 <PGId PGId ="30" OrderNo="4"/>
 				    </PGIds>'	
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @handle	INT
			,@GameType TINYINT
			,@Sporttype	TINYINT

	DECLARE @tmpLeagueMapping TABLE (PGId INT, [OrderNo] INT)
	
	SELECT @GameType =  CASE WHEN l.sporttype= 43 THEN l.OverTimeSession ELSE 0 END
						,@Sporttype = l.sporttype
						FROM League l WITH(NOLOCK)
						WHERE l.LeagueId = @LeagueId


	BEGIN TRY
		EXEC sp_xml_preparedocument @handle OUTPUT, @PGIdSources
		
		INSERT INTO  @tmpLeagueMapping  (	PGId ,  OrderNo  )
			SELECT PGId , OrderNo 
			FROM OPENXML(@handle,'PGIds/PGId',1) WITH(  PGId	 INT
														,OrderNo INT
													) AS tbl 
		EXEC sp_xml_removedocument @handle

		IF EXISTS(SELECT TOP 1 1 FROM @tmpLeagueMapping)
		BEGIN
			
			IF EXISTS ( SELECT PGId FROM @tmpLeagueMapping WHERE PGId = 0)
				BEGIN			
					DECLARE @GameTypes VARCHAR(MAX) = ''

					SELECT @GameTypes  = CASE WHEN @Sporttype =43 THEN '<GameTypes><GameType Id= "'+CAST(@GameType AS VARCHAR(2)) +'" Remark="" IsActive="1" /></GameTypes>'
											ELSE ''
										END
			
					EXEC [dbo].[NAP_Set_ProviderGameTypeMapping] 
						 @SourceId	 = 1001
						,@Sporttype	 = @Sporttype
						,@SourceName ='Screenshot'
						,@Remark	 = 'n/a'
						,@IsActive	 = 1
						,@GameTypes  = @GameTypes
						,@ErrCode	 = @ErrCode	
						,@ErrMsg	 = @ErrMsg
					
					INSERT INTO @tmpLeagueMapping	(PGId ,  OrderNo  )
						SELECT pgm.PGId , 1 
						FROM ProviderGameTypeMapping pgm  WITH(NOLOCK)
						WHERE pgm.SourceId = 1001 	
							AND pgm.GameType = @GameType
							AND pgm.sporttype = @Sporttype						 													 												 		 
				END

			;WITH cte_Source
			AS
			(
				SELECT	 @LeagueId AS LeagueId
						,PGId
						,OrderNo
				FROM	@tmpLeagueMapping
				WHERE	PGId <> 0

			)

			MERGE dbo.ProviderLeagueMappingOutsideSource  AS Target
			USING (SELECT LeagueId, PGId, OrderNo FROM cte_Source ) AS SOURCE
				ON	TARGET.LeagueId = SOURCE.LeagueId
					AND Target.PGId = SOURCE.PGId
			WHEN MATCHED THEN 
				UPDATE SET Target.OrderNo = SOURCE.OrderNo
			WHEN NOT MATCHED BY TARGET THEN
				INSERT (LeagueId, PGId, OrderNo)
				VALUES (SOURCE.LeagueId, SOURCE.PGId, SOURCE.OrderNo)
			WHEN NOT MATCHED BY SOURCE and Target.LeagueId = @LeagueID THEN
				DELETE;
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrMsg   = ISNULL(@ErrMsg,'') + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
		 RETURN
	END CATCH
END
GO



