/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet " viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[NAP_Set_ProviderResultSel]
	 @MatchID				INT 
	,@ResourceIDs			VARCHAR(MAX)
	,@SourceIDs				VARCHAR(MAX)
	,@LatestRecord			BIT
AS
/*
    Created by: 20240122@Aries
    Task: Provider Result Log [Redmine:#199100]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20240122@Aries: Provider Result Log [Redmine:#199100]
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Data(ResourceId VARCHAR(20),SourceId SMALLINT,SourceName VARCHAR(50), HomeValue VARCHAR(50),AwayValue VARCHAR(50),OtherInfo VARCHAR(50),CreateDate DATETIME,AutoPayoutStatus TINYINT, RankNo INT)		
	CREATE TABLE #ResourceInfo(ResourceId VARCHAR(20) PRIMARY KEY,OrdNo SMALLINT)		

	DECLARE @tmpResourceID			TABLE (ResourceID VARCHAR(20))
	DECLARE @tmpSourceID			TABLE (SourceID SMALLINT)
	DECLARE @Sporttype				SMALLINT
		   ,@ExternalResultTable	TINYINT

	SELECT @Sporttype = m.Sporttype
	FROM match AS m WITH(NOLOCK)
	WHERE m.matchid = @MatchID

	SELECT @ExternalResultTable = ExternalResultTable
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
		INSERT INTO #Data(ResourceId, SourceId,SourceName,HomeValue,AwayValue,OtherInfo,CreateDate,RankNo)
		SELECT pr.ResourceId
			  ,pr.SourceId
			  ,p.SourceName
			  ,pr.HomeValue
			  ,pr.AwayValue
			  ,pr.OtherInfo
			  ,pr.CreateDate
			  ,ROW_NUMBER() OVER (PARTITION BY pr.SourceId,pr.ResourceId ORDER BY pr.CreateDate DESC) AS RankNo
		FROM ProviderExternalResultDetail AS pr WITH(NOLOCK)
			INNER JOIN  ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = pr.SourceId
			INNER JOIN  @tmpSourceID AS tp ON tp.SourceId = pr.SourceId
			LEFT JOIN  @tmpResourceID AS r ON r.ResourceID = pr.ResourceID
		WHERE pr.MatchId = @MatchID
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
	END
	ELSE IF @ExternalResultTable = 2
	BEGIN
		INSERT INTO #Data(ResourceId, SourceId,SourceName,HomeValue,AwayValue,OtherInfo,CreateDate,RankNo)
		SELECT pr.ResourceId
			  ,pr.SourceId
			  ,p.SourceName
			  ,pr.HomeValue
			  ,pr.AwayValue
			  ,pr.OtherInfo
			  ,pr.CreateDate
			  ,ROW_NUMBER() OVER (PARTITION BY pr.SourceId,pr.ResourceId ORDER BY pr.CreateDate DESC) AS RankNo
		FROM ProviderExternalResultDetailOS AS pr WITH(NOLOCK)
			INNER JOIN  ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = pr.SourceId
			INNER JOIN  @tmpSourceID AS tp ON tp.SourceId = pr.SourceId
			LEFT JOIN  @tmpResourceID AS r ON r.ResourceID = pr.ResourceID
		WHERE pr.MatchId = @MatchID
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
	END
	ELSE IF @ExternalResultTable = 3
	BEGIN
		INSERT INTO #Data(ResourceId, SourceId,SourceName,HomeValue,AwayValue,OtherInfo,CreateDate,RankNo)
		SELECT pr.ResourceId
			  ,pr.SourceId
			  ,p.SourceName
			  ,pr.HomeValue
			  ,pr.AwayValue
			  ,pr.OtherInfo
			  ,pr.CreateDate
			  ,ROW_NUMBER() OVER (PARTITION BY pr.SourceId,pr.ResourceId ORDER BY pr.CreateDate DESC) AS RankNo
		FROM ProviderExternalResultDetailES AS pr WITH(NOLOCK)
			INNER JOIN  ProviderInfo AS p WITH(NOLOCK) ON p.SourceId = pr.SourceId
			INNER JOIN  @tmpSourceID AS tp ON tp.SourceId = pr.SourceId
			LEFT JOIN  @tmpResourceID AS r ON r.ResourceID = pr.ResourceID
		WHERE pr.MatchId = @MatchID
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
	END

	IF @Sporttype = 1
	BEGIN
		INSERT INTO #Data(ResourceId,HomeValue,AwayValue,CreateDate,AutoPayoutStatus,RankNo)
		SELECT IIF(ap.CalculationType = 1,'01','00') AS ResourceId
			  ,ap.HomeValue
			  ,ap.AwayValue
			  ,ap.CreatedDate
			  ,ap.StatusId
			  ,1 AS RankNo
		FROM  AutoPayoutResult AS ap WITH(NOLOCK)
			LEFT JOIN  @tmpResourceID AS r ON (ap.CalculationType = 1 AND r.ResourceID = '01') OR (ap.CalculationType = 2 AND r.ResourceID = '00')
		WHERE ap.matchID = @MatchID
			AND ap.CalculationType IN (1,2)
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END 
	END
	ELSE
	BEGIN
		INSERT INTO #Data(ResourceId,HomeValue,AwayValue,CreateDate,AutoPayoutStatus,RankNo)
		SELECT ap.ResourceId
			  ,ap.HomeValue
			  ,ap.AwayValue
			  ,ap.CreatedDate
			  ,ap.StatusId
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
		  ,tbl.OrdNo
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