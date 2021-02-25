/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Profile] 
	@matchid INT
    ,@action VARCHAR(6) = 'CAL'
	,@creator INT = 0
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
			,@IsExistMinorBettype BIT
			,@IsSkipBalanceUpdate BIT
			,@filterby INT 
			,@minrowid INT 
			,@maxrowid INT 
			,@sqlCommand VARCHAR(MAX)
			,@mode VARCHAR(15)
			,@strBettypes VARCHAR(MAX)
			
			
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange

	SELECT	@batchNo = 2000
			,@threshold = 200000
			,@DummyResourceIds = ''
			,@DummyResourceResults = ''

			,@strTransIds = ''
			,@oddstype = 0
			,@IsMarked = 0
			,@modds = 0
			
			,@ErrCode = 0
			,@ErrMsg = ''
			,@IsExistW  = 1
			,@IsExistD  = 1
			,@IsExistL = 1
			,@IsExistMinorBettype = 1
			,@IsSkipBalanceUpdate = 0
			,@filterby = 0
			,@minrowid = 0
			,@maxrowid = 0	
			,@sqlCommand = ''
			,@mode = 'profile-major'
			,@strBettypes = ''

    SELECT	@fth = FinalHomeScore
			,@fta = FinalAwayScore
			,@hth = HTHomeScore
			,@hta = HTAwayScore
			,@sporttype = sporttype
			,@goalrecord = goalrecord
			,@isRefundHT = CASE WHEN betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END 
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


	;WITH cteResource
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
		SELECT 	CAST('08' AS VARCHAR(20)) AS ResourceID
				,CAST( @goalrecord AS VARCHAR(50)) AS HomeValue
				,NULL
		WHERE	@action IN ('CAL', 'CAL-FT')
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
			AND f.SettledByProfile = 1
			AND SettleType = 'MNL'
			AND pfID > 0
	
	SELECT	@strBettypes = @strBettypes + CAST(bettype AS VARCHAR) + ','
	FROM	#tmpSelectedRID
	GROUP BY bettype

	INSERT INTO #tmpTotalTransId (TransId, modds, oddstype, isMarked, betdaqid)
	SELECT b.transid
		,m.modds		
		,ISNULL(sr.OddsType,0) AS oddstype
		,CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS isMarked
		,b.betdaqid
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

	WHILE (1=1)
	BEGIN		
		IF @IsExistW = 0 AND @IsExistD = 0 AND @IsExistL = 0 AND @IsExistMinorBettype = 0
			BREAK

		SET @IsSkipBalanceUpdate = 0
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
		ELSE IF @IsExistW = 0 AND @IsExistD = 0 AND @IsExistMinorBettype = 1 -- minor bettypes
		BEGIN
			 EXEC dbo.NAP_Admin_Settlement_3
                @matchid            = @matchid
                ,@mode                = @action    
				,@IsReSettledTickets = @IsReSettledTickets
				,@creator = @creator

			SET @IsExistMinorBettype = 0
			SET @IsSkipBalanceUpdate = 1
		END
		ELSE IF @IsExistW = 0 AND @IsExistD = 0 AND @IsExistMinorBettype = 0 AND @IsExistL = 1
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

			SET @IsExistL = 0
			SET @rowcount = @@ROWCOUNT
		END
		
		IF @IsSkipBalanceUpdate = 0
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
					
					END TRY
					BEGIN CATCH
						SELECT  @ErrCode = 1001017 
								,@ErrMsg = ERROR_MESSAGE()
					END CATCH
			
					SET @minrowid = @minrowid + @batchNo
				
				END			
			END
			
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

		-- balance before settled
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
		
		-- balance after settled
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

		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			,@BalanceWalletAfter	= @BalanceWalletAfter
	END
END
