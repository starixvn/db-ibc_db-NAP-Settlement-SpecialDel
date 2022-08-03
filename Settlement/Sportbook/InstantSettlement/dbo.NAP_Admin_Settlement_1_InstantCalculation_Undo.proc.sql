/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_InstantCalculation_Undo] 
	@Creator 			INT
	, @MatchId			INT
	, @Mode				VARCHAR(10)
	, @InstantKey		INT
	, @HomeScore		VARCHAR(50)
	, @AwayScore		VARCHAR(50)
	, @ResourceResult	VARCHAR(MAX)	= NULL
	, @IP				VARCHAR(15)		= ''
	, @ErrCode			INT				= 0		OUTPUT
	, @ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*    
	Creator: 20161004@Bobby
    Task: Implement Instant Calculation
    DB: DBTXN/BODB02
	Original:

    Revisions:        
		- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20170420@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20180822@Kathy: Correct total acccount changed balance [Redmine:#99465]
		- 20190621@Sol: Auto Payout Phase 3 - Change command for Instant Calculation to avoid wrong replacing SP deployment [Redmine:#116073]
		- 20191213@Max: Instant Settlement for Corner Bettype [Redmine:#124951]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
        - @Mode: ['INST-HT', 'INST-FT']
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @start						DATETIME
		, @stop							DATETIME
		, @LogData						NVARCHAR(300)
		, @eventstatus					NVARCHAR(50)
		, @betstatus					NVARCHAR(50)
		, @sporttype					SMALLINT
		, @ticketCount					INT	
		, @Remark						VARCHAR(500)
		, @ActionLogId					INT
		, @TotalAccount					INT
		, @TotalAccount_Updated			INT
		, @Action						VARCHAR(20)
		------------------------------------
		, @isExistMatch					BIT
		, @avaiableProcess				BIT
		, @CalculationType				TINYINT
		, @hthomescore					TINYINT
		, @htawayscore					TINYINT
		, @finalhomescore				TINYINT
		, @finalawayscore				TINYINT
		, @hScore						TINYINT
		, @aScore						TINYINT
		, @hScore1H						TINYINT
		, @aScore1H						TINYINT
		, @hScore2H						TINYINT
		, @aScore2H						TINYINT
		, @fromTransId					BIGINT
		, @toTransId					BIGINT
		, @FGNG							VARCHAR(50)
		, @GoalRecord					VARCHAR(50)
		, @InstantKeyValue				VARCHAR(50)
		, @livehomescore				TINYINT
		, @liveawayscore				TINYINT
		, @FGLGCheck					TINYINT
		--CornerBettype
		,@ChildMatchType		TINYINT
		,@CornerResultString	NVARCHAR(MAX)
		,@Char					VARCHAR(1)
		,@Position				TINYINT
		,@HomeRaceTo			TINYINT
		,@AwayRaceTo			TINYINT
		,@LenResultString		TINYINT
		,@ResultCorner			NVARCHAR(MAX) = ''
		,@hdp					VARCHAR(5) = ''
		,@ResourceResult_Corner	NVARCHAR(MAX) = ''
		,@ResourceResult_CornerRace NVARCHAR(MAX) = ''
		,@NeitherRaceTo			TINYINT
		,@IsCentral				BIT
		,@HTBetStatus			NVARCHAR(50) = ''
		,@FTBetStatus			NVARCHAR(50) = ''

	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	
	CREATE TABLE #tempUndoTickets (transid BIGINT PRIMARY KEY, custid INT, bettype SMALLINT, betteam NVARCHAR(10),hdp1 smallmoney)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	DECLARE @ResultDetail_Corner AS TABLE (hdp INT, ResourceID VARCHAR(20), HomeValue VARCHAR(10))
	
	DECLARE @instantBettype TABLE (bettype SMALLINT)

	SELECT @start					= CURRENT_TIMESTAMP
		, @FGLGCheck				= 0
		, @InstantKeyValue			= CAST(@InstantKey AS VARCHAR(50))
		, @ticketCount				= 0
		, @TotalAccount				= 0 
		, @TotalAccount_Updated		= 0
		, @Action					= 'UNDO-INST'
	
	SELECT
		@HomeScore			= ps.HomeValue
		, @AwayScore		= ps.AwayValue
		, @GoalRecord		= ISNULL(fgng.GoalRecord, '')
		, @CalculationType	= ps.TypeId
		
	FROM DBPRO.bodb02.dbo.ProviderResultDetail ps WITH (NOLOCK) 
		OUTER APPLY (	
			SELECT HomeValue AS GoalRecord
			FROM DBPRO.bodb02.dbo.ProviderResultDetail ps WITH (NOLOCK) 
			WHERE MatchId 			= @MatchId
				AND TypeId			= 103 --FGNG
				AND AwayValue 		= @InstantKeyValue
				
		) AS fgng
	WHERE ProviderResultDetailId 	= @InstantKey
	
	SELECT @start					= CURRENT_TIMESTAMP
		, @ActionLogId				= 182
		, @isExistMatch				= 1

	-- CHECK match validation
	SELECT TOP(1)
		@sporttype 				= m.sporttype
		, @betstatus			= ISNULL(m.betstatus,'')
		, @hthomescore			= m.hthomescore
		, @htawayscore			= m.htawayscore
		, @livehomescore		= m.livehomescore
		, @liveawayscore		= m.liveawayscore
		, @ChildMatchType		= m.ChildMatchType
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @matchid
	
	--SET scores in 1H & 2H
	SELECT @hScore		= CAST(@HomeScore AS INT)
		, @aScore		= CAST(@AwayScore AS INT)
		, @hScore1H		= CASE WHEN @CalculationType = 101 THEN @hScore ELSE ISNULL(@hthomescore,0) END
		, @aScore1H		= CASE WHEN @CalculationType = 101 THEN @aScore ELSE ISNULL(@htawayscore,0) END 
		, @hScore2H		= CASE WHEN @CalculationType = 102 THEN @hScore-@hScore1H ELSE 0 END
		, @aScore2H		= CASE WHEN @CalculationType = 102 THEN @aScore-@aScore1H ELSE 0 END
		, @GoalRecord	= CASE WHEN LEFT(@GoalRecord, 1) = ';' THEN SUBSTRING(@GoalRecord,2,LEN(@GoalRecord) - 1) ELSE @GoalRecord END
		, @FGNG			= CASE 
							WHEN LEFT(@GoalRecord, 1) = 'H' THEN '1'  
							WHEN LEFT(@GoalRecord, 1) = 'A' THEN '2'  
							ELSE ''
						END 
		, @FGNG			= CASE WHEN @FGNG <> '' THEN @FGNG + ':1' ELSE '' END
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT @matchid AS matchid
		,1 AS KeyId

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @Matchid
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
	    SELECT	@ErrCode
				,@ErrMsg
	    
	    RETURN
	END
				
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
	
	--CHECK avaiable process
	IF(@sporttype IS NULL OR  @ErrCode <> 0 OR @avaiableProcess = 0) RETURN
		
	INSERT INTO @instantBettype (bettype)
	SELECT bettype
	FROM dbo.f_Set_Instant_GetBettypes()
	WHERE 1	= 	CASE 
					WHEN @CalculationType = 101 AND InstantType & 1 = 1 THEN 1
					WHEN @CalculationType = 102 AND InstantType & 2 = 2 THEN 1
					ELSE 0 
				END
	
	--CornerRace
	IF @ChildMatchType = 204
	BEGIN
		SELECT @CornerResultString = ISNULL(@GoalRecord, '')
			,@ResultCorner = ''
			,@Position = 1
			,@HomeRaceTo = 0
			,@AwayRaceTo = 0
			,@NeitherRaceTo = 0
		SELECT @LenResultString = LEN(@CornerResultString)

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

					INSERT INTO @ResultDetail_Corner (HDP, ResourceID, HomeValue)
					VALUES (@HomeRaceTo,CAST(@hdp AS VARCHAR), @Char)
					
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
						
					INSERT INTO @ResultDetail_Corner (HDP,ResourceID, HomeValue)
					VALUES (@AwayRaceTo,CAST(@hdp AS VARCHAR), @Char)

				END
			END
			
			SET @Position = @Position + 1	 	
		END
		
		SELECT @ResultCorner = STUFF(
								(
									SELECT ';' + CAST(HDP AS VARCHAR) + HomeValue 
									FROM @ResultDetail_Corner FOR XML PATH ('')
								)
								, 1, 1, ''
							 ) + ';'
		FROM @ResultDetail_Corner
		
		SELECT @NeitherRaceTo = (SELECT COUNT(1) FROM @ResultDetail_Corner)
	END
	
	INSERT INTO #tempUndoTickets (transid, custid, bettype, betteam, hdp1)
	SELECT b.transid
		, b.custid
		, b.bettype
		, b.betteam
		, b.hdp1
	FROM dbo.bettrans b WITH(NOLOCK)		
		CROSS APPLY [dbo].[f_Set_Instant_CalModds](
													b.bettype
													, b.betteam
													, b.hdp1
													, b.hdp2
													, @hScore1H
													, @aScore1H
													, @hScore2H
													, @aScore2H
													, @FGNG
													, @CalculationType
													, @ResultCorner
													, @NeitherRaceTo
													, @GoalRecord
												) AS ods
	WHERE matchid = @matchid
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND b.recommend <> 1688156) --exclude betdaq/betfair
		AND EXISTS(SELECT 1 FROM @instantBettype WHERE bettype = b.bettype)
		AND b.statusId IN (112,113)
		AND (
			ods.StatusId = 0 OR b.statusId <> ods.statusId
		)
		AND ISNULL(b.betdaqid,0) <> -2
	
	IF @ChildMatchType = 204 
	BEGIN
		SET @ResourceResult = ''
		SELECT @ResourceResult = (
									SELECT DISTINCT 
												CASE 
													WHEN bettype IN (486,487) THEN CAST(bettype AS VARCHAR) 
																					+ CASE 
																						WHEN hdp1 < 10 THEN '0' + CAST(hdp1 AS VARCHAR) 
																						ELSE CAST(hdp1 AS VARCHAR) 
																					END 
													ELSE CAST(bettype AS VARCHAR) 
												END AS Id
									FROM (
											SELECT DISTINCT bettype, CASE WHEN bettype IN (486, 487) THEN CONVERT(INT, hdp1) 
																		ELSE 0 END AS hdp1
											FROM #tempUndoTickets WITH (NOLOCK)
											WHERE bettype IN (486,487,488,489,490) 
										)AS t
									FOR XML RAW ('Resource'), ROOT ('Results')
								)
	END
		
	BEGIN TRY	
		-------------------------------------------------------------
		---        CAPTURE value BALANCE before settlement        ---
		---------------------------VVVV------------------------------
		INSERT INTO @BalanceWalletBefore (
			matchid
			, custid
			, balanceType
			, BonusID
			, WalletType
			, balance
		)
		SELECT @matchid AS matchid 
			, t.custid
			, 1 -- Sports
			, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
			, ISNULL(b.WalletType, 2) AS WalletType -- Cash Wallet as default
			, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(ROWLOCK)
			INNER JOIN #tempUndoTickets t ON b.transid = t.transid
			
		GROUP BY t.custid
			, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
			, ISNULL(b.WalletType, 2)
			
		SELECT @TotalAccount = @@ROWCOUNT
			
		--do instant calculation per batch of tickets
		DECLARE @strInstantTicket	VARCHAR(MAX)
			, @batchCount			INT
			, @batchRowCount		INT
			, @nextTransId			BIGINT
		
		DECLARE @tempInstantBatch 	TABLE (transid BIGINT, modds MONEY)

		SELECT @batchCount			= 1000
			, @fromTransId			= MIN(transid)
			, @toTransId			= MAX(transid)
			, @nextTransId			= @fromTransId
		FROM #tempUndoTickets t
				
		WHILE (1=1)
		BEGIN 
			
			DELETE @tempInstantBatch

			INSERT INTO @tempInstantBatch (transid, modds)
			SELECT TOP (@batchCount)
				t.transid
				, 0 AS modds
			FROM #tempUndoTickets t
			WHERE t.transid BETWEEN @nextTransId AND @toTransId
			ORDER BY t.transid

			SELECT @batchRowCount	= @@ROWCOUNT
				, @ticketCount		+=	@batchRowCount
				, @strInstantTicket = CAST((SELECT b.transid AS t
												,b.modds AS m 
											FROM @tempInstantBatch b
											FOR XML AUTO) AS VARCHAR(MAX));

			/*SELECT t.*, b.bettype, b.status, b.betteam,b.modds
			FROM @tempInstantBatch t
			inner join dbo.bettrans b (nolock) on t.transid = b.transid*/
									
			EXEC dbo.NAP_Admin_Calculate_Main
				@matchid		= @MatchId
				, @Action 		= @Action
				, @Mode 		= @Mode
				, @strTransIds 	= @strInstantTicket
			
			SELECT @nextTransId = MAX(transid) + 1
			FROM @tempInstantBatch

			IF(@nextTransId > @toTransId OR @batchRowCount < @batchCount) BREAK;
			
		END
			
	END TRY
	BEGIN CATCH
		
		SELECT @ErrCode = 1001017, @ErrMsg = ERROR_MESSAGE()
		
		--CAPTURE balance with error
		INSERT INTO @BalanceWalletAfter (
			matchid
			, custid
			, balanceType
			, bonusID
			, WalletType
			, balance
		)
		SELECT @matchid AS matchid 
			, t.custid
			, 1 -- Sports
			, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
			, ISNULL(b.WalletType, 2) AS WalletType -- Cash Wallet as default
			, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(ROWLOCK)
			INNER JOIN #tempUndoTickets t ON b.transid = t.transid
			
		GROUP BY t.custid
			, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
			, ISNULL(b.WalletType, 2)
			
		---INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionLogId

		------ releasing Settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= @isExistMatch
			, @IsReleased		= 1
			
		RETURN
	END CATCH
	
	-- UPDATE match betstatus
	--SELECT @FGLGCheck 		= MAX(CASE WHEN bettype = 127 AND RIGHT(betteam, 1) IN ('0', '1' ) THEN 1 ELSE 0 END)
	--	, @FGLGCheck 		+= MAX(CASE WHEN bettype = 14 AND RIGHT(betteam, 1) IN ('0', '1' ) THEN 2 ELSE 0 END)	
	--FROM #tempUndoTickets 
	IF @ChildMatchType = 204 
	BEGIN
		IF @ResourceResult IS NOT NULL
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
					@Command        = 'NAP_Admin_Settlement_1_InstantCalculation-UNDO',
					@MatchID        = @MatchID,                  
					@ResourceResult	= @ResourceResult,                    
					@creator        = @creator	
		END
	END
	ELSE
	BEGIN
		;WITH cteFGLGTicket
		AS
		(
			SELECT	MAX(CASE WHEN bettype = 127 AND statusID BETWEEN 112 AND 113 AND RIGHT(betteam,1) = '1' THEN 1 ELSE 0 END) AS HasSettledHTFGLGTicket
					,MAX(CASE WHEN bettype = 14 AND statusID BETWEEN 112 AND 113 AND RIGHT(betteam,1) = '1' THEN 1 ELSE 0 END) AS HasSettledFTFGLGTicket
					,SUM(CASE WHEN bettype = 127 THEN 1 ELSE 0 END) CntHTFGLG				
					,SUM(CASE WHEN bettype = 14 THEN 1 ELSE 0 END) CntFTFGLG
			FROM	dbo.bettrans WITH (NOLOCK)
			WHERE	matchid = @MatchId
					AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
			GROUP BY matchid
		)
		SELECT @FGLGCheck = CASE
								WHEN @Mode = 'INST-HT' 
									THEN CASE 
											WHEN HasSettledHTFGLGTicket = 1 OR HasSettledFTFGLGTicket = 1 THEN 0
											WHEN CntHTFGLG > 0 AND CntFTFGLG > 0 THEN 3
											WHEN CntFTFGLG > 0 THEN 2
											WHEN CntHTFGLG > 0 THEN 1
											ELSE 0
										END
								ELSE CASE	-- 'INST-FT'
										WHEN HasSettledFTFGLGTicket = 1 THEN 0
										WHEN CntFTFGLG > 0 THEN 2
										ELSE 0
									END
							END
		FROM	cteFGLGTicket

		IF @FGLGCheck > 0
		BEGIN
			SELECT @HTBetStatus = ''
			WHERE @FGLGCheck & 1 <> 1

			SELECT @FTBetStatus = ''
			WHERE @FGLGCheck & 2 <> 2

			EXEC DBPRO.bodb02.dbo.NAP_Admin_Match_Update
				@Command         = 'NAP_Admin_Settlement_1_InstantCalculation-Undo'
				,@MatchID        = @matchid
				,@creator        = @Creator
				,@HTBetStatus	 = @HTBetStatus
				,@FTBetStatus	 = @FTBetStatus
		END	
	END
	
	--capture balance after
	INSERT INTO @BalanceWalletAfter (
		matchid
		,custid
		,balanceType
		,BonusID
		,WalletType	
		,balance
	)
	SELECT @matchid AS matchid
		, t.custid
		, 1 -- Sports
		, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
		, ISNULL(b.WalletType, 2) AS WalletType -- Cash Wallet as default
		, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM dbo.bettrans b WITH(ROWLOCK)
		INNER JOIN #tempUndoTickets t ON b.transid = t.transid
	
	GROUP BY t.custid
		, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
		, ISNULL(b.WalletType, 2)

	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionLogId
		
	SELECT @TotalAccount_Updated = COUNT(1)
	FROM @BalanceWalletBefore b
		INNER JOIN @BalanceWalletAfter a 
		ON b.custid = a.custid
	WHERE b.balance <> a.balance
	
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP

	--RESET final scores	
	SELECT @hthomescore		=  CASE WHEN @CalculationType = 101 THEN @hScore ELSE @hthomescore END
		, @htawayscore		=  CASE WHEN @CalculationType = 101 THEN @aScore ELSE @htawayscore END
		, @finalhomescore	=  CASE WHEN @CalculationType = 102 THEN @hScore ELSE @finalhomescore END
		, @finalawayscore	=  CASE WHEN @CalculationType = 102 THEN @aScore ELSE @finalawayscore END
			
	
	SELECT @LogData = 'NAP: Instant Uncalculate (' + @mode + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
		+ ' Score:' + CAST(ISNULL(@homescore, 0) AS NVARCHAR(10)) + '-' + CAST(ISNULL(@awayscore, 0) AS NVARCHAR(10)) 
		+ ' Instant action:' + CAST(@mode AS NVARCHAR(10)) 
		+ ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	
	EXEC dbo.Logfile_V2 
		@UserID = @creator
		,@Doing = @LogData
		,@extend = @MatchId
	
	IF @IsCentral = 1
	BEGIN
		SELECT @Remark ='NAP: Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms;' 
								+ ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
								+ ' Bal:' + CAST(ISNULL(@TotalAccount_Updated, 0) AS VARCHAR(20)) + '/' + CAST(ISNULL(@TotalAccount, 0) AS VARCHAR(20))
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				, @Matchid			= @matchid
				, @ActionId			= @ActionLogId
				, @finalhomescore	= @finalhomescore
				, @finalawayscore	= @finalawayscore
				, @hthomescore		= @hthomescore
				, @htawayscore		= @htawayscore
				, @GoalRecord		= @goalrecord
				, @betstatus		= @betstatus
				, @Remark			= @Remark
				, @IP				= @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				, @Matchid			= @matchid
				, @ActionId			= @ActionLogId
				, @finalhomescore	= @finalhomescore
				, @finalawayscore	= @finalawayscore
				, @hthomescore		= @hthomescore
				, @htawayscore		= @htawayscore
				, @GoalRecord		= @goalrecord
				, @betstatus		= @betstatus
				, @Remark			= @Remark
				, @IP				= @IP
		END CATCH
	END

	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess
	DROP TABLE #tempUndoTickets
	
	RETURN;
END
GO