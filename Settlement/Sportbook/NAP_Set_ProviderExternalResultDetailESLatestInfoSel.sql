/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ProviderExternalResultDetailESLatestInfoSel
	@MatchId INT
	,@SettleType	VARCHAR(10) = 'MNL'
AS
/*
    Created by: 20200721@Kathy
    Task: get provider result [Redmine:#136931]
    DB: DBPRO/BODB02  
    
    Revisions:            
		- 20200721@Kathy: get provider result [Redmine:#136931]
		- 20200810@Louisa: get OutsideSource result [Redmine:#138656]
		- 20200904@Louisa: Implement for EARLY [Redmine:#140407]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]

	Param's Explanation:
		If not exists SourceId = 1001 ==> Add dummy values
		If not exist score for Top 4 OutsideSource: HomeValue=AwayValue=''

		@SettleType: 'MNL'- Manual, 'EAR'- Early
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT
	DECLARE @LeagueId INT
	DECLARE @GameType TINYINT

	DECLARE @tmpLatestResult AS TABLE (ProviderExternalId INT,SourceId SMALLINT,ResourceId	varchar(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	DECLARE @tmpProviderExternalResult AS TABLE (SourceId SMALLINT,SourceName VARCHAR(50) ,Remark NVARCHAR(1000), ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OrderNo INT)
	DECLARE @tmpSourceId AS TABLE ( SourceId SMALLINT,SourceName VARCHAR(50), Remark NVARCHAR(1000) , OrderNo INT )

	SET @SportType = 43

	SELECT @LeagueId = m.LeagueId FROM dbo.Match m WITH(NOLOCK) WHERE m.MatchId = @MatchId
	SELECT @GameType = l.OverTimeSession FROM dbo.League l WITH(NOLOCK) WHERE l.leagueid = @LeagueId
	
	;WITH cteLatestId
	AS(
		SELECT	ROW_NUMBER() OVER (PARTITION BY p.SourceId, p.ResourceId ORDER BY p.CreateDate DESC) AS rn
				,p.SourceId
				,p.ResourceId
				,p.ProviderExternalId
				, HomeValue
				, AwayValue
		FROM	dbo.ProviderExternalResultDetailES p WITH(NOLOCK)
		WHERE	p.MatchId = @MatchId
			AND ISNULL(p.IsLive,0) = 0
	)
	INSERT INTO @tmpLatestResult (ProviderExternalId, SourceId,ResourceId, HomeValue, AwayValue)
	SELECT l.ProviderExternalId, l.SourceId ,l.ResourceId, l.HomeValue, l.AwayValue
	FROM cteLatestId l	
		LEFT JOIN dbo.f_Set_MajorRound(@SportType) fsmr
			ON l.ResourceId = fsmr.ResourceId
	WHERE rn = 1
		 AND 1 = CASE WHEN @SettleType = 'MNL' AND fsmr.ResourceId IS NOT NULL THEN 1
				   WHEN @SettleType ='EAR' AND  fsmr.ResourceId IS  NULL THEN  1
				   ELSE 0
				   END

	INSERT INTO @tmpSourceId (SourceId,SourceName, Remark, OrderNo)
	SELECT  pgm.SourceId, pi.SourceName, pi.Remark, ISNULL(plmo.OrderNo, pgm.OrderNo) AS OrderNo
	FROM   ProviderInfo pi WITH(NOLOCK)
		INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)
			ON pi.SourceId  = pgm.SourceId
		LEFT JOIN ProviderLeagueMappingOutsideSource plmo WITH(NOLOCK)
			ON plmo.PGId =  pgm.PGId and plmo.LeagueId  = @LeagueId
	WHERE GameType = @GameType
		AND (
				pgm.SourceId <= 1001 
				OR  plmo.PGId  IS NOT NULL
			) 
		AND pi.isActive = 1
		AND pgm.isActive = 1

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpSourceId s WHERE s.SourceId = 100)
		BEGIN
			INSERT INTO @tmpSourceId (SourceId,	SourceName, Remark, OrderNo)
			VALUES (100,'Trader Score','n/a', 0)
		END

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpSourceId s WHERE s.SourceId = 1001)
		BEGIN
			INSERT INTO @tmpSourceId (SourceId,SourceName, Remark, OrderNo)
			VALUES (1001,'Screenshot','n/a', 1)
		END

	INSERT INTO @tmpProviderExternalResult(SourceId, SourceName, Remark, ResourceId, HomeValue, AwayValue, OrderNo)
	SELECT	s.SourceId, s.SourceName, s.Remark, ISNULL(l.ResourceId,'00'), ISNULL(l.HomeValue,'') , ISNULL(l.AwayValue,''), s.OrderNo
	FROM	@tmpLatestResult l
		RIGHT JOIN @tmpSourceId s 
			ON s.SourceId = l.SourceId
	WHERE	( l.SourceId < 1001 AND s.SourceId IS NOT NULL)
		OR s.SourceId >= 1001
				
	SELECT	t.SourceId
			,t.SourceName
			,t.Remark
			,t.ResourceId
			,t.HomeValue
			,t.AwayValue
			,t.OrderNo
	FROM	@tmpProviderExternalResult t

END
GO
