/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ExternalResultDetailUpd]
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

	Param's Explanation:
		@SelectedResources: <Resources>
						    	<Resource Id="01" Home="2" Away="3" />
						    	<Resource Id="00" Home="3" Away="4" />
						      </Resources>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpAllResult TABLE (
									 ResourceId VARCHAR(20)
									, HomeValue	VARCHAR(50)
									, AwayValue	VARCHAR(50)
								)

	DECLARE @xmlResults XML
	
	SET @xmlResults = CAST(@SelectedResources AS XML)
	

	INSERT INTO @tmpAllResult(ResourceId, HomeValue, AwayValue)
	SELECT 
			    T.c.value('@Id', 'VARCHAR(20)') as Id
			    ,T.c.value('@Home', 'VARCHAR(50)') as HomeValue
			    ,T.c.value('@Away', 'VARCHAR(50)') as AwayValue
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
			SELECT  r.ResourceId, r.HomeValue, r.AwayValue
			FROM    @tmpAllResult r
		) AS SOURCE ON TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid							
	WHEN MATCHED AND ResultStatusID NOT IN ( 2, 5 ) AND SettlementStatusID = 0 THEN 
			UPDATE SET HomeValue		= SOURCE.HomeValue
						,AwayValue      = SOURCE.AwayValue
						,ResultStatusId	= 3
						,LastModifyDate = GETDATE()
						,LastModifyBy   = @UserId
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
		VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, 3, 0, GETDATE(), GETDATE(), @UserId, @UserId);

	END TRY

	BEGIN CATCH
		SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
         RETURN
	END CATCH
END
