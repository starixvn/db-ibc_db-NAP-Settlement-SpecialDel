/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_Fantasy_ScheduleSel]
AS
/*	Creator: 20230616@Aries
	Task: Support Direct Payout for Soccer Fantasy Matches
	DB: DBPRO/BODB02
	
	Revisions:
		- 20230616@Aries: Created [Redmine:#189493]

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

	DECLARE @tmpMatch		TABLE(MatchId INT,LeagueId INT, HtHomescore INT, FinalHomescore INT, HtAwayscore INT, FinalAwayscore INT, Action  VARCHAR(20),LastParentCalculateDate DATETIME,  AutoSetting TINYINT, SettlementStatus TINYINT)
	DECLARE @tmpParentInfo	TABLE(MatchId INT,MatchParentId INT,ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),SettlementStatusID TINYINT,LastModifyDate DATETIME,SettlementStatus TINYINT,   IsValid BIT)

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		 @SPName		=	@ProcName
		,@WaitingTime	=	@WaitingTime	OUTPUT
		,@IsWaiting		=	@IsWaiting		OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, AutoSetting
		FROM @tmpMatch

		RETURN
	END

	SET @CurrentDate = CAST(GETDATE() AS DATE)
	SELECT	@FromDate = DATEADD(DAY,-1,@CurrentDate)
		   ,@ToDate = DATEADD(DAY,1,@CurrentDate)


	INSERT INTO @tmpMatch(MatchId,LeagueId,AutoSetting, SettlementStatus)
	SELECT m.MatchId
		  ,m.LeagueId
		  ,ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AS AutoSetting
		  ,m.SettlementStatus
	FROM match AS m WITH(NOLOCK)
		INNER JOIN dbo.League AS l WITH(NOLOCK) ON	m.leagueid = l.leagueid
		OUTER APPLY (SELECT	TOP 1 1 AS IsCalculated
					 FROM dbo.ResultDetail AS rd WITH(NOLOCK)
					 WHERE rd.MatchId = m.matchid
						AND rd.ResourceId IN ('00','01')
						AND rd.ResultStatusID IN (2,5)
					) AS r
		OUTER APPLY (SELECT TOP 1 1 AS IsExistAP 
					 FROM dbo.AutoPayoutResult AS apr WITH(NOLOCK) 
					 WHERE apr.MatchId = m.matchid 
				) AS rs
		OUTER APPLY (SELECT TOP 1 1 AS IsExistAR
					 FROM dbo.AutoRefundResult AS arr WITH(NOLOCK) 
					 WHERE arr.MatchId = m.matchid 
				) AS ar
	WHERE m.eventstatus = 'running' 
		AND m.eventdate BETWEEN @FromDate AND @ToDate
		AND m.leagueid IN (16371,65550,89611)
		AND ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0))  & 16 > 0
		AND ISNULL(m.SettlementStatus,0) & 87 = 0
		AND r.IsCalculated IS NULL
		AND rs.IsExistAP IS NULL
		AND ar.IsExistAR IS NULL
		
	INSERT INTO @tmpParentInfo(MatchId,MatchParentId,ResourceId, HomeValue, AwayValue,SettlementStatusID,LastModifyDate,SettlementStatus, IsValid)
	SELECT fm.MatchId
		  ,pr.ParentID
		  ,rd.ResourceId
		  ,IIF(CHARINDEX(','+CAST(m.homeid AS VARCHAR(20))+',', ','+mp.fantasyh+',') > 0,CAST(rd.HomeValue AS INT),0)  + 
		   IIF(CHARINDEX(','+CAST(m.awayid AS VARCHAR(20))+',', ','+mp.fantasyh+',') > 0,CAST(rd.AwayValue AS INT),0)  AS HomeValue
		  ,IIF(CHARINDEX(','+CAST(m.homeid AS VARCHAR(20))+',', ','+mp.fantasya+',') > 0,CAST(rd.HomeValue AS INT),0)  + 
		   IIF(CHARINDEX(','+CAST(m.awayid AS VARCHAR(20))+',', ','+mp.fantasya+',') > 0,CAST(rd.AwayValue AS INT),0)  AS AwayValue
		  ,rd.SettlementStatusID
		  ,rd.LastModifyDate
		  ,m.SettlementStatus
		  ,CASE WHEN mp.fantasy IS NULL THEN 0
				WHEN m.MatchId IS NULL THEN 0
				ELSE 1
			END AS IsValid
	FROM  @tmpMatch AS fm
		OUTER APPLY	(SELECT pv.fantasy
						   ,pv.fantasyh
						   ,pv.fantasya
					FROM (SELECT mpf.MatchId, mpf.[key], mpf.Value
						  FROM dbo.Match_Property AS mpf WITH(NOLOCK)
						  WHERE  mpf.matchid = fm.matchid AND mpf.[key] LIKE 'fantasy%'
					) f
					PIVOT(MAX( f.Value) 
						  FOR f.[key] IN ([fantasy],[fantasyh],[fantasya] )
					) pv
		) AS mp
		OUTER APPLY (SELECT CAST(p.[value] AS INT) AS ParentID
					 FROM STRING_SPLIT(mp.[fantasy],',') AS p
		) AS pr 
		LEFT JOIN  dbo.match AS m WITH(NOLOCK) ON m.MatchId = pr.ParentID
		LEFT JOIN  dbo.ResultDetail AS rd WITH(NOLOCK) ON rd.MatchId = pr.ParentID AND rd.ResourceId IN ('00','01')
	
	DELETE m
	FROM @tmpMatch AS m
	WHERE NOT EXISTS (SELECT 1
					  FROM @tmpParentInfo AS pr
					  WHERE m.MatchId = pr.MatchId)
	  OR EXISTS (SELECT 1
				 FROM @tmpParentInfo AS pr
				 WHERE m.MatchId = pr.MatchId AND pr.IsValid = 0);
	
	UPDATE m
	SET  m.Action = 'REFUND'
	FROM @tmpMatch AS m
	WHERE EXISTS (SELECT MAX(pr.LastModifyDate) AS LastModifyDate
				  FROM @tmpParentInfo AS pr
				  WHERE pr.MatchId = m.MatchId 
				  GROUP BY pr.MatchId,pr.MatchParentId
				  HAVING COUNT(1) % 2 = 0 AND SUM(IIF(SettlementStatusID = 1,4,0)) / COUNT(1) =  4) 
		


	UPDATE m
	SET  m.Action = 'CAL'
		,m.LastParentCalculateDate = tbl.LastParentCalculateDate
		,m.FinalHomescore = tbl.FinalHomescore
		,m.FinalAwayscore = tbl.FinalAwayscore
		,m.HtHomescore = tbl.HtHomescore
		,m.HtAwayscore = tbl.HtAwayscore
	FROM @tmpMatch AS m
		CROSS APPLY (
				SELECT MAX(LastModifyDate) AS LastParentCalculateDate
					  ,SUM(IIF(ResourceId = '00', CAST(HomeValue AS INT),0)) AS FinalHomescore
					  ,SUM(IIF(ResourceId = '00', CAST(AwayValue AS INT),0)) AS FinalAwayscore
					  ,SUM(IIF(ResourceId = '01', CAST(HomeValue AS INT),0)) AS HtHomescore
					  ,SUM(IIF(ResourceId = '01', CAST(AwayValue AS INT),0)) AS HtAwayscore
				FROM @tmpParentInfo AS pr
				WHERE pr.MatchId = m.MatchId 
				GROUP BY pr.MatchId
				HAVING COUNT(1) % 2 = 0 AND SUM(IIF(pr.SettlementStatusID = 4 AND  ISNULL(pr.SettlementStatus,0) & 119 = 0,4,0)) / COUNT(1) =  4
		) AS tbl 
	WHERE m.SettlementStatus  & 32 = 0


	DECLARE @CurrTime DATETIME = GETDATE()

	SELECT m.MatchId
		  ,m.LeagueId
		  ,m.HtHomescore
		  ,m.FinalHomescore
		  ,m.HtAwayscore
		  ,m.FinalAwayscore
		  ,m.Action
		  ,m.AutoSetting
		  ,2 AS TypeId
	FROM @tmpMatch AS m
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime
			FROM dbo.SettlementSetting AS ss WITH (NOLOCK)
			WHERE ss.LeagueId = m.LeagueId
				AND ss.AutoType = 5
		) AS ss
	WHERE (m.Action = 'CAL' AND m.LastParentCalculateDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,1), @CurrTime)) OR
		   m.Action = 'REFUND'

END
GO
