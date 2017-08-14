/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_OutrightSettlementActionIns_ByListOutrights
	@OrIds			VARCHAR(MAX)
	,@ActionType	TINYINT
	
	,@ErrCode		INT 			= 0		OUTPUT
	,@ErrMsg		VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created: 20170809@Kathy
	DB: DBPRO/bodb02
	Task: Insert result into Intg_OddsFeed_SettlementAction_Outright to log Outright Settlement Action [Redmine:#80704]
	
	Revisions:
		-20170809@Kathy: Create new SP [Redmine:#80704]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Status VARCHAR(10)
			,@IsDeadheat BIT
			,@DeadHeat	TINYINT
			
	DECLARE @tmpOutrightResults TABLE (
		Orid			INT
		,LeagueId		INT
		,TeamId			INT
		,ActionType		TINYINT		
	)
	
	SELECT @Status = ''
		,@IsDeadheat = 0
		,@DeadHeat = 1
		
	BEGIN TRY
		INSERT INTO @tmpOutrightResults (Orid, LeagueId, TeamId, ActionType)
		SELECT	o.orid
				,o.leagueid
				,o.teamid
				,@ActionType
		FROM	dbo.outright o WITH(ROWLOCK)
			INNER JOIN dbo.f_SplitString(@Orids, ',') f
				ON o.orid = f.val
		OPTION (MAXRECURSION 0)
		
		;WITH cteMaxTStamp
		AS(
			SELECT OrId, MAX(TStamp) AS maxTStamp
			FROM dbo.Intg_OddsFeed_SettlementAction_Outright WITH (NOLOCK)
			WHERE OrId IN (SELECT Orid FROM @tmpOutrightResults)
			GROUP BY OrId
		)
		,cteOrIds
		AS(
			SELECT	i.OrId, i.ActionType, i.Status, i.IsDeadheat, i.Deadheat
			FROM	dbo.Intg_OddsFeed_SettlementAction_Outright i WITH(NOLOCK)
			WHERE	EXISTS (SELECT TOP 1 1 FROM cteMaxTStamp c WHERE i.OrId = c.OrId AND i.TStamp = c.maxTStamp)
		)
		DELETE t
		FROM @tmpOutrightResults t
		WHERE EXISTS (SELECT	TOP 1 1
						FROM	cteOrIds o
						WHERE	t.Orid = o.OrId
								AND t.ActionType = o.ActionType
								AND @Status = o.Status
								AND @IsDeadheat = o.IsDeadheat
								AND @DeadHeat = o.Deadheat				
			)
			
		INSERT INTO dbo.Intg_OddsFeed_SettlementAction_Outright(LeagueId, OrId, TeamId, ActionType, Status, IsDeadheat, Deadheat, CreateTime)
		SELECT LeagueId, Orid, TeamId, ActionType, @Status, @IsDeadheat, @DeadHeat, GETDATE()
		FROM @tmpOutrightResults
		
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH
END
GO
