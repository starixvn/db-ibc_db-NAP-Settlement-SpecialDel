/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[ExecRep_NAP_Admin_10]
	 @TransIDs		VARCHAR(MAX)	= ''
	,@MatchID		INT
	,@Status		VARCHAR(10)		= NULL 
	,@Action		VARCHAR(10)		='CAL'	
	,@Deadheat		FLOAT			= 1 
	,@Winlostdate   DATETIME		= NULL	

	,@ErrCode		INT				= 0  OUTPUT
	,@ErrMsg		VARCHAR(300)	= '' OUTPUT
AS
/*     
	 Created: 20220603@Aries  
	 Task:  Settlement Outright 
	 Database: DBTXN-bodb02  
   
	 Revision:  
	  - 20230109@Aries:  Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]
	  
    
	 Param's Explanation:  

*/  
BEGIN
	SET NOCOUNT ON 
	
	DECLARE	 @CommWinRate			SMALLMONEY
			,@CommLostRate			SMALLMONEY
			,@IsCentral				BIT = 0
			,@ActionID				INT
			,@CheckNegativeBalance	INT = 0
			,@Remark				VARCHAR(500)
			,@MinTransID			BIGINT
			,@MaxTransID			BIGINT
			,@StepNumber			INT = 0
			,@IsSiteDB				BIT = 0

	DECLARE @tmpTransId TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @tmpBalanceChanged TABLE (CustId INT, Balance MONEY)
	
	
	SET @ActionID = CASE WHEN @Action = 'CAL' AND @Status IN ('WON','LOSE') THEN 136
						 WHEN @Action = 'CAL' AND @Status IN ('REFUND') THEN 138
						 WHEN @Action = 'UNDO'	THEN 145
					 END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT	

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLogIns','P') IS NOT NULL 
		SET @IsSiteDB = 1

	INSERT INTO @tmpTransId(transid)
	SELECT value 
	FROM STRING_SPLIT(@TransIDs,',')

	IF @@ROWCOUNT = 0 RETURN

	BEGIN TRY
		IF @Action='UNDO'
		BEGIN
			SET @StepNumber = 1;
			UPDATE b
			SET  b.ruben = 0
				,b.STATUS = 'running'
				,b.statusID = 0
				,b.winlost = 0
				,b.awinlost = 0
				,b.mwinlost = 0
				,b.swinlost = 0
				,b.playercomm = 0
				,b.comm = 0
				,b.acomm = 0
				,b.scomm = 0
			OUTPUT  deleted.custid,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
			INTO @tmpBalanceChanged (CustId, Balance)
			FROM @tmpTransId AS t
				INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON t.transid = b.transid 
		END 
		ELSE IF @Action = 'CAL' AND @Status = 'WON'
		BEGIN
			SET @StepNumber = 2;
			UPDATE b
			SET	@commWinRate = CASE b.comstatus WHEN '0' THEN 1 -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
												WHEN '1' THEN 0 
												ELSE 1 END
				,b.[status] = 'WON'
				,b.ruben = 1 
				,b.winlostdate = @winlostdate --convert(char(10),getdate(),111)
				,b.statuswinlost = 2
				,b.Swinlost = -(b.odds - 1) * b.spositiontaking * b.stake / @deadheat
				,b.mwinlost = -(b.odds - 1) * b.mpositiontaking * b.stake / @deadheat
				,b.awinlost = -(b.odds - 1) * b.apositiontaking * b.stake / @deadheat
				,b.winlost = (((b.odds - 1) / @deadheat)+1) * b.stake 
				,b.Scomm = @commWinRate * (1  - b.spositiontaking - b.mpositiontaking - b.apositiontaking) * b.sdiscount * b.stake
				,b.acomm = @commWinRate * (1  - b.mpositiontaking - b.apositiontaking) * b.adiscount * b.stake
				,b.comm  = @commWinRate * (1  - b.apositiontaking) * b.discount * b.stake
				,b.playercomm = @commWinRate * b.playerdiscount * b.stake
				,b.statusID = 112
			OUTPUT  deleted.custid,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
			INTO @tmpBalanceChanged (CustId, Balance)
			FROM @tmpTransId AS t
				INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON t.transid = b.transid
			
		END
		ELSE IF @Action = 'CAL' AND @Status = 'LOSE'
		BEGIN
			SET @StepNumber = 3;
			UPDATE b
			SET	@commLostRate = CASE comstatus  WHEN '0' THEN 1
												WHEN '1' THEN 2 
												ELSE 1 END--'s','m'
				,b.[status] = 'LOSE'
				,b.ruben = 1 
				,b.winlostdate = @winlostdate
				,b.statuswinlost = 4
				,b.Swinlost = b.spositiontaking * b.stake
				,b.mwinlost = b.mpositiontaking * b.stake
				,b.awinlost = b.apositiontaking * b.stake
				,b.winlost =0
				,b.Scomm = @commLostRate * (1 - b.spositiontaking - b.mpositiontaking - b.apositiontaking) * b.sdiscount * b.stake
				,b.acomm = @commLostRate * (1 - b.mpositiontaking - b.apositiontaking) * b.adiscount * b.stake
				,b.comm  = @commLostRate * (1 - b.apositiontaking) * b.discount * b.stake
				,b.playercomm = @commLostRate * b.playerdiscount * b.stake
				,b.statusID = 113
			OUTPUT  deleted.custid, (inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
			INTO @tmpBalanceChanged (CustId, Balance)
			FROM @tmpTransId AS t
				INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON t.transid = b.transid
		END
		ELSE IF @Action = 'CAL' AND @Status = 'REFUND'
		BEGIN
			SET @StepNumber = 4;
			UPDATE b
			SET	 b.[status] = 'Refund'
				,b.ruben = 1 
				,b.winlostdate = @winlostdate
				,b.statuswinlost = 4
				,b.swinlost = 0
				,b.mwinlost = 0
				,b.awinlost = 0
				,b.winlost = b.actual_stake
				,b.scomm = 0
				,b.acomm = 0
				,b.comm  = 0
				,b.playercomm = 0
				,b.statusID = 103
			OUTPUT  deleted.custid, (inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
			INTO @tmpBalanceChanged (CustId, Balance)
			FROM @tmpTransId AS t
				INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON t.transid = b.transid
		END
	
		IF @IsCentral = 1 OR @IsSiteDB = 1
		BEGIN
			SET @StepNumber = 5;
			INSERT INTO dbo.BalCreditSportsPending (custid, balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@tmpBalanceChanged AS t
			GROUP BY custid
			HAVING SUM(Balance) > 0

			SET @StepNumber = 6;
			INSERT INTO dbo.BalDebitSportsPending(custid, balance)
			SELECT	custid, ABS(SUM(Balance)) Balance
			FROM	@tmpBalanceChanged AS t
			GROUP BY custid
			HAVING SUM(Balance) < 0
			SET @CheckNegativeBalance = @@ROWCOUNT

			IF @CheckNegativeBalance <> 0
			BEGIN
				SET @StepNumber = 7;
				INSERT INTO [bodb02].[dbo].[BalanceNegative] ([ExecDate],[MatchID],[ActionID],[GroupID],[CustID],[Balance],[StatusID],[Remark])
				SELECT	 GETDATE()
						,@MatchID
						,@ActionId 
						,3 AS GroupID 
						,bal.CustID
						,SUM(bal.Balance)
						,0
						,NULL
				FROM	@tmpBalanceChanged AS bal
				GROUP BY bal.CustId
				HAVING SUM(Balance) < 0
			 END
		END 
	END TRY
	BEGIN CATCH
		SET @ErrCode = @StepNumber
		SET @ErrMsg = LEFT(ERROR_MESSAGE(),200)

		IF @StepNumber IN (5,6)
		BEGIN
			INSERT INTO dbo.BalanceErr (Custid, BalanceGroup, BalanceAmt, ExecutedSP, ErrMsg)
			SELECT	 bn.Custid
					,1 AS BalanceGroup
					,SUM(bn.balance) AS BalanceAmt
					,'ExecRep_NAP_Admin_10' AS ExecutedSP
					,@ErrMsg AS ErrMsg
			FROM @tmpBalanceChanged AS bn
			GROUP BY bn.CustId
			HAVING SUM(bn.balance) <> 0		
		END
	END CATCH
END

GO