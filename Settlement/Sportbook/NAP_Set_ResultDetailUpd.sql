/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ResultDetailUpd]
(
	 @MatchId INT   
	,@UserId INT 
	,@SelectedResources VARCHAR(MAX)
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
)
AS 
/*
    Created by: 20250109@Hughie
    Task: Save Trader Score button 
    DB: DBPRO/BODB02 
    
    Revisions:
		-20250109@Hughie: Create new SP [Readmine:#216004]
		-20251015@Hughie: Player Scores Input Screen [Readmine:#236275]

	Param's Explanation:
		@SelectedResources: <Resources>
						    	<Resource Id="6754545" Home="None" Away="" ResultStatusId="3" OtherInfo ='685250,873970' />
						    	<Resource Id="6762626" Home="Y" Away="" ResultStatusId="3" OtherInfo ='677096,873970' />
						     </Resources>

*/		

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpAllResult TABLE (
									 ResourceId VARCHAR(20)
									, HomeValue	VARCHAR(50)
									, AwayValue	VARCHAR(50)
									, ResultStatusId TINYINT
									, OtherInfo VARCHAR(50)
								)

	DECLARE @xmlResults XML
	
	SET @xmlResults = CAST(@SelectedResources AS XML)

	INSERT INTO @tmpAllResult(ResourceId, HomeValue, AwayValue, ResultStatusId, OtherInfo)
	SELECT 
			    T.c.value('@Id', 'VARCHAR(20)') as Id
			    ,T.c.value('@Home', 'VARCHAR(50)') as HomeValue
			    ,T.c.value('@Away', 'VARCHAR(50)') as AwayValue
				,T.c.value('@ResultStatusId', 'TINYINT') as ResultStatusId
				,T.c.value('@OtherInfo', ' VARCHAR(50)') as OtherInfo
	        FROM @xmlResults.nodes('Resources/Resource') T(c)

	BEGIN TRY				
	IF EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail r WITH(ROWLOCK)
				INNER JOIN @tmpAllResult tmp 
					ON r.MatchID = @MatchId AND  r.ResourceID = tmp.ResourceId
				WHERE r.ResultStatusId IN ( 2, 5 )
				)
	BEGIN
		SELECT @ErrCode	 = 1001051
				,@ErrMsg = 'WARNING! Cannot continue due to selected results are settled.'
		RETURN
	END	

	MERGE dbo.ResultDetail TARGET
	USING (
			SELECT  r.ResourceId, r.HomeValue, r.AwayValue, r.ResultStatusId, r.OtherInfo
			FROM    @tmpAllResult r
		) AS SOURCE ON TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid							
	WHEN MATCHED AND TARGET.ResultStatusID NOT IN ( 2, 5 ) AND SettlementStatusID = 0 THEN 
			UPDATE SET HomeValue		= SOURCE.HomeValue
						,AwayValue      = SOURCE.AwayValue
						,ResultStatusId	= SOURCE.ResultStatusId
						,LastModifyDate = GETDATE()
						,LastModifyBy   = @UserId
						,OtherInfo		= SOURCE.OtherInfo
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy, OtherInfo)               
		VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, SOURCE.ResultStatusId, 0, GETDATE(), GETDATE(), @UserId, @UserId, OtherInfo);

	END TRY

	BEGIN CATCH
		SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
         RETURN
	END CATCH
END
