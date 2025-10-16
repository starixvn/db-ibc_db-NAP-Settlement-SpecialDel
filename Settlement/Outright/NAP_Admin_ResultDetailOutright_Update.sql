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
		- 20250805@Hughie: Apply SOP for Outright phase 2 [Redmine:#233004]

	Param's Explanation:

*/
BEGIN

SET NOCOUNT ON

	DECLARE @LeagueId INT

	SELECT @LeagueId = leagueid 
	FROM outright WITH (NOLOCK)
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
						,TARGET.SettledBy			= @AdminID
						,TARGET.RepUpdateTime		= dbo.f_GetDateTime2()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT(
			Orid
			,Leagueid
			,Teamid
			,Result
			,ResultStatusID
			,SettlementStatusID
			,IsDeadheat
			,SettledBy
			,RepUpdateTime
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
			,dbo.f_GetDateTime2()
		);

	IF EXISTS (SELECT 1 FROM ResultDetailOutright r WITH (NOLOCK) WHERE leagueid = @LeagueId AND r.Orid = @Orid AND Result = 'WON')
	BEGIN
		UPDATE r WITH (UPDLOCK,ROWLOCK)
		SET r.SumWon = (SELECT COUNT(1) FROM ResultDetailOutright WITH (NOLOCK) WHERE leagueid = @LeagueId AND Result = 'WON' AND ResultStatusID IN (2,5))
			,r.RepUpdateTime = dbo.f_GetDateTime2()
		FROM ResultDetailOutright r
		WHERE r.leagueid = @LeagueId AND r.Result = 'WON' AND ResultStatusID IN (2,5)
	END
	ELSE IF EXISTS (SELECT 1 FROM ResultDetailOutright r WITH (NOLOCK) WHERE leagueid = @LeagueId AND r.Orid = @Orid AND Result <> 'WON')
	BEGIN
		UPDATE r WITH (UPDLOCK,ROWLOCK)
		SET r.SumWon = 0
			,r.RepUpdateTime = dbo.f_GetDateTime2()
		FROM ResultDetailOutright r
		WHERE r.leagueid = @LeagueId AND r.Orid = @Orid AND r.Result <> 'WON'
	END

END
GO

