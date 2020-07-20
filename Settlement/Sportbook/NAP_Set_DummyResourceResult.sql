/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_DummyResourceResult
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

	DECLARE @FTHome INT
			,@FTAway INT
			,@HTHome INT
			,@HTAway INT
			,@Q1Home INT
			,@Q2Home INT
			,@Q3Home INT
			,@Q4Home INT
			,@Q1Away INT
			,@Q2Away INT
			,@Q3Away INT
			,@Q4Away INT

			,@CorrectQuaterOddEven VARCHAR(50)

	DECLARE @tmpDummyResourceIds AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ssId TINYINT)
	DECLARE @tmpDummyResourceResults AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ssId TINYINT)

	DECLARE @tmpResultDetail AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ssId TINYINT)

	SET @CorrectQuaterOddEven = ''
	
	INSERT INTO @tmpDummyResourceIds(ResourceId)
	SELECT	val
	FROM	dbo.f_SplitString(@DummyResourceIds, ',')
	WHERE	val <> ''
	OPTION (MAXRECURSION 0)

	INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
	SELECT	ResourceId, HomeValue, AwayValue, SettlementStatusID
	FROM	DBPRO.bodb02.dbo.ResultDetail WITH(NOLOCK)
	WHERE	MatchId = @MatchId
	
	IF @Sporttype = 2
	BEGIN
		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
		SELECT	t.ResourceId, '', '', 0
		FROM	(
					VALUES ('00'), ('01'), ('02'), ('OT')
						,('Q1'), ('Q2'), ('Q3'), ('Q4')
			)	t(ResourceId)
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpResultDetail WHERE ResourceId = t.ResourceId)

		SELECT	@FTHome = ISNULL(SUM(CASE WHEN ResourceId = '00' THEN HomeValue ELSE 0 END), 0)
				,@FTAway = ISNULL(SUM(CASE WHEN ResourceId = '00' THEN AwayValue ELSE 0 END), 0)
				,@HTHome = ISNULL(SUM(CASE WHEN ResourceId = '01' THEN HomeValue ELSE 0 END), 0)
				,@HTAway = ISNULL(SUM(CASE WHEN ResourceId = '01' THEN AwayValue ELSE 0 END), 0)
				,@Q1Home = ISNULL(SUM(CASE WHEN ResourceId = 'Q1' THEN HomeValue ELSE 0 END), 0)
				,@Q1Away = ISNULL(SUM(CASE WHEN ResourceId = 'Q1' THEN AwayValue ELSE 0 END), 0)
				,@Q2Home = ISNULL(SUM(CASE WHEN ResourceId = 'Q2' THEN HomeValue ELSE 0 END), 0)
				,@Q2Away = ISNULL(SUM(CASE WHEN ResourceId = 'Q2' THEN AwayValue ELSE 0 END), 0)
				,@Q3Home = ISNULL(SUM(CASE WHEN ResourceId = 'Q3' THEN HomeValue ELSE 0 END), 0)
				,@Q3Away = ISNULL(SUM(CASE WHEN ResourceId = 'Q3' THEN AwayValue ELSE 0 END), 0)
				,@Q4Home = ISNULL(SUM(CASE WHEN ResourceId = 'Q4' THEN HomeValue ELSE 0 END), 0)
				,@Q4Away = ISNULL(SUM(CASE WHEN ResourceId = 'Q4' THEN AwayValue ELSE 0 END), 0)
		FROM	@tmpResultDetail
		WHERE	ResourceId LIKE 'Q[1-4]'
				OR ResourceId IN ('01', '00')

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
			WHERE	r.ResourceId LIKE 'Q[1-4]' OR r.resourceId = '00'
			GROUP BY result.ResourceId
		END

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '624')
		BEGIN
			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
			SELECT	'624'
					,@FTHome - @HTHome
					,@FTAway - @HTAway
					,ssId
			FROM	@tmpResultDetail
			WHERE	ResourceId = '00'
        END
		
		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '625')
		BEGIN
			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
			SELECT	'625'
					,@FTHome - @HTHome
					,ssId
			FROM	@tmpResultDetail
			WHERE	ResourceId = '00'
        END
		
		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '626')
		BEGIN
			INSERT INTO @tmpDummyResourceResults (ResourceId, AwayValue, ssId)
			SELECT	'626'
					,@FTAway - @HTAway
					,ssId
			FROM	@tmpResultDetail
			WHERE	ResourceId = '00'
        END

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '632')
		BEGIN
			SELECT	@CorrectQuaterOddEven = @CorrectQuaterOddEven 
						+ CASE WHEN result.Value % 2 = 0 THEN 'e' ELSE 'o' END
			FROM	@tmpResultDetail r
				CROSS APPLY (
					SELECT	CAST(r.HomeValue AS INT) + CAST(r.AwayValue AS INT) AS Value
				) result
			WHERE	r.ResourceId LIKE 'Q[1-4]'
			ORDER BY r.ResourceId

			INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
			SELECT	'632', @CorrectQuaterOddEven, ssId
			FROM	@tmpResultDetail
			WHERE	ResourceId = '00' 
		END

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '633')
		BEGIN
			INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue, ssId)
			SELECT	'633', (@Q1Home - @Q1Away), (@Q2Home - @Q2Away), ssId
			FROM	@tmpResultDetail
			WHERE	ResourceId = '01'
		END

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '634')
		BEGIN
			INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue, ssId)
			SELECT	'634', (@Q3Home - @Q3Away), (@Q4Home - @Q4Away), ssId
			FROM	@tmpResultDetail
			WHERE	ResourceId = '00'
		END

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId IN ('635', '636', '637', '638', '639', '640', '641', '644'))
		BEGIN
			INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue, ssId)
			SELECT	res.ResourceId
					,SUM(result.HomeValue)
					,SUM(result.AwayValue)
					,MAX(CASE WHEN r.ResourceId = '00' THEN r.ssId ELSE 0 END) AS ssId
			FROM	@tmpResultDetail r 
				CROSS APPLY(
					SELECT	ResourceId
					FROM	@tmpDummyResourceIds
					WHERE	ResourceId IN ('635', '636', '637', '638', '639', '640', '641', '644')
				)res
				CROSS APPLY(
					SELECT	CASE 
								WHEN r.ResourceId = '00' THEN 0
								WHEN res.ResourceId = '639' THEN 0 -- only count the number of away team have higher scores (Away Team Quarters Win Over/Under)
								WHEN res.ResourceId IN ('640', '641') THEN CASE WHEN CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) = 0 THEN 1 ELSE 0 END
								WHEN CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) > 0 THEN 1
								ELSE 0
							END AS HomeValue
							,CASE 
								WHEN r.ResourceId = '00' THEN 0
								WHEN res.ResourceId = '638' THEN 0 -- only count the number of home team have higher scores (Home Team Quarters Win Over/Under)
								WHEN res.ResourceId IN ('640', '641') THEN 0
								WHEN CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) < 0 THEN 1
								ELSE 0
							END AS AwayValue
				) result
				
			WHERE	r.ResourceId LIKE 'Q[1-4]' OR r.resourceId = '00'
			GROUP BY res.ResourceId

			DECLARE @FTHomePoint INT
					,@FTAwayPoint INT
			
			SELECT	@FTHomePoint = HomeValue
					,@FTAwayPoint = AwayValue
			FROM	@tmpDummyResourceResults
			WHERE	ResourceId = '636'

			UPDATE @tmpDummyResourceResults
				SET HomeValue = CASE
									WHEN @FTHomePoint > @FTAwayPoint 
										THEN CASE
												WHEN @Q1Home < @Q1Away OR @Q2Home < @Q2Away THEN 'H'
												ELSE '' 
											END
									WHEN @FTHomePoint < @FTAwayPoint
										THEN CASE
												WHEN @Q1Home > @Q1Away OR @Q2Home > @Q2Away THEN 'A'
												ELSE ''
											END
									ELSE ''
								END
					,AwayValue = ''
			WHERE	ResourceId = '636'
		END
		
		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '642')
		BEGIN
			INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue, ssId)
			SELECT	'642'
					,CASE
						WHEN result.Q1Diff > 0 AND result.Q2Diff > 0 THEN 'h12'
						WHEN result.Q1Diff > 0 AND result.Q3Diff > 0 THEN 'h13'
						WHEN result.Q1Diff > 0 AND result.Q4Diff > 0 THEN 'h14'
						WHEN result.Q2Diff > 0 AND result.Q3Diff > 0 THEN 'h23'
						WHEN result.Q2Diff > 0 AND result.Q4Diff > 0 THEN 'h24'
						WHEN result.Q3Diff > 0 AND result.Q4Diff > 0 THEN 'h34'

						WHEN result.Q1Diff < 0 AND result.Q2Diff < 0 THEN 'a12'
						WHEN result.Q1Diff < 0 AND result.Q3Diff < 0 THEN 'a13'
						WHEN result.Q1Diff < 0 AND result.Q4Diff < 0 THEN 'a14'
						WHEN result.Q2Diff < 0 AND result.Q3Diff < 0 THEN 'a23'
						WHEN result.Q2Diff < 0 AND result.Q4Diff < 0 THEN 'a24'
						WHEN result.Q3Diff < 0 AND result.Q4Diff < 0 THEN 'a34'

						WHEN result.Q1Diff = 0 OR result.Q2Diff = 0 OR (result.Q1Diff < 0 AND result.Q2Diff > 0) OR (result.Q1Diff > 0 AND result.Q2Diff < 0) THEN 'aos12'
						WHEN result.Q1Diff = 0 OR result.Q3Diff = 0 OR (result.Q1Diff < 0 AND result.Q3Diff > 0) OR (result.Q1Diff > 0 AND result.Q3Diff < 0) THEN 'aos13'
						WHEN result.Q1Diff = 0 OR result.Q4Diff = 0 OR (result.Q1Diff < 0 AND result.Q4Diff > 0) OR (result.Q1Diff > 0 AND result.Q4Diff < 0) THEN 'aos14'
						WHEN result.Q2Diff = 0 OR result.Q3Diff = 0 OR (result.Q2Diff < 0 AND result.Q3Diff > 0) OR (result.Q2Diff > 0 AND result.Q3Diff < 0) THEN 'aaos23'
						WHEN result.Q2Diff = 0 OR result.Q4Diff = 0 OR (result.Q2Diff < 0 AND result.Q4Diff > 0) OR (result.Q2Diff > 0 AND result.Q4Diff < 0) THEN 'aaos24'
						WHEN result.Q3Diff = 0 OR result.Q4Diff = 0 OR (result.Q3Diff < 0 AND result.Q4Diff > 0) OR (result.Q3Diff > 0 AND result.Q4Diff < 0) THEN 'aaos34'
						ELSE ''
					END AS HomeValue
					,'' AS AwayValue
					,r.ssId
			FROM	@tmpResultDetail r
				CROSS APPLY(
					SELECT	@Q1Home - @Q1Away AS Q1Diff
							,@Q2Home - @Q2Away AS Q2Diff
							,@Q3Home - @Q3Away AS Q3Diff
							,@Q4Home - @Q4Away AS Q4Diff
				)result
			WHERE	ResourceId = '00'
		END

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '643')
		BEGIN
			DECLARE @MaxValue INT
			SELECT	@MaxValue = MAX(CAST(HomeValue AS INT) + CAST(AwayValue AS INT))
			FROM	@tmpResultDetail
			WHERE	ResourceId LIKE 'Q[1-4]'

			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
			SELECT	'643'
					,CASE 
						WHEN m.Q1Max+ m.Q2Max + m.Q3Max + m.Q4Max = 1 
							THEN CASE 
									WHEN m.Q1Max = 1 THEN '1q'
									WHEN m.Q2Max = 1 THEN '2q'
									WHEN m.Q3Max = 1 THEN '3q'
									WHEN m.Q4Max = 1 THEN '4q'
									ELSE '' -- not happend
								END
						ELSE 'tie'
					END
					,''
					,r.ssId
			FROM	@tmpResultDetail r
				CROSS APPLY (
					SELECT	CASE WHEN @Q1Home + @Q1Away = @MaxValue THEN 1 ELSE 0 END AS Q1Max
							,CASE WHEN @Q2Home + @Q2Away = @MaxValue THEN 1 ELSE 0 END AS Q2Max
							,CASE WHEN @Q3Home + @Q3Away = @MaxValue THEN 1 ELSE 0 END AS Q3Max
							,CASE WHEN @Q4Home + @Q4Away = @MaxValue THEN 1 ELSE 0 END AS Q4Max
							
				)m
				
			WHERE	r.resourceId = '00'
		END

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '645')
		BEGIN
			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
			SELECT	'645'
					,CASE
						WHEN result.HTDiff > 0 AND result.SecondHDiff > 0 THEN 'hh'
						WHEN result.HTDiff > 0 AND result.SecondHDiff = 0 THEN 'hd'
						WHEN result.HTDiff > 0 AND result.SecondHDiff < 0 THEN 'ha'
						WHEN result.HTDiff = 0 AND result.SecondHDiff > 0 THEN 'dh'
						WHEN result.HTDiff = 0 AND result.SecondHDiff < 0 THEN 'da'
						WHEN result.HTDiff < 0 AND result.SecondHDiff > 0 THEN 'ah'
						WHEN result.HTDiff < 0 AND result.SecondHDiff = 0 THEN 'ad'
						WHEN result.HTDiff < 0 AND result.SecondHDiff < 0 THEN 'aa'
						ELSE ''
					END
					,''
					,r.ssId
			FROM	@tmpResultDetail r
				CROSS APPLY (
					SELECT	@HTHome - @HTAway AS HTDiff
							,(@FTHome - @HTHome) - (@FTAway - @HTAway) AS SecondHDiff
				)result
			WHERE	r.resourceId = '00'
		END
	END

	SET @DummyResourceResults = CONVERT(VARCHAR(MAX),(
		SELECT	ResourceId AS '@Id'
				,HomeValue AS '@Home'
				,AwayValue AS '@Away'
				,ssId AS '@ssId'
		FROM @tmpDummyResourceResults
		FOR XML PATH('r'), ROOT('root'), TYPE))

END
GO
