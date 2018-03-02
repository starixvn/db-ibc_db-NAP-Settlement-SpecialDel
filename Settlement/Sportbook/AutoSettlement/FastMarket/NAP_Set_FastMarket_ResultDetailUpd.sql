/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId INT
	,@Results		VARCHAR(MAX)
	,@EventCounters	VARCHAR(MAX)	= NULL
	,@Action		VARCHAR(20)		= 'CAL'
	,@IsAuto		BIT				= 0
	,@AdminId		INT				= 0
AS
/*
	Created: 20160427@Patrick
	Task: Update result of Fast market 
	DB: DBPRO.BODB02
	Original:
	
	Revisions:
		- 20170113@Kathy: Enhancement for Fast Market [Redmine:#69951]
		- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]

	Param's Explanation:
		- @Results: 
				'<r>
					<b Id="221">
						<r p="0" r="36" />
						<r p="1" r="1" />
						<r p="2" r="4" />
					</b>
				</r>'
		- @EventCounters: 
				'<r>
					<e Id="221CNT02">
						<r p="0" r="2" />
						<r p="1" r="1" />
					</e>
					<e Id="221CNT03">
						<r p="0" r="4" />
						<r p="1" r="2" />
					</e>
					...
				</r>'
			
		
*/
BEGIN	
	SET NOCOUNT ON
	-- In this sesion, Home value means the result in 1st of match, Away value means the result in 2nd of match (not home/away team)
	DECLARE @xmlData			XML
			,@ResultStatus		TINYINT
			,@xmlEventCounter	XML
			
	DECLARE @tblData TABLE (
		ResourceId				VARCHAR(20) -- 22X00
		,ResourceId_BetOption	VARCHAR(20) -- 22X01
		,position				TINYINT
		,betOption				TINYINT
	)

	DECLARE @tblDataEventCounter TABLE(
		ResourceId	VARCHAR(20)
		,Position	TINYINT
		,Result		TINYINT
	)
	
	DECLARE @tblPosition TABLE(
		ResourceId	VARCHAR(20)
		,strPosHome	VARCHAR(1000)
		,strPosAway VARCHAR(1000)
	)

	SELECT	@xmlData = CONVERT(XML, @Results)
			,@xmlEventCounter = CONVERT(XML, @EventCounters)

	SET @ResultStatus = CASE 
							WHEN @Action = 'CAL' AND @IsAuto = 0 THEN 5
							WHEN @Action = 'CAL' AND @IsAuto = 1 THEN 4
							WHEN @Action = 'REFUND' THEN 6
							WHEN @Action = 'UNDO' THEN 3
							ELSE 0
						END	
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
			,X.C.value('@r','TINYINT') as BetOption
		FROM @xmlData.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
	)
	INSERT INTO @tblData (ResourceId, ResourceId_BetOption, position, betOption)
	SELECT	CAST(bettype * 100 AS VARCHAR(20)) ResourceId -- 22X00
			,CAST(bettype * 100 + 1 AS VARCHAR(20)) ResourceId -- 22X01
			,Position
			,ISNULL(betOption,0)
	FROM	TmpData
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )

	INSERT INTO @tblDataEventCounter (ResourceId, Position, Result)
	SELECT	T.C.value('@Id', 'VARCHAR(20)') AS ResourceId
			,X.C.value('@p','TINYINT') AS Position
			,X.C.value('@r','TINYINT') AS Result
	FROM	@xmlEventCounter.nodes('/r/e') AS T(C)
		CROSS APPLY C.nodes('r') AS X(C)

	-- 22X00
	BEGIN
		-- result status
		INSERT INTO dbo.ResultDetail (MatchId, ResourceId, HomeValue, AwayValue, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
		SELECT	@matchId, t.ResourceId, REPLICATE('0', 50), REPLICATE('0', 50), @AdminId, GETDATE(), @AdminId, GETDATE()
		FROM	@tblData t
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail WITH(NOLOCK) WHERE MatchId = @matchid AND t.ResourceId = ResourceId)
		GROUP BY t.ResourceId
	
		INSERT INTO @tblPosition (ResourceId, strPosHome, strPosAway)
		SELECT	t.ResourceId
				,STUFF ((SELECT	',' + CAST(position AS VARCHAR(200)) + '|' + CAST(@ResultStatus AS VARCHAR(1))
							FROM	@tblData	
							WHERE	ResourceId = t.ResourceId 
									AND position <=44
							FOR XML PATH ('')
					),1,1,'') strPosHome
				,STUFF ((SELECT	',' + CAST(position - 45 AS VARCHAR(200)) + '|' + CAST(@ResultStatus AS VARCHAR(1))
							FROM	@tblData	
							WHERE	ResourceId = t.ResourceId
									AND position >=45
							FOR XML PATH ('')
					),1,1,'') strPosAway
		FROM	dbo.ResultDetail t WITH(ROWLOCK)
		WHERE	t.MatchId = @matchid
				AND t.ResourceId LIKE '22_00'
	
		/* 
			(ResouceId: 22X00) update settlement status of earch bettype 
				- each char represent the resultStatus of the statuss (digits [0-6]).
				- the index of the char means the xx min resultStatus
		*/
		UPDATE	r 
			SET	HomeValue = CASE WHEN ISNULL(p.strPosHome,'') <> '' THEN dbo.f_Set_SetChars(r.HomeValue, p.strPosHome) ELSE r.HomeValue END 
				,AwayValue = CASE WHEN ISNULL(p.strPosAway,'') <> '' THEN dbo.f_Set_SetChars(r.AwayValue, p.strPosAway) ELSE r.AwayValue END
				,LastModifyBy = @AdminId
				,LastModifyDate = GETDATE()
		FROM	dbo.ResultDetail r  WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tblPosition p 
				ON	r.MatchId = @matchid
					AND r.ResourceId = p.ResourceId
		WHERE	r.ResourceId LIKE '22_00'
	END

	IF @IsAuto = 0
	BEGIN
		-- 221CNTXX
		BEGIN
			-- Insert initial eventcounter if missing
			INSERT INTO dbo.ResultDetail (MatchId, ResourceId, HomeValue, AwayValue, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
			SELECT	@MatchId, t.ResourceId, REPLICATE('0',50), REPLICATE('0', 50), @AdminId, GETDATE(), @AdminId, GETDATE()
			FROM	@tblDataEventCounter t
			WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail WITH(NOLOCK) WHERE MatchId = @MatchId AND t.ResourceId = ResourceId)
			GROUP BY t.ResourceId
		
			IF EXISTS (SELECT TOP 1 1 FROM @tblDataEventCounter)
			BEGIN
				INSERT INTO @tblPosition (ResourceId, strPosHome, strPosAway)
				SELECT	t.ResourceId
						,STUFF ((SELECT	',' + CAST(position AS VARCHAR(200)) + '|' + CAST(Result AS VARCHAR(1))
									FROM	@tblDataEventCounter	
									WHERE	ResourceId = t.ResourceId 
											AND position <=44
									FOR XML PATH ('')
							),1,1,'') strPosHome
						,STUFF ((SELECT	',' + CAST(position - 45 AS VARCHAR(200)) + '|' + CAST(Result AS VARCHAR(1))
									FROM	@tblDataEventCounter	
									WHERE	ResourceId = t.ResourceId
											AND position >=45
									FOR XML PATH ('')
							),1,1,'') strPosAway
				FROM	dbo.ResultDetail t WITH(ROWLOCK)
				WHERE	t.MatchId = @matchid
						AND t.ResourceId LIKE '221CNT__'

				/*
					(ResouceId: 221CNTXX) Event counter of each interval of bettype
						- each char represent the resultStatus of the statuss (digits [0-6]).
						- the index of the char means the xx min resultStatus
				*/
				UPDATE	r 
					SET	HomeValue = CASE WHEN ISNULL(p.strPosHome,'') <> '' THEN dbo.f_Set_SetChars(r.HomeValue, p.strPosHome) ELSE r.HomeValue END 
						,AwayValue = CASE WHEN ISNULL(p.strPosAway,'') <> '' THEN dbo.f_Set_SetChars(r.AwayValue, p.strPosAway) ELSE r.AwayValue END
						,LastModifyBy = @AdminId
						,LastModifyDate = GETDATE()
				FROM	dbo.ResultDetail r  WITH(ROWLOCK, UPDLOCK)
					INNER JOIN @tblPosition p 
						ON	r.MatchId = @matchid
							AND r.ResourceId = p.ResourceId
				WHERE	r.ResourceId LIKE '221CNT__'	
			END
		END

		-- 22X01
		IF @Action IN ('CAL', 'UNDO') 
		BEGIN
			-- betoption
			INSERT INTO dbo.ResultDetail (MatchId, ResourceId, HomeValue, AwayValue, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
			SELECT	@matchId, t.ResourceId_BetOption, REPLICATE(CHAR('0'), 50), REPLICATE(CHAR('0'), 50), @AdminId, GETDATE(), @AdminId, GETDATE()
			FROM	@tblData t
			WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail WITH(NOLOCK) WHERE MatchId = @matchid AND t.ResourceId_BetOption = ResourceId)
			GROUP BY t.ResourceId_BetOption

			INSERT INTO @tblPosition (ResourceId, strPosHome, strPosAway)
			SELECT	t.ResourceId
					,STUFF ((SELECT	',' + CAST(position AS VARCHAR(200)) + '|' + CAST(betOption AS VARCHAR(200))
								FROM	@tblData	
								WHERE	ResourceId_BetOption = t.ResourceId
										AND position <=44
								FOR XML PATH ('')
						),1,1,'') strBetOptionHome
					,STUFF ((SELECT	',' + CAST(position - 45 AS VARCHAR(200)) + '|' + CAST(betOption AS VARCHAR(200))
								FROM	@tblData	
								WHERE	ResourceId_BetOption = t.ResourceId
										AND position >=45
								FOR XML PATH ('')
						),1,1,'') strBetOptionAway
			FROM	dbo.ResultDetail t WITH(ROWLOCK)
			WHERE	t.MatchId = @matchid
					AND t.ResourceId LIKE '22_01'

			/*
				(ResouceId: 22X01) Result of each interval of bettype
					- each char in ascii represent the result of the bet options (digits [0-6]).
					- the index of the char means the xx min result
			*/
			UPDATE r 
				SET HomeValue = CASE WHEN ISNULL(p.strPosHome,'') <> '' THEN dbo.f_Set_SetBytes(r.HomeValue, p.strPosHome) ELSE r.HomeValue END
					,AwayValue = CASE WHEN ISNULL(p.strPosAway,'') <> '' THEN dbo.f_Set_SetBytes(r.AwayValue, p.strPosAway) ELSE r.AwayValue END
					,LastModifyBy = @AdminId
					,LastModifyDate = GETDATE()
			FROM	dbo.ResultDetail r WITH(ROWLOCK, UPDLOCK)
				INNER JOIN @tblPosition p 
					ON	r.MatchId = @matchid
						AND r.ResourceId = p.ResourceId
			WHERE	r.ResourceId LIKE '22_01'	
		END
	END	
END

GO