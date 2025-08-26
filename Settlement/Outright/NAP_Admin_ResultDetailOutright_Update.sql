/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_ResultDetailOutright_Update]
(
	@Orid			INT	
	,@Status		VARCHAR(10)     = ''
	,@IsDeadheat	BIT				= 0 
	,@AdminID		INT				= 5838421
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(200)	= ''	OUTPUT
)
AS
/*
    Created by: 20250825@Hughie
    Task: Update result of Outright [Redmine:#232955]
    DB: DBPRO/BODB02 
    
    Revisions:   
		- 20250805@Hughie: Created [Redmine:#232955]

	Param's Explanation:

*/
BEGIN

SET NOCOUNT ON

	BEGIN TRY				
	IF EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetailOutright r WITH(ROWLOCK)
				WHERE r.Orid = @Orid AND r.ResultStatusId IN (2, 5)
				)
	BEGIN
		SELECT @ErrCode	 = 1001051
				,@ErrMsg = 'WARNING! Cannot continue due to selected results are settled.'
		RETURN
	END	

	MERGE dbo.ResultDetailOutright TARGET
	USING (
			SELECT	o.leagueid
					,o.teamid
					, COUNT(CASE WHEN o.status = 'WON' AND o.IsDeadheat = 1 THEN o.Orid END) AS DeadHeatTeam
					FROM outright o WITH (NOLOCK)
					WHERE o.Orid = @Orid
					GROUP BY o.leagueid, o.teamid
		) AS SOURCE ON TARGET.Orid = @Orid					
	WHEN MATCHED AND ResultStatusID NOT IN (2, 5) AND SettlementStatusID = 0 THEN 
			UPDATE SET Result = @Status
						,ResultStatusId	= 5
						,SettlementStatusID = 4
						,IsDeadheat = @IsDeadheat
						,SumWon = SOURCE.DeadHeatTeam
						,ModifiedDate = GETDATE()
						,ModifiedBy   = @AdminID
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (Orid, Leagueid, Teamid, Result, ResultStatusID, SettlementStatusID, IsDeadheat, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)               
		VALUES (@Orid, SOURCE.Leagueid, SOURCE.Teamid, @Status, 5, 4, @IsDeadheat, @AdminID, GETDATE(), @AdminID, GETDATE());

	END TRY

	BEGIN CATCH
		SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
         RETURN
	END CATCH
END
GO

