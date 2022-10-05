/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_ScheduleSel
	@sporttype TINYINT = 1
AS
/*
	Creator: 20201216@Louisa
	Task: Auto refund ET & PEN match [Redmine:#145597]
	DB: DBPRO/bodb02
	Revisions:
		- 20201216@Louisa: Get ET & PEN match for Auto Refund Service [Redmine:#145597]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220512@Louisa: Auto Refund for Badminton [Redmine:#171676]
		- 20220929@Louisa: check deployment flag [Redmine:#175251]
*/
BEGIN
	
	SET NOCOUNT ON

	DECLARE @procName SYSNAME	= OBJECT_NAME(@@procid)
			,@IsWaiting BIT = 0
	
	DECLARE  @returntable TABLE (MatchId INT, leagueid INT, TypeId TINYINT, ResourceId VARCHAR(20), ResultStatusID TINYINT)

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT MatchId, leagueid, TypeId, ResourceId, ResultStatusID
		FROM @returntable

		RETURN
	END


	IF @sporttype = 1
	BEGIN
		INSERT INTO @returntable (MatchId, leagueid, TypeId, ResourceId, ResultStatusID)
		SELECT ar.MatchId
			 , m.leagueid
			 , ar.TypeId
			 , '00' AS ResourceId
			 , NULL AS ResultStatusID
		FROM dbo.AutoRefundResult ar WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = ar.matchid
		WHERE m.sporttype = 1
			AND ar.SourceId = 105
			AND ar.StatusId = 0
			AND ar.TypeId = 1
	END

	ELSE
	BEGIN
		INSERT INTO @returntable (MatchId, leagueid, TypeId, ResourceId, ResultStatusID)
		SELECT ar.MatchId
			 , m.leagueid
			 , ar.TypeId
			 , ar.ResourceId
			 ,ISNULL(r.ResultStatusID, 0) AS  ResultStatusID
		FROM dbo.AutoRefundResultOS ar WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = ar.matchid
			OUTER APPLY (	SELECT r.ResultStatusID FROM dbo.ResultDetailOS r (NOLOCK)
							WHERE  ar.MatchId = r.MatchId AND ar.ResourceId = r.ResourceId
						) r
		WHERE m.sporttype = @sporttype
			AND ar.StatusId = 0
			AND ar.TypeId = 1
	END

	SELECT MatchId, leagueid, TypeId, ResourceId, ResultStatusID
	FROM @returntable

END
GO

