/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" IsNested="1"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_ValidationFM_Event  
(
	 @matchid		INT = 0
	,@Action		VARCHAR(10)
	,@IsAuto		BIT = 0
	,@SelectedResources	VARCHAR(MAX) = NULL
	,@AutoSetting		TINYINT = 0
	,@ErrCode		INT		= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation Fastmarket [Redmine:#175251]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xmlResourceResult	XML
			,@IsFailed			BIT = 0
			,@subErrMsg		VARCHAR(MAX) = ''

			-- bettype 228
			,@BetOption1st	VARCHAR(50)
			,@BetOption2nd	VARCHAR(50)
			,@ResultStatus1st VARCHAR(50)			
			,@ResultStatus2nd VARCHAR(50)
			,@minSelectedPosition TINYINT
			,@maxSelectedPosition TINYINT

			-- bettype 229
			,@BetOptionHome_1st VARCHAR(50)
			,@BetOptionHome_2nd VARCHAR(50)
			,@BetOptionAway_1st VARCHAR(50)
			,@BetOptionAway_2nd VARCHAR(50)

	DECLARE @tblFM_Data TABLE (
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

	SET @xmlResourceResult = CONVERT(XML, @SelectedResources)
	
	INSERT INTO @tblResultDetail (ResourceId, HomeValue, AwayValue, OtherInfo)
	SELECT	ResourceId, HomeValue, AwayValue, OtherInfo
	FROM	dbo.ResultDetail r WITH (ROWLOCK)
	WHERE	matchid = @matchid

	INSERT INTO @tblSpecialResultDetail (ResourceId, HomeValue, AwayValue, OtherInfo)
	SELECT	ResourceId, HomeValue, AwayValue, OtherInfo
	FROM	@tblResultDetail
	WHERE	ResourceId LIKE '221WB__' OR ResourceId = '221SUS'

	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@Position','TINYINT') as Position
			,X.C.value('@Result','TINYINT') as BetOption
		FROM @xmlResourceResult.nodes('/BetTypes/BetType') AS T(C)
			CROSS APPLY
				C.nodes('Item') AS X(C)
	)
	INSERT INTO @tblFM_Data (bettype, ResourceId, ResourceId_BetOption, Position, BetOption)
	SELECT	bettype
			,CAST(BetType * 100 AS VARCHAR(20)) AS ResourceId
			,CASE WHEN bettype = 229 THEN '22901H' ELSE CAST(BetType * 100 + 1 AS VARCHAR(20)) END AS ResourceId_BetOption
			,Position
			,BetOption
	FROM TmpData t
	OPTION ( OPTIMIZE FOR ( @xmlResourceResult = NULL ) )

	--start: Check for 228
	IF EXISTS (SELECT TOP 1 1 FROM @tblFM_Data WHERE bettype = 228)
	BEGIN
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
		FROM	@tblFM_Data
		WHERE	bettype = 228

		IF @Action = 'CAL'
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
						FROM	@tblResultDetail_228 t
						WHERE	t.ResourceId = '22800'
								AND 1 = CASE
											WHEN t.Value NOT IN (4,5) AND t.Position < @minSelectedPosition THEN 1 -- previous interval
											WHEN t.Position BETWEEN @minSelectedPosition AND @maxSelectedPosition -- between selected intervals
												AND NOT EXISTS (SELECT TOP 1 1 FROM @tblFM_Data d WHERE t.Position = d.Position) THEN 1
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
									AND NOT EXISTS (SELECT TOP 1 1 FROM @tblFM_Data d WHERE d.Position = t.Position) THEN 1
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
	--End checking for 228

	--Start: Checking for 229
	IF EXISTS (SELECT TOP 1 1 FROM @tblFM_Data WHERE bettype = 229)
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
		FROM	@tblFM_Data
		WHERE	bettype = 229

		IF @Action = 'CAL'
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
						FROM	@tblResultDetail_229 t
						WHERE	t.ResourceId = '22900'
								AND 1 = CASE
											WHEN t.Value NOT IN (4,5) AND t.Position < @minSelectedPosition THEN 1 -- previous interval
											WHEN t.Position BETWEEN @minSelectedPosition AND @maxSelectedPosition -- between selected intervals
												AND NOT EXISTS (SELECT TOP 1 1 FROM @tblFM_Data d WHERE t.Position = d.Position) THEN 1
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
									AND NOT EXISTS (SELECT TOP 1 1 FROM @tblFM_Data d WHERE d.Position = t.Position) THEN 1
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
	--/End: Checking for 229

	IF @Action = 'CAL'
	BEGIN
		-- Compare selected intervals with each existing WB session
		IF EXISTS (SELECT TOP 1 1 FROM @tblFM_Data WHERE bettype BETWEEN 221 AND 227) --222,224,227
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
			FROM	@tblFM_Data d
				CROSS APPLY (	SELECT CASE
										WHEN d.bettype IN (222, 224, 227) THEN 4
										ELSE 0
									END AS mins				
							)m
				CROSS APPLY (	SELECT TOP 1 1 AS IsOverlap                                                                                                                     
								FROM	cteWaterBreak wb
								WHERE	d.Position BETWEEN wb.startWB - m.mins AND wb.endWB 
							) wb

			IF @ErrCode <> 0
				RETURN
		END
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
	FROM	@tblFM_Data d
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
	BEGIN
		RETURN
	END

	IF @IsAuto = 1
	BEGIN		
		IF EXISTS (SELECT TOP 1 1 FROM @tblFM_Data WHERE bettype NOT IN (SELECT bettype FROM dbo.f_Set_GetGroupBettypes() WHERE GroupId = 9)) -- FM
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
														WHEN t.Position <= 44 THEN r.HomeValue 
														ELSE AwayValue 
													END, t.Position)
												)
		FROM	@tblFM_Data t
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
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail r
				ON r.ResourceId = t.ResourceId
		WHERE	r.ResourceId NOT LIKE '22[8-9]00'
		-- end update for bettype between 221 and 227

		--For bettype 228
		UPDATE t
			SET BetOption = r.Value
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail_228 r
				ON	r.ResourceId = t.ResourceId_BetOption 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22801'

		UPDATE t
			SET ResultStatus = r.Value
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail_228 r 
				ON	r.ResourceId = t.ResourceId 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22800'
		-- end update for bettype 228

		--For bettype 229
		UPDATE t
			SET BetOption = r.Value
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail_229 r
				ON	r.ResourceId = t.ResourceId_BetOption 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22901H'

		UPDATE t
			SET ResultStatus = r.Value
		FROM	@tblFM_Data t
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
				FROM @tblFM_Data
				WHERE t.bettype = bettype	
					 AND (ResultStatus IN (0,3,4,5,6,7)
							OR ResultStatus IS NULL
							OR BetOption IS NULL
						)
				FOR XML PATH ('')),1,1,'')
			+ '</br>'
		FROM @tblFM_Data t
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
				FROM @tblFM_Data
				WHERE t.bettype = bettype	
					 AND (ResultStatus IN (0,3,5,6,7)
						OR BetOption = 0
					)
				FOR XML PATH ('')),1,1,'')
			+ '</br>'
		FROM @tblFM_Data t
		WHERE	t.ResultStatus IN (3,5,6,7) OR t.BetOption = 0
				AND t.bettype NOT IN (228, 229)
		GROUP BY t.bettype
		
		IF ISNULL(@subErrMsg,'') <> ''
		BEGIN
			SELECT	 @ErrCode	= 1001012
					,@ErrMsg	= 'Failed:' + @subErrMsg		
			RETURN
		END
	
	END

END
GO