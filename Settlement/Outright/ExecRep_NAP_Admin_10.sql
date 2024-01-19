/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_10]
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
	  - 20230526@Kathy: wrong SMA winlost because of order in calculate formula [Redmine:#188795]
	  - 20230523@Kathy: scaleout - credit [Redmine:#188452]
	  - 20231123@Kathy: Enhance outright settlement to prevent discrepancy data on winlostdate between SiteDBs & CentralDB [Redmine:#197266]
	  
    
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
			,@SettlementTime		DATETIME
			,@transInfoJson			NVARCHAR(MAX)
			,@NewStatusID			TINYINT
			,@NewWinLost			MONEY
			
	DECLARE @tmpTransId TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @tmpTransInfo TABLE (TransId			BIGINT
								,CustId				INT
								,Balance			MONEY
								,winlostdate		DATETIME
								,statuswinlost		TINYINT
								,SettlementTime		DATETIME
								,WinLost			MONEY
								,aWinLost			MONEY
								,mWinLost			MONEY
								,sWinLost			MONEY
								,PlayerComm			MONEY
								,Comm				MONEY
								,aComm				MONEY
								,sComm				MONEY
								,statusID			TINYINT								
								,status				NVARCHAR(20)
								,ruben				TINYINT)	
	
	SET @SettlementTime = GETDATE(); 

	SET @ActionID = CASE WHEN @Action = 'CAL' AND @Status IN ('WON','LOSE') THEN 136
						 WHEN @Action = 'CAL' AND @Status IN ('REFUND') THEN 138
						 WHEN @Action = 'UNDO'	THEN 145
					 END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT	

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog_3rd','U') IS NOT NULL AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLog_3rdIns','P') IS NOT NULL 
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
			SET  @NewWinLost = 0
				,@NewStatusID = 0
				,b.ruben = 0
				,b.STATUS = 'running'
				,b.statusID = @NewStatusID
				,b.winlost = @NewWinLost
				,b.statuswinlost = NULL
				,b.awinlost = 0
				,b.mwinlost = 0
				,b.swinlost = 0
				,b.playercomm = 0
				,b.comm = 0
				,b.acomm = 0
				,b.scomm = 0
			OUTPUT  inserted.TransId
				,	inserted.custid
				,	(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
				,	inserted.winlostdate
				,	inserted.statuswinlost
				,	CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,	inserted.WinLost
				,	inserted.aWinLost
				,	inserted.mWinLost
				,	inserted.sWinLost
				,	inserted.PlayerComm
				,	inserted.Comm
				,	inserted.aComm
				,	inserted.sComm
				,	inserted.statusID
				,	inserted.status
				,	inserted.ruben
			INTO @tmpTransInfo (TransId, CustId, Balance, winlostdate, statuswinlost, SettlementTime, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, statusID, status, ruben)
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
				,@NewWinLost = b.stake * (((b.odds - 1) / @deadheat)+1)
				,@NewStatusID = 112
				,b.[status] = 'WON'
				,b.ruben = 1 
				,b.winlostdate = @winlostdate --convert(char(10),getdate(),111)
				,b.statuswinlost = 2
				,b.Swinlost = - b.stake * (b.odds - 1) * b.spositiontaking/ @deadheat
				,b.mwinlost = - b.stake * (b.odds - 1) * b.mpositiontaking/ @deadheat
				,b.awinlost = - b.stake * (b.odds - 1) * b.apositiontaking/ @deadheat
				,b.winlost = @NewWinLost
				,b.Scomm = @commWinRate * b.sdiscount * b.stake * (1  - b.spositiontaking - b.mpositiontaking - b.apositiontaking) 
				,b.acomm = @commWinRate * b.adiscount * b.stake * (1  - b.mpositiontaking - b.apositiontaking) 
				,b.comm  = @commWinRate * b.discount * b.stake * (1  - b.apositiontaking) 
				,b.playercomm = @commWinRate * b.playerdiscount * b.stake
				,b.statusID = @NewStatusID
				,b.SettlementTime =  CASE WHEN b.winlost <> @NewWinLost OR b.statusID <> @NewStatusID THEN @SettlementTime ELSE b.SettlementTime END
			OUTPUT  inserted.TransId
				,	inserted.custid
				,	(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
				,	inserted.winlostdate
				,	inserted.statuswinlost
				,	CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,	inserted.WinLost
				,	inserted.aWinLost
				,	inserted.mWinLost
				,	inserted.sWinLost
				,	inserted.PlayerComm
				,	inserted.Comm
				,	inserted.aComm
				,	inserted.sComm
				,	inserted.statusID
				,	inserted.status
				,	inserted.ruben
			INTO @tmpTransInfo (TransId, CustId, Balance, winlostdate, statuswinlost, SettlementTime, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, statusID, status, ruben)
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
				,@NewWinLost = 0
				,@NewStatusID = 113
				,b.[status] = 'LOSE'
				,b.ruben = 1 
				,b.winlostdate = @winlostdate
				,b.statuswinlost = 4
				,b.Swinlost = b.spositiontaking * b.stake
				,b.mwinlost = b.mpositiontaking * b.stake
				,b.awinlost = b.apositiontaking * b.stake
				,b.winlost = @NewWinLost
				,b.Scomm = @commLostRate * b.sdiscount * b.stake * (1 - b.spositiontaking - b.mpositiontaking - b.apositiontaking) 
				,b.acomm = @commLostRate * b.adiscount * b.stake * (1 - b.mpositiontaking - b.apositiontaking) 
				,b.comm  = @commLostRate * b.discount * b.stake * (1 - b.apositiontaking) 
				,b.playercomm = @commLostRate * b.playerdiscount * b.stake
				,b.statusID = @NewStatusID
				,b.SettlementTime =  CASE WHEN b.winlost <> @NewWinLost OR b.statusID <> @NewStatusID THEN @SettlementTime ELSE b.SettlementTime END
			OUTPUT  inserted.TransId
				,	inserted.custid
				,  (inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
				,	inserted.winlostdate
				,	inserted.statuswinlost
				,	CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,	inserted.WinLost
				,	inserted.aWinLost
				,	inserted.mWinLost
				,	inserted.sWinLost
				,	inserted.PlayerComm
				,	inserted.Comm
				,	inserted.aComm
				,	inserted.sComm
				,	inserted.statusID
				,	inserted.status
				,	inserted.ruben
			INTO @tmpTransInfo (TransId, CustId, Balance, winlostdate, statuswinlost, SettlementTime, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, statusID, status, ruben)
			FROM @tmpTransId AS t
				INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON t.transid = b.transid
		END
		ELSE IF @Action = 'CAL' AND @Status = 'REFUND'
		BEGIN
			SET @StepNumber = 4;
			UPDATE b
			SET	 @NewWinLost = b.actual_stake
				,@NewStatusID = 103 
				,b.[status] = 'Refund'
				,b.ruben = 1 
				,b.winlostdate = @winlostdate
				,b.statuswinlost = 4
				,b.swinlost = 0
				,b.mwinlost = 0
				,b.awinlost = 0
				,b.winlost = @NewWinLost
				,b.scomm = 0
				,b.acomm = 0
				,b.comm  = 0
				,b.playercomm = 0
				,b.statusID = @NewStatusID
				,b.SettlementTime =  CASE WHEN b.winlost <> @NewWinLost OR b.statusID <> @NewStatusID THEN @SettlementTime ELSE b.SettlementTime END
			OUTPUT  inserted.TransId
				,	inserted.custid
				,	(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
				,	inserted.winlostdate
				,	inserted.statuswinlost
				,	CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,	inserted.WinLost
				,	inserted.aWinLost
				,	inserted.mWinLost
				,	inserted.sWinLost
				,	inserted.PlayerComm
				,	inserted.Comm
				,	inserted.aComm
				,	inserted.sComm
				,	inserted.statusID
				,	inserted.status
				,	inserted.ruben
			INTO @tmpTransInfo (TransId, CustId, Balance, winlostdate, statuswinlost, SettlementTime, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, statusID, status, ruben)
			FROM @tmpTransId AS t
				INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON t.transid = b.transid
		END
	
		IF @IsCentral = 1 OR @IsSiteDB = 1
		BEGIN
			SET @StepNumber = 5;
			INSERT INTO dbo.BalCreditSportsPending (custid, balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@tmpTransInfo AS t
			GROUP BY custid
			HAVING SUM(Balance) > 0

			SET @StepNumber = 6;
			INSERT INTO dbo.BalDebitSportsPending(custid, balance)
			SELECT	custid, ABS(SUM(Balance)) Balance
			FROM	@tmpTransInfo AS t
			GROUP BY custid
			HAVING SUM(Balance) < 0
			SET @CheckNegativeBalance = @@ROWCOUNT

			IF @CheckNegativeBalance <> 0 AND OBJECT_ID('BalanceNegative','U') IS NOT NULL
			BEGIN
				SET @StepNumber = 7;
				INSERT INTO dbo.BalanceNegative ([ExecDate],[MatchID],[ActionID],[GroupID],[CustID],[Balance],[StatusID],[Remark])
				SELECT	 GETDATE()
						,@MatchID
						,@ActionId 
						,3 AS GroupID 
						,bal.CustID
						,SUM(bal.Balance)
						,0
						,NULL
				FROM	@tmpTransInfo AS bal
				GROUP BY bal.CustId
				HAVING SUM(Balance) < 0
			 END
		END 
		
		IF @Action = 'CAL' AND @Status = 'UpdWLD'
		BEGIN
			SET @StepNumber = 8;

			UPDATE b
			SET	b.winlostdate = @winlostdate
			OUTPUT  inserted.TransId
				,	inserted.winlostdate
			INTO @tmpTransInfo (TransId, winlostdate)
			FROM @tmpTransId AS t
				INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) 
					ON 	t.transid = b.transid
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
			FROM @tmpTransInfo AS bn
			GROUP BY bn.CustId
			HAVING SUM(bn.balance) <> 0		
		END
	END CATCH

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		IF @Action = 'CAL' AND @Status = 'UpdWLD'
			SET @transInfoJson = (
				SELECT	transId AS 't'					
						,winlostdate AS 'wld' 
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)
		ELSE
			SET @transInfoJson = (
				SELECT	transId AS 't'
					,@MatchID AS 'mid'
					,SettlementTime AS 'st'
					,winlost AS 'w' 
					,awinlost AS 'aw' 
					,mwinlost AS 'mw' 
					,swinlost AS 'sw' 
					,playercomm AS 'pc' 
					,comm AS 'c' 
					,acomm  AS 'ac' 
					,scomm  AS 'sc' 
					,statusID AS 'sid' 
					,status   AS 's' 
					,winlostdate AS 'wld' 
					,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(3)) END AS 'statuswl' 
					,ruben  AS 'r'  
					
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)
		
		EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateOutright'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@SettlementAction = @Action
				,@TicketType = 's'
				,@EventTable = 2
	END
END

GO