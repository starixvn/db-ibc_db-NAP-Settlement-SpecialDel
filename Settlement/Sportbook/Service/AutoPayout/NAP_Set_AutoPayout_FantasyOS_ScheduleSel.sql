/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_FantasyOS_ScheduleSel]
AS
/*	Creator: 20240305@Aries
	Task: Direct Payout for the Fantasy Match of Basketball [Redmine:#199768]
	DB: DBPRO/BODB02
	
	Revisions:
		- 20240305@Aries: Created [Redmine:#199768]
		- 20240422@Aries: Fix a issue due to the insufficient Leagueid of Fantasy matches for Basketball [Redmine:#204170]
		- 20240621@Aries: Enhance Auto Refund to add waiting time [Redmine:#206153]
		- 20240731@Aries: Apply Direct Payout for SABA CLUB FRIENDLY and SABA ENGLISH PREMIER LEAGUE - Virtual FC 24 - 16 Mins Play [Redmine:#208347]
		- 20241001@Aries: Support Direct Payout for Australia NBL - Fantasy Matches [Redmine:#211429]
		- 20241001@Aries: Support Direct Payout for Philippines PBA Governors Cup - Fantasy Matches of Basketball [Redmine:#210967]
		- 20241002@Aries: Support a tool to add leagues for Direct Payout [Redmine:#211265]
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @ProcName			SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime		VARCHAR(10)
			,@IsWaiting			BIT = 0
			,@Currentdate		DATETIME
			,@FromDate			DATETIME
			,@ToDate			DATETIME	

	DECLARE @tblLeagueID		TABLE(LeagueId INT)

	CREATE TABLE #tmpMatch(MatchId INT,LeagueId INT,Sporttype SMALLINT,ResultTable TINYINT, Action  VARCHAR(20), SettlementStatus TINYINT,LastParentCalculateDate DATETIME, TotalResourceFantasy INT, TotalParent INT, IsCnfRefund BIT DEFAULT 0, PRIMARY KEY (MatchId) WITH (IGNORE_DUP_KEY = ON))
	CREATE TABLE #tmpParent(MatchId INT,ParentId INT,Sporttype SMALLINT,ResultTable TINYINT,ParentEventStatus NVARCHAR(100),SettlementStatus TINYINT, IsValid BIT, PRIMARY KEY (MatchId,ParentId) WITH (IGNORE_DUP_KEY = ON))
	CREATE TABLE #tmpParentResource(MatchId INT,ParentId INT,ParentEventStatus NVARCHAR(100),ParentSettlementStatus TINYINT,ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),SettlementStatusID TINYINT,ResultSetting TINYINT,LastModifyDate DATETIME, PRIMARY KEY (MatchId,ParentId,ResourceId) WITH (IGNORE_DUP_KEY = ON))
	CREATE TABLE #tmpSportResource(Sporttype SMALLINT,ResourceId VARCHAR(20), PRIMARY KEY (Sporttype,ResourceId) WITH (IGNORE_DUP_KEY = ON))

	SET @CurrentDate = CAST(GETDATE() AS DATE)
	SELECT	@FromDate = DATEADD(DAY,-1,@CurrentDate)
		   ,@ToDate = DATEADD(DAY,1,@CurrentDate)

	INSERT INTO @tblLeagueID(LeagueId)
	SELECT LeagueId
	FROM SettlementSetting WITH(NOLOCK)
	WHERE AutoType = 10

	INSERT INTO #tmpSportResource(Sporttype,ResourceId)
	VALUES (2, 'Q1')
          ,(2, 'Q2')
		  ,(2, '01')
		  ,(2, 'Q3')
		  ,(2, 'Q4')
		  ,(2, '00')

	INSERT INTO #tmpMatch(MatchId,LeagueId,Sporttype,ResultTable,SettlementStatus)
	SELECT m.MatchId
		  ,m.LeagueId
		  ,m.Sporttype
		  ,ts.ResultTable
		  ,m.SettlementStatus
	FROM @tblLeagueID AS ls 
		INNER JOIN dbo.League AS l WITH(NOLOCK) ON	ls.leagueid = l.leagueid
		INNER JOIN match AS m WITH(NOLOCK)  ON	m.leagueid = l.leagueid
		INNER JOIN dbo.SettlementResultTableSetting AS ts WITH(NOLOCK) ON ts.Sporttype = l.Sporttype
		OUTER APPLY (SELECT TOP 1 1 AS IsExistAP 
					 FROM dbo.AutoPayoutResultOS AS apr WITH(NOLOCK) 
					 WHERE apr.MatchId = m.matchid 
				) AS rs
		OUTER APPLY (SELECT TOP 1 1 AS IsExistAR
					 FROM dbo.AutoRefundResultOS AS arr WITH(NOLOCK) 
					 WHERE arr.MatchId = m.matchid 
				) AS ar
	WHERE m.eventstatus = 'running' 
		AND m.eventdate BETWEEN @FromDate AND @ToDate
		AND ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0))  & 16 > 0
		AND ISNULL(m.SettlementStatus,0) & 87 = 0
		AND rs.IsExistAP IS NULL
		AND ar.IsExistAR IS NULL

	INSERT INTO #tmpParent(MatchId,ParentId,Sporttype,ResultTable,ParentEventStatus,SettlementStatus,IsValid)
	SELECT fm.MatchId
		  ,pr.ParentID
		  ,fm.Sporttype
		  ,fm.ResultTable
		  ,m.eventstatus AS ParentEventStatus
		  ,m.SettlementStatus
		  ,CASE WHEN m.MatchId IS NULL THEN 0
				ELSE 1
			END AS IsValid
	FROM  #tmpMatch AS fm
		INNER JOIN dbo.Match_Property AS mp WITH(NOLOCK) ON  mp.matchid = fm.matchid AND mp.[key] = 'fantasy'
		OUTER APPLY (SELECT CAST(p.[value] AS INT) AS ParentID
					 FROM STRING_SPLIT(mp.[Value],',') AS p
		) AS pr 
		LEFT JOIN  dbo.match AS m WITH(NOLOCK) ON m.MatchId = pr.ParentID

	DELETE m
	FROM #tmpMatch AS m
	WHERE NOT EXISTS (SELECT 1
					  FROM #tmpParent AS pr
					  WHERE m.MatchId = pr.MatchId)
	  OR EXISTS (SELECT 1
				 FROM #tmpParent AS pr
				 WHERE m.MatchId = pr.MatchId AND pr.IsValid = 0);
	

	UPDATE m
	SET  m.TotalParent = (SELECT COUNT(1) FROM #tmpParent AS p WHERE m.MatchId = p.MatchId )
		,m.TotalResourceFantasy = (SELECT COUNT(1) FROM #tmpSportResource AS r WHERE r.Sporttype = m.Sporttype)
	FROM #tmpMatch AS m

	IF EXISTS (SELECT 1 FROM #tmpMatch WHERE ResultTable = 1)
	BEGIN
	
		DELETE	m
		FROM #tmpMatch AS m
		WHERE m.ResultTable = 1
			AND EXISTS (
					SELECT	1
					FROM dbo.ResultDetail AS rd WITH(NOLOCK)
						INNER JOIN  #tmpSportResource AS r ON r.ResourceID = rd.ResourceID AND r.Sporttype = m.Sporttype
					WHERE rd.MatchId = m.matchid
							AND rd.ResultStatusID IN (2,5)
			)
		
		UPDATE m
		SET m.IsCnfRefund = 1
		FROM #tmpMatch AS m
		WHERE m.ResultTable = 1
			AND EXISTS (
					SELECT	1
					FROM dbo.ResultDetail AS rd WITH(NOLOCK)
						INNER JOIN  #tmpSportResource AS r ON r.ResourceID = rd.ResourceID AND r.Sporttype = m.Sporttype
					WHERE rd.MatchId = m.matchid
							AND ISNULL(rd.ResultSetting,0) & 6 > 0
			)

		INSERT INTO #tmpParentResource(MatchId,ParentId,ParentEventStatus,ParentSettlementStatus,ResourceId, HomeValue, AwayValue,SettlementStatusID,ResultSetting,LastModifyDate)
		SELECT p.MatchId,p.ParentId,p.ParentEventStatus,p.SettlementStatus,rd.ResourceId, rd.HomeValue, rd.AwayValue, rd.SettlementStatusID,rd.ResultSetting, rd.LastModifyDate
		FROM #tmpParent AS p
			INNER JOIN  #tmpSportResource AS r ON r.Sporttype = p.Sporttype
			INNER JOIN dbo.ResultDetail AS rd WITH(NOLOCK) ON r.ResourceID = rd.ResourceID AND p.ParentId = rd.MatchId
		WHERE p.ResultTable = 1
	END

	IF EXISTS (SELECT 1 FROM #tmpMatch WHERE ResultTable = 2)
	BEGIN
		DELETE	m
		FROM #tmpMatch AS m
		WHERE m.ResultTable = 2
			AND EXISTS (
					SELECT	1
					FROM dbo.ResultDetailOS AS rd WITH(NOLOCK)
						INNER JOIN  #tmpSportResource AS r ON r.ResourceID = rd.ResourceID AND r.Sporttype = m.Sporttype
					WHERE rd.MatchId = m.matchid
							AND rd.ResultStatusID IN (2,5)
			)

		UPDATE m
		SET m.IsCnfRefund = 1
		FROM #tmpMatch AS m
		WHERE m.ResultTable = 1
			AND EXISTS (
					SELECT	1
					FROM dbo.ResultDetail AS rd WITH(NOLOCK)
						INNER JOIN  #tmpSportResource AS r ON r.ResourceID = rd.ResourceID AND r.Sporttype = m.Sporttype
					WHERE rd.MatchId = m.matchid
							AND ISNULL(rd.ResultSetting,0) & 6 > 0
			)

		INSERT INTO #tmpParentResource(MatchId,ParentId,ParentEventStatus,ParentSettlementStatus,ResourceId, HomeValue, AwayValue,SettlementStatusID,ResultSetting,LastModifyDate)
		SELECT p.MatchId,p.ParentId,p.ParentEventStatus,p.SettlementStatus,rd.ResourceId, rd.HomeValue, rd.AwayValue, rd.SettlementStatusID,rd.ResultSetting, rd.LastModifyDate
		FROM #tmpParent AS p
			INNER JOIN  #tmpSportResource AS r ON r.Sporttype = p.Sporttype
			INNER JOIN dbo.ResultDetailOS AS rd WITH(NOLOCK) ON r.ResourceID = rd.ResourceID AND p.ParentId = rd.MatchId
		WHERE p.ResultTable = 2
	END

	UPDATE m
	SET  m.Action = 'REFUND'
		,m.LastParentCalculateDate = tbl.LastParentRefundDate
	FROM #tmpMatch AS m
		CROSS APPLY(SELECT TOP 1 MAX(pr.LastModifyDate) AS LastParentRefundDate
					FROM #tmpParentResource AS pr
					WHERE pr.MatchId = m.MatchId 
						AND pr.ParentEventStatus = 'completed'
						AND pr.SettlementStatusID = 1
					GROUP BY pr.MatchId,pr.ParentId
					HAVING COUNT(1) = m.TotalResourceFantasy
					ORDER BY MAX(pr.LastModifyDate) ASC)  AS tbl

	UPDATE m
	SET  m.Action = 'CAL'
		,m.LastParentCalculateDate = tbl.LastParentCalculateDate
	FROM #tmpMatch AS m
		CROSS APPLY (
				SELECT MAX(pr.LastModifyDate) AS LastParentCalculateDate
				FROM #tmpParentResource AS pr
				WHERE pr.MatchId = m.MatchId 
					AND pr.ParentEventStatus = 'completed'
					AND pr.SettlementStatusID = 4
					AND ISNULL(pr.ResultSetting,0) & 6 = 0
					AND ISNULL(pr.ParentSettlementStatus,0) & 119 = 0
				GROUP BY pr.MatchId
				HAVING COUNT(1) = m.TotalParent * m.TotalResourceFantasy 
		) AS tbl 
	WHERE m.SettlementStatus  & 32 = 0
		AND m.IsCnfRefund != 1
	

	DECLARE @CurrTime DATETIME = GETDATE()

	SELECT m.MatchId
		  ,m.LeagueId
		  ,m.Action
	FROM #tmpMatch AS m
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime
			FROM dbo.SettlementSetting AS ss WITH (NOLOCK)
			WHERE ss.LeagueId = m.LeagueId
				AND ss.AutoType = 5
		) AS ss
		OUTER APPLY(
			SELECT TOP 1 ssr.WaitingTime
			FROM dbo.SettlementSetting AS ssr WITH (NOLOCK)
			WHERE ssr.LeagueId = m.LeagueId
				AND ssr.AutoType = 7
		) AS ssr
	WHERE 1 = CASE WHEN m.Action = 'CAL' AND m.LastParentCalculateDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,300), @CurrTime) THEN 1
				   WHEN m.Action = 'REFUND' AND m.LastParentCalculateDate <= DATEADD(SECOND, - ISNULL(ssr.WaitingTime,0), @CurrTime) THEN 1
				   ELSE 0
			  END
		 
END
GO
