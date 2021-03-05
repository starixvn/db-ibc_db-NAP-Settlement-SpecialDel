/*<info serverAlias="DBPRO-bodb02 " executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT


	SET @SportType = 5

	DECLARE @tmpLatestResult AS TABLE ( SourceId SMALLINT,ResourceId	varchar(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	DECLARE @tmpProviderExternalResult AS TABLE (SourceId SMALLINT,SourceName VARCHAR(50) ,Remark NVARCHAR(1000), ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OrderNo INT)
	DECLARE @tmpSourceId AS TABLE ( SourceId SMALLINT,SourceName VARCHAR(50), Remark NVARCHAR(1000) , OrderNo INT )

	;WITH cteLatestId
	AS(
		SELECT	ROW_NUMBER() OVER (PARTITION BY p.SourceId, p.ResourceId ORDER BY p.CreateDate DESC) AS rn
				,p.SourceId
				,p.ResourceId
				,p.ProviderExternalId
				, HomeValue
				, AwayValue
		FROM	dbo.ProviderExternalResultDetailOS p WITH(NOLOCK)
		WHERE	p.MatchId = @MatchId
	)

	INSERT INTO @tmpLatestResult ( SourceId,ResourceId, HomeValue, AwayValue)
	SELECT l.SourceId ,l.ResourceId, l.HomeValue, l.AwayValue
	FROM cteLatestId l	
		LEFT JOIN dbo.f_Set_MajorRound(@SportType) fsmr
			ON l.ResourceId = fsmr.ResourceId
	WHERE rn = 1
		 AND 1 = CASE WHEN @SettleType = 'MNL' AND fsmr.ResourceId IS NOT NULL THEN 1
				   WHEN @SettleType ='EAR' AND  fsmr.ResourceId IS  NULL THEN  1
				   ELSE 0
				   END
	
	INSERT INTO @tmpSourceId (SourceId,SourceName, Remark, OrderNo)
	SELECT  pgm.SourceId, pi.SourceName, pi.Remark,  pgm.OrderNo
	FROM   ProviderInfo pi WITH(NOLOCK)
		INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)
			ON pi.SourceId  = pgm.SourceId 
	WHERE   pgm.Sporttype = @SportType
		AND pgm.SourceId <= 1001
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
