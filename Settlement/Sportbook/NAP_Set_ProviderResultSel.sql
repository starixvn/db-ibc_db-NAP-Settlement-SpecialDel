/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[NAP_Set_ProviderResultSel]
	 @MatchID				INT 
	,@ResourceIDs			VARCHAR(MAX)
	,@SourceIDs				VARCHAR(MAX)
	,@LatestRecord			BIT
	,@IsLive				BIT = 0
AS
/*
    Created by: 20240122@Aries
    Task: Provider Result Log [Redmine:#199100]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20240122@Aries: Provider Result Log [Redmine:#199100]
		- 20240307@Aries: Enhance the Provider Result Logs Phase 2 [Redmine: #201480]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		- 20241002@Aries: direct payout for early soccer [Redmine:#211079]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]
		- 20241212@Aries: Support to add a parameter to the new Live column for Provider Tables [Redmine:#215143]
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Data(ResourceId VARCHAR(20),SourceId SMALLINT,SourceName VARCHAR(50), HomeValue VARCHAR(50),AwayValue VARCHAR(50),OtherInfo VARCHAR(50),CreateDate DATETIME,AutoPayoutStatus TINYINT, Remark VARCHAR(1000), RankNo INT, IsLive BIT)		
	CREATE TABLE #ResourceInfo(ResourceId VARCHAR(20) PRIMARY KEY,OrdNo SMALLINT)		

	DECLARE @tmpResourceID			TABLE (ResourceID VARCHAR(20))
	DECLARE @tmpSourceID			TABLE (SourceID SMALLINT)
	DECLARE @Sporttype				SMALLINT
		   ,@ExternalResultTable	TINYINT

	SELECT @Sporttype = m.Sporttype
	FROM match AS m WITH(NOLOCK)
	WHERE m.matchid = @MatchID

	SELECT @ExternalResultTable = CASE WHEN st.sporttype = 8 THEN 2 ELSE ExternalResultTable END
	FROM SettlementResultTableSetting AS st WITH(NOLOCK)
	WHERE st.Sporttype = @Sporttype

	INSERT INTO @tmpResourceID(ResourceID)
	SELECT f.value
	FROM STRING_SPLIT(@ResourceIDs, ',') AS f 

	INSERT INTO @tmpSourceID(SourceID)
	SELECT f.value
	FROM STRING_SPLIT(@SourceIDs, ',') AS f 

	INSERT INTO #ResourceInfo(ResourceId,OrdNo)
	SELECT ResourceId,MIN(ISNULL(OrdNo,9999))
	FROM SettlementSpecialBettypeProfile AS sp WITH(NOLOCK) 
	WHERE Sporttype = @Sporttype
	GROUP BY ResourceId

	IF @ExternalResultTable = 1
	BEGIN
		INSERT INTO #Data(ResourceId, SourceId,SourceName,HomeValue,AwayValue,OtherInfo,CreateDate,RankNo,IsLive)
		SELECT pr.ResourceId
			  ,pr.SourceId
			  ,p.SourceName
			  ,pr.HomeValue
			  ,pr.AwayValue
			  ,pr.OtherInfo
			  ,pr.CreateDate
			  ,ROW_NUMBER() OVER (PARTITION BY pr.SourceId,pr.ResourceId ORDER BY pr.CreateDate DESC) AS RankNo
			  ,pr.IsLive
		FROM ProviderExternalResultDetail AS pr WITH(NOLOCK)
			INNER JOIN  ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = pr.SourceId
			INNER JOIN  @tmpSourceID AS tp ON tp.SourceId = pr.SourceId
			LEFT JOIN  @tmpResourceID AS r ON r.ResourceID = pr.ResourceID
		WHERE pr.MatchId = @MatchID
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
			AND ISNULL(pr.IsLive,0) = @IsLive
	END
	ELSE IF @ExternalResultTable = 2
	BEGIN
		INSERT INTO #Data(ResourceId, SourceId,SourceName,HomeValue,AwayValue,OtherInfo,CreateDate,RankNo,IsLive)
		SELECT pr.ResourceId
			  ,pr.SourceId
			  ,p.SourceName
			  ,pr.HomeValue
			  ,pr.AwayValue
			  ,pr.OtherInfo
			  ,pr.CreateDate
			  ,ROW_NUMBER() OVER (PARTITION BY pr.SourceId,pr.ResourceId ORDER BY pr.CreateDate DESC) AS RankNo
			  ,pr.IsLive
		FROM ProviderExternalResultDetailOS AS pr WITH(NOLOCK)
			INNER JOIN  ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = pr.SourceId
			INNER JOIN  @tmpSourceID AS tp ON tp.SourceId = pr.SourceId
			LEFT JOIN  @tmpResourceID AS r ON r.ResourceID = pr.ResourceID
		WHERE pr.MatchId = @MatchID
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
			AND ISNULL(pr.IsLive,0) = @IsLive
	END
	ELSE IF @ExternalResultTable = 3
	BEGIN
		INSERT INTO #Data(ResourceId, SourceId,SourceName,HomeValue,AwayValue,OtherInfo,CreateDate,RankNo,IsLive)
		SELECT pr.ResourceId
			  ,pr.SourceId
			  ,p.SourceName
			  ,pr.HomeValue
			  ,pr.AwayValue
			  ,pr.OtherInfo
			  ,pr.CreateDate
			  ,ROW_NUMBER() OVER (PARTITION BY pr.SourceId,pr.ResourceId ORDER BY pr.CreateDate DESC) AS RankNo
			  ,pr.IsLive
		FROM ProviderExternalResultDetailES AS pr WITH(NOLOCK)
			INNER JOIN  ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = pr.SourceId
			INNER JOIN  @tmpSourceID AS tp ON tp.SourceId = pr.SourceId
			LEFT JOIN  @tmpResourceID AS r ON r.ResourceID = pr.ResourceID
		WHERE pr.MatchId = @MatchID
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
			AND ISNULL(pr.IsLive,0) = @IsLive
	END

	IF @Sporttype = 1
	BEGIN
		INSERT INTO #Data(ResourceId,HomeValue,AwayValue,CreateDate,AutoPayoutStatus,Remark,RankNo)
		SELECT CASE WHEN ap.CalculationType = 1 THEN '01'
                    WHEN ap.CalculationType = 2 THEN '00'
                    ELSE ap.ResourceID 
               END AS ResourceId
			  ,ap.HomeValue
			  ,ap.AwayValue
			  ,ap.CreatedDate
			  ,ap.StatusId
			  ,ap.Remark
			  ,1 AS RankNo
		FROM  AutoPayoutResult AS ap WITH(NOLOCK)
			LEFT JOIN  @tmpResourceID AS r ON (ap.CalculationType = 1 AND r.ResourceID = '01') OR (ap.CalculationType = 2 AND r.ResourceID = '00') OR (ap.CalculationType = 5 AND r.ResourceID = ap.ResourceID)
		WHERE ap.matchID = @MatchID
			AND ap.CalculationType IN (1,2,5)
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END 

		INSERT INTO #Data(ResourceId, SourceId,SourceName,HomeValue,AwayValue,CreateDate,RankNo)
		SELECT IIF(pr.TypeId = 1,'01','00') AS ResourceId
			  ,pr.SourceId
			  ,p.SourceName
			  ,pr.HomeValue
			  ,pr.AwayValue
			  ,pr.CreatedDate AS CreateDate
			  ,ROW_NUMBER() OVER (PARTITION BY pr.SourceId,pr.TypeId ORDER BY pr.CreatedDate DESC) AS RankNo
		FROM ProviderResultDetail AS pr WITH(NOLOCK)
			INNER JOIN  ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = pr.SourceId
			INNER JOIN  @tmpSourceID AS tp ON tp.SourceId = pr.SourceId
			LEFT JOIN  @tmpResourceID AS r ON (pr.TypeId = 1 AND r.ResourceID = '01') OR (pr.TypeId = 2 AND r.ResourceID = '00')
		WHERE pr.MatchId = @MatchID
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
	END
	ELSE
	BEGIN
		INSERT INTO #Data(ResourceId,HomeValue,AwayValue,CreateDate,AutoPayoutStatus,Remark,RankNo)
		SELECT ap.ResourceId
			  ,ap.HomeValue
			  ,ap.AwayValue
			  ,ap.CreatedDate
			  ,ap.StatusId
			  ,ap.Remark
			  ,1 AS RankNo
		FROM  AutoPayoutResultOS AS ap WITH(NOLOCK)
			LEFT JOIN  @tmpResourceID AS r ON r.ResourceID = ap.ResourceID
		WHERE ap.matchID = @MatchID
			AND ISNULL(ap.SourceID,0) = 0
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
	END

	SELECT d.ResourceId 
		  ,d.SourceName
		  ,d.HomeValue
		  ,d.AwayValue
		  ,d.OtherInfo
		  ,d.CreateDate
		  ,d.AutoPayoutStatus 
		  ,d.Remark
		  ,tbl.OrdNo
		  ,d.IsLive
	FROM #Data AS d
		OUTER APPLY(
			SELECT TOP 1  r.OrdNo
			FROM #ResourceInfo AS r 
			WHERE d.ResourceId = r.ResourceId
		) AS tbl
	WHERE 1 = CASE WHEN @LatestRecord  = 1 AND RankNo = 1 THEN 1
				   WHEN @LatestRecord = 0				  THEN 1
				   ELSE 0
			  END
	ORDER BY CreateDate ASC, tbl.OrdNo ASC
END
GO