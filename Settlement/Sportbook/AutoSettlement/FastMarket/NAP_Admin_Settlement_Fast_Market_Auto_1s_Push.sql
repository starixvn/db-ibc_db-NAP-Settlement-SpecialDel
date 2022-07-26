/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s_Push] @MatchId INT
	,@Action				VARCHAR(20)
	,@Results				VARCHAR(MAX)
	,@EventCounters			VARCHAR(MAX) = NULL

	,@IsAuto				BIT			= 0
	,@AdminId				INT			= 0
	,@Ip					VARCHAR(20)	= ''
	,@IsReSettledTickets	BIT			= 1
	,@IsSettleDetermined	BIT			= 0

	,@ErrCode				INT			= 0		OUTPUT
	,@ErrMsg				VARCHAR(MAX)= ''	OUTPUT
AS
/*
	Created: 20160428@Patrick
	Task: Fast market - Auto/Manual settlement
	DB: DBTXN.BODB02
	Original:
	
	Revisions:
			- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
			- 20170123@Kathy: Checking auto settlement FM setting of match before settling  [Redmine:#69949]
			- 20170427@Bobby: 72789 - Implement bonus system into NAP Settlement
			- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]
			- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
			- 20190813@Helen: Remove vnteam in metadata
			- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
			- 20200928@Helen: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
			- 20201106@Kathy: Add "Water Break" Concept to Fast Markets [Readmine:#143573]
			- 20210107@Kathy: Support settle determined [Readmine:#147141]
			- 20210225@Kathy: Wrong Water break validation  [Readmine:#150682]
			- 20210406@Kathy: New bettype 229 [Readmine:#152748]
			- 20210428@Kathy: - Allow to settle directly for bettype 228 [Redmine:#153155]
							  - Check SP is in deployment 			
			- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
			- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
			- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
			
	Param's Explanation:
		- @Result: 
			Format:	 '<BetTypes>
							<BetType Id="">
								<Item Position="" Result="" />
								<Item Position="" Result="" />
							</BetType>
	
						</BetTypes>'

	    - @EventCounters: 221CNT02 - Goals
						 221CNT03 - Corners
						 221CNT04 - Free Kicks
						 221CNT05 - Goal Kicks
						 221CNT06 - Throw Ins
						 221CNT08 - Penalties

			Format:		'<EventCounters>
								<EventCounter Id="221CNT02">
									<Item Position="0" Result="2" />
									<Item Position="1" Result="1" />
								</EventCounter>
								<EventCounter Id="221CNT03">
									<Item Position="0" Result="4" />
									<Item Position="1" Result="2" />
								</EventCounter>
								...
							</EventCounters>'
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @matchcode		NVARCHAR(50)
			,@sporttype		INT
			,@leagueid		INT
			,@sqlCommand	NVARCHAR(MAX)
			,@procName		NVARCHAR(128) = OBJECT_NAME(@@PROCID)
			,@xmlData		XML
			,@subErrMsg		VARCHAR(MAX) = ''
			,@AutoSetting	TINYINT
			,@xmlEventCounter	XML

			-- new bettype 228
			,@BetOption1st	VARCHAR(50)
			,@BetOption2nd	VARCHAR(50)
			,@ResultStatus1st VARCHAR(50)			
			,@ResultStatus2nd VARCHAR(50)
			,@minSelectedPosition TINYINT
			,@maxSelectedPosition TINYINT

			-- new bettype 229
			,@BetOptionHome_1st VARCHAR(50)
			,@BetOptionHome_2nd VARCHAR(50)
			,@BetOptionAway_1st VARCHAR(50)
			,@BetOptionAway_2nd VARCHAR(50)

			,@IsFailed BIT = 0
			
			,@WaitingTime VARCHAR(10)
			,@IsWaiting BIT = 0
			
	DECLARE @tblData TABLE (
		bettype					SMALLINT
		,ResourceId				VARCHAR(20)
		,ResourceId_BetOption	VARCHAR(20)
		,Position				TINYINT
		,BetOption				TINYINT
		,ResultStatus			TINYINT
		,IsSettleDetermined		BIT
	)
	
	DECLARE @tblResultDetail TABLE (
		ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,OtherInfo		VARCHAR(50)
	)

	DECLARE @tblSpecialResultDetail TABLE (
		ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,OtherInfo		VARCHAR(50)
	)
	
	DECLARE @tblResultDetail_228 TABLE (
		ResourceId				VARCHAR(20)
		,Position				TINYINT 
		,Value					TINYINT
	)

	DECLARE @tblResultDetail_229 TABLE (
		ResourceId				VARCHAR(20)
		,Position				TINYINT 
		,Value					TINYINT
	)

	SELECT	@matchcode = m.matchcode
			,@sporttype = m.sporttype
			,@leagueid = m.leagueid
			,@AutoSetting = m.AutoSetting
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId
		
	SET @xmlData = CONVERT(XML, @Results)
	SET @xmlEventCounter = CONVERT(XML, @EventCounters)
	
	INSERT INTO @tblResultDetail (ResourceId, HomeValue, AwayValue, OtherInfo)
	SELECT	ResourceId, HomeValue, AwayValue, OtherInfo
	FROM	DBPRO.bodb02.dbo.ResultDetail r WITH (ROWLOCK)
	WHERE	matchid = @matchid

	INSERT INTO @tblSpecialResultDetail (ResourceId, HomeValue, AwayValue, OtherInfo)
	SELECT	ResourceId, HomeValue, AwayValue, OtherInfo
	FROM	@tblResultDetail
	WHERE	ResourceId LIKE '221WB__' OR ResourceId = '221SUS'
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@Position','TINYINT') as Position
			,X.C.value('@Result','TINYINT') as BetOption
		FROM @xmlData.nodes('/BetTypes/BetType') AS T(C)
			CROSS APPLY
				C.nodes('Item') AS X(C)
	)
	INSERT INTO @tblData (bettype, ResourceId, ResourceId_BetOption, Position, BetOption, IsSettleDetermined)
	SELECT	bettype
			,CAST(BetType * 100 AS VARCHAR(20)) AS ResourceId
			,CASE WHEN bettype = 229 THEN '22901H' ELSE CAST(BetType * 100 + 1 AS VARCHAR(20)) END AS ResourceId_BetOption
			,Position
			,BetOption
			,@IsSettleDetermined AS IsSettleDetermined
	FROM TmpData t
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )
	
	IF EXISTS (SELECT TOP 1 1 FROM @tblData WHERE bettype = 228)
	BEGIN
		-- For bettype 228
		SELECT @BetOption1st = HomeValue, @BetOption2nd = AwayValue
		FROM @tblResultDetail
		WHERE ResourceId = '22801'
	
		SELECT @ResultStatus1st = HomeValue, @ResultStatus2nd = AwayValue
		FROM @tblResultDetail
		WHERE ResourceId = '22800'

		IF @BetOption1st IS NOT NULL OR @BetOption2nd IS NOT NULL OR @ResultStatus1st IS NOT NULL OR @ResultStatus2nd IS NOT NULL
		BEGIN
			INSERT INTO @tblResultDetail_228 (ResourceId, Position, Value)
			SELECT	'22800', f.pos AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@ResultStatus1st) f
			WHERE	f.pos < 46 AND ISNULL(@ResultStatus1st,'') <> ''
			UNION ALL
			SELECT	'22800', f.pos + 46 AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@ResultStatus2nd) f
			WHERE	f.pos < 45 AND ISNULL(@ResultStatus2nd,'') <> ''
			UNION ALL
			SELECT	'22801', f.pos AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@BetOption1st) f
			WHERE	f.pos < 46 AND ISNULL(@BetOption1st,'') <> ''
			UNION ALL
			SELECT	'22801', f.pos + 46 AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@BetOption2nd) f
			WHERE	f.pos < 45 AND ISNULL(@BetOption2nd,'') <> ''
		END		

		SELECT	@maxSelectedPosition = MAX(Position)
				,@minSelectedPosition = MIN(Position)
		FROM	@tblData
		WHERE	bettype = 228

		IF @Action = 'CAL'
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
						FROM	@tblResultDetail_228 t
						WHERE	t.ResourceId = '22800'
								AND 1 = CASE
											WHEN t.Value NOT IN (4,5) AND t.Position < @minSelectedPosition THEN 1 -- previous interval
											WHEN t.Position BETWEEN @minSelectedPosition AND @maxSelectedPosition -- between selected intervals
												AND NOT EXISTS (SELECT TOP 1 1 FROM @tblData d WHERE t.Position = d.Position) THEN 1
											ELSE 0
										END
			)
				SET @IsFailed = 1
		END		
		ELSE IF @Action = 'REFUND'
		BEGIN
			IF EXISTS (SELECT TOP 1 1
						FROM	@tblResultDetail_228 t
						WHERE	t.ResourceId = '22800'
								AND 1 = CASE
										WHEN t.Value NOT IN (4,5) AND t.Position < @minSelectedPosition THEN 1 
										ELSE 0
									END
			)
				SET @IsFailed = 1
												
		END
		ELSE IF @Action = 'UNDO'
		BEGIN
			IF EXISTS (SELECT TOP 1 1
			FROM	@tblResultDetail_228 t
			WHERE	t.ResourceId = '22800'
					AND t.Value IN (4,5)
					AND 1 = CASE 
								WHEN t.Position > @maxSelectedPosition THEN 1
								WHEN t.Position BETWEEN @minSelectedPosition AND @maxSelectedPosition 
									AND NOT EXISTS (SELECT TOP 1 1 FROM @tblData d WHERE d.Position = t.Position) THEN 1
								ELSE 0
							END
			)
				SET @IsFailed = 1
		END
		
		IF @IsFailed = 1
		BEGIN
			SELECT	 @ErrCode	= 1001015
						,@ErrMsg	= 'WARNING! Cannot continue due to procedure violations. Please check selected intervals' + CASE WHEN @IsAuto = 0 THEN ' or reload the screen' ELSE '' END + ' and try again.'
			RETURN
		END
	END	

	IF EXISTS (SELECT TOP 1 1 FROM @tblData WHERE bettype = 229)
	BEGIN
		-- For bettype 229
		SELECT	@BetOptionHome_1st = HomeValue
				,@BetOptionHome_2nd = AwayValue
		FROM	@tblResultDetail
		WHERE	ResourceId = '22901H'

		SELECT	@BetOptionAway_1st = HomeValue
				,@BetOptionAway_2nd = AwayValue
		FROM	@tblResultDetail
		WHERE	ResourceId = '22901A'
	
		SELECT	@ResultStatus1st = HomeValue
				,@ResultStatus2nd = AwayValue
		FROM	@tblResultDetail
		WHERE	ResourceId = '22900'

	
		INSERT INTO @tblResultDetail_229 (ResourceId, Position, Value)
		SELECT	'22900', f.pos AS Position, f.ResultStatus AS Value
		FROM	dbo.f_Set_GetChars(@ResultStatus1st) f
		WHERE	f.pos < 46 AND ISNULL(@ResultStatus1st,'') <> ''
		UNION ALL
		SELECT	'22900', f.pos + 46 AS Position, f.ResultStatus AS Value
		FROM	dbo.f_Set_GetChars(@ResultStatus2nd) f
		WHERE	f.pos < 45 AND ISNULL(@ResultStatus2nd,'') <> ''
		UNION ALL
		SELECT	'22901H', f.Position, f.Result
		FROM (
			SELECT	fh.pos AS Position, (fh.ResultStatus + fa.ResultStatus * 10) AS Result, ff.ResultStatus AS ResultStatus
			FROM	dbo.f_Set_GetChars(@BetOptionHome_1st) fh
				INNER JOIN dbo.f_Set_GetChars(@BetOptionAway_1st) fa
					on fh.pos = fa.pos
				INNER JOIN dbo.f_Set_GetChars(@ResultStatus1st) ff 
					ON	fh.pos = ff.pos
			WHERE	fh.pos < 46 AND ISNULL(@BetOptionHome_1st,'') <> '' AND ISNULL(@BetOptionAway_1st,'') <> ''
		) f
		UNION ALL
		SELECT	'22901H', f.Position, f.Result
		FROM(
			SELECT	fh.pos + 46 AS Position, (fh.ResultStatus + fa.ResultStatus * 10) AS Result, ff.ResultStatus AS ResultStatus
			FROM	dbo.f_Set_GetChars(@BetOptionHome_2nd) fh
				INNER JOIN dbo.f_Set_GetChars(@BetOptionAway_2nd) fa
					ON fh.pos = fa.pos
				INNER JOIN dbo.f_Set_GetChars(@ResultStatus2nd) ff 
					ON	fh.pos = ff.pos
			WHERE	fh.pos < 45 AND ISNULL(@BetOptionHome_2nd,'') <> '' AND ISNULL(@BetOptionAway_2nd,'') <> ''
		)f		

		SELECT	@maxSelectedPosition = MAX(Position)
				,@minSelectedPosition = MIN(Position)
		FROM	@tblData
		WHERE	bettype = 229

		IF @Action = 'CAL'
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
						FROM	@tblResultDetail_229 t
						WHERE	t.ResourceId = '22900'
								AND 1 = CASE
											WHEN t.Value NOT IN (4,5) AND t.Position < @minSelectedPosition THEN 1 -- previous interval
											WHEN t.Position BETWEEN @minSelectedPosition AND @maxSelectedPosition -- between selected intervals
												AND NOT EXISTS (SELECT TOP 1 1 FROM @tblData d WHERE t.Position = d.Position) THEN 1
											ELSE 0
										END
			)
				SET @IsFailed = 1
		END		
		ELSE IF @Action = 'REFUND'
		BEGIN
			IF EXISTS (SELECT TOP 1 1
						FROM	@tblResultDetail_229 t
						WHERE	t.ResourceId = '22900'
								AND 1 = CASE
										WHEN t.Value NOT IN (4,5) AND t.Position < @minSelectedPosition THEN 1 
										WHEN t.Value IN (4,5) AND t.Position > @maxSelectedPosition THEN 1 
										ELSE 0
									END
			)
				SET @IsFailed = 1
												
		END
		ELSE IF @Action = 'UNDO'
		BEGIN
			IF EXISTS (SELECT TOP 1 1
			FROM	@tblResultDetail_229 t
			WHERE	t.ResourceId = '22900'
					AND t.Value IN (4,5)
					AND 1 = CASE 
								WHEN t.Position > @maxSelectedPosition THEN 1
								WHEN t.Position BETWEEN @minSelectedPosition AND @maxSelectedPosition 
									AND NOT EXISTS (SELECT TOP 1 1 FROM @tblData d WHERE d.Position = t.Position) THEN 1
								ELSE 0
							END
			)
				SET @IsFailed = 1
		END

		IF @IsFailed = 1
		BEGIN
			SELECT	 @ErrCode	= 1001015
						,@ErrMsg	= 'WARNING! Cannot continue due to procedure violations. Please check selected intervals' + CASE WHEN @IsAuto = 0 THEN ' or reload the screen' ELSE '' END + ' and try again.'
			RETURN
		END
	END	

	IF @Action = 'CAL'
	BEGIN
		-- Compare selected intervals with each existing WB session
		IF EXISTS (SELECT TOP 1 1 FROM @tblData WHERE bettype BETWEEN 221 AND 227) --222,224,227
		BEGIN
			;WITH cteWaterBreak
			AS (
				SELECT	CAST(HomeValue AS INT) AS startWB
						,CAST(AwayValue AS INT) AS endWB
				FROM	@tblSpecialResultDetail
				WHERE	ResourceId LIKE '221WB__'
			)
			SELECT	@ErrCode = 1001047
					,@ErrMsg = 'WARNING! Cannot continue due to invalid intervals selected. Please check with special sessions and try again.'
			FROM	@tblData d
				CROSS APPLY (	
					SELECT CASE
								WHEN d.bettype IN (222, 224, 227) THEN 4
								ELSE 0
							END AS mins				
				)m
				CROSS APPLY (SELECT TOP 1 1 AS IsOverlap                                                                                                                     
								FROM	cteWaterBreak wb
								WHERE	d.Position BETWEEN wb.startWB - m.mins AND wb.endWB 
						) wb

			IF @ErrCode <> 0
				RETURN
		END

		-- Compare selected intervals with suspend time
		;WITH cteSUS
		AS (
			SELECT	CAST(HomeValue AS INT) AS startSUS
					,CAST(SUBSTRING(otherinfo,CHARINDEX(':',otherinfo)+ 1,LEN(otherinfo)) AS SMALLMONEY) AS second 
			FROM	@tblSpecialResultDetail
			WHERE	ResourceId = '221SUS'
		)
		SELECT	@ErrCode = 1001047
				,@ErrMsg = 'WARNING! Cannot continue due to invalid intervals selected. Please check with special sessions and try again.'
		FROM	@tblData d
			CROSS APPLY (	
				SELECT CASE
							WHEN d.bettype IN (222, 224, 227) THEN 4
							ELSE 0
						END AS mins
						,CASE 
							WHEN d.bettype IN (228, 229)
								THEN CASE 
										WHEN d.Position <= 44 THEN d.Position
										ELSE d.Position - 1
									END
							ELSE d.Position
						END AS Position			
			)m
			CROSS APPLY (SELECT TOP 1 1 AS IsOverlap
							FROM	cteSUS sus
							WHERE	m.Position BETWEEN sus.startSUS - m.mins AND 90
									OR m.Position >=  sus.startSUS - m.mins
									OR (d.bettype IN (228, 229) AND sus.second = 0 AND m.Position + 1 = sus.startSUS) 
							) sus

		IF @ErrCode <> 0
			RETURN
	END

	IF @IsAuto = 1
	BEGIN		
		IF EXISTS (SELECT TOP 1 1 FROM @tblData WHERE bettype NOT IN (SELECT bettype FROM dbo.f_Set_GetGroupBettypes() WHERE GroupId = 9)) -- FM
		BEGIN
			SELECT	 @ErrCode	= 1001016
					,@ErrMsg	= 'There are some bettypes not belong to Fast Market' 

			RETURN
		END

		IF @Action <> 'CAL'
		BEGIN
			SELECT	 @ErrCode	= 1001036
					,@ErrMsg	= 'The auto-settlement failed due to wrong action.' 

			RETURN
		END
		
		IF @AutoSetting IS NULL
			SELECT @AutoSetting = ISNULL(AutoSetting,0)
			FROM	dbo.League WITH(NOLOCK)
			WHERE	leagueid = @leagueid
	
		IF @AutoSetting & 4 < 4  -- 100 -- setting of Fast Market
		BEGIN
			SELECT	@ErrCode = 1001017
					,@ErrMsg = 'The auto-settlement failed due to OFF setting.'
			
			RETURN
		END

		IF EXISTS (SELECT TOP 1 1 FROM @tblData WHERE bettype IN (228,229))
			SET @IsReSettledTickets = 0

		-- For bettype between 221 and 227	
		UPDATE t
			SET	BetOption = (SELECT TOP 1 byte 
							 FROM dbo.f_Set_GetByte(CASE 
														WHEN t.Position <= 44 THEN r.HomeValue 
														ELSE AwayValue 
													END, t.Position)
												)
		FROM	@tblData t
			INNER JOIN @tblResultDetail r
				ON r.ResourceId = t.ResourceId_BetOption
		WHERE	r.ResourceId NOT LIKE '22[8-9]01%'
				
		UPDATE t
		SET	ResultStatus = (SELECT TOP 1 [char] 
							 FROM dbo.f_Set_GetChar(CASE 
														WHEN t.Position <=44 THEN r.HomeValue 
														ELSE r.AwayValue 
													END, CASE WHEN t.Position <=44 THEN t.Position ELSE t.Position - 45 END)
												)
		FROM	@tblData t
			INNER JOIN @tblResultDetail r
				ON r.ResourceId = t.ResourceId
		WHERE	r.ResourceId NOT LIKE '22[8-9]00'
		-- end update for bettype between 221 and 227

		--For bettype 228
		UPDATE t
			SET BetOption = r.Value
		FROM	@tblData t
			INNER JOIN @tblResultDetail_228 r
				ON	r.ResourceId = t.ResourceId_BetOption 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22801'

		UPDATE t
			SET ResultStatus = r.Value
		FROM	@tblData t
			INNER JOIN @tblResultDetail_228 r 
				ON	r.ResourceId = t.ResourceId 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22800'
		-- end update for bettype 228

		--For bettype 229
		UPDATE t
			SET BetOption = r.Value
		FROM	@tblData t
			INNER JOIN @tblResultDetail_229 r
				ON	r.ResourceId = t.ResourceId_BetOption 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22901H'

		UPDATE t
			SET ResultStatus = r.Value
		FROM	@tblData t
			INNER JOIN @tblResultDetail_229 r 
				ON	r.ResourceId = t.ResourceId 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22900'
		-- end update for bettype 229
			
		-- No Result, UNDO, CAL (manually, auto), REFUND
		SELECT @subErrMsg = @subErrMsg + 'Bettype: ' + CAST(t.bettype AS VARCHAR) 
			+ ', Interval: ' + STUFF((SELECT ',' + CAST(Position AS VARCHAR) + '-'
						+ CASE
							WHEN ResultStatus = 3 THEN 'Undo'
							WHEN ResultStatus = 4 THEN 'Automatically Settled'
							WHEN ResultStatus = 5 THEN 'Manually Settled'
							WHEN ResultStatus = 6 THEN 'Refunded'
							WHEN ResultStatus = 7 THEN 'Refunded SDT'
							WHEN ResultStatus = 0 THEN 'No KeyedIn'
							ELSE 'Unknown Err'
						END
				FROM @tblData
				WHERE t.bettype = bettype	
					 AND (ResultStatus IN (0,3,4,5,6,7)
							OR ResultStatus IS NULL
							OR BetOption IS NULL
						)
				FOR XML PATH ('')),1,1,'')
			+ '</br>'
		FROM @tblData t
		WHERE	t.bettype IN (228, 229)
				AND (ResultStatus IN (0,3,4,5,6,7) OR t.ResultStatus IS NULL OR t.BetOption IS NULL)
		GROUP BY t.bettype

		-- No Result, UNDO, CAL (manually), REFUND
		SELECT @subErrMsg = @subErrMsg + 'Bettype: ' + CAST(t.bettype AS VARCHAR) 
			+ ', Interval: ' + STUFF((SELECT ',' + CAST(Position AS VARCHAR) + '-'
						+ CASE
							WHEN ResultStatus = 3 THEN 'Undo'
							WHEN ResultStatus = 5 THEN 'Manually Settled'
							WHEN ResultStatus = 6 THEN 'Refunded'
							WHEN ResultStatus = 7 THEN 'Refunded SDT'
							WHEN BetOption = 0 THEN 'No KeyedIn'
						END
				FROM @tblData
				WHERE t.bettype = bettype	
					 AND (ResultStatus IN (0,3,5,6,7)
						OR BetOption = 0
					)
				FOR XML PATH ('')),1,1,'')
			+ '</br>'
		FROM @tblData t
		WHERE	t.ResultStatus IN (3,5,6,7) OR t.BetOption = 0
				AND t.bettype NOT IN (228, 229)
		GROUP BY t.bettype
		
		DELETE 
		FROM @tblData
		WHERE	(ResultStatus IN (3,5,6,7) OR BetOption = 0) AND bettype NOT IN (228, 229)
		
		IF ISNULL(@subErrMsg,'') <> ''
		BEGIN
			SELECT	 @ErrCode	= 1001012
					,@ErrMsg	= 'Failed:' + @subErrMsg
			
			RETURN
		END
	END
	
	SET @Results = CAST((
					SELECT bettype '@Id'
						,(SELECT Position '@p'
								,BetOption '@r'
								,CASE WHEN r.bettype = 229 THEN 0 ELSE @IsSettleDetermined END AS '@s'
								,CASE WHEN r.bettype IN (228, 229) THEN 1 ELSE NULL END AS '@i' -- HasInjuryTime
							FROM @tblData WHERE r.bettype = bettype FOR XML PATH('r'), TYPE)
					FROM @tblData r
					GROUP BY r.bettype
					FOR XML PATH('b'), ROOT ('r'), TYPE
				) AS VARCHAR(MAX))		
	
	;WITH cteEventCounter
	AS (
		SELECT T.C.value('@Id', 'VARCHAR(20)') AS 'Id'
			,X.C.value('@Position','TINYINT') AS Position
			,X.C.value('@Result','TINYINT') AS Result
		FROM	@xmlEventCounter.nodes('/EventCounters/EventCounter') AS T(C)
			CROSS APPLY C.nodes('Item') AS X(C)
	)
	SELECT @EventCounters = CAST((SELECT   Id '@Id'
			,(	SELECT	Position AS '@p'
						,Result AS '@r'
				FROM	cteEventCounter 
				WHERE	Id = c.Id 
				FOR XML PATH('r'), TYPE)
	FROM	cteEventCounter c
	GROUP BY Id
	FOR XML PATH('e'), ROOT('r'), TYPE)  AS VARCHAR(MAX))

	EXEC dbo.NAP_Admin_Settlement_Checking @MatchId = @MatchId
		,@xmlData = @Results
		,@Action = @Action
		,@Mode = 'CAL-FM'
		,@IsAuto = @IsAuto
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
		
	IF @ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = @ErrMsg

		RETURN
	END

	SELECT	@ErrCode = 0
			,@ErrMsg = ''
			,@sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 
															+ ', @Results = ''' + CONVERT(VARCHAR(MAX), @Results) + ''''
															+ CASE 
																WHEN @EventCounters IS NULL THEN ''
																ELSE ', @EventCounters = ''' + @EventCounters + '''' 
															END
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
															+ ', @IsAuto = ' + CONVERT(NVARCHAR(50), @IsAuto)
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + ''''
															+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) 
															+ ', @IsSettleDetermined = ' + CONVERT(NVARCHAR(50), @IsSettleDetermined) 
															+ ', @ErrCode = @ErrCode OUTPUT' 
															+ ', @ErrMsg = @ErrMsg OUTPUT'
														
	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
	BEGIN
		BEGIN TRY
			EXEC sys.sp_executesql @sqlCommand
				,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode INT OUTPUT'
				,@ErrMsg = @ErrMsg OUTPUT
				,@ErrCode = @ErrCode OUTPUT
		END TRY

		BEGIN CATCH
			SELECT	@ErrMsg	= @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
					,@ErrCode= @ErrCode
				
			RETURN
		END CATCH
	END
	ELSE
	BEGIN
		INSERT INTO dbo.Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand)
		SELECT @MatchId, @matchcode, 0, @leagueid, @sporttype, @AdminId, @IP, 'CAL-FM', @sqlCommand
	END
	
	IF @subErrMsg <> ''
	BEGIN
		SELECT	 @ErrCode	= 1001012
				,@ErrMsg	= 'Failed:' + @subErrMsg 
	END
	
END
GO
