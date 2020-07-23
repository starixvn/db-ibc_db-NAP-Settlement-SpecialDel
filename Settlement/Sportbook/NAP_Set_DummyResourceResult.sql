/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_DummyResourceResult]
	@MatchId INT
	,@Sporttype SMALLINT
	,@DummyResourceIds VARCHAR(MAX)
	,@DummyResourceResults VARCHAR(MAX) = '' OUTPUT

AS
/*  Creator: 20200703@Kathy
	Task: Calculate result for dummy resourceId
	DB: DBPRO/BODB02

	Revisions:
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpDummyResourceIds AS TABLE (ResourceId VARCHAR(20))
	DECLARE @tmpDummyResourceResults AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ssId TINYINT)
	DECLARE @tmpResultDetail AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ssId TINYINT)

	INSERT INTO @tmpDummyResourceIds(ResourceId)
	SELECT	val
	FROM	dbo.f_SplitString(@DummyResourceIds, ',')
	WHERE	val <> ''
	OPTION (MAXRECURSION 0)

	INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
	SELECT	ResourceId, HomeValue, AwayValue, SettlementStatusID
	FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
	WHERE	matchid = @MatchId

	INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
	SELECT	t.ResourceId, '', '', 0
	FROM	(
				VALUES ('00'), ('01'), ('02'), ('OT')
					,('Q1'), ('Q2'), ('Q3'), ('Q4')
		)	t(ResourceId)
	WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpResultDetail WHERE ResourceId = t.ResourceId)

	IF @Sporttype = 2
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '603')
		BEGIN
			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
			SELECT	result.ResourceId 
					,CASE
						WHEN MAX(result.HomeValue) > MAX(result.AwayValue) THEN 'H'
						WHEN MAX(result.HomeValue) < MAX(result.AwayValue) THEN 'A'
						ELSE 'N'
					END
					,''
					,MAX(CASE WHEN r.ResourceId = '00' THEN r.ssId ELSE 0 END) AS ssId
			FROM	@tmpResultDetail r
				CROSS APPLY (
					SELECT	t.ResourceId
							,CASE WHEN r.ResourceId = '00' THEN 0 ELSE CAST(r.HomeValue AS INT) END AS HomeValue
							,CASE WHEN r.resourceId = '00' THEN 0 ELSE CAST(r.AwayValue AS INT) END AS AwayValue
							,CASE WHEN r.resourceId = '00' THEN r.ssId ELSE 0 END AS ssId 
					FROM	@tmpDummyResourceIds t
					WHERE	t.ResourceId = '603'
				) result
			WHERE	(r.ResourceId LIKE 'Q[1-4]' OR r.resourceId = '00')
			GROUP BY result.ResourceId
		END
	END

	SET @DummyResourceResults = CONVERT(VARCHAR(MAX),(
		SELECT	ResourceId AS '@Id'
				,HomeValue AS '@Home'
				,AwayValue AS '@Away'
				,ssId AS '@ssId'
		FROM @tmpDummyResourceResults
		WHERE	ResourceId <> ''
		FOR XML PATH('r'), ROOT('root'), TYPE))

END
GO