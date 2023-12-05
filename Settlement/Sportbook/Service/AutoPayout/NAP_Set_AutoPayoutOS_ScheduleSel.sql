/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoPayoutOS_ScheduleSel
	 @AutoPayoutGroup	SMALLINT
	,@ResourceType		SMALLINT = 0
AS
/*
	Creator: 20231002@Aries
	Task: Apply Auto Payout for Cricket by using TheSports Provider [Redmine:#195768]
	DB: DBPRO/bodb02
	Revisions:
		- 20231002@Aries: Created  [Redmine: #195768]

	Param's Explanation:
		-@ResourceType: 0-ALL, 1-Main, 2-Early

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @procName				SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime			VARCHAR(10)
			,@IsWaiting				BIT = 0
			,@CurrentDate			DATETIME
			,@CurrentDateTime		DATETIME
			,@FromDate				DATETIME
			,@ToDate				DATETIME
			,@Result_FromDate		DATETIME

	DECLARE @ResultTableSetting TABLE (Sporttype SMALLINT, ResultTable TINYINT,ExternalResultTable TINYINT
									   ,AP_Group SMALLINT
									   ,AP_Check_M_Hold BIT, AP_Check_M_Hedge BIT,AP_Check_M_Setting BIT
									   ,AP_Check_R_MactchCompleted BIT, AP_Check_R_Hold BIT,AP_Check_R_CnfRefund BIT
									   ,AP_Main_NumberProvider  TINYINT,AP_Main_WaitingTime  INT, AP_Main_CheckList  VARCHAR(100)
									   ,AP_EAR_NumberProvider  TINYINT,AP_EAR_WaitingTime  INT,AP_EAR_CheckList VARCHAR(100))

	IF OBJECT_ID('tempdb..#Match') IS NOT NULL DROP TABLE #Match
	CREATE TABLE #Match (matchId INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),eventstatus NVARCHAR(100), leagueId INT,sporttype SMALLINT, ResultTable TINYINT,ExternalResultTable TINYINT
						,AP_Check_R_MactchCompleted BIT, AP_Check_R_Hold BIT,AP_Check_R_CnfRefund BIT
						,AP_Main_NumberProvider  TINYINT,AP_Main_WaitingTime  INT
						,AP_EAR_NumberProvider  TINYINT,AP_EAR_WaitingTime  INT)

	IF OBJECT_ID('tempdb..#MatchResource') IS NOT NULL DROP TABLE #MatchResource
	CREATE TABLE #MatchResource (matchId INT,IsTrader SMALLINT DEFAULT 0,ResourceId VARCHAR(20), ResourceType SMALLINT,CreatedDate DATETIME,TotalProvider TINYINT DEFAULT 0)

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		 @SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT  NULL AS matchId
			   ,NULL AS SportType
			   ,NULL AS LeagueId
			   ,NULL AS ResourceId
			   ,NULL AS ResourceType
			   ,NULL AS ResouceStatus
		FROM #MatchResource m

		RETURN
	END

	SELECT	 @CurrentDateTime	= GETDATE()
			,@CurrentDate		= CAST(@CurrentDateTime AS DATE)
	SELECT	 @FromDate			= DATEADD(DAY,-1,@CurrentDate)
			,@ToDate			= DATEADD(DAY,1,@CurrentDate)
			,@Result_FromDate   = DATEADD(HOUR,-5,@CurrentDateTime)

	INSERT INTO @ResultTableSetting(Sporttype,ResultTable,ExternalResultTable
	                               ,AP_Group ,AP_Check_M_Hold, AP_Check_M_Hedge,AP_Check_M_Setting
								   ,AP_Check_R_MactchCompleted, AP_Check_R_Hold,AP_Check_R_CnfRefund
								   ,AP_Main_NumberProvider,AP_Main_WaitingTime,AP_Main_CheckList
								   ,AP_EAR_NumberProvider,AP_EAR_WaitingTime,AP_EAR_CheckList)
	SELECT Sporttype,ResultTable,ExternalResultTable
		  ,AP_Group 
		  ,AP_Check_M_Hold, AP_Check_M_Hedge,AP_Check_M_Setting
		  ,AP_Check_R_MactchCompleted, AP_Check_R_Hold,AP_Check_R_CnfRefund
		  ,AP_Main_NumberProvider,AP_Main_WaitingTime,AP_Main_CheckList
		  ,AP_EAR_NumberProvider,AP_EAR_WaitingTime,AP_EAR_CheckList
	FROM SettlementResultTableSetting WITH(NOLOCK)
	WHERE AP_Group = @AutoPayoutGroup

	IF @ResourceType = 1
	BEGIN
		INSERT INTO #Match(matchId,eventstatus,leagueid,sporttype,ResultTable,ExternalResultTable,AP_Check_R_MactchCompleted, AP_Check_R_Hold,AP_Check_R_CnfRefund,AP_Main_NumberProvider,AP_Main_WaitingTime,AP_EAR_NumberProvider,AP_EAR_WaitingTime)
		SELECT m.matchId,m.eventstatus,m.leagueid,m.sporttype,st.ResultTable,st.ExternalResultTable,st.AP_Check_R_MactchCompleted, st.AP_Check_R_Hold,st.AP_Check_R_CnfRefund,st.AP_Main_NumberProvider,st.AP_Main_WaitingTime,st.AP_EAR_NumberProvider,st.AP_EAR_WaitingTime
		FROM dbo.match AS m WITH(NOLOCK)
			INNER JOIN dbo.League AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN @ResultTableSetting AS st ON st.sporttype = m.sporttype
		WHERE m.eventstatus = 'running'
			AND m.eventdate BETWEEN @FromDate AND @ToDate
			AND ISNULL(m.ChildMatchType,0) != 200
			AND 1 = CASE WHEN AP_Check_M_Hold = 1	 AND ISNULL(m.SettlementStatus,0) & 87 != 0					 THEN 0
						 WHEN AP_Check_M_Hedge = 1   AND CHARINDEX('hedge', m.matchcode) != 0					 THEN 0
						 WHEN AP_Check_M_Setting = 1 AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 1 != 1 THEN 0
						 ELSE 1 END
	END
	ELSE IF @ResourceType IN (0,2)
	BEGIN
		INSERT INTO #Match(matchId,eventstatus,leagueid,sporttype,ResultTable,ExternalResultTable,AP_Check_R_MactchCompleted, AP_Check_R_Hold,AP_Check_R_CnfRefund,AP_Main_NumberProvider,AP_Main_WaitingTime,AP_EAR_NumberProvider,AP_EAR_WaitingTime)
		SELECT m.matchId,m.eventstatus,m.leagueid,m.sporttype,st.ResultTable,st.ExternalResultTable,st.AP_Check_R_MactchCompleted, st.AP_Check_R_Hold,st.AP_Check_R_CnfRefund,st.AP_Main_NumberProvider,st.AP_Main_WaitingTime,st.AP_EAR_NumberProvider,st.AP_EAR_WaitingTime
		FROM dbo.match AS m WITH(NOLOCK)
			INNER JOIN dbo.League AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN @ResultTableSetting AS st ON st.sporttype = m.sporttype
		WHERE m.eventstatus IN ('running','completed')
			AND m.eventdate BETWEEN @FromDate AND @ToDate
			AND ISNULL(m.ChildMatchType,0) != 200
			AND 1 = CASE WHEN AP_Check_M_Hold = 1	 AND ISNULL(m.SettlementStatus,0) & 87 != 0					 THEN 0
						 WHEN AP_Check_M_Hedge = 1   AND CHARINDEX('hedge', m.matchcode) != 0					 THEN 0
						 WHEN AP_Check_M_Setting = 1 AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 1 != 1 THEN 0
						 ELSE 1 END
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ExternalResultTable = 1)
	BEGIN 
		INSERT INTO #MatchResource (matchId,ResourceId,ResourceType,CreatedDate,TotalProvider)
		SELECT m.matchId,p.ResourceId,f.ResourceType,p.CreatedDate,p.TotalProvider
		FROM #Match AS m
			CROSS APPLY (SELECT r.matchId,r.ResourceId, COUNT(DISTINCT r.SourceID) AS TotalProvider,  MIN(r.CreateDate) AS CreatedDate
						 FROM ProviderExternalResultDetail AS r WITH(NOLOCK)
						 WHERE  r.matchId = m.matchId
							AND r.SourceID != 100
							AND r.CreateDate > @Result_FromDate
						 GROUP BY r.matchId,r.ResourceId) AS p
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = p.matchid
							AND os.ResourceId = p.ResourceID 
							AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype)  f WHERE p.ResourceId = f.ResourceID) f
		WHERE m.ExternalResultTable = 1
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN @ResourceType = 0 THEN 1
			             WHEN @ResourceType = f.ResourceType THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 ELSE 1 END	
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ExternalResultTable = 2)
	BEGIN
		INSERT INTO #MatchResource (matchId,ResourceId,ResourceType,CreatedDate,TotalProvider)
		SELECT m.matchId,p.ResourceId,f.ResourceType,p.CreatedDate,p.TotalProvider
		FROM #Match AS m
			CROSS APPLY (SELECT r.matchId,r.ResourceId, COUNT(DISTINCT r.SourceID) AS TotalProvider,  MIN(r.CreateDate) AS CreatedDate
						 FROM ProviderExternalResultDetailOS AS r WITH(NOLOCK)
						 WHERE  r.matchId = m.matchId
							AND r.SourceID != 100
							AND r.CreateDate > @Result_FromDate
						 GROUP BY r.matchId,r.ResourceId) AS p
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = p.matchid
							AND os.ResourceId = p.ResourceID 
							AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype)  f WHERE p.ResourceId = f.ResourceID) f
		WHERE m.ExternalResultTable = 2
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN @ResourceType = 0 THEN 1
			             WHEN @ResourceType = f.ResourceType THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 ELSE 1 END
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ExternalResultTable = 3)
	BEGIN
		INSERT INTO #MatchResource (matchId,ResourceId,ResourceType,CreatedDate,TotalProvider)
		SELECT m.matchId,p.ResourceId,f.ResourceType,p.CreatedDate,p.TotalProvider
		FROM #Match AS m
			CROSS APPLY (SELECT r.matchId,r.ResourceId, COUNT(DISTINCT r.SourceID) AS TotalProvider,  MIN(r.CreateDate) AS CreatedDate
						 FROM ProviderExternalResultDetailES AS r WITH(NOLOCK)
						 WHERE  r.matchId = m.matchId
							AND r.SourceID != 100
							AND r.CreateDate > @Result_FromDate
						 GROUP BY r.matchId,r.ResourceId) AS p
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = p.matchid
							AND os.ResourceId = p.ResourceID 
							AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype)  f WHERE p.ResourceId = f.ResourceID) f
		WHERE m.ExternalResultTable = 3
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN @ResourceType = 0 THEN 1
			             WHEN @ResourceType = f.ResourceType THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 ELSE 1 END
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ResultTable = 1)
	BEGIN
		DELETE mr
		FROM #MatchResource AS mr
		WHERE EXISTS (SELECT 1 
					  FROM dbo.ResultDetail AS r WITH(NOLOCK)
					  WHERE r.matchid = mr.matchid
						AND r.ResourceId = mr.ResourceId
						AND (r.SettlementStatusID != 0 OR ISNULL(r.ResultSetting,0) & 6  != 0))

		INSERT INTO #MatchResource(matchId,ResourceId,CreatedDate,ResourceType,IsTrader)
		SELECT m.matchId,r.ResourceId,ISNULL(r.LastModifyDate,r.CreateDate),f.ResourceType,1 AS IsTrader
		FROM #Match AS m
			INNER JOIN dbo.ResultDetail AS r WITH(NOLOCK) ON r.MatchID = m.matchid AND r.ResultStatusID = 3			
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = r.matchid
								AND os.ResourceId = r.ResourceID 
								AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype)  f WHERE r.ResourceId = f.ResourceID) f
		WHERE m.ResultTable = 1
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN @ResourceType = 0 THEN 1
			             WHEN @ResourceType = f.ResourceType THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_CnfRefund = 1 AND ISNULL(r.ResultSetting,0) & 6  != 0 THEN 0
						 WHEN m.AP_Check_R_Hold = 1 AND f.ResourceType = 2 AND ISNULL(r.ResultSetting,0) & 1  != 0 THEN 0
						 WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 ELSE 1 END
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ResultTable = 2)
	BEGIN	
		DELETE mr
		FROM #MatchResource AS mr
		WHERE EXISTS (SELECT 1 
					  FROM dbo.ResultDetailOS AS r WITH(NOLOCK)
					  WHERE r.matchid = mr.matchid
						AND r.ResourceId = mr.ResourceId
						AND (r.SettlementStatusID != 0 OR ISNULL(r.ResultSetting,0) & 6  != 0))

		INSERT INTO #MatchResource(matchId,ResourceId,CreatedDate,ResourceType,IsTrader)
		SELECT m.matchId,r.ResourceId,ISNULL(r.LastModifyDate,r.CreateDate),f.ResourceType,1 AS IsTrader
		FROM #Match AS m
			INNER JOIN dbo.ResultDetailOS AS r WITH(NOLOCK) ON r.MatchID = m.matchid AND r.ResultStatusID = 3			
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = r.matchid
								AND os.ResourceId = r.ResourceID 
								AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype)  f WHERE r.ResourceId = f.ResourceID) f
		WHERE m.ResultTable = 2
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN @ResourceType = 0 THEN 1
			             WHEN @ResourceType = f.ResourceType THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_CnfRefund = 1 AND ISNULL(r.ResultSetting,0) & 6  != 0 THEN 0
						 WHEN m.AP_Check_R_Hold = 1 AND f.ResourceType = 2 AND ISNULL(r.ResultSetting,0) & 1  != 0 THEN 0
						 WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 ELSE 1 END	
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ResultTable = 3)
	BEGIN
		DELETE mr
		FROM #MatchResource AS mr
		WHERE EXISTS (SELECT 1 
					  FROM dbo.ResultDetailES AS r WITH(NOLOCK)
					  WHERE r.matchid = mr.matchid
						AND r.ResourceId = mr.ResourceId
						AND (r.SettlementStatusID != 0 OR ISNULL(r.ResultSetting,0) & 6  != 0))

		INSERT INTO #MatchResource(matchId,ResourceId,CreatedDate,ResourceType,IsTrader)
		SELECT m.matchId,r.ResourceId,ISNULL(r.LastModifyDate,r.CreateDate),f.ResourceType,1 AS IsTrader
		FROM #Match AS m
			INNER JOIN dbo.ResultDetailES AS r WITH(NOLOCK) ON r.MatchID = m.matchid AND r.ResultStatusID = 3			
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = r.matchid
								AND os.ResourceId = r.ResourceID 
								AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype)  f WHERE r.ResourceId = f.ResourceID) f
		WHERE m.ResultTable = 3
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN @ResourceType = 0 THEN 1
			             WHEN @ResourceType = f.ResourceType THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_CnfRefund = 1 AND ISNULL(r.ResultSetting,0) & 6  != 0 THEN 0
						 WHEN m.AP_Check_R_Hold = 1 AND f.ResourceType = 2 AND ISNULL(r.ResultSetting,0) & 1  != 0 THEN 0
						 WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 ELSE 1 END		
	END

	SELECT Sporttype, AP_Main_CheckList AS MainCheckList ,AP_EAR_CheckList AS EarlyCheckList
	FROM @ResultTableSetting

	;WITH CTE_Provider AS (
			SELECT mr.matchId, mr.ResourceId,mr.ResourceType
				  ,MIN(mr.CreatedDate) AS CreatedDate
				  ,MAX(mr.TotalProvider) AS TotalProvider
				  ,MAX(mr.IsTrader) AS TotalTrader
			FROM #MatchResource AS mr
			GROUP BY matchId,ResourceId,ResourceType
	)
	SELECT m.matchId
		  ,m.SportType
		  ,m.LeagueId
		  ,cte.ResourceId
		  ,cte.ResourceType
		  ,s.ResourceStatus
	FROM CTE_Provider AS cte
		INNER JOIN #Match AS m on cte.matchId = m.matchId
		CROSS APPLY(
			SELECT CASE WHEN cte.ResourceType = 1 AND cte.TotalProvider >= m.AP_Main_NumberProvider AND  cte.TotalTrader = 1 THEN 1
						WHEN cte.ResourceType = 2 AND cte.TotalProvider >= m.AP_EAR_NumberProvider AND  cte.TotalTrader = 1 THEN 1
						WHEN cte.ResourceType = 1 AND DATEDIFF(second,cte.CreatedDate,@CurrentDateTime) > m.AP_Main_WaitingTime AND (cte.TotalProvider < m.AP_Main_NumberProvider OR  cte.TotalTrader < 1) THEN 2
						WHEN cte.ResourceType = 2 AND DATEDIFF(second,cte.CreatedDate,@CurrentDateTime) > m.AP_EAR_WaitingTime AND (cte.TotalProvider < m.AP_EAR_NumberProvider  OR  cte.TotalTrader < 1) THEN 2
						ELSE 0
			END AS ResourceStatus
		) AS s	
	WHERE s.ResourceStatus != 0

END
GO


 