/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_1_InstantCalculation
	@Creator 			INT
	, @MatchId		INT
	, @Mode			VARCHAR(10) = 'INST-HT'
	, @InstantKey		INT
	, @HomeScore		VARCHAR(50)
	, @AwayScore		VARCHAR(50)
	, @ResourceResult	VARCHAR(MAX) = NULL
	, @IP			VARCHAR(15)
	, @IsAutoInst		BIT 		   = 0
	, @SourceID		TINYINT	   = NULL
	, @ErrCode		INT		   = 0	OUTPUT
	, @ErrMsg			NVARCHAR(200)= ''	OUTPUT
	
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
		- 20180709@Helen: Enhance Performance for Instant Calculation - [Redmine: 98608]
		- 20180123@Benjamin: Add @IsAutoInst and @SourceID parameter for Determine Manual Instant/Auto Instant [Redmine:#86964]
		- 20181114@Helen:  Second Accept - Processing for Waiting Tickets [Redmine:104755]
		- 20181109@Helen: Wrong member balance while doing Cashout /Bettrade at the same time of Instant settle [Redmine:101652]
		- 20190107@Kathy: set ticket running if it is accepted by both auto accept & second accept [Redmine:#107452]
		- 20190305@Sol:  New Formula for Comm [Redmine:#109007]

    Param's Explanation:
        - @Mode: ['INST-HT', 'INST-FT']
        - @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
        - @IsAutoInst: 1-Auto Instant 0-Manual Instant
    
    Sample execution:
		exec NAP_Admin_Settlement_1_InstantCalculation @Creator = 8 , @MatchId = 27089242, @InstantKey = 10485,@IP = '1',@HomeScore = 2, @AwayScore = 1    
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
		, @InstKeyValue					VARCHAR(50)
		, @FGLGCheck					TINYINT
		, @FLValue 						VARCHAR(50)
		, @betstatusOld					VARCHAR(50)
		, @Source						VARCHAR(50) = 'Soccerway'
		, @strTransCashout VARCHAR (MAX)
		
		
	DECLARE @BalanceWalletBefore 			TVP_BalanceWalletChange
		, @BalanceWalletAfter				TVP_BalanceWalletChange
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #temp_bettrans (TransID bigint, MOdds money, CustID int, Balance money, BetType smallint, BonusID int, WalletType tinyint, actual_stake MONEY, srecommend INT)
	DECLARE @CashoutTickets_tmp AS TABLE (TransID BIGINT,custid INT, balance MONEY)
			
	DECLARE @instantBettype TABLE (bettype SMALLINT)
	DECLARE @xmlCashoutTicket XML
	
	
	SET @InstKeyValue		= CAST(@InstantKey AS VARCHAR(50))
	
	SELECT
		@HomeScore		= ps.HomeValue
		, @AwayScore		= ps.AwayValue
		, @GoalRecord		= ISNULL(fgng.GoalRecord, '')
	FROM DBPRO.bodb02.dbo.ProviderResultDetail ps WITH (NOLOCK) 
		OUTER APPLY (	
			SELECT HomeValue AS GoalRecord
			FROM DBPRO.bodb02.dbo.ProviderResultDetail ps WITH (NOLOCK) 
			WHERE MatchId 			= @MatchId
				AND TypeId		= 103 --FGNG
				AND AwayValue 		= @InstKeyValue
				
		) AS fgng
	WHERE ProviderResultDetailId 	= @InstantKey
	
	SELECT @start					= CURRENT_TIMESTAMP
		, @TicketCount				= 0
		, @TotalAccount			= 0
		, @TotalAccount_Updated		= 0
		, @Action					= 'CAL-INST'
		, @CalculationType 			= CASE @Mode
										WHEN 'INST-HT' THEN 101
										WHEN 'INST-FT' THEN 102
										ELSE 0
									END
		/*, @ActionLogId				= CASE @CalculationType
										WHEN 101 THEN 178
										WHEN 102 THEN 179
										END
		*/										

		, @ActionLogId				= CASE WHEN @CalculationType = 101 AND @IsAutoInst = 0 THEN 178
									  WHEN @CalculationType = 102 AND @IsAutoInst = 0 THEN 179
									  WHEN @CalculationType = 101 AND @IsAutoInst = 1 THEN 195
									  WHEN @CalculationType = 102 AND @IsAutoInst = 1 THEN 196									  
								  END
										
		, @isExistMatch			= 1
		, @hScore					= CAST(@HomeScore AS INT)
		, @aScore					= CAST(@AwayScore AS INT)
		, @FGLGCheck				= 0

	-- check match validation
	SELECT @sporttype 		= m.sporttype
		, @betstatus		= ISNULL(m.betstatus,'')
		, @hthomescore		= m.hthomescore
		, @htawayscore		= m.htawayscore
		, @finalhomescore	= m.finalhomescore
		, @finalawayscore	= m.finalawayscore
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @matchid

	--SET scores in 1H & 2H
	SELECT @hScore1H	= CASE WHEN @CalculationType = 101 THEN @hScore ELSE ISNULL(@hthomescore, 0) END
		, @aScore1H	= CASE WHEN @CalculationType = 101 THEN @aScore ELSE ISNULL(@htawayscore,0) END 
		, @hScore2H	= CASE WHEN @CalculationType = 102 THEN @hScore-@hScore1H ELSE 0 END
		, @aScore2H	= CASE WHEN @CalculationType = 102 THEN @aScore-@aScore1H ELSE 0 END
		, @GoalRecord	= CASE WHEN LEFT(@GoalRecord, 1) = ';' THEN SUBSTRING(@GoalRecord,2,LEN(@GoalRecord) - 1) ELSE @GoalRecord END
		, @FGNG		= CASE 
						  WHEN LEFT(@GoalRecord, 1) = 'H' THEN '1'  
						  WHEN LEFT(@GoalRecord, 1) = 'A' THEN '2'  
						  ELSE ''
					  END 
		, @FGNG		= CASE WHEN @FGNG <> '' THEN @FGNG + ':1' ELSE '' END
		, @FGLGCheck	= 0
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT @matchid AS matchid
		,1 AS KeyId
			
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode		= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@sporttype IS NULL OR  @ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	-- COLLECT instant Bettypes
	INSERT INTO @instantBettype (bettype)
	SELECT bettype
	FROM dbo.f_Set_Instant_GetBettypes()
	WHERE 1	= CASE 
				WHEN @CalculationType = 101 AND InstantType & 1 = 1 THEN 1
				WHEN @CalculationType = 102 AND InstantType & 2 = 2 THEN 1
				ELSE 0 
			  END
	
	--do instant calculation per batch of tickets
	DECLARE @strInstantTicket	VARCHAR(MAX)
		, @batchCount			INT
		, @batchRowCount		INT
		, @startBatchNo		INT
	
	DECLARE @tempAccountBalance TABLE (custid INT, IsUpdated BIT)
	DECLARE @tempInstantBatch 	TABLE (
		transid 				BIGINT
		, modds 				MONEY
		, custid 				INT
		, balance				MONEY
		, bettype 				SMALLINT
		, BonusID 				INT
		, WalletType 			TINYINT
		, actual_stake			MONEY
		, srecommend			INT
	)
	
	SELECT @batchCount			= 1000 
		,@startBatchNo			= 1

	INSERT INTO #temp_bettrans (TransID, MOdds, CustID, Balance, BetType, BonusID, WalletType,actual_stake, srecommend)
	SELECT TransID = b.transid
		,MOdds = ods.modds
		,CustID = b.custid
		,Balance = b.winlost - b.actual_stake + b.playercomm
		,BetType = b.bettype
		,BonusID = CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
		,WalletType = ISNULL(b.WalletType, 2) -- Cash Wallet as default
		,actual_stake = b.actual_stake -- used to determine cashout tickets that make changes Balance (Captured Before)
		,srecommend = b.srecommend
	FROM dbo.bettrans b WITH(NOLOCK)
		OUTER APPLY [dbo].[f_Set_Instant_CalModds](
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
											) AS ods
	WHERE matchid = @matchid
		AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND b.recommend <> 1688156) --exclude betdaq/betfair
		AND EXISTS(SELECT TOP 1 1 FROM @instantBettype WHERE bettype = b.bettype)
		AND ((b.statusId = 0 AND ISNULL(b.SecAcceptFlag,0)=0)
			 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
			 )	
		AND ods.modds IS NOT NULL
	
	--DO loop Inst.CAL
	WHILE (1=1)
	BEGIN 
		BEGIN TRY
			--CLEAR instant batch & balance table
			DELETE @tempInstantBatch
			DELETE @BalanceWalletBefore
			DELETE @BalanceWalletAfter
			DELETE @CashoutTickets_tmp
			
			DELETE T
			OUTPUT deleted.TransID, deleted.MOdds,deleted.CustID, deleted.Balance, deleted.BetType, deleted.BonusID, deleted.WalletType, deleted.actual_stake, deleted.srecommend
			INTO @tempInstantBatch(transid, modds, custid, balance, bettype, BonusID, WalletType, actual_stake, srecommend)
			FROM (SELECT TOP (@batchCount) *
				  FROM #temp_bettrans 
				  ORDER BY custid
				 ) AS T
				 
			--GATHER string transid to do Inst.CAL
			SELECT @batchRowCount = @@ROWCOUNT
					
			IF @batchRowCount = 0 BREAK -- no more to run
			
			/* for debug
			SET @startBatchNo = @startBatchNo + 1
			PRINT 'BATCH:' + CONVERT(VARCHAR, @startBatchNo)
			*/
			
			SET @ticketCount += @batchRowCount
			SET @strInstantTicket = CAST((SELECT b.transid AS t
												,b.modds AS m 
												,b.actual_stake AS a
												,b.bettype as bt
												,b.srecommend as sr
											FROM @tempInstantBatch b
											FOR XML AUTO) AS VARCHAR(MAX)
										)
			
			IF(@strInstantTicket IS NOT NULL) 
			BEGIN
				
				-------------------------------------------------------------
				---        CAPTURE value BALANCE before settlement        ---
				---------------------------VVVV------------------------------
				INSERT INTO @BalanceWalletBefore (
					matchid
					,custid					
					,balanceType
					,bonusID
					,walletType
					,balance
				)
				SELECT @matchid AS matchid
					, b.custid
					,1 -- Sports
					, b.bonusID
					, b.walletType
					, SUM(b.balance) AS balance
				FROM @tempInstantBatch AS b
				GROUP BY b.custid
					, b.bonusID
					, b.walletType
				
				/* -- for testing cashout tickets happen after capture Balance Before
				RAISERROR ('CASH OUT TICKET PLS', 0, 1) WITH NOWAIT
				WAITFOR DELAY '00:00:15'
				*/	
					
				--DO instant calculation
				EXEC dbo.NAP_Admin_Calculate_Main
					@matchid		= @MatchId
					, @Action 		= @Action
					, @Mode 		= @Mode
					, @strTransIds 	= @strInstantTicket
					, @strTransCashout = @strTransCashout OUTPUT
				
				-- Adjust BL before for affected cashout tickets
				IF @strTransCashout <> ''
				BEGIN
					SET @xmlCashoutTicket = CONVERT(XML, @strTransCashout)
					
					INSERT INTO @CashoutTickets_tmp(transid,custid, balance)
					SELECT T.C.value('./@t', 'BIGINT') 		AS transid
							, T.C.value('./@c', 'INT') 	AS custid
							,T.C.value('./@b', 'MONEY') 	AS balance
					FROM @xmlCashoutTicket.nodes('/b') AS T(C)
					OPTION (OPTIMIZE FOR (@xmlCashoutTicket = NULL ))
					
					UPDATE bf
						SET balance = bf.balance - bl.balance_old + bl.balance_new
					FROM @BalanceWalletBefore bf
						INNER JOIN  (SELECT	c.custid,c.BonusID,c.WalletType, SUM(c.balance) AS balance_old, SUM(tmp.balance) AS balance_new
									 FROM  @CashoutTickets_tmp tmp 
												INNER JOIN @tempInstantBatch C ON c.TransID = tmp.transid AND tmp.custid = c.custid
									 GROUP BY c.custid,c.BonusID,c.WalletType
									 ) AS bl ON bl.custid = bf.custid AND bf.bonusId =  bl.BonusID AND bf.walletType = bl.WalletType
				END
				-------------------------------------------------------------
				---        CAPTURE value BALANCE after settlement        ---
				---------------------------VVVV------------------------------
				INSERT INTO @BalanceWalletAfter (
					matchid
					,custid					
					,balanceType
					,bonusID
					,walletType
					,balance
				)
				SELECT @matchid AS matchid 
					, t.custid
					,1 -- Sports
					, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
					, ISNULL(b.WalletType, 2) AS WalletType -- Cash Wallet as default
					, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM dbo.bettrans b WITH(ROWLOCK)
					INNER JOIN @tempInstantBatch AS t ON b.transid = t.transid
				GROUP BY t.custid
					, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
					, ISNULL(b.WalletType, 2)
				
				---INSERT data into pending balance table   
				EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				@BalanceWalletBefore	= @BalanceWalletBefore
				, @BalanceWalletAfter	= @BalanceWalletAfter
				
				-- capture acc has updated balanced
				INSERT INTO @tempAccountBalance (custid, IsUpdated)
				SELECT b.custid
					, CASE WHEN b.balance <> a.balance THEN 1 ELSE 0 END AS IsUpdated
				FROM @BalanceWalletBefore b
					INNER JOIN @BalanceWalletAfter a 
					ON b.custid = a.custid
			END

		END TRY
		BEGIN CATCH
			--capture balance with error
			INSERT INTO @BalanceWalletAfter (
				matchid
				,custid					
				,balanceType
				,bonusID
				,walletType
				,balance
			)
			SELECT @matchid AS matchid 
				, t.custid
				, 1 -- Sports
				, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
				, ISNULL(b.WalletType, 2) -- Cash Wallet as default
				, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM dbo.bettrans b WITH(ROWLOCK)
				INNER JOIN @tempInstantBatch t ON b.transid = t.transid
			GROUP BY t.custid
				, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
				, ISNULL(b.WalletType, 2)
							
			---INSERT data into pending balance table   
			EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			, @BalanceWalletAfter	= @BalanceWalletAfter
			
			--SET ERROR code
			SELECT @ErrCode = 1001017, @ErrMsg = ERROR_MESSAGE()
				
			BREAK
		END CATCH
	END
	
	--Exit process with ERROR
	IF(@ErrCode <> 0) 
	BEGIN
		------ releasing Settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= @isExistMatch
			, @IsReleased		= 1
		RETURN
	END
		
	SELECT @SourceID = CASE WHEN @IsAutoInst = 0 THEN 100 ELSE 5 END
	
	--UPDATE back to AutoPayoutResult
	EXEC DBPRO.BODB02.dbo.NAP_Set_AutoPayoutResultUpd @MatchId = @matchid, @TypeId = @CalculationType, @StatusId = 2, @IsIncludedUpdateMatch = 1, @SourceID = @SourceID --Completed
	
	;WITH cteFGLGTicket
	AS
	(
		SELECT	MAX(CASE WHEN bettype = 127 THEN 1 ELSE 0 END) AS HasSettledHTFGLGTicket
				,MAX(CASE WHEN bettype = 14 THEN 1 ELSE 0 END) AS HasSettledFTFGLGTicket
		FROM	dbo.bettrans WITH (NOLOCK)
		WHERE	matchid = @MatchId
				AND bettype IN (14, 127)
				AND statusId BETWEEN 112 AND 113
		GROUP BY matchid
	)
	SELECT @FGLGCheck = CASE
							WHEN @Mode = 'INST-HT' 
								THEN CASE 
										WHEN HasSettledHTFGLGTicket = 1 AND HasSettledFTFGLGTicket = 1 THEN 3
										WHEN HasSettledFTFGLGTicket = 1 THEN 2
										WHEN HasSettledHTFGLGTicket = 1 THEN 1
										ELSE 0
									END
							ELSE CASE	-- 'INST-FT'
									WHEN HasSettledFTFGLGTicket = 1 THEN 2
									ELSE 0
								END
						END
	FROM	cteFGLGTicket
	
	--UPDATE back to match's betstatus
	IF(@FGLGCheck > 0) -- The first time to do IS
	BEGIN
		--SET betstatus
		SELECT @betstatus	= ISNULL(@betstatus,'')
			,@FLValue		= CASE 
								WHEN LEFT(@GoalRecord, 1) = 'H' THEN '1-0;'  
								WHEN LEFT(@GoalRecord, 1) = 'A' THEN '2-0;'  
							END
		IF CHARINDEX ('1FL', @betstatus) = 0
			SELECT @betstatus	= CASE WHEN CHARINDEX('1FL', @betstatus) > 0 THEN REPLACE(@betstatus, SUBSTRING(@betstatus,CHARINDEX('1FL', @betstatus), 8), '') ELSE @betstatus END
				, @betstatus	+= '1FL:' + @FLValue 
			WHERE @FGLGCheck & 1 = 1
		
		IF CHARINDEX ('FL', REPLACE(@betstatus, CASE WHEN CHARINDEX('1FL', @betstatus) > 0 THEN SUBSTRING(@betstatus, CHARINDEX('1FL', @betstatus),8) ELSE '' END,'')) = 0			
			SELECT @betstatus	= CASE WHEN CHARINDEX(';FL', @betstatus) > 0 THEN REPLACE(@betstatus, SUBSTRING(@betstatus,CHARINDEX(';FL', @betstatus), 8), '') ELSE @betstatus END
				, @betstatus	+= 'FL:' + @FLValue 
			WHERE @FGLGCheck & 2 = 2
		
		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
            @Command         = 'NAP_Admin_Settlement_1_InstantCalculation'
            ,@MatchID        = @matchid
            ,@creator        = @creator
			,@BetStatus 	 = @betstatus
		
		IF @ResourceResult IS NOT NULL	
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
				@Command        = 'NAP_Admin_Settlement_1_InstantCalculation-CAL',
				@MatchID        = @MatchID,                  
				@ResourceResult	= @ResourceResult,                    
				@creator        = @creator
	END
	
	--SET @TotalAccount_Updated
	SELECT @TotalAccount 		= COUNT(1)
		, @TotalAccount_Updated = SUM(CASE WHEN acc.IsUpdated = 1 THEN 1 ELSE 0 END)
	FROM (
		SELECT DISTINCT custid, IsUpdated
		FROM @tempAccountBalance
	) AS acc
	
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP
	
	--RESET final scores
	SELECT @hthomescore		=  CASE WHEN @CalculationType = 101 THEN @hScore ELSE @hthomescore END
		, @htawayscore		=  CASE WHEN @CalculationType = 101 THEN @aScore ELSE @htawayscore END
		, @finalhomescore	=  CASE WHEN @CalculationType = 102 THEN @hScore ELSE @finalhomescore END
		, @finalawayscore	=  CASE WHEN @CalculationType = 102 THEN @aScore ELSE @finalawayscore END
			
	SELECT @LogData = 'NAP: Instant Calculate (' + @Mode + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
		+ ' Score:' + CAST(ISNULL(@homescore, 0) AS NVARCHAR(10)) + '-' + CAST(ISNULL(@awayscore, 0) AS NVARCHAR(10)) 
		+ ' Instant action:' + CAST(@Mode AS NVARCHAR(10)) 
		+ ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.WriteLog_UserLog @UserID = @creator, @Doing = @LogData
	
	IF @IsAutoInst = 0		
	BEGIN
	SELECT @Remark ='NAP: Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms;' 
							+ ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
							+ ' Bal:' + CAST(ISNULL(@TotalAccount_Updated, 0) AS VARCHAR(20)) + '/' +	CAST(ISNULL(@TotalAccount, 0) AS VARCHAR(20))

	END


	IF @IsAutoInst = 1 
	BEGIN
	SELECT @Remark ='NAP: Source:' + @Source + (CASE WHEN @ErrCode > 0  THEN ' Failed: ' + @ErrMsg ELSE '' END)	
							+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms;' 
							+ ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
							+ ' Bal:' + CAST(ISNULL(@TotalAccount_Updated, 0) AS VARCHAR(20)) + '/' +	CAST(ISNULL(@TotalAccount, 0) AS VARCHAR(20))	
	END
							
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
	
	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess
	DROP TABLE #temp_bettrans
		
	RETURN;
END

GO