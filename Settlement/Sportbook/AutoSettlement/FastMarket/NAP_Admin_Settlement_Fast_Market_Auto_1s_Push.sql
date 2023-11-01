/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s_Push] @MatchId INT
	,@Action				VARCHAR(20)
	,@Results				VARCHAR(MAX)
	,@OldResults			VARCHAR(MAX) = NULL
	,@EventCounters			VARCHAR(MAX) = NULL
	,@IsAuto				BIT			= 0
	,@AdminId				INT			= 0
	,@Ip					VARCHAR(20)	= ''
	,@IsReSettledTickets	BIT			= 1
	,@IsSettleDetermined	BIT			= 0
	,@BroadcastSessionId	VARCHAR(50) = NULL
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
			- 20230817@Kathy: Write log [Redmine:#192311]
			
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
			,@xmlEventCounter	XML
			
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
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId
		
	SET @xmlData = CONVERT(XML, @Results)
	SET @xmlEventCounter = CONVERT(XML, @EventCounters)
	
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

	IF @IsAuto = 1
	BEGIN		
		INSERT INTO @tblResultDetail (ResourceId, HomeValue, AwayValue, OtherInfo)
		SELECT	ResourceId, HomeValue, AwayValue, OtherInfo
		FROM	DBPRO.bodb02.dbo.ResultDetail r WITH (ROWLOCK)
		WHERE	matchid = @matchid

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
		
		DELETE 
		FROM @tblData
		WHERE	(ResultStatus IN (3,5,6,7) OR BetOption = 0) AND bettype NOT IN (228, 229)
	
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


	SELECT	@sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 
															+ ', @Results = ''' + CONVERT(VARCHAR(MAX), @Results) + ''''
															+ CASE 
																WHEN @OldResults IS NULL THEN ''
																ELSE ', @OldResults = ''' + CONVERT(VARCHAR(MAX), @OldResults) + ''''
															END
															+ CASE 
																WHEN @EventCounters IS NULL THEN ''
																ELSE ', @EventCounters = ''' + @EventCounters + '''' 
															END
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
															+ ', @IsAuto = ' + CONVERT(NVARCHAR(50), @IsAuto)
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + ''''
															+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) 
															+ ', @IsSettleDetermined = ' + CONVERT(NVARCHAR(50), @IsSettleDetermined) 
															+  CASE WHEN @BroadcastSessionId IS NOT NULL 
																	THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
																	ELSE '' END +
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
		INSERT INTO dbo.Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand, BroadcastSessionId)
		SELECT @MatchId, @matchcode, 0, @leagueid, @sporttype, @AdminId, @IP, 'CAL-FM', @sqlCommand, @BroadcastSessionId
	END
	
END
GO
