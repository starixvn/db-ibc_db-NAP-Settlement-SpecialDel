/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		- 20220929@Louisa: check deployment flag [Redmine:#178765]
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]
		- 20230328@Aries: Support Auto Payout for Main Tennis Matches [Redmine: #182329]
		- 20230616@Aries: Support Direct Payout for Soccer Fantasy Matches [Redmine:#189493]
		- 20230808@Aries: Enhance Auto Refund for Tennis Matches [Redmine:#189433]
		- 20240614@Aries: Add fantasy leagueId [Redmine:#206489]
		- 20240621@Aries: Enhance Auto Refund to add waiting time [Redmine:#206153]
		- 20241002@Aries: Support a tool to add leagues for Direct Payout [Redmine:#211265]
*/
BEGIN
	
	SET NOCOUNT ON

	DECLARE @procName SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting BIT = 0
	
	DECLARE  @returntable TABLE (MatchId INT,ParentID INT,  leagueid INT, TypeId TINYINT,SourceId TINYINT, ResourceId VARCHAR(20), ResultStatusID TINYINT, SettlementStatusId TINYINT, CreateDate DATETIME)
	DECLARE @tblLeagueID		TABLE(LeagueId INT)

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
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
		INSERT INTO @tblLeagueID(LeagueId)
		SELECT LeagueId
		FROM SettlementSetting WITH(NOLOCK)
		WHERE AutoType = 9

		INSERT INTO @returntable (MatchId, leagueid, TypeId, ResourceId, ResultStatusID,CreateDate)
		SELECT ar.MatchId
			 , m.leagueid
			 , ar.TypeId
			 , '00' AS ResourceId
			 , NULL AS ResultStatusID
			 , ar.CreateDate
		FROM dbo.AutoRefundResult ar WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = ar.matchid
			LEFT JOIN @tblLeagueID AS l  ON l.leagueid = m.leagueid
		WHERE m.sporttype = 1
			AND ar.SourceId = 105
			AND ar.StatusId = 0
			AND ar.TypeId = 1
			AND l.leagueid IS NULL -- Exclude Fantasy Match
	END
	ELSE IF @sporttype = 5
	BEGIN
		INSERT INTO @returntable (MatchId,ParentID, leagueid, TypeId,SourceId, ResourceId, ResultStatusID, SettlementStatusId,CreateDate)
		SELECT ar.MatchId
			 , m.ParentID
			 , m.leagueid
			 , ar.TypeId
			 , ar.SourceId
			 , ar.ResourceId
			 ,ISNULL(r.ResultStatusID, 0) AS  ResultStatusID
			 ,ISNULL(r.SettlementStatusID,0) AS SettlementStatusID
			 , ar.CreateDate
		FROM dbo.AutoRefundResultOS ar WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = ar.matchid
			OUTER APPLY (	SELECT r.ResultStatusID, r.SettlementStatusID FROM dbo.ResultDetail r (NOLOCK)
							WHERE  ar.MatchId = r.MatchId AND ar.ResourceId = r.ResourceId
						) r
		WHERE m.sporttype = @sporttype
			AND ar.StatusId = 0
			AND ar.TypeId = 1
	END
	ELSE
	BEGIN
		INSERT INTO @returntable (MatchId, leagueid, TypeId, ResourceId, ResultStatusID, SettlementStatusId,CreateDate)
		SELECT ar.MatchId
			 , m.leagueid
			 , ar.TypeId
			 , ar.ResourceId
			 ,ISNULL(r.ResultStatusID, 0) AS  ResultStatusID
			 ,ISNULL(r.SettlementStatusID,0) AS SettlementStatusID
			 , ar.CreateDate
		FROM dbo.AutoRefundResultOS ar WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = ar.matchid
			OUTER APPLY (	SELECT r.ResultStatusID, r.SettlementStatusID FROM dbo.ResultDetailOS r (NOLOCK)
							WHERE  ar.MatchId = r.MatchId AND ar.ResourceId = r.ResourceId
						) r
		WHERE m.sporttype = @sporttype
			AND ar.StatusId = 0
			AND ar.TypeId = 1
	END

	DECLARE @CurrTime DATETIME = GETDATE()

	SELECT m.MatchId,m.ParentID, @sporttype AS Sporttype, m.leagueid, m.TypeId,m.SourceId, m.ResourceId, m.ResultStatusID, m.SettlementStatusId
	FROM @returntable AS m
		OUTER APPLY(
			SELECT TOP 1 ssr.WaitingTime
			FROM dbo.SettlementSetting AS ssr WITH (NOLOCK)
			WHERE ssr.LeagueId = m.LeagueId
				AND ssr.AutoType = 7
		) AS ssr
	WHERE  m.CreateDate <= DATEADD(SECOND, - ISNULL(ssr.WaitingTime,0), @CurrTime)

END
GO

