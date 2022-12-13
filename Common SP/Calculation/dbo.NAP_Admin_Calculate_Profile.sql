/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Profile]
	@matchid		INT = 0
	,@transIds		VARCHAR(MAX) = ''
	,@SettlementProcessingId BIGINT
	,@ServerAlias VARCHAR(50) = ''
	,@ServerName SYSNAME = ''
	,@modds MONEY
	,@IsMarked BIT
	,@OddsType SMALLINT
	,@ActionId INT = 0
	,@SessionId BIGINT = 0
	,@ErrMessage VARCHAR(300) = '' OUTPUT
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20220926@Louisa: Fix issue cannot syn modds NULL from SiteDB to CentralDB [Redmine:178189]
		- 20221010@Kathy: Do not upd odds, oddsspread of bettype 468 if refund [Redmine:#178941]
		- 20221019@Kathy: Add ActionId [Redmine:#179274]
		- 20221025@Louisa: Use Json log format for soccer [Redmine:#179449]
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]
		- 20221011@Kathy: Using Json [Redmine:#178694]

	Param's Explanation:  
		   
		@transIds = '<root>
						<r t="104730774034"/>
						<r t="104729373985"/>
					</root>'
					t:  transid
					so:  ScoreBoxOdds
					ss: ScoreBoxScore
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @AllowCalculation	BIT
			,@AllowRefund BIT
			,@Action VARCHAR(20)
			
	SET @ServerName = CASE WHEN ISNULL(@ServerName,'') = '' THEN @@SERVERNAME ELSE @ServerName END
	SET @Action = CASE 
					WHEN @ActionID BETWEEN 100 AND 102 OR @ActionId IN (157,158) THEN 'CAL' 
					WHEN @ActionID BETWEEN 109 AND 111 THEN 'REFUND'
				END
				
	IF @ServerName <> @@SERVERNAME
		RETURN

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT
			,@AllowRefund		= @AllowRefund OUTPUT
			
		IF @AllowCalculation = 0 AND @Action = 'CAL'
			RETURN
			
		IF @AllowRefund = 0 AND @Action = 'REFUND' 
			RETURN

	END
	-----------------------CHECK SERVER-----------------------------------------
	
	DECLARE @commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@commHalfWLRate	SMALLMONEY
			,@odds				SMALLMONEY
			,@winlost			MONEY
			,@stake				MONEY
			,@statusId			TINYINT
			,@IsUpd_Void		BIT = 0
			,@xml				XML
			,@batchno			INT = 2000
			,@settlementTime	DATETIME
			,@CheckNegativeBalance INT = 0
			,@StepDone			VARCHAR(300) = 'Done update'
			,@FcUpdateTime		DATETIME2
			
			,@transInfo		NVARCHAR(MAX)
			,@IsSiteDB		BIT = 0
			,@FunctionName	VARCHAR(50)
	
	DECLARE @tmpTransId TABLE (transid BIGINT PRIMARY KEY, ScoreBoxOdds MONEY, ScoreBoxScore INT)
	DECLARE @tmpBalanceChanged TABLE (CustId INT, Balance MONEY, WalletType INT, BonusId INT, BonusStatus INT DEFAULT(0), MatchId INT
			,transId BIGINT
			,modds MONEY, odds SMALLMONEY, oddsspread MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT,FcUpdateTime DATETIME2

			,bef_winlost MONEY
			,bef_statusid TINYINT
	)

	SET @xml = CAST(@transIds AS XML)

	IF @OddsType <> 2 -- Has ScoreBox bettype
	BEGIN
		INSERT INTO @tmpTransId (TransID)
		SELECT	T.C.value('./@t', 'bigint') AS transid
		FROM	@xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
	END
	ELSE
	BEGIN
		INSERT INTO @tmpTransId (TransID, ScoreBoxOdds, ScoreBoxScore)
		SELECT	T.C.value('./@t', 'bigint') AS transid
				,T.C.value('./@so', 'MONEY') AS ScoreBoxOdds
				,T.C.value('./@ss', 'MONEY') AS ScoreBoxScore
		FROM	@xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))

		SET @OddsType = 0
	END

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL
			AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLogIns','P') IS NOT NULL 
		SET @IsSiteDB = 1

	SET @settlementTime = GETDATE()	
	SET @FcUpdateTime = SYSDATETIME()
		
	IF @ServerAlias = 'DBTXN' OR @IsSiteDB = 1
	BEGIN
		BEGIN TRY
			UPDATE TOP(@batchno)  b
			SET
				@commWinRate = CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
									WHEN '0' THEN 1
									WHEN '1' THEN 0
									ELSE 1 END
				,@commLostRate = CASE b.comstatus
									WHEN '0' THEN 1
									WHEN '1' THEN 2
									ELSE 1 END
				,@commHalfWLRate = 0.5
				,@odds = (CASE	
								WHEN b.bettype IN (468, 469) THEN t.ScoreBoxOdds
								WHEN b.odds < 0 THEN 1 
	   							WHEN @oddstype = 1 THEN b.odds - 1  ----/*DECIMAL ONLY*/
								ELSE b.odds END)
				----------------------------------------------------------------------------------------------------------------
				,@IsUpd_Void = CASE WHEN b.statusID = 102 OR @IsMarked = 1 THEN 0 ELSE 1 END
				,modds = @modds
				,odds = CASE 
							WHEN b.bettype IN (468, 469) AND @modds IS NOT NULL THEN @odds 
							ELSE b.odds END
				,oddsspread = CASE 
								WHEN b.bettype IN (468, 469)  AND @modds IS NOT NULL THEN t.ScoreBoxScore 
								ELSE b.oddsspread END				
				,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
										WHEN @modds = 0.25 THEN 1 
										WHEN @modds = 0 AND b.oddstype <> 6 THEN 0 
										WHEN @modds = 0 AND b.oddstype = 6 
											THEN CASE
													WHEN b.oddsspread = 0 THEN 0
													WHEN b.oddsspread > 0 THEN 2
													ELSE 4
												END
										WHEN @modds = - 0.25 THEN 3
										WHEN @modds < - 0.25 THEN 4
										WHEN @modds IS NULL THEN 6
									END 			   	
				,@winlost = CASE
						WHEN @modds >  0.25 THEN b.actual_stake + b.stake * @odds
						WHEN @modds =  0.25 THEN b.actual_stake + b.stake * @odds * 0.5						
						WHEN @modds =  0 AND b.oddstype <> 6 THEN b.actual_stake
						WHEN @modds =  0 AND b.oddstype = 6 
							THEN CASE 
									WHEN b.oddsspread = 0 THEN b.actual_stake
									WHEN b.oddsspread > 0 THEN b.actual_stake + b.stake * b.odds * (b.oddsspread/100) -- oddsspread > 0: WON
									ELSE b.actual_stake * (1 - ABS(b.oddsspread/100))  -- oddsspread < 0: LOSE
								END
						WHEN @modds = -0.25 THEN actual_stake * 0.5
						WHEN @modds < -0.25 THEN CASE	
													WHEN b.bettype IN(468, 469) THEN b.actual_stake + b.stake * @odds
													ELSE 0
												END
						WHEN @modds IS NULL THEN b.actual_Stake
						END 	
				,@stake = b.stake
				-- check winlost or status change to update SettlementTime
				,@statusId = CASE
								WHEN @modds > 0 THEN 112 --WON
								WHEN @modds = 0 AND b.oddstype <> 6 THEN 111 --DRAW
								WHEN @modds = 0 AND b.oddstype = 6 
									THEN CASE 
											WHEN b.oddsspread = 0 THEN 111 
											WHEN b.oddsspread > 0 THEN 112
											ELSE 113
										END
								WHEN @modds < 0 THEN 113 --LOSE
								WHEN @modds IS NULL THEN 103 -- REFUND
							END
				,SettlementTime = CASE 
										WHEN @IsUpd_Void = 0 THEN b.SettlementTime 
										ELSE CASE WHEN b.winlost <> @winlost OR b.statusID <> @statusId THEN @settlementTime ELSE b.SettlementTime END
									END
						
				,WinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN WinLost 
								ELSE @winlost
							END
				,aWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN aWinLost 
								ELSE CASE
										WHEN @modds >  0.25 THEN b.stake * @odds * -b.apositiontaking
										WHEN @modds =  0.25 THEN b.stake * @odds * -b.apositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6    THEN 0
										WHEN @modds =  0 AND b.oddstype = 6    
											THEN CASE 
													WHEN b.oddsspread = 0 THEN 0
													WHEN b.oddsspread > 0 THEN b.stake * b.odds * (b.oddsspread/100) * -b.apositiontaking -- oddsspread > 0: WON
													ELSE b.actual_stake * ABS(b.oddsspread/100) * b.apositiontaking -- oddsspread < 0: LOSE
												END
										WHEN @modds = -0.25 THEN b.actual_stake * b.apositiontaking * 0.5
										WHEN @modds < -0.25 THEN CASE 
																	WHEN b.bettype IN (468, 469) THEN b.stake * @odds * (-b.apositiontaking) 
																	ELSE b.actual_stake * b.apositiontaking
																END
										WHEN @modds IS NULl THEN 0
									END
							END
							
				,mWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN b.mWinLost 
								ELSE CASE
										WHEN @modds >  0.25 THEN b.stake * @odds * -b.mpositiontaking
										WHEN @modds =  0.25 THEN b.stake * @odds * -b.mpositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
										WHEN @modds =  0 AND b.oddstype = 6        
											THEN CASE 
													WHEN oddsspread = 0 THEN 0
													WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
													ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
												END
										WHEN @modds = -0.25 THEN b.actual_stake * b.mpositiontaking * 0.5
										WHEN @modds < -0.25 THEN CASE 
																	WHEN b.bettype IN (468, 469) THEN b.stake * @odds * (-b.mpositiontaking) 
																	ELSE b.actual_stake * b.mpositiontaking
																END
										WHEN @modds IS NULl THEN 0
									END
							END
					
				,sWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN b.sWinLost 
								ELSE CASE
										WHEN @modds >  0.25 THEN b.stake * @odds * -b.spositiontaking
										WHEN @modds =  0.25 THEN stake * @odds * -b.spositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
										WHEN @modds =  0 AND b.oddstype = 6       
											THEN CASE 
													WHEN oddsspread = 0 THEN 0
													WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
													ELSE actual_stake * ABS(oddsspread/100) * spositiontaking 
												END
										WHEN @modds = -0.25 THEN b.actual_stake * b.spositiontaking * 0.5
										WHEN @modds < -0.25 THEN CASE 
																	WHEN b.bettype IN (468, 469) THEN b.stake * @odds * (-b.spositiontaking) 
																	ELSE b.actual_stake * b.spositiontaking
																END
										WHEN @modds IS NULl THEN 0
									END
							END

				,PlayerComm = CASE 
								WHEN @IsUpd_Void = 0 THEN PlayerComm 
								ELSE CASE
										WHEN @modds >  0.25 THEN @commWinRate * b.playerdiscount * @stake
										WHEN @modds =  0.25 THEN @commWinRate * b.playerdiscount * @stake * @commHalfWLRate
										WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
										WHEN @modds =  0 AND b.oddstype = 6        
											THEN CASE
													WHEN oddsspread = 0 THEN 0
													WHEN oddsspread > 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100)
													ELSE @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
												END
										WHEN @modds = -0.25 THEN @commLostRate * b.playerdiscount * @stake * @commHalfWLRate
										WHEN @modds < -0.25 THEN @commLostRate * b.playerdiscount * @stake
										WHEN @modds IS NULl THEN 0
									END
							END
					
				,Comm = CASE 
							WHEN @IsUpd_Void = 0 THEN Comm 
							ELSE CASE
									WHEN @modds >  0.25 THEN @commWinRate * b.discount * @stake * (1-b.apositiontaking)
									WHEN @modds =  0.25 THEN @commWinRate * b.discount * @stake * (1-b.apositiontaking) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
									WHEN @modds =  0 AND b.oddstype = 6       
										THEN CASE 
												WHEN oddsspread = 0 THEN 0
												WHEN oddsspread > 0 THEN @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
												ELSE @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
											END
									WHEN @modds = -0.25 THEN @commLostRate * b.discount * @stake * (1-b.apositiontaking) * @commHalfWLRate
									WHEN @modds < -0.25 THEN @commLostRate * b.discount * @stake * (1-b.apositiontaking)
									WHEN @modds IS NULl THEN 0
								END
						END
					
				,aComm = CASE 
							WHEN @IsUpd_Void = 0 THEN aComm 
							ELSE CASE
									WHEN @modds >  0.25 THEN @commWinRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking))
									WHEN @modds =  0.25 THEN @commWinRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6        
										THEN CASE
												WHEN oddsspread = 0 THEN 0
												WHEN oddsspread > 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
												ELSE @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
											END
									WHEN @modds = -0.25 THEN @commLostRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds < -0.25 THEN @commLostRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking))
									WHEN @modds IS NULl THEN 0
								END
						END
					
				,sComm = CASE 
							WHEN @IsUpd_Void = 0 THEN sComm 
							ELSE CASE
									WHEN @modds >  0.25 THEN @commWinRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
									WHEN @modds =  0.25 THEN @commWinRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6        
										THEN CASE
												WHEN oddsspread = 0 THEN 0
												WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
												ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
											END
									WHEN @modds = -0.25 THEN @commLostRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds < -0.25 THEN @commLostRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
									WHEN @modds IS NULl THEN 0
								END
						END
					
				,Status = CASE 
							WHEN @IsUpd_Void = 0 THEN Status 
							ELSE CASE
									WHEN @modds > 0 THEN 'WON'
									WHEN @modds = 0 AND b.oddstype <> 6 THEN 'DRAW'
									WHEN @modds = 0 AND b.oddstype = 6 
										THEN CASE 
												WHEN oddsspread = 0 THEN 'DRAW' 
												WHEN oddsspread > 0 THEN 'WON'
												ELSE 'LOSE'
											END
									WHEN @modds < 0 THEN 'LOSE'
									WHEN @modds IS NULl THEN 'Refund'
								END
						END
				,StatusID = CASE 
								WHEN @IsUpd_Void = 0 THEN b.StatusID 
								ELSE @statusId
							END
				,ruben=CASE 
							WHEN @IsUpd_Void = 0 THEN b.ruben 
							ELSE 1
						END
				,FcUpdateTime = CASE WHEN @statusId = 103 THEN @FcUpdateTime ELSE b.FcUpdateTime END
			OUTPUT	deleted.custid
					,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
					,inserted.WalletType
					,inserted.BonusID
					,inserted.matchId

					,inserted.transid
					,inserted.modds, inserted.odds, inserted.oddsspread, inserted.statuswinlost
					,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
					,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
					,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
					,inserted.Status,inserted.StatusID,inserted.ruben
					,CASE WHEN inserted.FcUpdateTime <> deleted.FcUpdateTime THEN inserted.FcUpdateTime ELSE NULL END

					,deleted.winlost
					,deleted.statusid		
			INTO @tmpBalanceChanged (
				CustId, Balance, WalletType, BonusId, MatchId
				
				,transId
				,modds, odds, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
				,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,FcUpdateTime

				,bef_winlost, bef_statusid
			)
			FROM @tmpTransId t
				INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
					ON  t.transid = b.transid 
			WHERE	 ISNULL(b.betdaqid,0) <> -2 
			OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
		
			SET @StepDone = @StepDone + ' bettrans'

			SELECT TOP 1 @matchid = MatchId
			FROM	@tmpBalanceChanged

			IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpBalanceChanged )
			BEGIN
				SET @transInfo = (
					SELECT	transId AS 't'
							,CASE WHEN modds IS NOT NULL THEN CAST(CAST(modds AS DECIMAL(10,4)) AS VARCHAR(11) ) ELSE ''  END AS 'm'
							,odds AS 'o'
							,oddsspread AS 'os' 
							,SettlementTime AS 'st' 
							,WinLost AS 'w' 
							,aWinLost AS 'aw' 
							,mWinLost AS 'mw' 
							,sWinLost AS 'sw' 
							,statuswinlost AS 'statuswl' 
							,PlayerComm AS 'pc' 
							,Comm AS 'c' 
							,aComm AS 'ac' 
							,sComm AS 'sc' 
							,Status AS 's' 
							,StatusID AS 'sid' 
							,ruben AS 'r' 
							,FcUpdateTime AS 'rut' 
							,bef_winlost AS 'bef_w' 
							,bef_statusid AS 'bef_sid' 
					
					FROM	@tmpBalanceChanged
					FOR JSON AUTO
				)

				SET @FunctionName = CASE WHEN @Action = 'REFUND' THEN 'RefundSoccer' ELSE 'CalculateSoccer' END
				
				EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns
					@SystemName		= 'Settlement'
					,@FunctionName	= @FunctionName
					,@TableName		= 'SiteDB_SettlementProcessing'
					,@MatchId		= @MatchId 
					,@Action		= 'I'
					,@TicketType	= 's'
					,@SettlementAction = @Action
					,@SessionId		= @SessionId
					,@IsParallel	= 1
					,@transInfoJson		= @transInfo
			END

			-- balance
			IF EXISTS (SELECT TOP 1 1 FROM @tmpBalanceChanged WHERE WalletType = 1)
			BEGIN				
				UPDATE t 
					SET BonusStatus = bw.StatusID
				FROM	@tmpBalanceChanged t
					INNER JOIN dbo.BonusWalletCredit bw WITH(NOLOCK)
						ON	t.CustId = bw.CustID
							AND t.BonusId = bw.BonusID
				WHERE	t.WalletType = 1
						AND t.BonusId > 0
						
				BEGIN TRY	
					INSERT INTO dbo.BonusWalletPending	(
						CustID
						, BonusID
						, Amount
					)
					SELECT 	bn.CustID
							, bn.BonusID
							, SUM(bn.balance) AS Amount
					FROM 	@tmpBalanceChanged bn
					WHERE 	bn.walletType			= 1
							AND bn.bonusID			> 0
					GROUP BY bn.CustId
							,bn.BonusId
					HAVING SUM(bn.balance) <> 0
					
					SET @StepDone = @StepDone + ', BonusWalletPending'
				END TRY	
				BEGIN CATCH
				
					INSERT INTO dbo.BalanceErr ( Custid, BalanceGroup, BalanceAmt, ExecutedSP, ErrMsg, BonusID)
					SELECT	bn.Custid
							, 1 AS BalanceGroup
							, SUM(bn.balance) AS BalanceAmt
							, 'NAP_Admin_Calculate_Profile' AS ExecutedSP
							, LEFT(ERROR_MESSAGE(),500) AS ErrMsg
							, bn.BonusID
					FROM	@tmpBalanceChanged bn
					WHERE	bn.walletType			= 1
							AND bn.bonusID			> 0
					GROUP BY bn.CustId
							,bn.BonusId
					HAVING SUM(bn.balance) <> 0					
				END CATCH
			END

			INSERT INTO dbo.BalCreditSportsPending (custid, balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@tmpBalanceChanged t
			WHERE	BonusStatus NOT IN (1,3)
			GROUP BY custid
			HAVING SUM(Balance) > 0
			
			SET @StepDone = @StepDone + ', BalCreditSportsPending'

			INSERT INTO dbo.BalDebitSportsPending(custid, balance)
			SELECT	custid, ABS(SUM(Balance)) Balance
			FROM	@tmpBalanceChanged t
			WHERE	BonusStatus NOT IN (1,3)
			GROUP BY custid
			HAVING SUM(Balance) < 0
			SET @CheckNegativeBalance = @@ROWCOUNT
			
			SET @StepDone = @StepDone + ', BalDebitSportsPending'

			IF @CheckNegativeBalance <> 0
			BEGIN
				INSERT INTO [bodb02].[dbo].[BalanceNegative] (
					[ExecDate]
					,[MatchID]
					,[ActionID]
					,[GroupID]
					,[CustID]
					,[Balance]
					,[StatusID]
					,[Remark]
				)
				SELECT	GETDATE()
						,@MatchID
						,@ActionId
						,1 AS GroupID 
						,CustID
						,SUM(Balance)
						,0
						,NULL
				FROM	@tmpBalanceChanged bal
				WHERE	bal.BonusStatus NOT IN (1,3)
				GROUP BY bal.CustId
				HAVING SUM(Balance) < 0
			END

			SET @StepDone = @StepDone + ', BalanceNegative'

			IF EXISTS (SELECT TOP 1 1 FROM @tmpBalanceChanged WHERE BonusStatus IN (1,3))
			BEGIN
				INSERT INTO dbo.BonusAdjustmentTransfer(
					LogDate
					, ExecDate
					, CustID
					, MatchID
					, BonusID
					, StatusID
					, Amount
					, isTransferred
				)
				SELECT 
						CURRENT_TIMESTAMP AS LogDate
						, CURRENT_TIMESTAMP AS ExecDate
						, bal.custid
						, @MatchID
						, bal.BonusId
						, bal.BonusStatus
						, SUM(bal.balance) AS Amount
						, 0 AS isTransferred
				FROM	@tmpBalanceChanged bal 
				WHERE	BonusStatus in (1,3)
				GROUP BY CustId, BonusId, BonusStatus
				HAVING SUM(balance) <> 0
			END

			SET @StepDone = @StepDone + ', BonusAdjustmentTransfer'

			DELETE 
			FROM	dbo.SettlementProcessing 
			WHERE	id = @SettlementProcessingId
					
		END TRY
		BEGIN CATCH
			SET @ErrMessage = @StepDone + 'Error: ' + ERROR_MESSAGE()

			UPDATE	dbo.SettlementProcessing
				SET StatusId = 3 -- failed
			WHERE	Id = @SettlementProcessingId
		END CATCH

		RETURN
	END 
	ELSE
	BEGIN
		UPDATE TOP(@batchno)  b
			SET
				@commWinRate = CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
									WHEN '0' THEN 1
									WHEN '1' THEN 0
									ELSE 1 END
				,@commLostRate = CASE b.comstatus
									WHEN '0' THEN 1
									WHEN '1' THEN 2
									ELSE 1 END
				,@commHalfWLRate = 0.5
				,@odds = (CASE	
								WHEN b.bettype IN (468, 469) THEN t.ScoreBoxOdds
								WHEN b.odds < 0 THEN 1 
	   							WHEN @oddstype = 1 THEN b.odds - 1  ----/*DECIMAL ONLY*/
								ELSE b.odds END)
				----------------------------------------------------------------------------------------------------------------
				,@IsUpd_Void = CASE WHEN b.statusID = 102 OR @IsMarked = 1 THEN 0 ELSE 1 END
				,modds = @modds
				,odds = CASE 
							WHEN b.bettype IN (468, 469) AND @modds IS NOT NULL THEN @odds 
							ELSE b.odds END
				,oddsspread = CASE 
								WHEN b.bettype IN (468, 469)  AND @modds IS NOT NULL THEN t.ScoreBoxScore 
								ELSE b.oddsspread END
				,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
										WHEN @modds = 0.25 THEN 1 
										WHEN @modds = 0 AND b.oddstype <> 6 THEN 0 
										WHEN @modds = 0 AND b.oddstype = 6 
											THEN CASE
													WHEN b.oddsspread = 0 THEN 0
													WHEN b.oddsspread > 0 THEN 2
													ELSE 4
												END
										WHEN @modds = - 0.25 THEN 3
										WHEN @modds < - 0.25 THEN 4
										WHEN @modds IS NULL THEN 6
									END 			   	
				,@winlost = CASE
						WHEN @modds >  0.25 THEN b.actual_stake + b.stake * @odds
						WHEN @modds =  0.25 THEN b.actual_stake + b.stake * @odds * 0.5						
						WHEN @modds =  0 AND b.oddstype <> 6 THEN b.actual_stake
						WHEN @modds =  0 AND b.oddstype = 6 
							THEN CASE 
									WHEN b.oddsspread = 0 THEN b.actual_stake
									WHEN b.oddsspread > 0 THEN b.actual_stake + b.stake * b.odds * (b.oddsspread/100) -- oddsspread > 0: WON
									ELSE b.actual_stake * (1 - ABS(b.oddsspread/100))  -- oddsspread < 0: LOSE
								END
						WHEN @modds = -0.25 THEN actual_stake * 0.5
						WHEN @modds < -0.25 THEN CASE	
													WHEN b.bettype IN(468, 469) THEN b.actual_stake + b.stake * @odds
													ELSE 0
												END
						WHEN @modds IS NULl THEN b.actual_stake
						END 	
				,@stake = b.stake
				-- check winlost or status change to update SettlementTime
				,@statusId = CASE
								WHEN @modds > 0 THEN 112 --WON
								WHEN @modds = 0 AND b.oddstype <> 6 THEN 111 --DRAW
								WHEN @modds = 0 AND b.oddstype = 6 
									THEN CASE 
											WHEN b.oddsspread = 0 THEN 111 
											WHEN b.oddsspread > 0 THEN 112
											ELSE 113
										END
								WHEN @modds < 0 THEN 113 --LOSE
								WHEN @modds IS NULl THEN 103 -- Refund
							END
				,SettlementTime = CASE 
										WHEN @IsUpd_Void = 0 THEN b.SettlementTime 
										ELSE CASE WHEN b.winlost <> @winlost OR b.statusID <> @statusId THEN @settlementTime ELSE b.SettlementTime END
									END
						
				,WinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN WinLost 
								ELSE @winlost
							END
				,aWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN aWinLost 
								ELSE CASE
										WHEN @modds >  0.25 THEN b.stake * @odds * -b.apositiontaking
										WHEN @modds =  0.25 THEN b.stake * @odds * -b.apositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6    THEN 0
										WHEN @modds =  0 AND b.oddstype = 6    
											THEN CASE 
													WHEN b.oddsspread = 0 THEN 0
													WHEN b.oddsspread > 0 THEN b.stake * b.odds * (b.oddsspread/100) * -b.apositiontaking -- oddsspread > 0: WON
													ELSE b.actual_stake * ABS(b.oddsspread/100) * b.apositiontaking -- oddsspread < 0: LOSE
												END
										WHEN @modds = -0.25 THEN b.actual_stake * b.apositiontaking * 0.5
										WHEN @modds < -0.25 THEN CASE 
																	WHEN b.bettype IN (468, 469) THEN b.stake * @odds * (-b.apositiontaking) 
																	ELSE b.actual_stake * b.apositiontaking
																END
										WHEN @modds IS NULl THEN 0
									END
							END
							
				,mWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN b.mWinLost 
								ELSE CASE
										WHEN @modds >  0.25 THEN b.stake * @odds * -b.mpositiontaking
										WHEN @modds =  0.25 THEN b.stake * @odds * -b.mpositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
										WHEN @modds =  0 AND b.oddstype = 6        
											THEN CASE 
													WHEN oddsspread = 0 THEN 0
													WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
													ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
												END
										WHEN @modds = -0.25 THEN b.actual_stake * b.mpositiontaking * 0.5
										WHEN @modds < -0.25 THEN CASE 
																	WHEN b.bettype IN (468, 469) THEN b.stake * @odds * (-b.mpositiontaking) 
																	ELSE b.actual_stake * b.mpositiontaking
																END
										WHEN @modds IS NULl THEN 0
									END
							END
					
				,sWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN b.sWinLost 
								ELSE CASE
										WHEN @modds >  0.25 THEN b.stake * @odds * -b.spositiontaking
										WHEN @modds =  0.25 THEN stake * @odds * -b.spositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
										WHEN @modds =  0 AND b.oddstype = 6       
											THEN CASE 
													WHEN oddsspread = 0 THEN 0
													WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
													ELSE actual_stake * ABS(oddsspread/100) * spositiontaking 
												END
										WHEN @modds = -0.25 THEN b.actual_stake * b.spositiontaking * 0.5
										WHEN @modds < -0.25 THEN CASE 
																	WHEN b.bettype IN (468, 469) THEN b.stake * @odds * (-b.spositiontaking) 
																	ELSE b.actual_stake * b.spositiontaking
																END
										WHEN @modds IS NULl THEN 0
									END
							END

				,PlayerComm = CASE 
								WHEN @IsUpd_Void = 0 THEN PlayerComm 
								ELSE CASE
										WHEN @modds >  0.25 THEN @commWinRate * b.playerdiscount * @stake
										WHEN @modds =  0.25 THEN @commWinRate * b.playerdiscount * @stake * @commHalfWLRate
										WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
										WHEN @modds =  0 AND b.oddstype = 6        
											THEN CASE
													WHEN oddsspread = 0 THEN 0
													WHEN oddsspread > 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100)
													ELSE @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
												END
										WHEN @modds = -0.25 THEN @commLostRate * b.playerdiscount * @stake * @commHalfWLRate
										WHEN @modds < -0.25 THEN @commLostRate * b.playerdiscount * @stake
										WHEN @modds IS NULl THEN 0
									END
							END
					
				,Comm = CASE 
							WHEN @IsUpd_Void = 0 THEN Comm 
							ELSE CASE
									WHEN @modds >  0.25 THEN @commWinRate * b.discount * @stake * (1-b.apositiontaking)
									WHEN @modds =  0.25 THEN @commWinRate * b.discount * @stake * (1-b.apositiontaking) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
									WHEN @modds =  0 AND b.oddstype = 6       
										THEN CASE 
												WHEN oddsspread = 0 THEN 0
												WHEN oddsspread > 0 THEN @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
												ELSE @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
											END
									WHEN @modds = -0.25 THEN @commLostRate * b.discount * @stake * (1-b.apositiontaking) * @commHalfWLRate
									WHEN @modds < -0.25 THEN @commLostRate * b.discount * @stake * (1-b.apositiontaking)
									WHEN @modds IS NULl THEN 0
								END
						END
					
				,aComm = CASE 
							WHEN @IsUpd_Void = 0 THEN aComm 
							ELSE CASE
									WHEN @modds >  0.25 THEN @commWinRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking))
									WHEN @modds =  0.25 THEN @commWinRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6        
										THEN CASE
												WHEN oddsspread = 0 THEN 0
												WHEN oddsspread > 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
												ELSE @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
											END
									WHEN @modds = -0.25 THEN @commLostRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds < -0.25 THEN @commLostRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking))
									WHEN @modds IS NULl THEN 0
								END
						END
					
				,sComm = CASE 
							WHEN @IsUpd_Void = 0 THEN sComm 
							ELSE CASE
									WHEN @modds >  0.25 THEN @commWinRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
									WHEN @modds =  0.25 THEN @commWinRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6        
										THEN CASE
												WHEN oddsspread = 0 THEN 0
												WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
												ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
											END
									WHEN @modds = -0.25 THEN @commLostRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
									WHEN @modds < -0.25 THEN @commLostRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
									WHEN @modds IS NULl THEN 0
								END
						END
					
				,Status = CASE 
							WHEN @IsUpd_Void = 0 THEN Status 
							ELSE CASE
									WHEN @modds > 0 THEN 'WON'
									WHEN @modds = 0 AND b.oddstype <> 6 THEN 'DRAW'
									WHEN @modds = 0 AND b.oddstype = 6 
										THEN CASE 
												WHEN oddsspread = 0 THEN 'DRAW' 
												WHEN oddsspread > 0 THEN 'WON'
												ELSE 'LOSE'
											END
									WHEN @modds < 0 THEN 'LOSE'
									WHEN @modds IS NULl THEN 'Refund'
								END
						END
				,StatusID = CASE 
								WHEN @IsUpd_Void = 0 THEN b.StatusID 
								ELSE @statusId
							END
				,ruben=CASE 
							WHEN @IsUpd_Void = 0 THEN b.ruben 
							ELSE 1
						END
				,FcUpdateTime = CASE WHEN @statusId = 103 THEN @FcUpdateTime ELSE b.FcUpdateTime END
		FROM @tmpTransId t
			INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
				ON  t.transid = b.transid 
		WHERE	 ISNULL(b.betdaqid,0) <> -2 
		OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)

		IF OBJECT_ID('SettlementProcessing', 'U') IS NOT NULL
			DELETE 
			FROM	dbo.SettlementProcessing 
			WHERE	id = @SettlementProcessingId
	END
END
