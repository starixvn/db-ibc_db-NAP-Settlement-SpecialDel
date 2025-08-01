/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayoutOS_ResultSel
	 @MatchId			INT
	,@SportType			SMALLINT
	,@ResourceIds		VARCHAR(MAX)
	
AS
/*
	Creator: 20231002@Aries
	Task: Apply Auto Payout for Cricket by using TheSports Provider  [Redmine: #195768]
	DB: DBPRO/bodb02
	Revisions:
		- 20231002@Aries: Created [Redmine:#195768]
		- 20231205@Aries: Get only provider [Redmine: #195768]
		- 20231222@Louisa: Allow retry AutoPayout Cricket when score mismatch [Redmine: #198781]
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]
		- 20240503@Aries: Support Auto Payout 2 for Basketball [Redmine:#203520]
		- 20241118@Aries: Fix an issue which is wrong settlement due to the lack of consistency when calculating Innnings [Redmine:#213767]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
		- 20250120@Aries: Enhance the Validate Order for Auto Payout2 [Redmine:#209415]
		- 20250326@Aries: Support AutoPayout2 for Ice Hockey [Redmine:#219397]
		- 20250625@Aries: Match completed, but the auto payout flow still logs a failure [Redmine:#231523]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @ResultTable				TINYINT = 0
			,@ExternalResultTable		TINYINT = 0
			,@GameType					TINYINT  = 0
			,@Main_InactiveProvider		VARCHAR(500)
			,@EAR_InactiveProvider		VARCHAR(500)
			
	DECLARE @Resource TABLE (ResourceId	VARCHAR(20), PRIMARY KEY (ResourceId))
	DECLARE @Result TABLE (MatchId INT, SourceId SMALLINT,ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),SettlementStatusID TINYINT, ResultStatusID TINYINT, CreateDate DATETIME)

	SELECT @ResultTable	= r.ResultTable 
		  ,@ExternalResultTable = r.ExternalResultTable 
	FROM dbo.SettlementResultTableSetting r (NOLOCK)
	WHERE r.Sporttype = @Sporttype

	SELECT	 @GameType =  CASE WHEN m.Sporttype= 43 THEN l.OverTimeSession ELSE 0 END
			,@Main_InactiveProvider = COALESCE(ms.Main_InactiveProvider,ss.Main_InactiveProvider,'') 
			,@EAR_InactiveProvider = COALESCE(ms.EAR_InactiveProvider,ss.EAR_InactiveProvider,'') 
	FROM match AS m WITH(NOLOCK)
		INNER JOIN League l WITH(NOLOCK) ON m.LeagueId = l.LeagueId	
		LEFT JOIN	dbo.SettlementSetting AS ss WITH(NOLOCK) ON m.leagueid = ss.leagueid AND ss.AutoType = 6	
		LEFT JOIN	dbo.AutoPayoutSetting AS ms WITH(NOLOCK) ON m.matchId = ms.matchId AND ms.AutoType = 6
	WHERE m.MatchId	 = @MatchId	

	INSERT INTO @Resource(ResourceId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ResourceIds,',')
	WHERE value != ''

	IF @ResultTable = 0
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT m.MatchId
			  ,r.ResourceID
			  ,IIF (r.ResourceID = '00', CAST(m.finalhomescore AS VARCHAR(50)),  CAST(m.hthomescore AS VARCHAR(50)))
			  ,IIF (r.ResourceID = '00', CAST(m.finalawayscore AS VARCHAR(50)),  CAST(m.htawayscore AS VARCHAR(50)))
			  ,3 AS ResultStatusID
			  ,NULL AS SettlementStatusID
			  ,pe.CreateDate
		FROM dbo.match AS m WITH(NOLOCK)
			INNER JOIN dbo.match_remark AS mr  WITH(NOLOCK) ON mr.matchid =  m.matchid
			CROSS APPLY (SELECT r.ResourceID
						 FROM (VALUES ('00'),('01')) AS r(ResourceID)
						 WHERE 1 = CASE WHEN mr.ConfirmFT > 0 AND r.ResourceID = '00' AND m.finalhomescore IS NOT NULL THEN 1
										WHEN mr.ConfirmHT > 0 AND r.ResourceID = '01' AND m.hthomescore IS NOT NULL THEN 1
										ELSE 0
									END
			) AS r 
			CROSS APPLY (
					SELECT TOP 1 pr.ProviderExternalId AS LastProviderExternalId
					FROM dbo.ProviderExternalResultDetailOS AS pr WITH(NOLOCK)
					WHERE pr.MatchId = m.matchid 
						AND pr.ResourceId = r.ResourceID
						AND pr.SourceId = 97
					ORDER BY pr.ProviderExternalId DESC
				) AS pid
			CROSS APPLY (
					SELECT TOP 1 p.CreateDate  
					FROM dbo.ProviderExternalResultDetailOS AS p WITH(NOLOCK)
					WHERE p.ProviderExternalId = pid.LastProviderExternalId
						AND p.HomeValue = IIF(r.ResourceID = '00', CAST(m.finalhomescore AS VARCHAR(50)),  CAST(m.hthomescore AS VARCHAR(50)))
						AND p.AwayValue = IIF(r.ResourceID = '00', CAST(m.finalawayscore AS VARCHAR(50)),  CAST(m.htawayscore AS VARCHAR(50)))
				) AS pe
		WHERE m.matchid = @MatchId
			AND m.eventstatus = 'running'
			AND r.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)
	
	END

	IF @ResultTable = 1
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetail AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)	
			AND rd.ResultStatusID = 3			
	END
	ELSE IF @ResultTable = 2
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetailOS AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)	
			AND rd.ResultStatusID = 3
	END
	ELSE IF @ResultTable = 3
	BEGIN
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID, CreateDate)
		SELECT	rd.MatchId, rd.ResourceID, rd.HomeValue, rd.AwayValue, rd.ResultStatusID, rd.SettlementStatusID, rd.LastModifyDate
		FROM	dbo.ResultDetailES AS rd WITH(NOLOCK)		
		WHERE rd.matchid = @MatchId	
			AND rd.ResourceID IN (SELECT r.ResourceID FROM @Resource AS r)
			AND rd.ResultStatusID = 3
	END

	IF @ExternalResultTable = 1
	BEGIN
		WITH CTE_Provider AS (
			SELECT MAX(p.ProviderExternalId) AS ProviderExternalId
			FROM ProviderExternalResultDetail AS p WITH(NOLOCK)
			WHERE  p.matchId = @MatchId
				AND p.ResourceId IN (SELECT r.ResourceID FROM @Resource AS r)
				AND p.SourceID < 1001 
				AND p.SourceID NOT IN (98,99,100)
				AND ISNULL(p.IsLive,0) = 0
			GROUP BY p.matchId,p.SourceId,p.ResourceId
		)
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,SourceId, CreateDate)
		SELECT rd.matchId,rd.ResourceId,rd.HomeValue,rd.AwayValue,rd.SourceId, rd.CreateDate
		FROM CTE_Provider AS cte	
			INNER JOIN ProviderExternalResultDetail AS rd WITH(NOLOCK) ON rd.ProviderExternalId = cte.ProviderExternalId
	END
	ELSE IF @ExternalResultTable = 2
	BEGIN
		WITH CTE_Provider AS (
			SELECT MAX(p.ProviderExternalId) AS ProviderExternalId
			FROM ProviderExternalResultDetailOS AS p WITH(NOLOCK)
			WHERE  p.matchId = @MatchId
				AND p.ResourceId IN (SELECT r.ResourceID FROM @Resource AS r)
				AND p.SourceID < 1001 
				AND p.SourceID NOT IN (98,99,100)
				AND ISNULL(p.IsLive,0) = 0
			GROUP BY p.matchId,p.SourceId,p.ResourceId
		)
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,SourceId, CreateDate)
		SELECT rd.matchId,rd.ResourceId,rd.HomeValue,rd.AwayValue,rd.SourceId,rd.CreateDate
		FROM CTE_Provider AS cte	
			INNER JOIN ProviderExternalResultDetailOS AS rd WITH(NOLOCK) ON rd.ProviderExternalId = cte.ProviderExternalId
	END
	ELSE IF @ExternalResultTable = 3
	BEGIN
		WITH CTE_Provider AS (
			SELECT MAX(p.ProviderExternalId) AS ProviderExternalId
			FROM ProviderExternalResultDetailES AS p WITH(NOLOCK)
			WHERE  p.matchId = @MatchId
				AND p.ResourceId IN (SELECT r.ResourceID FROM @Resource AS r)
				AND p.SourceID < 1001 
				AND p.SourceID NOT IN (98,99,100)
				AND ISNULL(p.IsLive,0) = 0
			GROUP BY p.matchId,p.SourceId,p.ResourceId
		)
		INSERT INTO @Result (MatchId, ResourceId, HomeValue, AwayValue,SourceId,CreateDate)
		SELECT rd.matchId,rd.ResourceId,rd.HomeValue,rd.AwayValue,rd.SourceId,rd.CreateDate
		FROM CTE_Provider AS cte	
			INNER JOIN ProviderExternalResultDetailES AS rd WITH(NOLOCK) ON rd.ProviderExternalId = cte.ProviderExternalId
	END

	SELECT m.matchId
		  ,m.SourceId
		  ,p.SourceName
		  ,m.ResourceId
		  ,m.HomeValue
		  ,m.AwayValue
		  ,m.CreateDate
		  ,ss.HasAwayValue
	FROM @Result AS m
		OUTER APPLY (
			SELECT TOP 1 tbl.ResourceId
			FROM [dbo].[f_Set_MajorRound](@SportType) AS tbl 
			WHERE tbl.ResourceId = m.ResourceId
		) AS mr
		OUTER APPLY (SELECT  TOP 1 
							 s.HasAwayValue
							,s.pfID
				     FROM SettlementSpecialBettypeProfile AS s WITH(NOLOCK)
					 WHERE s.ResourceID = m.ResourceID
						AND s.SportType = @SportType
		) AS ss
		LEFT JOIN ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = m.SourceId
		OUTER APPLY (SELECT TOP 1 1 AS IsMapped
					 FROM dbo.ProviderGameTypeMapping AS p WITH(NOLOCK)
					 WHERE p.sporttype = @SportType
						AND p.SourceId = m.SourceID
						AND p.isActive = 1
						AND p.GameType = @GameType) AS pm
	WHERE (pm.IsMapped IS NOT NULL OR m.SourceId IS NULL)
		AND  (ss.pfID IS NOT NULL OR mr.ResourceId IS NOT NULL)
		AND 1 = CASE WHEN ISNULL(m.SourceId,0) > 0 
						  AND IIF(mr.ResourceId IS NOT NULL,@Main_InactiveProvider,@EAR_InactiveProvider) != '' 
						  AND CHARINDEX(','+CAST(m.SourceID AS VARCHAR)+',',','+ IIF(mr.ResourceId IS NOT NULL,@Main_InactiveProvider,@EAR_InactiveProvider) +',') > 0 THEN 0
					 ELSE 1
				END

		
END
GO




