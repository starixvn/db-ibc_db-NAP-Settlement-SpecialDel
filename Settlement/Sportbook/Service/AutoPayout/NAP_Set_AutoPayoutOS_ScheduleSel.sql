/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoPayoutOS_ScheduleSel
	 @AutoPayoutGroup	SMALLINT
AS
/*
	Creator: 20231002@Aries
	Task: Apply Auto Payout for Cricket by using TheSports Provider [Redmine:#195768]
	DB: DBPRO/bodb02
	Revisions:
		- 20231002@Aries: Created  [Redmine: #195768]
		- 20231205@Aries: Get only provider [Redmine: #195768]
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]
		- 20240524@Aries: Enhance the AutoPayout2 for Overwatch of eSports [Redmine:#202948]
		- 20240503@Aries: Support Auto Payout 2 for Basketball [Redmine:#203520]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
		- 20250120@Aries: Enhance the Validate Order for Auto Payout2 [Redmine:#209415]
		- 20250326@Aries: Support AutoPayout2 for Ice Hockey [Redmine:#219397]
		- 20250604@Aries: Enhance the performance on the DBPRO for the Settlement flow [Redmine:#229607]
		- 20250605@Aries: Settlement - The Table Tennis could not auto payout [Redmine:#229681]
		- 20250625@Aries: Match completed, but the auto payout flow still logs a failure [Redmine:#231523]
		- 20250709@Max: Auto Payout 2- Support Template with FT only for Golf [Redmine: #231388]

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

	DECLARE @tblLeagueID		TABLE(LeagueId INT)

	DECLARE @ResultTableSetting TABLE (Sporttype SMALLINT, ResultTable TINYINT,ExternalResultTable TINYINT
									   ,AP_Group SMALLINT
									   ,AP_Check_M_Hold BIT, AP_Check_M_Hedge BIT,AP_Check_M_Setting BIT
									   ,AP_Check_R_MactchCompleted BIT, AP_Check_R_Hold BIT,AP_Check_R_CnfRefund BIT
									   ,AP_Main_NumberProvider  TINYINT,AP_Main_WaitingTime  INT, AP_Main_CheckList  VARCHAR(100)
									   ,AP_EAR_NumberProvider  TINYINT,AP_EAR_WaitingTime  INT,AP_EAR_CheckList VARCHAR(100))

	IF OBJECT_ID('tempdb..#Match') IS NOT NULL DROP TABLE #Match
	CREATE TABLE #Match (matchId INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),eventstatus NVARCHAR(100), leagueId INT,sporttype SMALLINT, ResultTable TINYINT,ExternalResultTable TINYINT
						,AP_Check_R_MactchCompleted BIT, AP_Check_R_Hold BIT,AP_Check_R_CnfRefund BIT

						,AP_Main BIT,AP_Main_TotalSource INT
						,AP_Main_NumberProvider  TINYINT,AP_Main_WaitingTime  INT,AP_Main_HasTrader  BIT
						,AP_Main_PrimaryProvider  VARCHAR(500),AP_Main_TotalPrimaryProvider  TINYINT, AP_Main_SecondaryProvider  VARCHAR(500), AP_Main_TotalSecondaryProvider TINYINT
						,AP_Main_InactiveProvider  VARCHAR(500)

						,AP_EAR  BIT,AP_EAR_TotalSource INT
						,AP_EAR_NumberProvider  TINYINT,AP_EAR_WaitingTime  INT, AP_EAR_HasTrader  BIT 
						,AP_EAR_PrimaryProvider  VARCHAR(500),AP_EAR_TotalPrimaryProvider  TINYINT, AP_EAR_SecondaryProvider  VARCHAR(500), AP_EAR_TotalSecondaryProvider TINYINT
						,AP_EAR_InactiveProvider  VARCHAR(500)

						,GameType TINYINT
						
						,hthomescore	INT
						,htawayscore	INT
						,finalhomescore	INT
						,finalawayscore	INT)

	IF OBJECT_ID('tempdb..#MatchResource') IS NOT NULL DROP TABLE #MatchResource
	CREATE TABLE #MatchResource (matchId INT,IsTrader SMALLINT DEFAULT 0,ResourceId VARCHAR(20), ResourceType SMALLINT,CreatedDate DATETIME,TotalProvider TINYINT DEFAULT 0,TotalPrimaryProvider TINYINT DEFAULT 0,TotalSecondaryProvider TINYINT DEFAULT 0,AP_TotalSecondaryProvider TINYINT)

	IF OBJECT_ID('tempdb..#MatchResourceConfirmDate') IS NOT NULL DROP TABLE #MatchResourceConfirmDate
	CREATE TABLE #MatchResourceConfirmDate (matchId INT,ResourceId VARCHAR(20),HomeValue VARCHAR(50), AwayValue VARCHAR(50), CreatedDate DATETIME)


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

	INSERT INTO @tblLeagueID(LeagueId)
	SELECT LeagueId
	FROM SettlementSetting WITH(NOLOCK)
	WHERE AutoType = 10

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

	INSERT INTO #Match(matchId,eventstatus,leagueid,sporttype
					  ,ResultTable,ExternalResultTable
					  ,AP_Check_R_MactchCompleted, AP_Check_R_Hold,AP_Check_R_CnfRefund

					  ,AP_Main
					  ,AP_Main_TotalSource
					  ,AP_Main_NumberProvider
					  ,AP_Main_WaitingTime
					  ,AP_Main_HasTrader
					  ,AP_Main_PrimaryProvider
					  ,AP_Main_TotalPrimaryProvider
					  ,AP_Main_SecondaryProvider
					  ,AP_Main_TotalSecondaryProvider
					  ,AP_Main_InactiveProvider

					  ,AP_EAR
					  ,AP_EAR_TotalSource
					  ,AP_EAR_NumberProvider
					  ,AP_EAR_WaitingTime
					  ,AP_EAR_HasTrader
					  ,AP_EAR_PrimaryProvider
					  ,AP_EAR_TotalPrimaryProvider
					  ,AP_EAR_SecondaryProvider
					  ,AP_EAR_TotalSecondaryProvider
					  ,AP_EAR_InactiveProvider

					  ,GameType
					  
					  ,hthomescore
					  ,htawayscore
					  ,finalhomescore	
					  ,finalawayscore)
	SELECT m.matchId,m.eventstatus,m.leagueid,m.sporttype
	      ,st.ResultTable,st.ExternalResultTable
		  ,st.AP_Check_R_MactchCompleted, st.AP_Check_R_Hold,st.AP_Check_R_CnfRefund

		  ,IIF(ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 1 = 1, 1,0) AS AP_Main
		  ,(COALESCE(ms.Main_NumberProvider,ss.Main_NumberProvider,st.AP_Main_NumberProvider) + COALESCE(ms.Main_HasTrader,ss.Main_HasTrader,1)) AS AP_Main_TotalSource
		  ,COALESCE(ms.Main_NumberProvider,ss.Main_NumberProvider,st.AP_Main_NumberProvider) AS  AP_Main_NumberProvider
		  ,COALESCE(ms.WaitingTime,ss.WaitingTime, st.AP_Main_WaitingTime) AS AP_Main_WaitingTime
		  ,COALESCE(ms.Main_HasTrader,ss.Main_HasTrader,1) AS AP_Main_HasTrader
		  ,COALESCE(ms.Main_PrimaryProvider,ss.Main_PrimaryProvider,'') AS AP_Main_PrimaryProvider
		  ,COALESCE(ms.Main_TotalPrimaryProvider,ss.Main_TotalPrimaryProvider,'') AS  AP_Main_TotalPrimaryProvider
		  ,COALESCE(ms.Main_SecondaryProvider,ss.Main_SecondaryProvider,'') AS AP_Main_SecondaryProvider
		  ,COALESCE(ms.Main_TotalSecondaryProvider,ss.Main_TotalSecondaryProvider,'') AS AP_Main_TotalSecondaryProvider
		  ,COALESCE(ms.Main_InactiveProvider,ss.Main_InactiveProvider,'') AS AP_Main_InactiveProvider

		  ,IIF(ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 32 = 32, 1,0) AS AP_EAR
		  ,(COALESCE(ms.EAR_NumberProvider,ss.EAR_NumberProvider,st.AP_EAR_NumberProvider) + COALESCE(ms.EAR_HasTrader,ss.EAR_HasTrader,1)) AS AP_EAR_TotalSource
		  ,COALESCE(ms.EAR_NumberProvider,ss.EAR_NumberProvider,st.AP_EAR_NumberProvider) AS AP_EAR_NumberProvider
		  ,COALESCE(ms.EAR_WaitingTime,ss.EAR_WaitingTime, st.AP_Main_WaitingTime) AS AP_EAR_WaitingTime
		  ,COALESCE(ms.EAR_HasTrader,ss.EAR_HasTrader,1) AS AP_EAR_HasTrader
		  ,COALESCE(ms.EAR_PrimaryProvider,ss.EAR_PrimaryProvider,'') AS AP_EAR_PrimaryProvider
		  ,COALESCE(ms.EAR_TotalPrimaryProvider,ss.EAR_TotalPrimaryProvider,'') AS AP_EAR_TotalPrimaryProvider
		  ,COALESCE(ms.EAR_SecondaryProvider,ss.EAR_SecondaryProvider,'') AS AP_EAR_SecondaryProvider
		  ,COALESCE(ms.EAR_TotalSecondaryProvider,ss.EAR_TotalSecondaryProvider,'') AS AP_EAR_TotalSecondaryProvider
		  ,COALESCE(ms.EAR_InactiveProvider,ss.EAR_InactiveProvider,'') AS AP_EAR_InactiveProvider
		  
		  ,CASE WHEN l.Sporttype= 43 THEN l.OverTimeSession ELSE 0 END AS GameType

		  ,IIF(mr.ConfirmHT > 0 AND m.hthomescore IS NOT NULL,m.hthomescore, NULL)
		  ,IIF(mr.ConfirmHT > 0 AND m.htawayscore IS NOT NULL,m.htawayscore, NULL) 
		  ,IIF(mr.ConfirmFT > 0 AND m.finalhomescore IS NOT NULL,m.finalhomescore, NULL) 
		  ,IIF(mr.ConfirmFT > 0 AND m.finalawayscore IS NOT NULL,m.finalawayscore, NULL) 
		  
	FROM dbo.match AS m WITH(NOLOCK)
		INNER JOIN dbo.match_remark AS mr  WITH(NOLOCK) ON mr.matchid =  m.matchid
		INNER JOIN dbo.League AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN @ResultTableSetting AS st ON st.sporttype = m.sporttype
		LEFT JOIN  dbo.SettlementSetting AS ss WITH(NOLOCK) ON m.leagueid = ss.leagueid AND ss.AutoType = 6
		LEFT JOIN  dbo.AutoPayoutSetting AS ms WITH(NOLOCK) ON m.matchId = ms.matchId AND ms.AutoType = 6
		LEFT JOIN  @tblLeagueID AS lf ON	l.leagueid = lf.leagueid
	WHERE m.eventstatus IN ('running','completed')
		AND m.eventdate BETWEEN @FromDate AND @ToDate
		AND ISNULL(m.ChildMatchType,0) != 200
		AND 1 = CASE WHEN AP_Check_M_Hold = 1	 AND ISNULL(m.SettlementStatus,0) & 87 != 0					 THEN 0
					 WHEN AP_Check_M_Hedge = 1   AND CHARINDEX('hedge', m.matchcode) != 0					 THEN 0
					 WHEN AP_Check_M_Setting = 1 AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 33 = 0 THEN 0
					 ELSE 1 END
		AND lf.leagueid IS NULL

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ExternalResultTable = 1)
	BEGIN 
		INSERT INTO #MatchResource (matchId,ResourceId,ResourceType,TotalProvider,TotalPrimaryProvider,TotalSecondaryProvider,CreatedDate,AP_TotalSecondaryProvider)
		SELECT m.matchId,r.ResourceId,f.ResourceType
			  ,COUNT(DISTINCT r.SourceID) AS TotalProvider
			  ,COUNT(DISTINCT IIF(CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_PrimaryProvider,m.AP_EAR_PrimaryProvider) +',') > 0,r.SourceID,NULL)) AS TotalPrimaryProvider
			  ,COUNT(DISTINCT IIF(CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_SecondaryProvider,m.AP_EAR_SecondaryProvider) +',') > 0,r.SourceID,NULL)) AS TotalSecondaryProvider
			  ,MIN(CASE WHEN CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_PrimaryProvider,m.AP_EAR_PrimaryProvider) +',') > 0 THEN r.CreateDate
						WHEN CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_SecondaryProvider,m.AP_EAR_SecondaryProvider) +',') > 0 AND IIF(f.ResourceType = 1, m.AP_Main_NumberProvider,  m.AP_EAR_NumberProvider) > 1 THEN r.CreateDate
						WHEN IIF(f.ResourceType = 1,m.AP_Main_TotalPrimaryProvider,m.AP_EAR_TotalPrimaryProvider)  = 0
							 OR (	 IIF(f.ResourceType = 1,m.AP_Main_TotalSecondaryProvider,m.AP_EAR_TotalSecondaryProvider)  = 0 
									AND  IIF(f.ResourceType = 1,m.AP_Main_TotalPrimaryProvider,m.AP_EAR_TotalPrimaryProvider) >= 1
									AND  IIF(f.ResourceType = 1,m.AP_Main_TotalSource,m.AP_EAR_TotalSource) > 1
								) 
							 THEN r.CreateDate
						 ELSE NULL
					 END) AS CreatedDate
			  ,MAX(IIF(f.ResourceType = 1,m.AP_Main_TotalSecondaryProvider,m.AP_EAR_TotalSecondaryProvider)) AS AP_TotalSecondaryProvider
		FROM ProviderExternalResultDetail AS r WITH(NOLOCK)
			INNER JOIN #Match AS m ON r.matchId = m.matchId
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype) f WHERE r.ResourceId = f.ResourceID) AS f
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = r.matchid
							AND os.ResourceId = r.ResourceID 
							AND ISNULL(os.SourceID,0) = 0) AS ap
			OUTER APPLY (SELECT TOP 1 1 AS IsMapped
						 FROM dbo.ProviderGameTypeMapping AS p WITH(NOLOCK)
						 WHERE p.sporttype = m.sporttype
							AND p.SourceId = r.SourceID
							AND p.isActive = 1) AS pm
		WHERE m.ExternalResultTable = 1
            AND r.SourceID < 1001 
			AND r.SourceID NOT IN (98,99,100)
			AND ISNULL(r.IsLive,0) = 0
			AND pm.IsMapped IS NOT NULL
			AND r.CreateDate > @Result_FromDate
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN m.AP_Main = 1 AND f.ResourceType = 1 THEN 1
			             WHEN m.AP_EAR = 1 AND f.ResourceType = 2 THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 WHEN m.AP_Main_NumberProvider = 0 AND f.ResourceType = 1 THEN 0
			             WHEN m.AP_EAR_NumberProvider = 0 AND f.ResourceType = 2 THEN 0
						 ELSE 1 END	
			AND CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_InactiveProvider,m.AP_EAR_InactiveProvider) +',') = 0
        GROUP BY m.matchid,r.ResourceId,f.ResourceType
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ExternalResultTable = 2)
	BEGIN
		INSERT INTO #MatchResource (matchId,ResourceId,ResourceType,TotalProvider,TotalPrimaryProvider,TotalSecondaryProvider,CreatedDate,AP_TotalSecondaryProvider)
		SELECT m.matchId,r.ResourceId,f.ResourceType
			  ,COUNT(DISTINCT r.SourceID) AS TotalProvider
			  ,COUNT(DISTINCT IIF(CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_PrimaryProvider,m.AP_EAR_PrimaryProvider) +',') > 0,r.SourceID,NULL)) AS TotalPrimaryProvider
			  ,COUNT(DISTINCT IIF(CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_SecondaryProvider,m.AP_EAR_SecondaryProvider) +',') > 0,r.SourceID,NULL)) AS TotalSecondaryProvider
			  ,MIN(CASE WHEN CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_PrimaryProvider,m.AP_EAR_PrimaryProvider) +',') > 0 THEN r.CreateDate
						WHEN CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_SecondaryProvider,m.AP_EAR_SecondaryProvider) +',') > 0 AND IIF(f.ResourceType = 1, m.AP_Main_NumberProvider,  m.AP_EAR_NumberProvider) > 1  THEN r.CreateDate
						WHEN IIF(f.ResourceType = 1,m.AP_Main_TotalPrimaryProvider,m.AP_EAR_TotalPrimaryProvider)  = 0
							 OR (	  IIF(f.ResourceType = 1,m.AP_Main_TotalSecondaryProvider,m.AP_EAR_TotalSecondaryProvider)  = 0 
								 AND  IIF(f.ResourceType = 1,m.AP_Main_TotalPrimaryProvider,m.AP_EAR_TotalPrimaryProvider) >= 1
								 AND  IIF(f.ResourceType = 1,m.AP_Main_TotalSource,m.AP_EAR_TotalSource) > 1
								) 
							THEN r.CreateDate
						ELSE NULL
					 END) AS CreatedDate
			  ,MAX(IIF(f.ResourceType = 1,m.AP_Main_TotalSecondaryProvider,m.AP_EAR_TotalSecondaryProvider)) AS AP_TotalSecondaryProvider
		FROM ProviderExternalResultDetailOS AS r WITH(NOLOCK)
			INNER JOIN #Match AS m ON r.matchId = m.matchId
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype) f WHERE r.ResourceId = f.ResourceID) AS f
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = r.matchid
							AND os.ResourceId = r.ResourceID 
							AND ISNULL(os.SourceID,0) = 0) AS ap		
			OUTER APPLY (SELECT TOP 1 1 AS IsMapped
						 FROM dbo.ProviderGameTypeMapping AS p WITH(NOLOCK)
						 WHERE p.sporttype = m.sporttype
							AND p.SourceId = r.SourceID
							AND p.isActive = 1) AS pm
		WHERE m.ExternalResultTable = 2
            AND r.SourceID < 1001 
			AND r.SourceID NOT IN (98,99,100)
			AND ISNULL(r.IsLive,0) = 0
			AND pm.IsMapped IS NOT NULL
			AND r.CreateDate > @Result_FromDate
			AND ap.IsExistsAP IS NULL
			AND 1 = CASE WHEN m.AP_Main = 1 AND f.ResourceType = 1 THEN 1
			             WHEN m.AP_EAR = 1 AND f.ResourceType = 2 THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 WHEN m.AP_Main_NumberProvider = 0 AND f.ResourceType = 1 THEN 0
			             WHEN m.AP_EAR_NumberProvider = 0 AND f.ResourceType = 2 THEN 0
						 ELSE 1 END	
			AND CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_InactiveProvider,m.AP_EAR_InactiveProvider) +',') = 0
        GROUP BY m.matchid,r.ResourceId,f.ResourceType	
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ExternalResultTable = 3)
	BEGIN
		INSERT INTO #MatchResource (matchId,ResourceId,ResourceType,TotalProvider,TotalPrimaryProvider,TotalSecondaryProvider,CreatedDate,AP_TotalSecondaryProvider)
		SELECT m.matchId,r.ResourceId,f.ResourceType
			  ,COUNT(DISTINCT r.SourceID) AS TotalProvider
			  ,COUNT(DISTINCT IIF(CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_PrimaryProvider,m.AP_EAR_PrimaryProvider) +',') > 0,r.SourceID,NULL)) AS TotalPrimaryProvider
			  ,COUNT(DISTINCT IIF(CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_SecondaryProvider,m.AP_EAR_SecondaryProvider) +',') > 0,r.SourceID,NULL)) AS TotalSecondaryProvider
			  ,MIN(CASE WHEN CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_PrimaryProvider,m.AP_EAR_PrimaryProvider) +',') > 0 THEN r.CreateDate
						WHEN CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_SecondaryProvider,m.AP_EAR_SecondaryProvider) +',') > 0 AND IIF(f.ResourceType = 1, m.AP_Main_NumberProvider,  m.AP_EAR_NumberProvider) > 1  THEN r.CreateDate
						WHEN IIF(f.ResourceType = 1,m.AP_Main_TotalPrimaryProvider,m.AP_EAR_TotalPrimaryProvider)  = 0
							 OR (	 IIF(f.ResourceType = 1,m.AP_Main_TotalSecondaryProvider,m.AP_EAR_TotalSecondaryProvider)  = 0 
								 AND IIF(f.ResourceType = 1,m.AP_Main_TotalPrimaryProvider,m.AP_EAR_TotalPrimaryProvider) >= 1
								 AND IIF(f.ResourceType = 1,m.AP_Main_TotalSource,m.AP_EAR_TotalSource) > 1
								) 
							 THEN r.CreateDate
						 ELSE NULL
					 END) AS CreatedDate
			  ,MAX(IIF(f.ResourceType = 1,m.AP_Main_TotalSecondaryProvider,m.AP_EAR_TotalSecondaryProvider)) AS AP_TotalSecondaryProvider
		FROM ProviderExternalResultDetailES AS r WITH(NOLOCK)
			INNER JOIN #Match AS m ON r.matchId = m.matchId
			CROSS APPLY (SELECT TOP 1 1 AS IsExistsProfile
						 FROM SettlementSpecialBettypeProfile AS s WITH(NOLOCK)
						 WHERE s.ResourceID = r.ResourceID
							AND s.SportType = m.sporttype
			) AS ss
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype) f WHERE r.ResourceId = f.ResourceID) AS f
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = r.matchid
							AND os.ResourceId = r.ResourceID 
							AND ISNULL(os.SourceID,0) = 0) AS ap		
			OUTER APPLY (SELECT TOP 1 1 AS IsMapped
						 FROM dbo.ProviderGameTypeMapping AS p WITH(NOLOCK)
						 WHERE p.sporttype = m.sporttype
							AND p.SourceId = r.SourceID
							AND p.isActive = 1
							AND p.GameType = m.GameType) AS pm
		WHERE m.ExternalResultTable = 3
            AND r.SourceID < 1001 
			AND r.SourceID NOT IN (98,99,100)
			AND ISNULL(r.IsLive,0) = 0
			AND pm.IsMapped IS NOT NULL
			AND r.CreateDate > @Result_FromDate
			AND ap.IsExistsAP IS NULL
			AND ss.IsExistsProfile IS NOT NULL
			AND 1 = CASE WHEN m.AP_Main = 1 AND f.ResourceType = 1 THEN 1
			             WHEN m.AP_EAR = 1  AND f.ResourceType = 2 THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 WHEN m.AP_Main_NumberProvider = 0 AND f.ResourceType = 1 THEN 0
			             WHEN m.AP_EAR_NumberProvider = 0 AND f.ResourceType = 2 THEN 0
						 ELSE 1 END	
			AND CHARINDEX(','+CAST(r.SourceID AS VARCHAR)+',',','+ IIF(f.ResourceType = 1,m.AP_Main_InactiveProvider,m.AP_EAR_InactiveProvider) +',') = 0
        GROUP BY m.matchid,r.ResourceId,f.ResourceType
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ResultTable = 0)
	BEGIN
		
		INSERT INTO #MatchResourceConfirmDate (matchId,ResourceId,HomeValue, AwayValue, CreatedDate)
		SELECT m.MatchId
			  ,r.ResourceID
			  ,IIF (r.ResourceID = '00', CAST(m.finalhomescore AS VARCHAR(50)),  CAST(m.hthomescore AS VARCHAR(50)))
			  ,IIF (r.ResourceID = '00', CAST(m.finalawayscore AS VARCHAR(50)),  CAST(m.htawayscore AS VARCHAR(50)))
			  ,pe.CreateDate
		FROM #Match AS m
			CROSS APPLY (SELECT r.ResourceID
						 FROM (VALUES ('00'),('01')) AS r(ResourceID)
						 WHERE 1 = CASE WHEN r.ResourceID = '00' AND m.finalhomescore IS NOT NULL THEN 1
										WHEN r.ResourceID = '01' AND m.hthomescore IS NOT NULL THEN 1
										ELSE 0
									END
			) AS r 
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = m.matchid
								AND os.ResourceId = r.ResourceID 
								AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (
					SELECT TOP 1 pr.ProviderExternalId AS LastProviderExternalId
					FROM dbo.ProviderExternalResultDetailOS AS pr WITH(NOLOCK)
					WHERE pr.MatchId = m.matchid 
						AND pr.ResourceId = r.ResourceID
						AND pr.SourceId = 97
					ORDER BY pr.ProviderExternalId DESC
				) AS pid
			OUTER APPLY (
					SELECT TOP 1 p.CreateDate  
					FROM dbo.ProviderExternalResultDetailOS AS p WITH(NOLOCK)
					WHERE p.ProviderExternalId = pid.LastProviderExternalId
						AND p.HomeValue = IIF(r.ResourceID = '00', CAST(m.finalhomescore AS VARCHAR(50)),  CAST(m.hthomescore AS VARCHAR(50)))
						AND p.AwayValue = IIF(r.ResourceID = '00', CAST(m.finalawayscore AS VARCHAR(50)),  CAST(m.htawayscore AS VARCHAR(50)))
				) AS pe
			OUTER APPLY (
					SELECT TOP 1 IsHTCal
					FROM dbo.match_remark r WITH (NOLOCK)
					WHERE r.matchid = m.matchId
					AND r.IsHTCal = 0
			)mr
		WHERE m.ResultTable = 0
			AND m.eventstatus = 'running'
			AND 1 = CASE WHEN r.ResourceID = '00' THEN 1
						WHEN r.ResourceID = '01' AND mr.IsHTCal = 0 THEN 1
					ELSE 0 END
			AND ap.IsExistsAP IS NULL
			AND m.AP_Main_HasTrader = 1

		INSERT INTO #MatchResource(matchId,ResourceId,CreatedDate,ResourceType,IsTrader)
		SELECT matchId,ResourceId,CreatedDate,1 AS ResourceType,1 AS IsTrader
		FROM #MatchResourceConfirmDate
		WHERE CreatedDate IS NOT NULL
	END

	IF EXISTS(SELECT 1 FROM @ResultTableSetting WHERE ResultTable = 1)
	BEGIN
		DELETE mr
		FROM #MatchResource AS mr
		WHERE EXISTS (SELECT 1 
					  FROM dbo.ResultDetail AS r WITH(NOLOCK)
					  WHERE r.matchid = mr.matchid
						AND r.ResourceId = mr.ResourceId
						AND (r.SettlementStatusID != 0 OR ISNULL(r.ResultSetting,0) & 7  != 0))

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
			AND 1 = CASE WHEN m.AP_Main = 1 AND f.ResourceType = 1 THEN 1
			             WHEN m.AP_EAR = 1  AND f.ResourceType = 2 THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_CnfRefund = 1 AND ISNULL(r.ResultSetting,0) & 6  != 0 THEN 0
						 WHEN m.AP_Check_R_Hold = 1 AND f.ResourceType = 2 AND ISNULL(r.ResultSetting,0) & 1  != 0 THEN 0
						 WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 WHEN m.AP_Main_HasTrader = 0 AND f.ResourceType = 1 THEN 0
			             WHEN m.AP_EAR_HasTrader = 0 AND f.ResourceType = 2 THEN 0
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
						AND (r.SettlementStatusID != 0 OR ISNULL(r.ResultSetting,0) & 7  != 0))

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
			AND 1 = CASE WHEN m.AP_Main = 1 AND f.ResourceType = 1 THEN 1
			             WHEN m.AP_EAR = 1  AND f.ResourceType = 2 THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_CnfRefund = 1 AND ISNULL(r.ResultSetting,0) & 6  != 0 THEN 0
						 WHEN m.AP_Check_R_Hold = 1 AND f.ResourceType = 2 AND ISNULL(r.ResultSetting,0) & 1  != 0 THEN 0
						 WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 WHEN m.AP_Main_HasTrader = 0 AND f.ResourceType = 1 THEN 0
			             WHEN m.AP_EAR_HasTrader = 0 AND f.ResourceType = 2 THEN 0
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
						AND (r.SettlementStatusID != 0 OR ISNULL(r.ResultSetting,0) & 7  != 0))

		INSERT INTO #MatchResource(matchId,ResourceId,CreatedDate,ResourceType,IsTrader)
		SELECT m.matchId,r.ResourceId,ISNULL(r.LastModifyDate,r.CreateDate),f.ResourceType,1 AS IsTrader
		FROM #Match AS m
			INNER JOIN dbo.ResultDetailES AS r WITH(NOLOCK) ON r.MatchID = m.matchid AND r.ResultStatusID = 3	
			CROSS APPLY (SELECT TOP 1 1 AS IsExistsProfile
						 FROM SettlementSpecialBettypeProfile AS s WITH(NOLOCK)
						 WHERE s.ResourceID = r.ResourceID
							AND s.SportType = m.sporttype
			) AS ss
			OUTER APPLY (SELECT TOP 1 1 AS IsExistsAP
						 FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
						 WHERE os.MatchId = r.matchid
								AND os.ResourceId = r.ResourceID 
								AND ISNULL(os.SourceID,0) = 0
						) AS ap
			OUTER APPLY (SELECT IIF(COUNT(1) = 1,1,2)  AS ResourceType FROM f_Set_MajorRound (m.sporttype)  f WHERE r.ResourceId = f.ResourceID) f
		WHERE m.ResultTable = 3
			AND ap.IsExistsAP IS NULL
			AND ss.IsExistsProfile IS NOT NULL
			AND 1 = CASE WHEN m.AP_Main = 1 AND f.ResourceType = 1 THEN 1
			             WHEN m.AP_EAR = 1  AND f.ResourceType = 2 THEN 1
						 ELSE 0
					END
			AND 1 = CASE WHEN m.AP_Check_R_CnfRefund = 1 AND ISNULL(r.ResultSetting,0) & 6  != 0 THEN 0
						 WHEN m.AP_Check_R_Hold = 1 AND f.ResourceType = 2 AND ISNULL(r.ResultSetting,0) & 1  != 0 THEN 0
						 WHEN m.AP_Check_R_MactchCompleted = 1 AND f.ResourceType = 1 AND m.eventstatus ='completed' THEN 0
						 WHEN m.AP_Main_HasTrader = 0 AND f.ResourceType = 1 THEN 0
			             WHEN m.AP_EAR_HasTrader = 0 AND f.ResourceType = 2 THEN 0
						 ELSE 1 END		
	END

	IF @AutoPayoutGroup >= 1000
	BEGIN
		DELETE mr
		FROM #MatchResource AS mr
		WHERE EXISTS (
			SELECT TOP 1 1
			FROM dbo.AutoPayoutPrepareOS AS ap WITH(NOLOCK)
			WHERE mr.matchId = ap.matchId
				AND mr.ResourceId = ap.ResourceId
		)
	END

	SELECT Sporttype, AP_Main_CheckList AS MainCheckList ,AP_EAR_CheckList AS EarlyCheckList
	FROM @ResultTableSetting

	;WITH CTE_Provider AS (
			SELECT mr.matchId, mr.ResourceId,mr.ResourceType
				  ,MIN(mr.CreatedDate) AS CreatedDate
				  ,MAX(mr.TotalProvider) AS TotalProvider
				  ,IIF(MAX(mr.TotalPrimaryProvider) > 0 AND (MAX(mr.TotalSecondaryProvider) > 0 OR MAX(AP_TotalSecondaryProvider) = 0),MAX(mr.TotalProvider),MAX(mr.TotalPrimaryProvider))  AS TotalProviderSelected
				  ,MAX(mr.IsTrader) AS HasTrader
			FROM #MatchResource AS mr
			GROUP BY matchId,ResourceId,ResourceType
	)
	SELECT m.matchId
		  ,m.SportType
		  ,m.LeagueId
		  ,cte.ResourceId
		  ,cte.ResourceType
		  ,s.ResourceStatus
		  ,m.AP_Main_WaitingTime AS MainRetryTime
		  ,m.AP_EAR_WaitingTime  AS EarlyRetryTime
		  ,ssp.relatedCalResources
		  ,ssp.relatedSettResources
	FROM CTE_Provider AS cte
		INNER JOIN #Match AS m on cte.matchId = m.matchId
		CROSS APPLY(
			SELECT CASE WHEN cte.ResourceType = 1 AND m.AP_Main_HasTrader = cte.HasTrader AND IIF(m.AP_Main_TotalPrimaryProvider = 0,cte.TotalProvider,cte.TotalProviderSelected) >= m.AP_Main_NumberProvider 
							AND (m.AP_Main_TotalSource > 1 OR DATEDIFF(SECOND,cte.CreatedDate,@CurrentDateTime) > m.AP_Main_WaitingTime)  THEN 1					    
						WHEN cte.ResourceType = 2 AND m.AP_EAR_HasTrader = cte.HasTrader AND IIF(m.AP_EAR_TotalPrimaryProvider = 0,cte.TotalProvider,cte.TotalProviderSelected) >= m.AP_EAR_NumberProvider 
							AND (m.AP_EAR_TotalSource > 1 OR DATEDIFF(SECOND,cte.CreatedDate,@CurrentDateTime) > m.AP_EAR_WaitingTime) THEN 1
						WHEN cte.ResourceType = 1 AND DATEDIFF(SECOND,cte.CreatedDate,@CurrentDateTime) > m.AP_Main_WaitingTime AND (IIF(m.AP_Main_TotalPrimaryProvider = 0,cte.TotalProvider,cte.TotalProviderSelected) < m.AP_Main_NumberProvider OR  m.AP_Main_HasTrader != cte.HasTrader ) THEN 2
						WHEN cte.ResourceType = 2 AND DATEDIFF(SECOND,cte.CreatedDate,@CurrentDateTime) > m.AP_EAR_WaitingTime AND (IIF(m.AP_EAR_TotalPrimaryProvider = 0,cte.TotalProvider,cte.TotalProviderSelected)< m.AP_EAR_NumberProvider  OR  m.AP_EAR_HasTrader != cte.HasTrader) THEN 2
						ELSE 0
			END AS ResourceStatus
		) AS s	
		OUTER APPLY (SELECT  TOP 1 pfID
							,JSON_VALUE(ss.APSetting,'$."relatedCalResources"') AS relatedCalResources
							,JSON_VALUE(ss.APSetting,'$."relatedSettResources"') AS relatedSettResources
				     FROM SettlementSpecialBettypeProfile AS ss WITH(NOLOCK)
					 WHERE ss.ResourceID = cte.ResourceID
						AND ss.SportType = m.SportType
		) AS ssp
	WHERE s.ResourceStatus != 0
		AND (ssp.pfID IS NOT NULL OR cte.ResourceType = 1)

	SELECT matchId,ResourceId,HomeValue, AwayValue
	FROM #MatchResourceConfirmDate
	WHERE CreatedDate IS NULL
END
GO


 