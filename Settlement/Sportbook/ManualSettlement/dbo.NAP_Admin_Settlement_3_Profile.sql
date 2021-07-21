/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Profile] 
	@matchid INT
    ,@action VARCHAR(6) = 'CAL'
	,@ActionID	INT = 0
	,@creator INT = 0
	,@ResourceResult VARCHAR(MAX) = NULL
	,@IsReSettledTickets BIT = 1
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
AS
/*
    Created: 20201123@Kathy
    Task : Covered SP for settlement
    DB: DBTXN/bodb02

    Revisions:
	   - 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
	   - 20210326@Louisa: Negative balance [Redmine:#152345]
	   - 20210621@Kathy: Prevent lock escalation [Redmine:#157286]
	   - 20210730@Kathy: Apply Settlement by Profile for minor bettype of soccer [Redmine:#158477]

	Param's Explanation:
	@ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

*/
BEGIN
    SET NOCOUNT ON;
	
	DECLARE @fth			INT
			,@fta			INT
			,@hth			INT
			,@hta			INT
			,@goalrecord	NVARCHAR(50)
			,@sporttype		SMALLINT
			,@isRefundHT	BIT
			,@batchNo		INT 
			,@rowcount		INT
			,@rowcountDummy INT
			,@threshold		INT

			,@handle		INT
			
			,@strTransIds	VARCHAR(MAX) 
			,@oddstype		TINYINT
			,@IsMarked		BIT
			,@modds			SMALLMONEY
			,@DummyResourceIds		VARCHAR(MAX) 
			,@DummyResourceResults VARCHAR(MAX)
			,@IsExistW BIT
			,@IsExistD BIT 
			,@IsExistL BIT
			,@IsExistSpecialBettype TINYINT

			,@filterby INT 
			,@minrowid INT 
			,@maxrowid INT 
			,@sqlCommand VARCHAR(MAX)
			,@mode VARCHAR(15)
			,@strBettypes VARCHAR(MAX)
			,@ChildMatchType		TINYINT
			,@xmlResourceResult		XML
			
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange

	SELECT	@batchNo = 2000
			,@threshold = 4500
			,@DummyResourceIds = ''
			,@DummyResourceResults = ''
			,@rowcountDummy = 0

			,@strTransIds = ''
			,@oddstype = 0
			,@IsMarked = 0
			,@modds = 0
			
			,@ErrCode = 0
			,@ErrMsg = ''
			,@IsExistW  = 1
			,@IsExistD  = 1
			,@IsExistL = 1
			,@IsExistSpecialBettype = 0

		
			,@filterby = 0
			,@minrowid = 0
			,@maxrowid = 0	
			,@sqlCommand = ''
			,@mode = 'profile-major'
			,@strBettypes = ''
			,@xmlResourceResult = CAST(@ResourceResult AS XML)

    SELECT	@fth = FinalHomeScore
			,@fta = FinalAwayScore
			,@hth = HTHomeScore
			,@hta = HTAwayScore
			,@sporttype = sporttype
			,@goalrecord = goalrecord
			,@isRefundHT = CASE WHEN betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
			,@ChildMatchType = ChildMatchType
    FROM	 DBPRO.bodb02.dbo.match WITH (NOLOCK) 
    WHERE	matchid = @matchid
    
	DECLARE @tmpResources TABLE(
		ResourceID VARCHAR(20)
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
	)
	DECLARE @tmpFilter TABLE(
		filterBy INT
		,minrowid INT
		,maxrowid INT
		,modds SMALLMONEY
		,isFinished BIT DEFAULT(0)
	)
	
	DECLARE @tmpGoalBettypes TABLE (bettype SMALLINT)

	CREATE TABLE #tmpSelectedRID (
		ResourceID		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,BetType		SMALLINT
		,BetID			BIGINT
		,pfID			SMALLINT
		,OddsType		SMALLINT
		,PRIMARY KEY (BetType,BetID)
	)	

	CREATE TABLE #tmpTotalTransId (
		TransId BIGINT PRIMARY KEY
		,modds SMALLMONEY
		,oddstype TINYINT
		,isMarked BIT
		,betdaqid BIGINT
		,bettype SMALLINT
		,hdp1 SMALLMONEY
		,StatusId TINYINT
	)

	CREATE TABLE #tmpBatchTransId
	(
		rowid INT IDENTITY(1,1) PRIMARY KEY
		,transid BIGINT
		,modds SMALLMONEY
		,filterBy INT
	)

	CREATE TABLE #tmpReferTransId (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tmpDummyTicket -- cashout: 901-> 903, 911; bettrade: 901 -> 903
	(
		transid BIGINT PRIMARY KEY
		,custid INT
		,bettype SMALLINT
	)

    ;WITH cteGoalResource
    AS
    (
        SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
                ,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
                ,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
                ,T.C.value('@SettlementStatusId', 'TINYINT') AS SettlementStatusId
        FROM    @xmlResourceResult.nodes('/Results/Resource') AS T(C)
    )
	,cteResource
	AS
	(
		SELECT	CAST('01' AS VARCHAR(20)) AS ResourceID
				,CAST( @hth AS VARCHAR(50)) AS HomeValue
				,CAST( @hta AS VARCHAR(50)) AS AwayValue
		WHERE	@action IN ('CAL', 'CAL-HT')
		UNION ALL
		SELECT 	CAST('00' AS VARCHAR(20)) AS ResourceID
				,CAST( @fth AS VARCHAR(50)) AS HomeValue
				,CAST( @fta AS VARCHAR(50)) AS AwayValue
		WHERE	@action IN ('CAL', 'CAL-FT')
		UNION ALL
		SELECT  ResourceId, HomeValue, AwayValue
		FROM	cteGoalResource
		WHERE   ResourceID IS NOT NULL
				AND SettlementStatusId = 4
	)
	INSERT INTO @tmpResources (ResourceID, HomeValue, AwayValue)
	SELECT	ResourceID, HomeValue, AwayValue
	FROM	cteResource

	-- insert dummy resouceid
	-----------------------------------------add more info-----------------------------------------
	SELECT	@DummyResourceIds = @DummyResourceIds + s.ResourceID + ','
	FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
		INNER JOIN @tmpResources t
			ON s.RefResourceId = t.ResourceID
	WHERE	s.SportType = @sportType
			AND s.SettleType = 'MNL'
			AND s.RefResourceId IS NOT NULL

	IF @DummyResourceIds <> ''
	BEGIN
		EXEC dbo.NAP_Set_DummyResourceResult
			@MatchID = @MatchID
			,@sportType = @sportType
			,@DummyResourceIds = @DummyResourceIds
			,@DummyResourceResults = @DummyResourceResults OUTPUT

		EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
		INSERT INTO @tmpResources(ResourceID, HomeValue, AwayValue)
		SELECT Id, Home, Away
		FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
															,Home VARCHAR(50)
															,Away VARCHAR(50)
											) AS tbl
		EXEC sp_xml_removedocument @handle
	END

	-- insert selectedRid
	INSERT INTO #tmpSelectedRID(
		ResourceID
		,HomeValue
		,AwayValue
		,BetType
		,BetID
		,pfID
		,OddsType
	)
	SELECT DISTINCT tbl.ResourceID
			,tbl.HomeValue
			,tbl.AwayValue
			,sp.BetType, sp.BetID, sp.pfID
			, sp.OddsType
	FROM	@tmpResources tbl
		INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
			ON	sp.ResourceID = tbl.ResourceID
		INNER JOIN dbo.f_Set_GetGroupBettypes() AS f
			ON	sp.bettype = f.BetType
	WHERE	sp.SportType = @SportType
			AND 1 = CASE	
						WHEN @action IN ('CAL', 'CAL-FT') AND @isRefundHT = 1 AND Is3x30 = 1 AND GroupId = 2 THEN 0 
						ELSE 1
					END
			AND SettleType = 'MNL'
			AND pfID > 0
	
	SELECT	@strBettypes = @strBettypes + CAST(bettype AS VARCHAR) + ','
	FROM	#tmpSelectedRID
	GROUP BY bettype

	INSERT INTO #tmpTotalTransId (TransId, modds, oddstype, isMarked, betdaqid, bettype, hdp1, StatusId)
	SELECT b.transid
		,CASE WHEN sr.pfID = 468 THEN NULL ELSE  m.modds END		
		,ISNULL(sr.OddsType,0) AS oddstype
		,CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS isMarked
		,b.betdaqid
		,b.bettype
		,b.hdp1
		,b.statusID
	FROM dbo.bettrans b WITH (NOLOCK)
		OUTER APPLY (
						SELECT TOP (1) mt.TransId
						FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						WHERE	mt.TransId = b.transId
		) mt
	  	INNER JOIN #tmpSelectedRID sr
	  		ON sr.BetType = b.bettype
	  	CROSS APPLY dbo.f_Set_Calculate_modds_major(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, b.betid) m
	WHERE	b.matchid = @MatchId
	  		AND b.statusID NOT IN (101)
			AND 1 = CASE 
						WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
						WHEN @IsReSettledTickets = 1 THEN 1
						ELSE 0
					END		

	IF @ChildMatchType = 204 AND @Action IN ('CAL', 'CAL-FT')
	BEGIN
		DECLARE @CornerResultString VARCHAR(50)
				,@Position				TINYINT
				,@HomeRaceTo			TINYINT
				,@AwayRaceTo			TINYINT
				,@LenResultString		TINYINT
				,@hdp					VARCHAR(5) = ''
				,@Index_Round_tmp		TINYINT = 0
				,@Index_Round			TINYINT = 1
				,@ResourceResult_Corner_Result	VARCHAR(MAX) = NULL
				,@Char					VARCHAR(1)

		DECLARE @tmpCornerRaceToResult TABLE (hdp INT, ResourceID VARCHAR(20), HomeValue VARCHAR(10),Index_Round TINYINT)
		DECLARE @tmpCornerResultDetail AS TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(10))
		DECLARE @tmpCornerBettype TABLE (Bettype SMALLINT, ResourceId VARCHAR(20))

		;WITH cteCornerBettypes 
		AS (
			SELECT	bettype
					,CAST(bettype AS VARCHAR) 
						+ CASE 
							WHEN bettype IN (486,487) 
								THEN CASE
										WHEN hdp1 < 10 THEN '0' ELSE '' END + CAST(CAST(hdp1 AS INT) AS VARCHAR) 
							ELSE '' 
						END AS ResouceId
			FROM	#tmpTotalTransId
			WHERE	bettype BETWEEN 486 AND 490
			GROUP BY bettype
					,CAST(bettype AS VARCHAR) 
						+ CASE 
							WHEN bettype IN (486,487) 
								THEN CASE
										WHEN hdp1 < 10 THEN '0' ELSE '' END + CAST(CAST(hdp1 AS INT) AS VARCHAR) 
							ELSE '' 
						END
		)
		INSERT INTO @tmpCornerBettype(Bettype, ResourceId)
		SELECT	bettype
				,ResouceId
		FROM	cteCornerBettypes		

		IF EXISTS (SELECT TOP 1 1 FROM @tmpCornerBettype WHERE bettype IN (486, 487))
		BEGIN
			SELECT	@CornerResultString = ISNULL(CASE WHEN LEFT(@GoalRecord, 1) = ';' THEN SUBSTRING(@GoalRecord,2,LEN(@GoalRecord) - 1) ELSE @GoalRecord END, '')
					,@Position = 1
					,@HomeRaceTo = 0
					,@AwayRaceTo = 0					
				
			SELECT @LenResultString = LEN(@CornerResultString)

			SET @Index_Round_tmp =  CASE WHEN CHARINDEX(';',@GoalRecord) = 0 THEN LEN(@GoalRecord) + 1 ELSE CHARINDEX(';',@GoalRecord) END

			WHILE (@Position <= @LenResultString)
			BEGIN
				SET @Char = SUBSTRING(@CornerResultString, @Position, 1)
				
				IF @Char = 'H'	
				BEGIN
					SET @HomeRaceTo = @HomeRaceTo + 1

					IF @HomeRaceTo > @AwayRaceTo
					BEGIN
						IF @HomeRaceTo < 10  
							SET @hdp = '0' + CAST(@HomeRaceTo AS VARCHAR(5))
						ELSE 
							SET @hdp = CAST(@HomeRaceTo AS VARCHAR(5))
						
						IF @Position <= @Index_Round_tmp
							SET @Index_Round = 1
						ELSE 
							SET @Index_Round = 2
								 
						INSERT INTO @tmpCornerRaceToResult (HDP, ResourceID, HomeValue,Index_Round)
						VALUES (@HomeRaceTo,CAST(@hdp AS VARCHAR), @Char,@Index_Round )
						
					END	
				END
				ELSE IF @Char = 'A' 
				BEGIN
					SET @AwayRaceTo = @AwayRaceTo + 1
					IF @AwayRaceTo > @HomeRaceTo
					BEGIN
						IF @AwayRaceTo < 10  
							SET @hdp = '0' + CAST(@AwayRaceTo AS VARCHAR(5))
						ELSE 
							SET @hdp = CAST(@AwayRaceTo AS VARCHAR(5))
						
						IF @Position <= @Index_Round_tmp
							SET @Index_Round = 1
						ELSE 
							SET @Index_Round = 2
								
						INSERT INTO @tmpCornerRaceToResult (HDP,ResourceID, HomeValue, Index_Round)
						VALUES (@AwayRaceTo,CAST(@hdp AS VARCHAR), @Char,@Index_Round)

					END
				END
				
				SET @Position = @Position + 1	 	
			END

			INSERT INTO @tmpCornerResultDetail (ResourceID, HomeValue)
			SELECT	result.ResourceID 
					,result.HomeValue
			FROM	@tmpCornerBettype cte
				CROSS APPLY (
					SELECT (CAST(cte.bettype AS VARCHAR) + ResourceID) AS ResourceID
								, HomeValue
							FROM @tmpCornerRaceToResult
							WHERE 1 = CASE 
											WHEN cte.bettype = 487 AND Index_Round = 1 THEN 1
											WHEN cte.bettype = 487 AND Index_Round = 2 THEN 0
											ELSE 1
										END	
							
							) AS Result
			WHERE cte.Bettype IN (486, 487)
		END
								
		INSERT INTO @tmpCornerResultDetail(ResourceID, HomeValue)
		SELECT  CAST(bettype AS VARCHAR)
				,CASE 
					WHEN bettype = 490 AND CHARINDEX(';', @CornerResultString) > 0 THEN SUBSTRING(@CornerResultString,CHARINDEX(';', @CornerResultString) + 1, 1)
					ELSE LEFT (@CornerResultString, 1)
				END	 AS HomeValue
		FROM	@tmpCornerBettype
		WHERE	bettype IN (488,489,490)

		SET @ResourceResult_Corner_Result = ''
		SELECT @ResourceResult_Corner_Result = (
												SELECT DISTINCT c1.ResourceID AS Id
													, CASE 
														WHEN c2.HomeValue IS NULL THEN 'N'
														WHEN c2.HomeValue IN (';','') THEN 'N' 
														ELSE c2.HomeValue
														END AS HomeValue
													, 4 AS SettlementStatusId
													, 5 AS ResultStatusId
												FROM @tmpCornerBettype  c1
													LEFT JOIN @tmpCornerResultDetail c2 ON c1.ResourceID = c2.ResourceID
												FOR XML RAW ('Resource'), ROOT ('Results')
												)

		IF @ResourceResult_Corner_Result IS NOT NULL
		BEGIN	
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
				@Command        = 'NAP_Admin_Settlement_1_InstantCalculation-CAL', -- reuse inst command
				@MatchID        = @MatchID,                  
				@ResourceResult	= @ResourceResult_Corner_Result,                    
				@creator        = @creator
		END	
	END

	SELECT TOP 1 @IsExistSpecialBettype = 1
	FROM	#tmpTotalTransId
	WHERE	modds IS NULL

	WHILE (1=1)
	BEGIN		
		IF @IsExistW = 0 AND @IsExistD = 0 AND @IsExistL = 0 AND @IsExistSpecialBettype = 0
			BREAK

		SET @rowcount = 0

		DELETE @BalanceWalletBefore
		DELETE @BalanceWalletAfter
		DELETE @tmpFilter
		TRUNCATE TABLE #tmpBatchTransId

		IF @IsExistW = 1 -- WON, WON 1/2
		BEGIN
			INSERT INTO #tmpBatchTransId(transid, modds, filterBy)
			SELECT transid
				,CASE 
					WHEN modds > 0.25 THEN 1
					WHEN modds < -0.25 THEN - 1
					ELSE modds END AS modds
				,CASE WHEN modds > 0.25 THEN POWER(2,0)
					  WHEN modds = 0.25 THEN power (2,1)
					  WHEN modds = 0 THEN power(2,2)
					  WHEN modds = -0.25 THEN power (2,3)
					  ELSE power(2,4) END
					+ CASE WHEN isMarked = 1 THEN POWER(2,5) ELSE 0 END
					+ CASE WHEN oddstype = 1 THEN POWER(2,6) ELSE 0 END 			
						AS filterBy			
			FROM #tmpTotalTransID
			WHERE modds > 0 
			ORDER BY filterBy

			SET @rowcount = @@ROWCOUNT
			SET @IsExistW = 0
		END
		ELSE IF @IsExistW = 0 AND @IsExistD = 1 -- LOSE 1/2, DRAW
		BEGIN
			INSERT INTO #tmpBatchTransId(transid, modds, filterBy)
			SELECT transid
				,CASE 
					WHEN modds > 0.25 THEN 1
					WHEN modds < -0.25 THEN - 1
					ELSE modds END AS modds
				,CASE WHEN modds > 0.25 THEN POWER(2,0)
					  WHEN modds = 0.25 THEN power (2,1)
					  WHEN modds = 0 THEN power(2,2)
					  WHEN modds = -0.25 THEN power (2,3)
					  ELSE power(2,4) END
					+ CASE WHEN isMarked = 1 THEN POWER(2,5) ELSE 0 END
					+ CASE WHEN oddstype = 1 THEN POWER(2,6) ELSE 0 END 			
						AS filterBy			
			FROM #tmpTotalTransID
			WHERE modds BETWEEN -0.25 AND 0 
			ORDER BY filterBy

			SET @rowcount = @@ROWCOUNT
			SET @IsExistD = 0
		END
		ELSE IF @IsExistW = 0 AND @IsExistD = 0 AND @IsExistL = 1
		BEGIN
			INSERT INTO #tmpBatchTransId(transid, modds, filterBy) -- LOSE
			SELECT transid
				,CASE 
					WHEN modds > 0.25 THEN 1
					WHEN modds < -0.25 THEN - 1
					ELSE modds END  AS modds
				,CASE WHEN modds > 0.25 THEN POWER(2,0)
					  WHEN modds = 0.25 THEN power (2,1)
					  WHEN modds = 0 THEN power(2,2)
					  WHEN modds = -0.25 THEN power (2,3)
					  ELSE power(2,4) END
					+ CASE WHEN isMarked = 1 THEN POWER(2,5) ELSE 0 END
					+ CASE WHEN oddstype = 1 THEN POWER(2,6) ELSE 0 END 			
						AS filterBy				
			FROM #tmpTotalTransID
			WHERE modds < -0.25
			ORDER BY filterBy

			SET @rowcount = @@ROWCOUNT
			SET @IsExistL = 0
		END
		ELSE IF @IsExistW = 0 AND @IsExistD = 0 AND @IsExistL = 0 AND @IsExistSpecialBettype = 1
		BEGIN
			INSERT INTO #tmpBatchTransId(transid, filterBy) 
			SELECT transid
					,CASE 
						WHEN modds > 0.25 THEN POWER(2,0)
						WHEN modds = 0.25 THEN power (2,1)
						WHEN modds = 0 THEN power(2,2)
						WHEN modds = -0.25 THEN power (2,3)
						ELSE power(2,4) END
						+ CASE WHEN isMarked = 1 THEN POWER(2,5) ELSE 0 END
						+ CASE WHEN oddstype = 1 THEN POWER(2,6) ELSE 0 END 			
							AS filterBy						
			FROM #tmpTotalTransID
			WHERE modds IS NULL

			SET @IsExistSpecialBettype = 2
			SET @rowcount = @@ROWCOUNT
		END
		BEGIN
			INSERT INTO @tmpFilter (filterBy, modds, minrowid, maxrowid)
			SELECT filterBy, min(modds) as modds, min(rowid) minrowid, max(rowid) maxrowid
			FROM #tmpBatchTransId
			GROUP BY filterBy

			-- balance before settled
			IF @rowcount <= @threshold
			BEGIN
				INSERT INTO @BalanceWalletBefore (
					matchid
					, custid
					, balanceType
					, walletType
					, bonusId
					, balance
				)
				SELECT @matchid AS matchid
					, b.custid
					,1 AS balanceType -- Sports
					, ISNULL(b.WalletType, 2) AS WalletType
					, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
					, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	#tmpBatchTransId st
					INNER LOOP JOIN dbo.bettrans b WITH(ROWLOCK)
						ON b.transid = st.transid
				GROUP BY b.custid
					, b.bonusID
					, b.walletType
			END
			ELSE
			BEGIN
				INSERT INTO @BalanceWalletBefore (
					matchid
					, custid
					, balanceType
					, walletType
					, bonusId
					, balance
				)
				SELECT @matchid AS matchid
					, b.custid
					,1 AS balanceType -- Sports
					, ISNULL(b.WalletType, 2) AS WalletType
					, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
					, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	#tmpBatchTransId st
					INNER HASH JOIN dbo.bettrans b WITH(ROWLOCK)
						ON b.transid = st.transid
				WHERE	b.matchid = @matchid
				GROUP BY b.custid
					, b.bonusID
					, b.walletType
			END

			WHILE (1=1)
			BEGIN
				SELECT TOP 1	
					@filterby =filterBy
					,@modds = modds
					,@oddstype = CASE WHEN filterby & 64 > 0 THEN 1 ELSE 0 END
					,@IsMarked = CASE WHEN filterby & 32 > 0 THEN 1 ELSE 0 END
					,@minrowid = minrowid
					,@maxrowid = maxrowid
				FROM @tmpFilter
				WHERE isFinished = 0
				order by filterBy

				IF @@ROWCOUNT = 0
					BREAK

				WHILE (1=1)
				BEGIN
					SET @strTransIds = (
										SELECT	TOP (@batchNo) transid AS '@t'
										FROM	#tmpBatchTransId
										where	rowId between @minrowid and @minrowid + @batchNo -1
												and rowId <= @maxrowid
										FOR XML PATH('r'), ROOT('root')
									)
					IF ISNULL(@strTransIds,'')  = ''
					BEGIN
						UPDATE @tmpFilter
							SET isFinished = 1
						WHERE	filterby = @filterby

						BREAK
					END
				
					BEGIN TRY
						-- write log before execute SP
						IF OBJECT_ID('SingleSettlementTrace','U') IS NOT NULL AND dbo.f_Set_GetWriteLogMode() = 1
						BEGIN
							SET @sqlCommand = 'EXEC dbo.NAP_Admin_Calculate_Main @matchid = ' + CONVERT(NVARCHAR(50), @matchid) 
								+ ', @mode = ' + CASE
									WHEN @mode IS NULL THEN 'NULL'
									ELSE '''' + CONVERT(NVARCHAR(50), @mode) + ''''
									END 
								+ ', @action = ' + CASE
									WHEN @action IS NULL THEN 'NULL'
									ELSE '''' + CONVERT(NVARCHAR(50), @action) + ''''
									END 
								+ ', @IsSettingByProfile = 1'
								+ ', @strTransIds = ''' + CONVERT(VARCHAR(MAX), @strTransIds) + '''' 
								+ ', @oddstype = ' + CONVERT(NVARCHAR(50), @oddstype)
								+ ', @isMarked = ' + CONVERT(NVARCHAR(50), @isMarked)
								+ ', @modds = ' + CONVERT(NVARCHAR(50), @modds)
								+ CASE WHEN @IsExistSpecialBettype = 2 THEN ', @IsExistSpecialBettype = ' + CONVERT(NVARCHAR(50), @IsExistSpecialBettype) ELSE '' END
								+ CASE WHEN @IsExistSpecialBettype = 2 THEN ', @fth = ' + CONVERT(NVARCHAR(50), @fth) ELSE '' END
								+ CASE WHEN @IsExistSpecialBettype = 2 THEN ', @fta = ' + CONVERT(NVARCHAR(50), @fta) ELSE '' END
								+ CASE WHEN @IsExistSpecialBettype = 2 THEN ', @hth = ' + CONVERT(NVARCHAR(50), @hth) ELSE '' END
								+ CASE WHEN @IsExistSpecialBettype = 2 THEN ', @hta = ' + CONVERT(NVARCHAR(50), @hta) ELSE '' END
								+ ', @CalledByBrokerService = 1'
						
							INSERT INTO dbo.SingleSettlementTrace (MatchId, SqlCommand)
							VALUES (@matchid, @sqlCommand)
						END

						EXEC dbo.NAP_Admin_Calculate_Main
							@matchid	  		 = @matchid
							,@action			 = @action
							,@IsSettingByProfile = 1
							,@strTransIds		 = @strTransIds
							,@mode				 = 'profile-major'
							,@oddstype			 = @oddstype
							,@IsMarked			 = @IsMarked
							,@modds				 = @modds
							,@IsExistSpecialBettype = @IsExistSpecialBettype
							,@fth = @fth
							,@fta = @fta
							,@hth = @hth
							,@hta = @hta
					
					END TRY
					BEGIN CATCH
						SELECT  @ErrCode = 1001017 
								,@ErrMsg = ERROR_MESSAGE()
					END CATCH
			
					SET @minrowid = @minrowid + @batchNo
				
				END			
			END
			
			IF @IsExistSpecialBettype = 2
				SET @IsExistSpecialBettype = 0

			-- balance after settled	
			IF @rowcount <= @threshold
			BEGIN
				INSERT INTO @BalanceWalletAfter (
					matchid
					, custid
					, balanceType
					, walletType
					, bonusId
					, balance
				)
				SELECT @matchid AS matchid
					, b.custid
					,1 AS balanceType -- Sports
					, ISNULL(b.WalletType, 2) AS WalletType
					, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
					, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	#tmpBatchTransId AS st
					INNER LOOP JOIN dbo.bettrans b WITH(ROWLOCK)
						ON b.transid = st.transid
				GROUP BY b.custid
					, b.bonusID
					, b.walletType
			END
			ELSE
			BEGIN
				INSERT INTO @BalanceWalletAfter (
					matchid
					, custid
					, balanceType
					, walletType
					, bonusId
					, balance
				)
				SELECT @matchid AS matchid
					, b.custid
					,1 AS balanceType -- Sports
					, ISNULL(b.WalletType, 2) AS WalletType
					, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
					, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	#tmpBatchTransId AS st
					INNER HASH JOIN dbo.bettrans b WITH(ROWLOCK)
						ON b.transid = st.transid
				WHERE	b.matchid = @matchid
				GROUP BY b.custid
					, b.bonusID
					, b.walletType
			END

			EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				@BalanceWalletBefore	= @BalanceWalletBefore
				,@BalanceWalletAfter	= @BalanceWalletAfter
				,@ActionId				= @ActionID
		END
	END
	
	-- cashout, bettrade
	BEGIN
		-- get main transid of Bettrade & transid of bettype 911
		;WITH cteMain
		AS(
			SELECT	b.transId, b.matchid, b.custid
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = @matchid
					AND b.betdaqid = 0 
			UNION ALL
			SELECT NULL, NULL, NULL
		)			
		INSERT INTO #tmpReferTransId(transid)
		SELECT	ISNULL(co.transid, main.transid) AS transid
		FROM cteMain main
			LEFT JOIN dbo.bettrans co WITH(NOLOCK)
				ON	co.matchid = main.matchid
					AND co.refno = main.transid
					AND co.custid = main.custid
					AND co.bettype = 911
		WHERE main.transid IS NOT NULL

		INSERT INTO #tmpDummyTicket (transid, custid, bettype) -- 911
		SELECT	transid, custid, bettype
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchid
				AND b.bettype = 911 
				AND EXISTS (SELECT TOP 1 1 FROM #tmpReferTransId t WHERE t.transid = b.transid)			
		UNION ALL
		SELECT	transid, custid, bettype -- 901, 902, 903, 912, 913
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchId
				AND b.bettype IN (901, 902, 903, 912, 913)					
				AND EXISTS (SELECT TOP 1 1 FROM #tmpReferTransId t WHERE t.transid = b.refno)
				
		INSERT INTO #tmpDummyTicket (transid, custid, bettype) -- 904, 914
		SELECT	transid, custid, bettype
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchId
				AND b.bettype IN (904, 914)
				AND EXISTS (SELECT TOP 1 1 
							FROM #tmpDummyTicket t 
							WHERE	1 = CASE 
											WHEN t.bettype = 902 AND b.bettype = 904 THEN 1
											WHEN t.bettype = 912 AND b.bettype = 914 THEN 1
											ELSE 0
										END
									AND t.custid = b.custid)
		
		DELETE FROM @BalanceWalletBefore
		DELETE FROM @BalanceWalletAfter
		
		SELECT @rowcountDummy = COUNT(1)
		FROM	#tmpDummyTicket
		
		-- balance before settled
		IF @rowcountDummy <= @threshold
		BEGIN
			INSERT INTO @BalanceWalletBefore (
				matchid
				, custid
				, balanceType
				, walletType
				, bonusId
				, balance
			)
			SELECT @matchid AS matchid
				,b.custid
				,1 AS balanceType -- Sports
				,2 AS WalletType
				,0 AS BonusId
				,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM	#tmpDummyTicket st
				INNER LOOP JOIN dbo.bettrans b WITH(ROWLOCK)
					ON b.transid = st.transid
			GROUP BY b.custid
				, b.bonusID
				, b.walletType
		END
		ELSE
		BEGIN
			INSERT INTO @BalanceWalletBefore (
				matchid
				, custid
				, balanceType
				, walletType
				, bonusId
				, balance
			)
			SELECT @matchid AS matchid
				,b.custid
				,1 AS balanceType -- Sports
				,2 AS WalletType
				,0 AS BonusId
				,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM	#tmpDummyTicket st
				INNER HASH JOIN dbo.bettrans b WITH(ROWLOCK)
					ON b.transid = st.transid
			WHERE	b.matchid = @matchid
			GROUP BY b.custid
				, b.bonusID
				, b.walletType
		END

		BEGIN TRY
		-- BetTrade
		IF EXISTS (SELECT TOP 1 1 FROM #tmpDummyTicket WHERE bettype BETWEEN 901 AND 910)
		BEGIN
			 EXEC dbo.NAP_Admin_Calculate_901
				 @matchid = @matchid
				,@action = 'CAL'
				,@mode = @action
				,@isRefundHT = @isRefundHT

			EXEC dbo.NAP_Admin_Calculate_904 -- BetTrade Winlost Sharing
				@MatchId = @matchid
				,@Action = @action
		END

		-- CashOut
		IF EXISTS (SELECT TOP 1 1 FROM #tmpDummyTicket WHERE bettype BETWEEN 911 AND 920)
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_911
				@matchid        = @matchid
				,@action        = 'CAL'
				,@mode          = @action
				,@strBettypes   = @strBettypes

			EXEC dbo.NAP_Admin_Calculate_914 -- CashOut Winlost Sharing
				@MatchId = @matchid
				,@Action = @action
		END
		END TRY
		BEGIN CATCH
			SELECT  @ErrCode = 1001017 
					,@ErrMsg = ERROR_MESSAGE()
		END CATCH
		
		INSERT INTO #tmpDummyTicket (transid, custid, bettype) -- 904, 914
		SELECT	b.transid, b.custid, b.bettype
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN #tmpDummyTicket t
				ON b.transid = t.transid
		WHERE	b.matchid = @matchId
				AND t.transid IS NULL
				AND b.bettype IN (904, 914)
				AND EXISTS (SELECT TOP 1 1 
							FROM #tmpDummyTicket t 
							WHERE	1 = CASE 
											WHEN t.bettype = 912 AND b.bettype = 914 THEN 1
											WHEN t.bettype = 902 AND b.bettype = 904 THEN 1
											ELSE 0
										END
									AND t.custid = b.custid)
		
		SELECT @rowcountDummy = COUNT(1)
		FROM	#tmpDummyTicket
		
		-- balance after settled
		IF @rowcountDummy <= @threshold
		BEGIN
			INSERT INTO @BalanceWalletAfter (
				matchid
				, custid
				, balanceType
				, walletType
				, bonusId
				, balance
			)
			SELECT @matchid AS matchid
				,b.custid
				,1 AS balanceType -- Sports
				,2 AS WalletType
				,0 AS BonusId
				,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM	#tmpDummyTicket st
				INNER LOOP JOIN dbo.bettrans b WITH(ROWLOCK)
					ON b.transid = st.transid
			GROUP BY b.custid
				, b.bonusID
				, b.walletType
		END 
		ELSE
		BEGIN
			INSERT INTO @BalanceWalletAfter (
				matchid
				, custid
				, balanceType
				, walletType
				, bonusId
				, balance
			)
			SELECT @matchid AS matchid
				,b.custid
				,1 AS balanceType -- Sports
				,2 AS WalletType
				,0 AS BonusId
				,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM	#tmpDummyTicket st
				INNER HASH JOIN dbo.bettrans b WITH(ROWLOCK)
					ON b.transid = st.transid
			WHERE	b.matchid = @matchid
			GROUP BY b.custid
				, b.bonusID
				, b.walletType
		END
		
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			,@BalanceWalletAfter	= @BalanceWalletAfter
			,@ActionId				= @ActionID
	END
END


