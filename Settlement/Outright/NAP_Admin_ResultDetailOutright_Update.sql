/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_ResultDetailOutright_Update]
(
	@Orid			INT	
	,@Status		VARCHAR(10)     = ''
	,@IsDeadheat	BIT				= 0 
	,@AdminID		INT				= 5838421
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

	DECLARE @LeagueId INT

	SELECT @LeagueId = leagueid 
	FROM outright 
	WHERE orid = @Orid

	MERGE dbo.ResultDetailOutright TARGET
	USING (
			SELECT	o.leagueid
					,o.teamid
					FROM outright o WITH (NOLOCK)
					WHERE o.Orid = @Orid
					GROUP BY o.leagueid, o.teamid
		) AS SOURCE ON TARGET.Orid = @Orid					
	WHEN MATCHED THEN 
			UPDATE SET	TARGET.Result				= @Status
						,TARGET.ResultStatusId		= 5
						,TARGET.SettlementStatusID	= 4
						,TARGET.IsDeadheat			= @IsDeadheat
						,TARGET.ModifiedDate		= GETDATE()
						,TARGET.ModifiedBy			= @AdminID
	WHEN NOT MATCHED BY TARGET THEN
		INSERT(
			Orid
			,Leagueid
			,Teamid
			,Result
			,ResultStatusID
			,SettlementStatusID
			,IsDeadheat
			,CreatedBy
			,CreatedDate
			,ModifiedBy
			,ModifiedDate
		)               
		VALUES(
			@Orid
			,SOURCE.Leagueid
			,SOURCE.Teamid
			,@Status
			,5 -- Manual Settlement
			,4 -- Completed
			,@IsDeadheat
			,@AdminID
			,GETDATE()
			,@AdminID
			,GETDATE()
		);

	IF EXISTS (SELECT 1 FROM ResultDetailOutright WHERE leagueid = @LeagueId AND Result = 'WON')
	BEGIN
		UPDATE r WITH (UPDLOCK,ROWLOCK)
		SET r.SumWon = (SELECT COUNT(1) FROM ResultDetailOutright WHERE leagueid = @LeagueId AND Result = 'WON')
		FROM ResultDetailOutright r
		WHERE r.leagueid = @LeagueId AND r.Result = 'WON'
	END
	ELSE
	BEGIN
		UPDATE r WITH (UPDLOCK,ROWLOCK)
		SET r.SumWon = 0
		FROM ResultDetailOutright r
		WHERE r.leagueid = @LeagueId AND r.Result <> 'WON'
	END

END
GO

