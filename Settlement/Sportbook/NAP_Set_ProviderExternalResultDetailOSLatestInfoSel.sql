/*<info serverAlias="DBPRO-bodb02 " executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailOSLatestInfoSel]
	@MatchId INT
	,@SettleType	VARCHAR(10) = 'MNL'
AS
/*
    Created by: 20200908@Louisa
    Task: get latest LSports result [Redmine:#139979]
    DB: DBPRO/BODB02
    
    Revisions:            
		- 20200908@Louisa: get latest LSports result [Redmine:#139979]
		- 20210305@Louisa: SOP for Tennis [Readmine:#150425]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155360,#155361]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192] 
		- 20220629@Louisa: Volleyball AIO [Redmineid:#173862]
		- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT
			,@LeagueId INT
			,@ExternalResultTable TINYINT

	SELECT @LeagueId = m.LeagueId 
		 ,@SportType = m.sporttype
	FROM dbo.Match m WITH(NOLOCK)
	WHERE m.MatchId = @MatchId

	SELECT @ExternalResultTable  = s.ExternalResultTable
	FROM dbo.SettlementResultTableSetting s WITH(NOLOCK)
	WHERE s.Sporttype = @SportType
	
	IF @SportType = 8
		SELECT @ExternalResultTable =2
				
	DECLARE @tmpLatestResult AS TABLE ( SourceId SMALLINT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50)	)
	DECLARE @tmpProviderExternalResult AS TABLE (SourceId SMALLINT,SourceName VARCHAR(50) ,Remark NVARCHAR(1000), ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OrderNo INT)
	DECLARE @tmpSourceId AS TABLE ( SourceId SMALLINT,SourceName VARCHAR(50), Remark NVARCHAR(1000) , OrderNo INT )

	IF @ExternalResultTable = 1
	BEGIN
		;WITH cteLatest (rn, SourceId, ResourceId, HomeValue, AwayValue) AS
		(
			SELECT	ROW_NUMBER() OVER (PARTITION BY p.SourceId, p.ResourceId ORDER BY p.CreateDate DESC) AS rn
					,p.SourceId
					,p.ResourceId
					,p.HomeValue
					,p.AwayValue
			FROM	dbo.ProviderExternalResultDetail p WITH(NOLOCK)
			WHERE	p.MatchId = @MatchId
				AND  ISNULL(p.IsLive,0) = 0
		)
		INSERT INTO @tmpLatestResult (SourceId, ResourceId, HomeValue, AwayValue)
		SELECT l.SourceId ,l.ResourceId, l.HomeValue, l.AwayValue
		FROM cteLatest l	
			LEFT JOIN dbo.f_Set_MajorRound(@SportType) fsmr
				ON l.ResourceId = fsmr.ResourceId
		WHERE rn = 1
			AND 1 = CASE WHEN @SettleType = 'MNL' AND fsmr.ResourceId IS NOT NULL THEN 1
					   WHEN @SettleType ='EAR' AND  fsmr.ResourceId IS  NULL THEN  1
					   ELSE 0
					   END
	END

	IF @ExternalResultTable = 2
	BEGIN
		;WITH cteLatestOS (rn, SourceId, ResourceId, HomeValue, AwayValue) AS
		(
			SELECT	ROW_NUMBER() OVER (PARTITION BY p.SourceId, p.ResourceId ORDER BY p.CreateDate DESC) AS rn
					,p.SourceId
					,p.ResourceId
					,p.HomeValue
					,p.AwayValue
			FROM	dbo.ProviderExternalResultDetailOS p WITH(NOLOCK)
			WHERE	p.MatchId = @MatchId
				AND  ISNULL(p.IsLive,0) = 0
		)
		INSERT INTO @tmpLatestResult (SourceId, ResourceId, HomeValue, AwayValue)
		SELECT l.SourceId ,l.ResourceId, l.HomeValue, l.AwayValue
		FROM cteLatestOS l	
			LEFT JOIN (
				SELECT 	ResourceId 
				FROM 	dbo.f_Set_MajorRound(@SportType)
				UNION ALL
				SELECT '8816' AS ResourceId -- total hits
				WHERE @SportType = 8
			) fsmr
				ON l.ResourceId = fsmr.ResourceId
		WHERE rn = 1
			AND 1 = CASE WHEN @SettleType = 'MNL' AND fsmr.ResourceId IS NOT NULL THEN 1
					   WHEN @SettleType ='EAR' AND  fsmr.ResourceId IS  NULL THEN  1
					   ELSE 0
					   END
	END
	
	INSERT INTO @tmpSourceId (SourceId,SourceName, Remark, OrderNo)
	SELECT  pgm.SourceId, pi.SourceName, pi.Remark,  ISNULL(plmo.OrderNo, pgm.OrderNo) AS OrderNo
	FROM   ProviderInfo pi WITH(NOLOCK)
		INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)
			ON pi.SourceId  = pgm.SourceId
		LEFT JOIN ProviderLeagueMappingOutsideSource plmo WITH(NOLOCK)
			ON plmo.PGId =  pgm.PGId and plmo.LeagueId  = @LeagueId
	WHERE   pgm.Sporttype = @SportType
		AND (	pgm.SourceId <= 1001 
				OR  plmo.PGId  IS NOT NULL
			)
		AND pi.isActive	 = 1
		AND pgm.isActive = 1
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpSourceId s WHERE s.SourceId = 100)
		BEGIN
			INSERT INTO @tmpSourceId (SourceId,	SourceName, Remark, OrderNo)
			VALUES (100,'Trader Score','n/a', 0)
		END

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpSourceId s WHERE s.SourceId = 1001)
		BEGIN
			INSERT INTO @tmpSourceId (SourceId,SourceName, Remark, OrderNo)
			SELECT 1001
				, CASE WHEN @SportType = 5 THEN 'Info Site' ELSE 'Screenshot' END
				,'n/a'
				, 1
		END

	INSERT INTO @tmpProviderExternalResult(SourceId, SourceName, Remark, ResourceId, HomeValue, AwayValue, OrderNo)
	SELECT	s.SourceId, s.SourceName, s.Remark, ISNULL(l.ResourceId,'00'), ISNULL(l.HomeValue,'') , ISNULL(l.AwayValue,''), s.OrderNo
	FROM	@tmpLatestResult l
		RIGHT JOIN @tmpSourceId s 
			ON s.SourceId = l.SourceId
	WHERE	( l.SourceId < 1001 AND s.SourceId IS NOT NULL )
		OR s.SourceId >= 1001
					 			
	SELECT	t.SourceId
			,CASE WHEN @SportType = 5 AND t.SourceId = 1001 THEN 'Info Site' ELSE t.SourceName END AS SourceName
			,t.Remark
			,t.ResourceId
			,t.HomeValue
			,t.AwayValue
			,t.OrderNo
	FROM	@tmpProviderExternalResult t

END
GO
