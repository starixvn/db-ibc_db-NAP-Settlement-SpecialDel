/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_DummyResourceResult]
	@MatchId INT
	,@Sporttype SMALLINT
	,@IsDetermined BIT = 0
	,@Action VARCHAR(20) = 'CAL'
	,@IsChecking BIT = 0
	,@WebResourceResult VARCHAR(MAX) = NULL
	,@DummyResourceIds VARCHAR(MAX)
	,@DummyResourceResults VARCHAR(MAX) = '' OUTPUT

AS
/*  Creator: 20200703@Kathy
	Task: Calculate result for dummy resourceId
	DB: DBTXN/BODB02

	Revisions:
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
		- 20210730@Kathy: Apply Settlement by Profile for minor bettype of soccer [Redmine:#158477]
		- 20211129@Kathy: fix issue bettype 486, 487
		- 20211129@Kathy: Extend datatype of table SettlementBettypeResult [Redmine:#165300]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220629@Louisa: Volleyball AIO ( 27 bettype ) [Redmineid:#173862]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		- 20230727@Aries: Basketball AIO  [Redmine:#191381]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FTHome INT
			,@FTAway INT
			,@HTHome INT
			,@HTAway INT
			,@2HHome INT
			,@2HAway INT
			,@Q1Home INT
			,@Q2Home INT
			,@Q3Home INT
			,@Q4Home INT
			,@OTHome INT
			,@Q1Away INT
			,@Q2Away INT
			,@Q3Away INT
			,@Q4Away INT
			,@OTAway INT
			,@Q1Done BIT 
			,@Q2Done BIT 
			,@HTDone BIT 
			,@Q3Done BIT
			,@Q4Done BIT 
			,@FTDone BIT 
			,@TotalRound	INT = 1
			,@CurrentRound	VARCHAR(50) = ''

			,@CorrectQuaterOddEven VARCHAR(50)
			,@TotalHomeScore INT
			,@TotalAwayScore INT
			,@FTFG VARCHAR(50)
			,@FTLG VARCHAR(50)
			,@HTFG VARCHAR(50)
			,@HTLG VARCHAR(50)
			,@ssId TINYINT

			,@FTOddEven SMALLINT
			,@HTOddEven	SMALLINT
			,@HTScoreDiff SMALLINT
			,@2HScoreDiff SMALLINT
			,@FTScoreDiff SMALLINT
			,@HTTotalScore SMALLINT
			,@2HTotalScore SMALLINT
			,@FTTotalScore SMALLINT
			,@HTCorrectScore VARCHAR(50)
			,@FTCorrectScore VARCHAR(50)
			,@FTGoalRecord VARCHAR(50)
			,@HTGoalRecord VARCHAR(50)

			,@home_firstteam2goals INT
			,@away_firstteam2goals INT
			,@home_firstteam3goals INT
			,@away_firstteam3goals INT

			,@Position	TINYINT
			,@HomeRaceTo TINYINT
			,@AwayRaceTo TINYINT
			,@NeitherRaceTo	TINYINT
			,@LenResultString TINYINT
			,@Char			VARCHAR(1)
			,@result NVARCHAR(200)
			,@string VARCHAR(50)
			,@ResourceId VARCHAR(20) 
			,@DeterminedType TINYINT
			,@MaxValue INT
			,@ResultTable TINYINT
			,@xmlWebResourceResult XML

	DECLARE @tmpDummyResourceIds AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000), ssId TINYINT)
	DECLARE @tmpDummyResourceResults AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000), ssId TINYINT, isCalculated BIT)

	DECLARE @tmpResultDetail AS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),ResultStatusID TINYINT,ssId TINYINT, isWeb BIT)

	SELECT	@ResultTable = ResultTable
	FROM	dbo.SettlementResultTableSetting WITH(NOLOCK)
	WHERE	Sporttype = @Sporttype

	SET @xmlWebResourceResult = CAST(@WebResourceResult AS XML)
	SET @CorrectQuaterOddEven = ''
	
	INSERT INTO @tmpDummyResourceIds(ResourceId)
	SELECT	[value]
	FROM	STRING_SPLIT(@DummyResourceIds, ',')
	WHERE	[value] <> ''

	IF @WebResourceResult IS NOT NULL
	BEGIN
		IF @Sporttype = 1
		BEGIN
			;WITH cteResourceResult
			AS
			(
				SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
						,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
						,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
						,T.C.value('@SettlementStatusId', 'TINYINT') AS SettlementStatusId
				FROM    @xmlWebResourceResult.nodes('/Results/Resource') AS T(C)
			)
			INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId, isWeb)
			SELECT	ResourceId, HomeValue, AwayValue, SettlementStatusID, 1
			FROM	cteResourceResult
		END
		ELSE IF @Sporttype = 2 AND @IsDetermined = 1
		BEGIN
			;WITH cteResourceSelected
			AS
			(
				SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
						,T.C.value('@Home', 'VARCHAR(50)') AS HomeValue
						,T.C.value('@Away', 'VARCHAR(50)') AS AwayValue
						,4 AS SettlementStatusId
				FROM    @xmlWebResourceResult.nodes('/Resources/Resource') AS T(C)
			)
			INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId, isWeb)
			SELECT	ResourceId, HomeValue, AwayValue, SettlementStatusID, 1
			FROM	cteResourceSelected
		END
		ELSE
		BEGIN
			;WITH cteResourceSelected
			AS
			(
				SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
						,T.C.value('@Home', 'VARCHAR(50)') AS HomeValue
						,T.C.value('@Away', 'VARCHAR(50)') AS AwayValue
						,4 AS SettlementStatusId
				FROM    @xmlWebResourceResult.nodes('/Results/Resource') AS T(C)
			)
			INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId, isWeb)
			SELECT	ResourceId, HomeValue, AwayValue, SettlementStatusID, 1
			FROM	cteResourceSelected
		END
	END

	IF @ResultTable = 1
	BEGIN
		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue,ResultStatusID, ssId)
		SELECT	ResourceId, HomeValue, AwayValue,ResultStatusID, SettlementStatusID
		FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
		WHERE	MatchId = @MatchId
				AND NOT EXISTS (SELECT TOP 1 1 FROM @tmpResultDetail t WHERE t.ResourceId = r.ResourceId)
	END
	ELSE IF @ResultTable = 2
	BEGIN
		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
		SELECT	r.ResourceId, r.HomeValue, r.AwayValue, r.SettlementStatusID
		FROM	DBPRO.bodb02.dbo.ResultDetailOS r WITH(NOLOCK)
			INNER JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON r.ResourceID = sd.ResourceID
		WHERE	MatchId = @MatchId
			AND ResultStatusID  IN ( 2, 5 )	
	END
	
	IF @Sporttype = 2
	BEGIN
		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
		SELECT	t.ResourceId, '', '', 0
		FROM	(
					VALUES ('00'), ('01'), ('02'), ('OT')
						,('Q1'), ('Q2'), ('Q3'), ('Q4')
			)	t(ResourceId)
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpResultDetail WHERE ResourceId = t.ResourceId)

		UPDATE @tmpResultDetail
		SET  HomeValue = '' 
			,AwayValue = '' 
		WHERE (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01', '00','OT'))
			AND @IsDetermined = 1
			AND ResultStatusID NOT IN (2,5)
			AND ISNULL(isWeb,0) = 0

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
				,@OTHome = ISNULL(SUM(CASE WHEN ResourceId = 'OT' THEN HomeValue ELSE 0 END), 0)
				,@OTAway = ISNULL(SUM(CASE WHEN ResourceId = 'OT' THEN AwayValue ELSE 0 END), 0)
		FROM	@tmpResultDetail
		WHERE	ResourceId LIKE 'Q[1-4]'
				OR ResourceId IN ('01','00','OT')

		IF @IsDetermined = 1
		BEGIN
			UPDATE @tmpResultDetail
			SET ssId = 0
			WHERE HomeValue = '' 
				OR AwayValue = ''
			
			IF @Action LIKE 'REFUND%' OR @Action LIKE 'CAL-INST%'
			BEGIN
				SELECT @CurrentRound = ResourceId 
				FROM @tmpResultDetail
				WHERE (ResourceId LIKE 'Q[1-4]'  OR ResourceId IN ('01', '00','OT'))
					AND ssId = 4
					AND IsWeb = 1
					AND (HomeValue != ''  OR AwayValue != '' )
			END

			SELECT @Q1Done = IIF(SUM(CASE WHEN ResourceId = 'Q1' AND ISNULL(HomeValue,'') != '' AND ISNULL(@CurrentRound,'') != 'Q1' THEN 1 ELSE 0 END) = 1,1,0)
				  ,@Q2Done = IIF(SUM(CASE WHEN ResourceId = 'Q2' AND ISNULL(HomeValue,'') != '' AND ISNULL(@CurrentRound,'') != 'Q2' THEN 1 ELSE 0 END) = 1,1,0)
				  ,@HTDone = IIF(SUM(CASE WHEN ResourceId = '01' AND ISNULL(HomeValue,'') != '' AND ISNULL(@CurrentRound,'') != '01' THEN 1 ELSE 0 END) = 1,1,0)
				  ,@Q3Done = IIF(SUM(CASE WHEN ResourceId = 'Q3' AND ISNULL(HomeValue,'') != '' AND ISNULL(@CurrentRound,'') != 'Q3' THEN 1 ELSE 0 END) = 1,1,0)
				  ,@Q4Done = IIF(SUM(CASE WHEN ResourceId = 'Q4' AND ISNULL(HomeValue,'') != '' AND ISNULL(@CurrentRound,'') != 'Q4' THEN 1 ELSE 0 END) = 1,1,0)		  
				  ,@FTDone = IIF(SUM(CASE WHEN ResourceId = '00' AND ISNULL(HomeValue,'') != '' AND ISNULL(@CurrentRound,'') != '00' AND ISNULL(@CurrentRound,'') != 'OT' THEN 1 ELSE 0 END) = 1,1,0)
			FROM @tmpResultDetail
			WHERE (ResourceId LIKE 'Q[1-4]'  OR ResourceId IN ('01', '00'))
				AND ssId = 4

			IF  EXISTS (SELECT 1 FROM @tmpResultDetail WHERE ResourceId IN ('Q1','Q2') AND ISNULL(HomeValue,'') != '') AND
				NOT EXISTS (SELECT 1 FROM @tmpResultDetail WHERE ResourceId = '01' AND isWeb = 1 AND ISNULL(HomeValue,'') != '')	
			BEGIN
				UPDATE @tmpResultDetail
				SET HomeValue = @Q1Home + @Q2Home, 
					AwayValue = @Q1Away + @Q2Away
				WHERE ResourceId = '01'

				SET @HTHome = @Q1Home + @Q2Home
				SET @HTAway = @Q1Away + @Q2Away
			END

			IF EXISTS (SELECT 1 FROM @tmpResultDetail WHERE ResourceId IN ('Q1','Q2','Q3','Q4','OT') AND ISNULL(HomeValue,'') != '')  AND
			   NOT EXISTS (SELECT 1 FROM @tmpResultDetail WHERE ResourceId = '00' AND isWeb = 1 AND ISNULL(HomeValue,'') != '')	
			BEGIN
				UPDATE @tmpResultDetail
				SET HomeValue = @Q1Home + @Q2Home + @Q3Home + @Q4Home + @OTHome, 
					AwayValue = @Q1Away + @Q2Away + @Q3Away + @Q4Away + @OTAway
				WHERE ResourceId = '00'

				SET @FTHome = @Q1Home + @Q2Home + @Q3Home + @Q4Home + @OTHome
				SET @FTAway = @Q1Away + @Q2Away + @Q3Away + @Q4Away + @OTAway
			END
			ELSE IF NOT EXISTS (SELECT 1 FROM @tmpResultDetail WHERE ResourceId = '00' AND ISNULL(HomeValue,'') != '') AND
					EXISTS (SELECT 1 FROM @tmpResultDetail WHERE ResourceId = '01' AND ISNULL(HomeValue,'') != '')				
			BEGIN
				UPDATE @tmpResultDetail
				SET HomeValue = @HTHome, 
					AwayValue = @HTAway
				WHERE ResourceId = '00'

				SET @FTHome = @HTHome
				SET @FTAway = @HTAway
			END


			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, isCalculated)
			SELECT	 r.ResourceId 
					,r.HomeValue 
					,r.AwayValue 
					,IIF(r.ResourceId IN ('01', '00') AND r.ssId = 4  ,1,0) AS  isCalculated
			FROM	@tmpResultDetail AS r
			WHERE r.ResourceId IN ('01', '00')
				OR ssId = 4  

		
			IF @Q1Done = 1 AND @Q2Done = 1 AND @Q3Done = 1 AND @Q4Done = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '603')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue)
				SELECT	result.ResourceId 
						,CASE
							WHEN MAX(result.HomeValue) > MAX(result.AwayValue) THEN 'H'
							WHEN MAX(result.HomeValue) < MAX(result.AwayValue) THEN 'A'
							ELSE 'N'
						END
						,''
				FROM	@tmpResultDetail r
					CROSS APPLY (
						SELECT	t.ResourceId
								,CAST(r.HomeValue AS INT) AS HomeValue
								,CAST(r.AwayValue AS INT) AS AwayValue
								,0 ASssId 
						FROM	@tmpDummyResourceIds t
						WHERE	t.ResourceId = '603'
					) result
				WHERE	r.ResourceId LIKE 'Q[1-4]' 
					AND r.ssId = 4
				GROUP BY result.ResourceId
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '632')
			BEGIN
				SELECT	@CorrectQuaterOddEven = @CorrectQuaterOddEven + CASE WHEN ssId = 4 AND r.ResourceId != @CurrentRound THEN IIF(result.Value % 2 = 0,'e', 'o') ELSE '_' END
				FROM	@tmpResultDetail r
					CROSS APPLY (
						SELECT	CAST(r.HomeValue AS INT) + CAST(r.AwayValue AS INT) AS Value
					) result
				WHERE	r.ResourceId LIKE 'Q[1-4]' 					
				ORDER BY r.ResourceId

				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue)
				VALUES('632', @CorrectQuaterOddEven)
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '633')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue)
				SELECT	'633'
						,CASE WHEN result.Q1Diff > 0 THEN 'h'
							  WHEN result.Q1Diff = 0 THEN 'd'
							  WHEN result.Q1Diff < 0 THEN 'a'
							  ELSE '_'
						 END
						  +
						 CASE WHEN result.Q2Diff > 0 THEN 'h'
							  WHEN result.Q2Diff = 0 THEN 'd'
							  WHEN result.Q2Diff < 0 THEN 'a'
							  ELSE '_'
						 END
						,''
				FROM (SELECT CASE WHEN @Q1Done = 1 THEN @Q1Home  - @Q1Away
								  ELSE NULL
							 END AS Q1Diff 
							,CASE WHEN @Q2Done = 1 THEN  @Q2Home - @Q2Away
								  ELSE NULL
							 END AS Q2Diff
					)result
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '634')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue)
				SELECT	'634'
						,CASE WHEN result.Q3Diff > 0 THEN 'h'
							  WHEN result.Q3Diff = 0 THEN 'd'
							  WHEN result.Q3Diff < 0 THEN 'a'
							  ELSE '_'
						 END
						  +
						 CASE WHEN result.Q4Diff > 0 THEN 'h'
							  WHEN result.Q4Diff = 0 THEN 'd'
							  WHEN result.Q4Diff < 0 THEN 'a'
							  ELSE '_'
						 END
						,''
				FROM (SELECT CASE WHEN @Q3Done = 1 THEN @Q3Home  - @Q3Away
								  ELSE NULL
							 END AS Q3Diff 
							,CASE WHEN @Q4Done = 1 THEN  @Q4Home - @Q4Away
								  ELSE NULL
							 END AS Q4Diff
					)result
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId IN ('635', '638', '639', '640', '641'))
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue)
				SELECT	res.ResourceId
						,SUM(result.HomeValue)
						,SUM(result.AwayValue)
				FROM	@tmpResultDetail r 
					CROSS APPLY(
						SELECT	ResourceId
						FROM	@tmpDummyResourceIds
						WHERE	ResourceId IN ('635', '638', '639', '640', '641')
					)res
					CROSS APPLY(
						SELECT	CASE 
									WHEN res.ResourceId = '635' THEN IIF(CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) > 0,5,1)	
									WHEN res.ResourceId = '638' THEN IIF(CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) > 0,1,0)
									WHEN res.ResourceId = '639' THEN IIF(CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) < 0,1,0)
									WHEN res.ResourceId = '640' THEN IIF(CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) = 0,5,1)
									WHEN res.ResourceId = '641' THEN IIF(CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) = 0,1,0)
									ELSE 0
								END AS HomeValue
								,CASE 
									WHEN res.ResourceId = '635' THEN IIF(CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) < 0,5,1)
									WHEN res.ResourceId IN ('638','639','640', '641') THEN 1			
									ELSE 0
								END AS AwayValue
					) result
				
				WHERE	r.ResourceId LIKE 'Q[1-4]' 
					AND r.ssId = 4
					AND r.ResourceId != @CurrentRound
				GROUP BY res.ResourceId
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '642')
			BEGIN
			
				DECLARE @QuaterResultSDT VARCHAR(1000) = ''

				;WITH CTE_Result (ResourceId,RoundNo, Result) AS (
						SELECT rs.ResourceId,
							   RIGHT(rs.ResourceId, 1) AS RoundNo,
							   CASE  WHEN CAST(rs.HomeValue AS INT) - CAST(rs.AwayValue AS INT) > 0 THEN 'h'
									 WHEN CAST(rs.HomeValue AS INT) - CAST(rs.AwayValue AS INT) = 0 THEN 'd'
									 ELSE 'a'
							   END
						FROM @tmpResultDetail AS rs
						WHERE rs.ResourceId LIKE 'Q[1-4]'
							AND rs.ResourceId != @CurrentRound
							AND rs.ssId = 4
				)
				SELECT @QuaterResultSDT = @QuaterResultSDT +
					   (CASE WHEN  r1.Result IN ('h','a','d') AND r1.Result = r2.Result  AND r2.RoundNo = r1.RoundNo THEN r1.ResourceId + r1.Result
							 WHEN  r1.Result IN ('h','a') AND r1.Result = r2.Result  AND r2.RoundNo != r1.RoundNo THEN r1.Result + IIF(r1.RoundNo < r2.RoundNo,r1.RoundNo,r2.RoundNo)  + IIF(r2.RoundNo > r1.RoundNo,r2.RoundNo,r1.RoundNo)
							 WHEN  r1.Result IN ('h','a') AND r2.Result IN ('h','a') AND r1.Result != r2.Result  AND r2.RoundNo != r1.RoundNo THEN 'aos' + IIF(r1.RoundNo < r2.RoundNo,r1.RoundNo,r2.RoundNo) + IIF(r2.RoundNo > r1.RoundNo,r2.RoundNo,r1.RoundNo)
							 WHEN  r1.Result IN ('d')  THEN 'aos' + IIF(r1.RoundNo < r2.RoundNo,r1.RoundNo,r2.RoundNo)  + IIF(r2.RoundNo > r1.RoundNo,r2.RoundNo,r1.RoundNo)
                             ELSE ''
						END )  + ','
				FROM CTE_Result AS r1
					CROSS JOIN  CTE_Result  AS r2
				WHERE CAST(r1.RoundNo AS INT) <=  CAST(r2.RoundNo AS INT)

				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue)
				VALUES('642', @QuaterResultSDT)
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '643')
			BEGIN
				DECLARE @CurrentRound643	VARCHAR(50)

				SELECT @CurrentRound643 = CASE WHEN @CurrentRound = 'Q1' THEN '1q'
											   WHEN @CurrentRound = 'Q2' THEN '2q'
											   WHEN @CurrentRound = 'Q3' THEN '3q'
											   WHEN @CurrentRound = 'Q4' THEN '4q'
											   ELSE NULL
										   END

				SELECT	@MaxValue = MAX(CAST(HomeValue AS INT) + CAST(AwayValue AS INT))
				FROM	@tmpResultDetail
				WHERE	ResourceId LIKE 'Q[1-4]'
					AND ssId = 4

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue)
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
						,IIF(@Q1Done = 1 OR @CurrentRound = 'Q1','1q,','')
							+ IIF(@Q2Done = 1 OR @CurrentRound = 'Q2','2q,','') 
							+ IIF(@Q3Done = 1 OR @CurrentRound = 'Q3','3q,','')
							+ IIF(@Q4Done = 1 OR @CurrentRound = 'Q4','4q,','') 	
							+ IIF(m.Q1Max + m.Q2Max + m.Q3Max + m.Q4Max > 1 AND m.Q1Max = 1,'tie(1q),','')
							+ IIF(m.Q1Max + m.Q2Max + m.Q3Max + m.Q4Max > 1 AND m.Q2Max = 1,'tie(2q),','')
							+ IIF(m.Q1Max + m.Q2Max + m.Q3Max + m.Q4Max > 1 AND m.Q3Max = 1,'tie(3q),','')
							+ IIF(m.Q1Max + m.Q2Max + m.Q3Max + m.Q4Max > 1 AND m.Q4Max = 1,'tie(4q),','')
							+ IIF(Q1Max = 0 AND @Q1Done = 1,'Low(1q),','')
							+ IIF(Q2Max = 0 AND @Q2Done = 1,'Low(2q),','')
							+ IIF(Q3Max = 0 AND @Q3Done = 1,'Low(3q),','')
							+ IIF(Q4Max = 0 AND @Q4Done = 1,'Low(4q),','')
							+ IIF(@CurrentRound643 IS NOT NULL AND @CurrentRound643 != 'OT','Current('+@CurrentRound643+'),','')
				FROM ( 
					SELECT	 CASE WHEN @Q1Home + @Q1Away = @MaxValue THEN 1 ELSE 0 END AS Q1Max
							,CASE WHEN @Q2Home + @Q2Away = @MaxValue THEN 1 ELSE 0 END AS Q2Max
							,CASE WHEN @Q3Home + @Q3Away = @MaxValue THEN 1 ELSE 0 END AS Q3Max
							,CASE WHEN @Q4Home + @Q4Away = @MaxValue THEN 1 ELSE 0 END AS Q4Max
							
				)m
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '645')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue)
				SELECT	'645'
						,CASE WHEN result.HTDiff > 0 THEN 'h'
							  WHEN result.HTDiff = 0 THEN 'd'
							  WHEN result.HTDiff < 0 THEN 'a'
							  ELSE '_'
						 END
						  +
						 CASE WHEN result.SecondHDiff > 0 THEN 'h'
							  WHEN result.SecondHDiff = 0 THEN 'd'
							  WHEN result.SecondHDiff < 0 THEN 'a'
							  ELSE '_'
						 END
						,''
				FROM (SELECT CASE WHEN @Q1Done = 1 AND @Q2Done = 1 THEN  (@Q1Home + @Q2Home) - (@Q1Away + @Q2Away)
								  WHEN @HTDone = 1 THEN @HTHome - @HTAway 
								  ELSE NULL
							 END AS HTDiff 
							,CASE WHEN @FTDone = 1 THEN (@FTHome - @HTHome) - (@FTAway - @HTAway)
								  ELSE NULL
							 END AS SecondHDiff
					)result
			END
		END
		ELSE
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
													WHEN @Q1Home < @Q1Away OR (@Q1Home = @Q1Away AND @Q2Home < @Q2Away) THEN 'H'
													ELSE '' 
												END
										WHEN @FTHomePoint < @FTAwayPoint
											THEN CASE
													WHEN @Q1Home > @Q1Away OR (@Q1Home = @Q1Away AND @Q2Home > @Q2Away) THEN 'A'
													ELSE ''
												END
										ELSE ''
									END
						,AwayValue = ''
				WHERE	ResourceId = '636'
			END
		
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '642')
			BEGIN
			
				DECLARE @QuaterResult VARCHAR(20) = ''

				SELECT	@QuaterResult = @QuaterResult 
							+ r.ResourceId + CASE 
												WHEN result.Value > 0 THEN 'h'
												WHEN result.value = 0 THEN 'd'
												ELSE 'a'
											END + ','
				FROM	@tmpResultDetail r
					CROSS APPLY (
						SELECT	CAST(r.HomeValue AS INT) - CAST(r.AwayValue AS INT) AS Value
					) result
				WHERE	r.ResourceId LIKE 'Q[1-4]'
				ORDER BY r.ResourceId

				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
				SELECT	'642', @QuaterResult, ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00' 
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '643')
			BEGIN
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

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId IN ('647','648','649','65001','65002','65003','65004'))
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT rs.RefResourceId,RIGHT(rs.Home,1),RIGHT(rs.Away,1),4
				FROM (SELECT CASE WHEN r.ResourceId = '00' THEN '647'
								  WHEN r.ResourceId = '01' THEN '648'
								  WHEN r.ResourceId = '02' THEN '649'
								  WHEN r.ResourceId = 'Q1' THEN '65001'
								  WHEN r.ResourceId = 'Q2' THEN '65002'
								  WHEN r.ResourceId = 'Q3' THEN '65003'
								  WHEN r.ResourceId = 'Q4' THEN '65004'
								  ELSE NULL 
							 END AS RefResourceId
							,IIF(CAST(r.HomeValue AS INT) >= CAST(r.AwayValue AS INT),r.HomeValue,r.AwayValue) AS Home
							,IIF(CAST(r.HomeValue AS INT) <= CAST(r.AwayValue AS INT),r.HomeValue,r.AwayValue) AS Away
					  FROM @tmpResultDetail AS r
					  WHERE	(r.ResourceId LIKE 'Q[1-4]' OR r.ResourceId IN ('01', '00','02'))
				) AS rs	
				WHERE  EXISTS (SELECT 1 FROM @tmpDummyResourceIds AS du WHERE du.ResourceId = rs.RefResourceId)
			END

		END
	END
	ELSE IF @Sporttype = 1
	BEGIN
		SET @DeterminedType = CASE WHEN @Action = 'CAL-HT' AND @IsDetermined = 1 THEN 2 ELSE 0 END

		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
		SELECT	t.ResourceId, '', '', 0
		FROM	(
					VALUES ('00'), ('01'), ('08'), ('14F'), ('14L')
			)	t(ResourceId)
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpResultDetail WHERE ResourceId = t.ResourceId)

		SELECT	@FTHome = ISNULL(SUM(CASE WHEN ResourceId = '00' THEN HomeValue ELSE 0 END), 0)
				,@FTAway = ISNULL(SUM(CASE WHEN ResourceId = '00' THEN AwayValue ELSE 0 END), 0)
				,@HTHome = ISNULL(SUM(CASE WHEN ResourceId = '01' THEN HomeValue ELSE 0 END), 0)
				,@HTAway = ISNULL(SUM(CASE WHEN ResourceId = '01' THEN AwayValue ELSE 0 END), 0)				
		FROM	@tmpResultDetail
		WHERE	ResourceId IN ('01', '00')

		IF @DeterminedType = 2
		BEGIN
			SELECT	@FTGoalRecord = HomeValue
			FROM	@tmpResultDetail
			WHERE	ResourceId = '09'
		END
		ELSE
		BEGIN
			SELECT	@FTGoalRecord = HomeValue
			FROM	@tmpResultDetail
			WHERE	ResourceId = '08'
		END

		SELECT	@HTGoalRecord = HomeValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = '09'

		SELECT	@2HHome = @FTHome - @HTHome
				,@2HAway = @FTAway - @HTAway
				,@HTOddEven = (@HTHome + @HTAway)%2
				,@FTOddEven = (@FTHome + @FTAway)%2
				,@HTScoreDiff = @HTHome - @HTAway
				,@2HScoreDiff = (@FTHome - @HTHome) - (@FTAway - @HTAway)
				,@HTTotalScore = @HTHome + @HTAway
				,@2HTotalScore = (@FTHome - @HTHome) + (@FTAway - @HTAway)
				,@FTTotalScore = @FTHome + @FTAway
				,@FTScoreDiff = @FTHome - @FTAway

		SELECT	@FTFG = MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END)
				,@FTLG = MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END)
		FROM	@tmpResultDetail
		WHERE	ResourceId IN ('14F', '14L')

		IF @IsDetermined = 0
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '14')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'14'
						,CASE @FTFG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:1'
							WHEN 'A' THEN '2:1'
							ELSE NULL END
						,CASE @FTLG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:2'
							WHEN 'A' THEN '2:2'
							ELSE NULL END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '08'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '127')
			BEGIN
				SELECT	@HTFG = MAX(CASE WHEN ResourceId = '127F' THEN HomeValue ELSE '' END)
						,@HTLG = MAX(CASE WHEN ResourceId = '127L' THEN HomeValue ELSE '' END)
						,@ssId = MIN(ssId)
				FROM	@tmpResultDetail
				WHERE	ResourceId IN ('127F', '127L')

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'127'
						,CASE @HTFG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:1'
							WHEN 'A' THEN '2:1'
							ELSE NULL END

						,CASE @HTLG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:2'
							WHEN 'A' THEN '2:2'
							ELSE NULL END
						,@ssId
			END
		
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '128')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'128'
						,CASE 
							WHEN @HTOddEven = 1 AND @FTOddEven = 1 THEN 'oo' 
							WHEN @HTOddEven = 1 AND @FTOddEven = 0 THEN 'oe' 
							WHEN @HTOddEven = 0 AND @FTOddEven = 1 THEN 'eo' 
							WHEN @HTOddEven = 0 AND @FTOddEven = 0 THEN 'ee' 
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '133')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'133'
						,CASE 
							WHEN @HTScoreDiff > 0 AND @2HScoreDiff > 0 THEN 'y'
							WHEN @HTScoreDiff <=0 OR @2HScoreDiff <= 0 THEN 'n'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '134')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'134'
						,CASE
							WHEN @HTScoreDiff < 0 AND @2HScoreDiff < 0 THEN 'y'
							WHEN @HTScoreDiff >=0 OR @2HScoreDiff >= 0 THEN 'n'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '140')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'140'
						,CASE
							WHEN @HTTotalScore > @2HTotalScore THEN '1h'
							WHEN @HTTotalScore = @2HTotalScore THEN 'tie'
							WHEN @HTTotalScore < @2HTotalScore THEN '2h'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '141')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'141'
						,CASE
							WHEN @HTHome > @2HHome THEN '1h'
							WHEN @HTHome = @2HHome THEN 'tie'
							WHEN @HTHome < @2HHome THEN '2h'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '142')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'142'
						,CASE
							WHEN @HTAway > @2HAway THEN '1h'
							WHEN @HTAway = @2HAway THEN 'tie'
							WHEN @HTAway < @2HAway THEN '2h'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '143')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'143'
						,@HTHome - @HTAway
						,@HTHome + @HTAway
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '144')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'144'
						,@FTHome - @FTAway
						,@FTHome + @FTAway
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '147')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'147'
						,CASE 
							WHEN @HTHome > 0 AND @2HHome > 0 THEN 'y'
							WHEN @HTHome = 0 OR @2HHome = 0 THEN 'n'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '148')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'148'
						,CASE 
							WHEN @HTAway > 0 AND @2HAway > 0 THEN 'y'
							WHEN @HTAway = 0 OR @2HAway = 0 THEN 'n'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '149')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'149'
						,CASE 
							WHEN @HTHome > @HTAway OR @2HHome > @2HAway THEN 'y'
							WHEN @HTHome <= @HTAway AND @2HHome <= @2HAway THEN 'n'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '150')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'150'
						,CASE 
							WHEN @HTAway > @HTHome OR @2HAway > @2HHome THEN 'y'
							WHEN @HTAway <= @HTHome AND @2HAway <= @2HHome THEN 'n'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '152')
			BEGIN
				SELECT @HTCorrectScore = CASE 
											WHEN @HTTotalScore >= 4 THEN '4+' 
											ELSE CAST(@HTHome AS VARCHAR(50)) + ':' + CAST(@HTAway AS VARCHAR(50))
										END
					,@FTCorrectScore =  CASE 
											WHEN @FTTotalScore >=4 THEN '4+'
											ELSE CAST(@FTHome AS VARCHAR(50)) + ':' + CAST(@FTAway AS VARCHAR(50))
										END
			
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'152'
						,@HTCorrectScore + '/' + @FTCorrectScore
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '172')
			BEGIN
				SELECT	@FTFG = HomeValue
				FROM	@tmpResultDetail
				WHERE	ResourceId ='14F'
			
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'172'
						,CASE 
							WHEN @FTFG = 'H' AND @FTHome - @FTAway > 0 THEN 'HH' 
							WHEN @FTFG = 'H' AND @FTHome - @FTAway = 0 THEN 'DH'
							WHEN @FTFG = 'H' AND @FTHome - @FTAway < 0 THEN 'AH'
							WHEN @FTFG = 'A' AND @FTHome - @FTAway > 0 THEN 'HA'
							WHEN @FTFG = 'A' AND @FTHome - @FTAway = 0 THEN 'DA'
							WHEN @FTFG = 'A' AND @FTHome - @FTAway < 0 THEN 'AA'
							WHEN @FTHome + @FTAway = 0 THEN 'NO'
							ELSE ''
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '189')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'189'
						,CASE 
							WHEN (@HTTotalScore - 1.5) > 0 AND (@2HTotalScore - 1.5) >0 THEN 'y' 
							WHEN ((@HTTotalScore - 1.5) <=0 OR (@2HTotalScore - 1.5) <=0 ) THEN 'n'
							ELSE NULL 
						END 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '190')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'190'
						,CASE 
							WHEN (@HTTotalScore - 1.5) < 0 AND (@2HTotalScore - 1.5) < 0 THEN 'y' 
							WHEN ((@HTTotalScore - 1.5) >=0 OR (@2HTotalScore - 1.5) >=0 ) THEN 'n'
							ELSE NULL 
						END 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '397')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'397'
						,CASE 
							WHEN @FTScoreDiff = 1 THEN 'H1'
							WHEN @FTScoreDiff = 2 THEN 'H2'
							WHEN @FTScoreDiff >=3 THEN 'H3+'
							WHEN @FTScoreDiff = 0 AND @FTTotalScore <> 0 THEN 'D'
							WHEN @FTScoreDiff = 0 THEN 'NG'
							WHEN @FTScoreDiff = -1 THEN 'A1' 
							WHEN @FTScoreDiff = -2 THEN 'A2' 
							WHEN @FTScoreDiff <= -3 THEN 'A3+'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '426')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'426'
						,CASE 
							WHEN @HTScoreDiff = 1 THEN 'H1'
							WHEN @HTScoreDiff >= 2 THEN 'H2+'
							WHEN @HTScoreDiff = -1 THEN 'A1'
							WHEN @HTScoreDiff <= -2 THEN 'A2+'
							WHEN @HTTotalScore = 0 THEN 'NG'
							WHEN @HTScoreDiff = 0 THEN 'D'
							ELSE NULL
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '417')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'417'
						,CASE 
							WHEN @FTHome > 0 AND @FTAway > 0 
								THEN CASE
										WHEN @FTHome > @FTAway THEN 'YH'
										WHEN @FTHome < @FTAway THEN 'YA'
										ELSE 'YD'
									END
							ELSE CASE
									WHEN @FTHome > @FTAway THEN 'NH'
									WHEN @FTHome < @FTAway THEN 'NA'
									ELSE 'ND'
								END
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '419')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'419'
						,CASE 
							WHEN @HTTotalScore > 0 THEN '1H'
							WHEN @2HTotalScore > 0 THEN '2H'
							ELSE 'N'
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '420')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'420'
						,CASE 
							WHEN @HTHome > 0 THEN '1H'
							WHEN @2HHome > 0 THEN '2H'
							ELSE 'N'
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '421')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'421'
						,CASE 
							WHEN @HTAway > 0 THEN '1H'
							WHEN @2HAway > 0 THEN '2H'
							ELSE 'N'
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '422')
			BEGIN
				SET @home_firstteam2goals = CHARINDEX('H',@FTGoalRecord,(CHARINDEX('H',@FTGoalRecord)+1))
				SET @away_firstteam2goals = CHARINDEX('A',@FTGoalRecord,(CHARINDEX('A',@FTGoalRecord)+1))

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'422'
						,CASE 
							WHEN (@home_firstteam2goals > 0 AND @away_firstteam2goals = 0) OR (@home_firstteam2goals <> 0 AND @home_firstteam2goals - @away_firstteam2goals < 0) THEN 'H'
							WHEN (@away_firstteam2goals > 0 AND @home_firstteam2goals = 0) OR (@away_firstteam2goals <> 0 AND @away_firstteam2goals - @home_firstteam2goals < 0) THEN 'A'
							ELSE 'N'
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '423')
			BEGIN
				SET @home_firstteam2goals = CHARINDEX('H',@FTGoalRecord,(CHARINDEX('H',@FTGoalRecord)+1))
				SET @away_firstteam2goals = CHARINDEX('A',@FTGoalRecord,(CHARINDEX('A',@FTGoalRecord)+1))
			
				SET @home_firstteam3goals = CASE WHEN @home_firstteam2goals > 0 THEN CHARINDEX('H',@FTGoalRecord, @home_firstteam2goals + 1) ELSE 0 END
				SET @away_firstteam3goals = CASE WHEN @away_firstteam2goals > 0 THEN CHARINDEX('A',@FTGoalRecord, @away_firstteam2goals + 1) ELSE 0 END

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'423'
						,CASE 
							WHEN (@home_firstteam3goals > 0 AND @away_firstteam3goals = 0) OR (@home_firstteam3goals <> 0 AND @home_firstteam3goals - @away_firstteam3goals < 0) THEN 'H'
							WHEN (@away_firstteam3goals > 0 AND @home_firstteam3goals = 0) OR (@away_firstteam3goals <> 0 AND @away_firstteam3goals - @home_firstteam3goals < 0) THEN 'A'
							ELSE 'N'
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '425')
			BEGIN
				DECLARE @curHome INT = 0
						,@curAway INT = 0
						,@index INT = 1
						,@WinFromBehind VARCHAR(1) = ''

				IF (@FTHome <> @FTAway) AND (@FTTotalScore) > 2
				BEGIN
					WHILE (@index <= LEN(REPLACE(@FTGoalRecord,';','')))
					BEGIN
						IF SUBSTRING(REPLACE(@FTGoalRecord,';',''),@index, 1) = 'H'
							SET @curHome = @curHome + 1
				
						IF SUBSTRING(REPLACE(@FTGoalRecord,';',''),@index, 1) = 'A' 
							SET @curAway = @curAway + 1				
			
						IF @FTHome > @FTAway AND @curHome < @curAway 
						BEGIN
							SET @WinFromBehind = 'H' 
							BREAK
						END
						IF @FTAway > @FTHome AND @curAway < @curHome
						BEGIN
							SET @WinFromBehind = 'A'
							BREAK
						END
			
						SET @index = @index + 1
					END
				END	

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'425'
						,@WinFromBehind
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END		

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '445')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'445'
						,CASE
							WHEN @HTHome > 0 AND @HTAway > 0 THEN CASE
																	WHEN @2HHome > 0 AND @2HAway> 0 THEN 'YY'
																	ELSE 'YN'
															END
							ELSE CASE 
										WHEN @2HHome > 0 AND @2HAway > 0 THEN 'NY'
										ELSE 'NN'
									END
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '446')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'446'
						,CASE
							WHEN @HTHome > 0 THEN CASE
														WHEN @2HHome > 0 THEN 'YY'
														ELSE 'YN'
												END
							ELSE CASE 
										WHEN @2HHome > 0 THEN 'NY'
										ELSE 'NN'
									END
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '447')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'447'
						,CASE
							WHEN @HTAway > 0 THEN CASE
														WHEN @2HAway > 0 THEN 'YY'
														ELSE 'YN'
												END
							ELSE CASE 
										WHEN @2HAway > 0 THEN 'NY'
										ELSE 'NN'
									END
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '448')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'448'
						,CASE WHEN @FTLG = 'N' THEN 'NG' ELSE @FTLG END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '08'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '449')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'449'
						,@FTTotalScore
						,@FTScoreDiff
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '450')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'450'
						,@FTTotalScore
						,@FTTotalScore %2 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '452')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'452'
						 ,@HTTotalScore
						 ,@2HTotalScore
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '454')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'454'
						 ,@FTFG
						 ,@FTScoreDiff
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '456')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'456'
						,CASE 
							WHEN @HTHome > 0 AND @HTAway > 0 
								THEN CASE
										WHEN @HTHome > @HTAway THEN 'YH'
										WHEN @HTHome < @HTAway THEN 'YA'
										ELSE 'YD'
									END
							ELSE CASE
									WHEN @HTHome > @HTAway THEN 'NH'
									WHEN @HTHome < @HTAway THEN 'NA'
									ELSE 'ND'
								END
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '467')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'467'
						,CASE 
							WHEN @HTTotalScore BETWEEN 0 AND 3 AND @FTTotalScore >= 7 THEN 'G' + CAST(@HTTotalScore AS VARCHAR(5)) + '/G7+'
							WHEN @HTTotalScore = 4 AND @FTTotalScore >= 8 THEN 'G4/G8+'
							WHEN @HTTotalScore = 5 AND @FTTotalScore >= 9 THEN 'G5/G9+'  
							WHEN @HTTotalScore = 6 AND @FTTotalScore >= 10 THEN 'G6/G10+'
							WHEN @HTTotalScore >= 7 AND @FTTotalScore >= 7 THEN 'G7+/G7+'
							ELSE 'G' + CAST(@HTTotalScore AS VARCHAR(5)) + '/G' + CAST(@FTTotalScore AS VARCHAR(5))						
					END          
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId IN ('486', '487'))
			BEGIN
				IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '486')
					SET @ResourceId = '486'
				ELSE
					SET @ResourceId = '487'

				WHILE (@ResourceId <> '00')
				BEGIN
					SELECT	@Position = 1
							,@HomeRaceTo = 0
							,@AwayRaceTo = 0
							,@string = CASE WHEN @ResourceId = '486' THEN @FTGoalRecord ELSE @HTGoalRecord END
							,@result = ''

					SELECT @LenResultString = LEN(@string)
			
					WHILE (@Position <= @LenResultString)
					BEGIN
						SET @Char = SUBSTRING(@string, @Position, 1)
			
						IF @Char = 'H'	
						BEGIN
							SET @HomeRaceTo = @HomeRaceTo + 1

							IF @HomeRaceTo > @AwayRaceTo
								SET  @result = @result + CAST(@HomeRaceTo AS VARCHAR) + @Char + ';'
					
						END
						ELSE IF @Char = 'A' 
						BEGIN
							SET @AwayRaceTo = @AwayRaceTo + 1

							IF @AwayRaceTo > @HomeRaceTo
								SET  @result = @result + CAST(@AwayRaceTo AS VARCHAR) + @Char + ';'
						END
			
						SET @Position = @Position + 1	 	
					END

					SET @NeitherRaceTo = CASE WHEN @HomeRaceTo > @AwayRaceTo THEN @HomeRaceTo ELSE @AwayRaceTo END + 1

					INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
					SELECT	@ResourceId	
							,case when right(@result,1) = ';' then SUBSTRING(@result,1,len(@result) - 1) else @result end
							--,@result
							,@NeitherRaceTo
							,ssId
					FROM	@tmpResultDetail
					WHERE	ResourceId = '00'

					IF @ResourceId = '487'
						BREAK

					SET @ResourceId = '487'
				END
			END
		
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '488')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
				SELECT	'488'
						,LEFT(REPLACE(@FTGoalRecord,';',''),1) 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '489')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
				SELECT	'489'
						,LEFT(REPLACE(@HTGoalRecord,';',''),1) 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '490')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
				SELECT	'490'
						,CASE 
							WHEN CHARINDEX(';', @FTGoalRecord) > 0 THEN SUBSTRING(@FTGoalRecord, CHARINDEX(';', @FTGoalRecord)+1,1) 
							ELSE LEFT(@FTGoalRecord,1) 
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '491')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
				SELECT	'491'
						,RIGHT(REPLACE(@FTGoalRecord,';',''),1)
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '492')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
				SELECT	'492'
						,RIGHT(@HTGoalRecord,1) 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '493')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
				SELECT	'493'
						,CASE WHEN @HTTotalScore = 0 AND @FTTotalScore >= 8 THEN '0/8+'
							WHEN @HTTotalScore = 1 AND @FTTotalScore >= 9 THEN '1/9+'  
							WHEN @HTTotalScore = 2 AND @FTTotalScore >= 10 THEN '2/10+'
							WHEN @HTTotalScore = 3 AND @FTTotalScore >= 11 THEN '3/11+'
							WHEN @HTTotalScore = 4 AND @FTTotalScore >= 12 THEN '4/12+'
							WHEN @HTTotalScore = 5 AND @FTTotalScore >= 13 THEN '5/13+'
							WHEN @HTTotalScore = 6 AND @FTTotalScore >= 14 THEN '6/14+'
							WHEN @HTTotalScore IN (7,8,9) AND @FTTotalScore >= 15 THEN CAST(@HTTotalScore AS VARCHAR(5)) + '/15+'
							ELSE CAST(@HTTotalScore AS VARCHAR(5)) + '/' + CAST(@FTTotalScore AS VARCHAR(5))
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END
		
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '02')
			BEGIN
				INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'02'
						,@FTHome - @HTHome
						,@FTAway - @HTAway
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '16')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'16'
						,CASE
							WHEN @HTHome > @HTAway 
								THEN '1:' + CASE
												WHEN @FTHome > @FTAway THEN '1'
												WHEN @FTHome = @FTAway THEN '0'
												WHEN @FTHome < @FTAway THEN '2'
												ELSE NULL
											END
							WHEN @HTHome = @HTAway 
								THEN '0:' + CASE
												WHEN @FTHome > @FTAway THEN '1'
												WHEN @FTHome = @FTAway THEN '0'
												WHEN @FTHome < @FTAway THEN '2'
												ELSE NULL
											END
							WHEN @HTHome < @HTAway 
								THEN '2:' + CASE
												WHEN @FTHome > @FTAway THEN '1'
												WHEN @FTHome = @FTAway THEN '0'
												WHEN @FTHome < @FTAway THEN '2'
												ELSE NULL
											END
							END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END 

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '22')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'22'
						,REPLACE(ISNULL(HomeValue, ''),';','') 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '08'
			END 

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '405')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'405'
						,CAST((@FTHome -@HTHome) AS NVARCHAR(6)) + ':' + CAST((@FTAway - @HTAway) AS NVARCHAR(6))
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END 

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '413')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'413'
						,CAST(@FTHome AS NVARCHAR(6)) + ':' + CAST(@FTAway AS NVARCHAR(6))
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END 

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '414')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'414'
						,CAST(@HTHome AS NVARCHAR(6)) + ':' + CAST(@HTAway AS NVARCHAR(6))
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '01'
			END 
		
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '416')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'416'
						,CAST(@HTHome AS NVARCHAR(10)) + ':' + CAST(@HTAway AS NVARCHAR(10)) AS HomeValue
						,CAST(@FTHome AS NVARCHAR(10)) + ':' + CAST(@FTAway AS NVARCHAR(10)) AS AwayValue
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END 
		END
		ELSE IF @IsDetermined = 1
		BEGIN	
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '14')
			BEGIN
				SELECT	@FTFG = MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END)
						,@FTLG = MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END)
						,@ssId = MIN(ssId)
				FROM	@tmpResultDetail
				WHERE	ResourceId IN ('14F', '14L')
						AND 1 = CASE 
									WHEN @IsChecking = 1 AND isWeb = 1 THEN 1
									WHEN @IsChecking = 0 THEN 1
									ELSE 0 
								END


				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'14'
						,CASE @FTFG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:1'
							WHEN 'A' THEN '2:1'
							ELSE NULL END

						,CASE @FTLG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:2'
							WHEN 'A' THEN '2:2'
							ELSE NULL END
						,@ssId
			END
			
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '127')
			BEGIN
				SELECT	@HTFG = MAX(CASE WHEN ResourceId = '127F' THEN HomeValue ELSE '' END)
						,@HTLG = MAX(CASE WHEN ResourceId = '127L' THEN HomeValue ELSE '' END)
						,@ssId = MIN(ssId)
				FROM	@tmpResultDetail
				WHERE	ResourceId IN ('127F', '127L')
						AND 1 = CASE 
									WHEN @IsChecking = 1 AND isWeb = 1 THEN 1
									WHEN @IsChecking = 0 THEN 1
									ELSE 0 
								END

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
				SELECT	'127'
						,CASE @HTFG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:1'
							WHEN 'A' THEN '2:1'
							ELSE NULL END

						,CASE @HTLG
							WHEN 'N' THEN '0:0'
							WHEN 'H' THEN '1:2'
							WHEN 'A' THEN '2:2'
							ELSE NULL END
						,@ssId
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '172')
			BEGIN	
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'172'
						,@FTFG
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '396')
			BEGIN	
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'396'
						,REPLACE(ISNULL(@FTGoalRecord, ''),';','')
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '08'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '422')
			BEGIN
				SET @home_firstteam2goals = CHARINDEX('H',@FTGoalRecord,(CHARINDEX('H',@FTGoalRecord)+1))
				SET @away_firstteam2goals = CHARINDEX('A',@FTGoalRecord,(CHARINDEX('A',@FTGoalRecord)+1))

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'422'
						,CASE 
							WHEN (@home_firstteam2goals > 0 AND @away_firstteam2goals = 0) OR (@home_firstteam2goals <> 0 AND @home_firstteam2goals - @away_firstteam2goals < 0) THEN 'H'
							WHEN (@away_firstteam2goals > 0 AND @home_firstteam2goals = 0) OR (@away_firstteam2goals <> 0 AND @away_firstteam2goals - @home_firstteam2goals < 0) THEN 'A'
							ELSE 'N'
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '423')
			BEGIN
				SET @home_firstteam2goals = CHARINDEX('H',@FTGoalRecord,(CHARINDEX('H',@FTGoalRecord)+1))
				SET @away_firstteam2goals = CHARINDEX('A',@FTGoalRecord,(CHARINDEX('A',@FTGoalRecord)+1))
			
				SET @home_firstteam3goals = CASE WHEN @home_firstteam2goals > 0 THEN CHARINDEX('H',@FTGoalRecord, @home_firstteam2goals + 1) ELSE 0 END
				SET @away_firstteam3goals = CASE WHEN @away_firstteam2goals > 0 THEN CHARINDEX('A',@FTGoalRecord, @away_firstteam2goals + 1) ELSE 0 END

				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'423'
						,CASE 
							WHEN (@home_firstteam3goals > 0 AND @away_firstteam3goals = 0) OR (@home_firstteam3goals <> 0 AND @home_firstteam3goals - @away_firstteam3goals < 0) THEN 'H'
							WHEN (@away_firstteam3goals > 0 AND @home_firstteam3goals = 0) OR (@away_firstteam3goals <> 0 AND @away_firstteam3goals - @home_firstteam3goals < 0) THEN 'A'
							ELSE 'N'
						END
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '448')
			BEGIN	
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'448'
						,@FTFG
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '454')
			BEGIN	
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'454'
						,@FTFG
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = '00'
			END
			
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId IN ('486', '487'))
			BEGIN	
				IF @xmlWebResourceResult IS NOT NULL
				BEGIN
					;WITH cteRaceTo
					AS(
						SELECT	LEFT(t.ResourceId,3) AS DummyResourceId
								,CAST(REPLACE(t.ResourceId,LEFT(t.ResourceId,3),'') AS INT) AS RaceTo
								,t.HomeValue AS TeamResult
								,t.ssId
						FROM	@tmpResultDetail t
						WHERE	t.ResourceId LIKE '48[6-7]%'	
								AND 1 = CASE 
											WHEN @IsChecking = 1 AND isWeb = 1 THEN 1
											WHEN @IsChecking = 0 THEN 1
											ELSE 0 
										END
					)
					,cteResult
					AS (
						SELECT	DummyResourceId
								,STRING_AGG(CAST(CAST(RaceTo AS VARCHAR(10)) + TeamResult AS VARCHAR(MAX)), ';') AS TeamRaceTo
								,MAX(CASE WHEN ssId = 4 AND TeamResult IN ('H', 'A') THEN RaceTo + 1 ELSE 0 END) AS NeitherRaceTo
								,MAX(ssId) AS ssId
						FROM	cteRaceTo
						GROUP BY DummyResourceId
					)
					INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, AwayValue, ssId)
					SELECT t.ResourceId, c.TeamRaceTo, c.NeitherRaceTo, c.ssId
					FROM @tmpDummyResourceIds t
						OUTER APPLY (
							SELECT	c.DummyResourceId, c.TeamRaceTo, CAST(c.NeitherRaceTo AS VARCHAR(2000)) AS NeitherRaceTo, c.ssId
							FROM	cteResult c
							WHERE	c.DummyResourceId = t.ResourceId
						) c
					WHERE t.ResourceId IN ('486', '487')

				END
				ELSE -- @WebResourceResult dont have ResourceId
				BEGIN
					IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '486')
						SET @ResourceId = '486'
					ELSE
						SET @ResourceId = '487'

					WHILE (@ResourceId <> '00')
				BEGIN
					SELECT	@Position = 1
							,@HomeRaceTo = 0
							,@AwayRaceTo = 0
							,@string = CASE WHEN @ResourceId = '486' THEN @FTGoalRecord ELSE @HTGoalRecord END
							,@result = ''

					SELECT @LenResultString = LEN(@string)
			
					WHILE (@Position <= @LenResultString)
					BEGIN
						SET @Char = SUBSTRING(@string, @Position, 1)
			
						IF @Char = 'H'	
						BEGIN
							SET @HomeRaceTo = @HomeRaceTo + 1

							IF @HomeRaceTo > @AwayRaceTo
								SET  @result = @result + CAST(@HomeRaceTo AS VARCHAR) + @Char + ';'
					
						END
						ELSE IF @Char = 'A' 
						BEGIN
							SET @AwayRaceTo = @AwayRaceTo + 1

							IF @AwayRaceTo > @HomeRaceTo
								SET  @result = @result + CAST(@AwayRaceTo AS VARCHAR) + @Char + ';'
						END
			
						SET @Position = @Position + 1	 	
					END

					SET @NeitherRaceTo = CASE WHEN @HomeRaceTo > @AwayRaceTo THEN @HomeRaceTo ELSE @AwayRaceTo END + 1

					INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
					SELECT	@ResourceId	
							,case when right(@result,1) = ';' then SUBSTRING(@result,1,len(@result) - 1) else @result end
							,@NeitherRaceTo
							,ssId
					FROM	@tmpResultDetail
					WHERE	ResourceId = '00'

					IF @ResourceId = '487'
						BREAK

					SET @ResourceId = '487'
				END
				END
			END
		
			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '488')
			BEGIN
				IF @xmlWebResourceResult IS NOT NULL
				BEGIN
					IF @IsChecking = 0
					BEGIN
						INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
						SELECT	r.ResourceId, r.HomeValue, r.ssId
						FROM	@tmpResultDetail r
						WHERE	r.ResourceId = '488'
								AND r.isWeb = 1
					END
					ELSE
					BEGIN
						INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
						SELECT	t.ResourceId, r.HomeValue, r.ssId
						FROM	@tmpDummyResourceIds t
							OUTER APPLY (
								SELECT	r.ResourceId, r.HomeValue, r.ssId
								FROM	@tmpResultDetail r
								WHERE	r.ResourceId = t.ResourceId
										AND r.isWeb = 1
						)r
						WHERE	t.ResourceId = '488'
					END
				END
				ELSE
					INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
					SELECT	'488'
							,LEFT(REPLACE(@FTGoalRecord,';',''),1) 
							,ssId
					FROM	@tmpResultDetail
					WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '489')
			BEGIN
				IF @xmlWebResourceResult IS NOT NULL
				BEGIN
					IF @IsChecking = 0
					BEGIN
						INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
						SELECT	r.ResourceId, r.HomeValue, r.ssId
						FROM	@tmpResultDetail r
						WHERE	r.ResourceId = '489'
								AND r.isWeb = 1
					END
					ELSE
					BEGIN
						INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
						SELECT	t.ResourceId, r.HomeValue, r.ssId
						FROM	@tmpDummyResourceIds t
							OUTER APPLY (
								SELECT	r.ResourceId, r.HomeValue, r.ssId
								FROM	@tmpResultDetail r
								WHERE	r.ResourceId = t.ResourceId
										AND r.isWeb = 1
						)r
						WHERE	t.ResourceId = '489'
					END
				END
				ELSE
					INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
					SELECT	'489'
							,LEFT(REPLACE(@HTGoalRecord,';',''),1) 
							,ssId
					FROM	@tmpResultDetail
					WHERE	ResourceId = '01'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '490')
			BEGIN
				IF @xmlWebResourceResult IS NOT NULL
				BEGIN
					IF @IsChecking = 0
					BEGIN
						INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
						SELECT	r.ResourceId, r.HomeValue, r.ssId
						FROM	@tmpResultDetail r
						WHERE	r.ResourceId = '490'
								AND r.isWeb = 1
					END
					ELSE
					BEGIN
						INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
						SELECT	t.ResourceId, r.HomeValue, r.ssId
						FROM	@tmpDummyResourceIds t
							OUTER APPLY (
								SELECT	r.ResourceId, r.HomeValue, r.ssId
								FROM	@tmpResultDetail r
								WHERE	r.ResourceId = t.ResourceId
										AND r.isWeb = 1
						)r
						WHERE	t.ResourceId = '490'
					END
					
				END
				ELSE
					INSERT INTO @tmpDummyResourceResults(ResourceId, HomeValue, ssId)
					SELECT	'490'
							,CASE 
								WHEN CHARINDEX(';', @FTGoalRecord) > 0 THEN SUBSTRING(@FTGoalRecord, CHARINDEX(';', @FTGoalRecord)+1,1) 
								ELSE LEFT(@FTGoalRecord,1) 
							END 
							,ssId
					FROM	@tmpResultDetail
					WHERE	ResourceId = '00'
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '22')
			BEGIN
				INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, ssId)
				SELECT	'22'
						,REPLACE(ISNULL(HomeValue, ''),';','') 
						,ssId
				FROM	@tmpResultDetail
				WHERE	ResourceId = CASE WHEN @DeterminedType = 2 THEN '09' ELSE '08' END
			END 
		END
	END

	ELSE IF @Sporttype IN ( 6, 9, 45 )
	BEGIN
		--Highest Scoring Set Total
		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '3902')
		BEGIN
			SET @MaxValue = 0

			SELECT	@MaxValue = MAX(CAST(HomeValue AS INT) + CAST(AwayValue AS INT))
			FROM	@tmpResultDetail
			WHERE	ResourceId LIKE '010[1-5]'

			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
			SELECT '3902', @MaxValue, 0, 0
		END

		IF NOT EXISTS ( SELECT TOP 1 1 FROM @tmpResultDetail)
		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ssId)
		SELECT	'00', '', '', 0
		
		SELECT	 @FTHome = SUM(CASE WHEN ResourceId = '00' THEN CAST(HomeValue AS INT) ELSE 0 END)
				,@FTAway = SUM(CASE WHEN ResourceId = '00' THEN CAST(AwayValue AS INT) ELSE 0 END)
				,@TotalHomeScore = SUM(CASE WHEN ResourceId <> '00' THEN CAST(HomeValue AS INT) ELSE 0 END)
				,@TotalAwayScore = SUM(CASE WHEN ResourceId <> '00' THEN CAST(AwayValue AS INT) ELSE 0 END)
		FROM	@tmpResultDetail r

		IF EXISTS (SELECT TOP 1 1 FROM @tmpDummyResourceIds WHERE ResourceId = '0100' OR ResourceId = '70400' )
		BEGIN
			INSERT INTO @tmpDummyResourceResults (ResourceId, HomeValue, AwayValue, ssId)
			SELECT	CASE WHEN @Sporttype = 9 THEN '70400' ELSE '0100' END
					,CAST(CASE @TotalHomeScore WHEN 0 THEN @FTHome ELSE @TotalHomeScore END AS VARCHAR(50))
					,CAST(CASE @TotalAwayScore WHEN 0 THEN @FTAway ELSE @TotalAwayScore END AS VARCHAR(50))
					,MIN(ssId)
			FROM @tmpResultDetail r
			GROUP BY ResourceId
		END
	END

	SET @DummyResourceResults = CONVERT(VARCHAR(MAX),(
		SELECT	ResourceId AS '@Id'
				,HomeValue AS '@Home'
				,AwayValue AS '@Away'
				,ssId AS '@ssId'
				,isCalculated AS '@isCal'
		FROM @tmpDummyResourceResults
		FOR XML PATH('r'), ROOT('root'), TYPE))

END