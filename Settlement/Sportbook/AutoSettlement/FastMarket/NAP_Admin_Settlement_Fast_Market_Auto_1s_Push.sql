/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s_Push] @MatchId INT
	,@Action				VARCHAR(20)
	,@Results				VARCHAR(MAX)
	,@EventCounters			VARCHAR(MAX) = NULL

	,@IsAuto				BIT			= 0
	,@AdminId				INT			= 0
	,@Ip					VARCHAR(20)	= ''
	,@IsReSettledTickets	BIT			= 1

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
			- 20200928@Helen: Implement New Bettype 288 Time Machine Over/Under [Redmine:#142001]
			
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
			,@procName		NVARCHAR(128)
			,@xmlData		XML
			,@rowcount		INT = 0
			,@subErrMsg		VARCHAR(MAX) = ''
			,@AutoSetting	TINYINT
			,@xmlEventCounter	XML
			,@ResouceResult_22801 VARCHAR(20) = '22801'
			,@ResouceResultStatus_22800 VARCHAR(20) = '22800'
			
	DECLARE @tblData TABLE (
		bettype					SMALLINT
		,ResourceId				VARCHAR(20)
		,ResourceId_BetOption	VARCHAR(20)
		,Position				TINYINT
		,BetOption				TINYINT
		,ResultStatus			TINYINT
	)
	
	DECLARE @tblResultDetail TABLE (
		ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
	)
	
	-- new bettype 228
	DECLARE @tblResultDetail_228 TABLE (ResourceId VARCHAR(20),ResourceId_BetOption VARCHAR(20),Position TINYINT ,Value TINYINT)
	DECLARE @BetOption1st VARCHAR(50), @ResultStatus1st VARCHAR(50),@BetOption2nd VARCHAR(50),@ResultStatus2nd VARCHAR(50)
	
	SELECT	@matchcode = m.matchcode
			,@sporttype = m.sporttype
			,@leagueid = m.leagueid
			,@AutoSetting = m.AutoSetting
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 1001001
				,@ErrMsg = 'Match does not exist!'
				
		RETURN
	END

	IF @Action IN ('CAL', 'REFUND') AND @IsAuto = 0
	BEGIN
		DECLARE @fixedErrMsg VARCHAR(300) = '' --cannot pass varchar(max) via linked server 

		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= @action
			,@IsEarly 	= 1
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @fixedErrMsg	OUTPUT

		IF @ErrCode > 0
		BEGIN
			SET @ErrMsg = @fixedErrMsg
			RETURN
		END
	END

	IF EXISTS (SELECT	TOP 1 1 
				FROM	dbo.Single_Calculate_Queue s WITH (NOLOCK)
				WHERE	s.matchid = @matchid 
						AND s.IsCalculating IN (0, 1)) 
		OR EXISTS (SELECT	TOP 1 1
					FROM	dbo.Parlay_Calculate_Queue p WITH (NOLOCK)
					WHERE	p.matchid = @matchid 
							AND p.IsCalculating IN (0, 1)
				)
	BEGIN
		SELECT	@ErrCode = 1001003
				,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		
		RETURN
	END
	
			
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
	INSERT INTO @tblData (bettype, ResourceId, ResourceId_BetOption, Position, BetOption)
	SELECT	bettype
			,CAST(BetType * 100 AS VARCHAR(20)) AS ResourceId
			,CAST(BetType * 100 + 1 AS VARCHAR(20)) AS ResourceId_BetOption
			,Position
			,BetOption
	FROM TmpData
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )
	
	SET @rowcount = @@rowcount
	
	INSERT INTO @tblResultDetail (ResourceId, HomeValue, AwayValue)
	SELECT	ResourceId, HomeValue, AwayValue
	FROM	DBPRO.bodb02.dbo.ResultDetail r WITH (ROWLOCK)
	WHERE	matchid = @matchid
	
	IF @IsAuto = 1
	BEGIN		
		IF EXISTS (SELECT TOP 1 1 FROM @tblData WHERE bettype NOT IN (SELECT bettype FROM dbo.f_Set_GetGroupBettypes() WHERE GroupId = 9)) -- FM
		BEGIN
			SELECT	 @ErrCode	= 1001016
					,@ErrMsg	= 'There are some bettypes not belong to Fast Market' 

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
		-- For bettype between 221 and 227	
		UPDATE t
			SET	BetOption = (SELECT TOP 1 byte 
							 FROM dbo.f_Set_GetByte(CASE 
														WHEN t.Position <=44 THEN r.HomeValue 
														ELSE AwayValue 
													END, t.Position)
												)
		FROM	@tblData t
			INNER JOIN @tblResultDetail r
				ON r.ResourceId = t.ResourceId_BetOption
		WHERE r.ResourceId NOT IN (@ResouceResult_22801)		
				
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
		WHERE r.ResourceId NOT IN (@ResouceResultStatus_22800)						
		
		-- For bettype 228
		SELECT @BetOption1st = HomeValue, @BetOption2nd = AwayValue
		FROM @tblResultDetail
		WHERE ResourceId = @ResouceResult_22801
		
		SELECT @ResultStatus1st = HomeValue, @ResultStatus2nd = AwayValue
		FROM @tblResultDetail
		WHERE ResourceId = @ResouceResultStatus_22800
		
		IF @BetOption1st IS NOT NULL OR @BetOption2nd IS NOT NULL OR @ResultStatus1st IS NOT NULL OR @ResultStatus2nd IS NOT NULL
		BEGIN
			INSERT INTO @tblResultDetail_228 (ResourceId, Position, Value)
			SELECT	@ResouceResultStatus_22800, f.pos AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@ResultStatus1st) f
			WHERE	f.pos < 46 AND ISNULL(@ResultStatus1st,'') <> ''
			UNION ALL
			SELECT	@ResouceResultStatus_22800, f.pos + 46 AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@ResultStatus2nd) f
			WHERE	f.pos < 45 AND ISNULL(@ResultStatus2nd,'') <> ''
			UNION ALL
			SELECT	@ResouceResult_22801, f.pos AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@BetOption1st) f
			WHERE	f.pos < 46 AND ISNULL(@BetOption1st,'') <> ''
			UNION ALL
			SELECT	@ResouceResult_22801, f.pos + 46 AS Position, f.ResultStatus AS Value
			FROM	dbo.f_Set_GetChars(@BetOption2nd) f
			WHERE	f.pos < 45 AND ISNULL(@BetOption2nd,'') <> ''
			
		END	
		
		-- Update BetOption and ResultStatus for bettype 228
		UPDATE t
			SET BetOption = r.Value
		FROM	@tblData t
			INNER JOIN @tblResultDetail_228 r
				ON r.ResourceId = t.ResourceId_BetOption AND t.Position = r.Position

		UPDATE t
			SET ResultStatus = r.Value
		FROM	@tblData t
			INNER JOIN @tblResultDetail_228 r ON r.ResourceId = t.ResourceId AND t.Position = r.Position
			
		-- No Result, UNDO, CAL (manually), REFUND
		SELECT @subErrMsg = @subErrMsg + 'Bettype: ' + CAST(t.bettype AS VARCHAR) 
			+ ', Interval: ' + STUFF((SELECT ',' + CAST(Position AS VARCHAR) + '-'
						+ CASE
							WHEN ResultStatus = 3 THEN 'Undo'
							WHEN ResultStatus = 5 THEN 'Manually Settled'
							WHEN ResultStatus = 6 THEN 'Refunded'
							WHEN BetOption = 0 THEN 'No KeyedIn'
						END
				FROM @tblData
				WHERE t.bettype = bettype	
					 AND (ResultStatus IN (0,3,5,6)
						OR BetOption = 0
					)
				FOR XML PATH ('')),1,1,'')
			+ '</br>'
		FROM @tblData t
		WHERE	t.ResultStatus IN (3,5,6) OR t.BetOption = 0
		GROUP BY t.bettype
		
		DELETE 
		FROM @tblData
		WHERE	ResultStatus IN (3,5,6) OR BetOption = 0		
		
		IF @@rowcount = @rowcount
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
			,@procName = OBJECT_NAME(@@PROCID)
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