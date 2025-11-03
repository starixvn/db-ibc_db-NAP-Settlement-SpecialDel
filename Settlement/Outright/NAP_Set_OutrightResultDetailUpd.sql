/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_OutrightResultDetailUpd]
(
	 @Leagueid INT
	,@UserId INT 
	,@SelectedResources VARCHAR(MAX)
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
)
AS 
/*
    Created by: 20250923@Hughie
    Task: Confirm Score 
    DB: DBPRO/BODB02 
    
    Revisions:
		-20250923@Hughie: Apply SOP for Outright Phase 2 [Readmine:#233004]
		-20251022@Hughie: Enhance SOP Outright Phase 3 [Readmine:#241793]

	Param's Explanation:
		@SelectedResources: <Resources>
						    	<Resource Orid="123324" Teamid="101" Result="WON" />					    	
						      </Resources>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpAllResult TABLE (
									Orid INT
									,Teamid	INT
									,Result	VARCHAR(10)
                                    ,IsDeadHeat BIT
									,ResultStatusId TINYINT
								)

	DECLARE @xmlResults XML
	
	SET @xmlResults = CAST(@SelectedResources AS XML)
	

	INSERT INTO @tmpAllResult(Orid, Teamid, Result, IsDeadHeat, ResultStatusId)
	SELECT 
			    T.c.value('@Orid', 'INT') as Orid
			    ,T.c.value('@Teamid', 'INT') as Teamid
			    ,T.c.value('@Result', 'VARCHAR(10)') as Result
                ,T.c.value('@IsDeadHeat', 'BIT') as IsDeadHeat
				,T.c.value('@ResultStatusId', 'TINYINT') as ResultStatusId
	        FROM @xmlResults.nodes('Resources/Resource') T(c)

	BEGIN TRY				
	IF EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetailOutright r WITH(ROWLOCK)
				INNER JOIN @tmpAllResult tmp 
					ON r.leagueid = @Leagueid AND r.Orid = tmp.Orid
				WHERE r.ResultStatusId IN ( 2, 5 )
				)
	BEGIN
		SELECT @ErrCode	 = 1001051
				,@ErrMsg = 'WARNING! Cannot continue due to selected results are settled.'
		RETURN
	END	

	MERGE dbo.ResultDetailOutright TARGET
	USING (
			SELECT  r.orid, r.Teamid, r.Result, r.IsDeadHeat, r.ResultStatusId
			FROM    @tmpAllResult r
		) AS SOURCE ON TARGET.Orid = SOURCE.Orid AND TARGET.leagueid = @leagueid						
	WHEN MATCHED AND TARGET.ResultStatusId NOT IN ( 2, 5 ) AND TARGET.SettlementStatusID = 0 THEN 
			UPDATE SET Result = SOURCE.Result
						,ResultStatusId	= SOURCE.ResultStatusId
                        ,IsDeadHeat = SOURCE.IsDeadHeat
						,ModifiedDate = GETDATE()
						,ModifiedBy   = @UserId
						,RepUpdateTime = dbo.f_GetDateTime2()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (Orid, Leagueid, Teamid, Result, ResultStatusID, SettlementStatusID, IsDeadHeat ,CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, RepUpdateTime)               
		VALUES (SOURCE.Orid, @Leagueid, SOURCE.Teamid, SOURCE.Result,SOURCE.ResultStatusId, 0, SOURCE.IsDeadHeat, @UserId, GETDATE(), @UserId, GETDATE(), dbo.f_GetDateTime2());

	END TRY

	BEGIN CATCH
		SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
         RETURN
	END CATCH
END
