/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_03] 
	@transIds	VARCHAR(MAX)
	,@Mode		VARCHAR(20)
	,@MatchId	INT = 0
	,@ActionID				INT = NULL
	,@IsCalculateBalance	BIT = 0
	,@ErrMessage			VARCHAR(300) = '' OUTPUT
	,@ErrCode				INT			 = 0  OUTPUT
AS
/*
	Created: 20211130@Kathy.Nguyen	
	Task: New cashout model [Redmine:#164838]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20211130@Kathy: New cashout model [Redmine:#164838]			
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Using Json [Redmine:#178694]
		- 20230214@Louisa: New way to update balance for cashout Basketball [Redmine:#182677]

	Param's Explanation:  
		   
		@transIds = '<root>
						<r t="104730774034" w="" s=""/>
					</root>'
					t: transid
					s: statuswinlost
					w: winlost
*/ 
BEGIN
	SET NOCOUNT ON
	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@AllowUndo			BIT
			,@AllowRefund		BIT
			,@IsSiteDB			BIT = 0
			,@IsCentral			BIT = 0
			,@BalanceChanged	TVP_BalanceWalletChange

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT
			,@AllowUndo			= @AllowUndo OUTPUT
			,@AllowRefund		= @AllowRefund OUTPUT

		IF @AllowCalculation = 0 AND @mode = 'CAL'
			RETURN
		
		IF @AllowUndo = 0 AND @mode = 'UNDO'
			RETURN

		IF @AllowRefund = 0 AND @mode = 'REFUND'
			RETURN

	END


	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT	

	DECLARE @handle 			INT
			,@statusId			TINYINT
			,@IsUpdated			BIT		
			,@settlementTime	DATETIME
			,@commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@transinfoJson		NVARCHAR(MAX)	

	DECLARE @tempTrans TABLE (TransID BIGINT, statuswinlost TINYINT, winlost MONEY)
	DECLARE @tmpTransInfo TABLE (CustId INT, Balance MONEY
			,transId BIGINT
			,statuswinlost TINYINT
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,FcUpdateTime DATETIME2
			,SettlementTime DATETIME
			,bef_winlost MONEY
			,bef_statusid TINYINT
	)

	---parse XML
	EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
	INSERT INTO @tempTrans(TransID, statuswinlost, winlost)
	SELECT t, s, w
	FROM OPENXML(@handle,'root/r',1) WITH(t   BIGINT
										 ,s   TINYINT
										 ,w	  MONEY
									) tbl
	EXEC sp_xml_removedocument @handle

	SET	@IsUpdated = 0
	SET @SettlementTime = GETDATE()

	UPDATE b
		SET @StatusId = CASE	
							WHEN b.statusID = 102 THEN 102
							WHEN t.statuswinlost = 6 THEN 103
							WHEN b.actual_stake < t.Winlost THEN 112
							WHEN b.actual_stake = t.Winlost THEN 111
							ELSE 113
						END
			,@IsUpdated = CASE WHEN b.statusID = 103 OR @StatusId = 103 THEN 1 ELSE 0 END
			,@commWinRate = CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
								WHEN '0' THEN 1
								WHEN '1' THEN 0
								ELSE 1 END
			,@commLostRate = CASE b.comstatus
								WHEN '0' THEN 1
								WHEN '1' THEN 2
								ELSE 1 END
			,statusID = CASE WHEN @IsUpdated = 1 THEN @StatusId ELSE b.statusID END
			,winlost = CASE 
							WHEN @IsUpdated = 1 
								THEN CASE WHEN @StatusId = 103 THEN b.actual_stake ELSE t.Winlost END 
							ELSE b.winlost 
						END
			,awinlost = CASE
							WHEN @IsUpdated = 0 THEN b.awinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.apositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.apositiontaking
						END
			,mwinlost = CASE
							WHEN @IsUpdated = 0 THEN b.mwinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.mpositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.mpositiontaking
						END
			,swinlost = CASE
							WHEN @IsUpdated = 0 THEN b.swinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.spositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.spositiontaking
						END
			,playercomm = CASE
							WHEN @IsUpdated = 0 THEN b.playercomm
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.playerdiscount
							WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.playerdiscount
							ELSE @commLostRate * b.stake * b.playerdiscount
						END
			,comm = CASE
						WHEN @IsUpdated = 0 THEN b.comm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.discount * (1-apositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.discount * (1-apositiontaking)
						ELSE @commLostRate * b.stake * b.discount * (1-apositiontaking)
					END
			,acomm = CASE
						WHEN @IsUpdated = 0 THEN b.acomm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
						ELSE @commLostRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
					END
			,scomm = CASE
						WHEN @IsUpdated = 0 THEN b.scomm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
						ELSE @commLostRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
					END
			,status = CASE 
						WHEN @IsUpdated = 0 THEN b.status
						WHEN @StatusId = 103 THEN 'Refund'
						WHEN @StatusId = 112 THEN 'WON'
						WHEN @StatusId = 111 THEN 'DRAW'
						ELSE 'LOSE'
					END
			,statuswinlost = t.statuswinlost
			,SettlementTime = CASE 
								WHEN @IsUpdated = 0 THEN b.SettlementTime
								ELSE CASE WHEN b.winlost <> t.Winlost OR b.statusID <> @StatusId THEN @settlementTime ELSE SettlementTime END
								END	
			,FcUpdateTime = CASE WHEN @statusId = 103 AND b.statusID <> 103 THEN SYSDATETIME() ELSE FcUpdateTime END
		OUTPUT	deleted.custid
					,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
					,inserted.transid
					, inserted.statuswinlost				
					,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
					,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
					,inserted.Status,inserted.StatusID
					,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
					,CASE WHEN inserted.FcUpdateTime <> deleted.FcUpdateTime THEN inserted.FcUpdateTime ELSE NULL END				
					,deleted.winlost
					,deleted.statusid		
			INTO @tmpTransInfo (
				CustId, Balance		
				,transId
				,statuswinlost,WinLost,aWinLost
				,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,SettlementTime,FcUpdateTime				
				,bef_winlost, bef_statusid
			)
	FROM	dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @tempTrans t
			ON b.transid = t.TransId

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		SET @transinfoJson = (
			SELECT	transId AS 't'	
					,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl' 					
					,WinLost AS 'w' 
					,aWinLost AS 'aw' 
					,mWinLost AS 'mw' 
					,sWinLost AS 'sw' 
					,PlayerComm AS 'pc' 
					,Comm AS 'c' 
					,aComm AS 'ac' 
					,sComm AS 'sc' 
					,Status AS 's' 
					,StatusID AS 'sid' 
					,FcUpdateTime AS 'rut' 
					,SettlementTime AS 'st'
					,bef_winlost AS 'bef_w' 
					,bef_statusid AS 'bef_sid' 
					
			FROM	@tmpTransInfo
			FOR JSON AUTO
		)
	
		EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
			@SystemName = 'Settlement' 
			,@FunctionName = 'CalculateCashout'
			,@TableName = 'bettrans'
			,@MatchId = @MatchId
			,@TransInfoJson = @TransInfoJson
			,@SettlementAction = @Mode
			,@TicketType = 's'
	END

	IF @IsCalculateBalance = 1 AND (@IsSiteDB = 1 OR @IsCentral = 1) ---except cashout soccer
	BEGIN
		INSERT INTO @BalanceChanged (matchid,custid, walletType, bonusId, balance)
		SELECT	 @MatchId
				,custid
				,2 AS walletType
				,0 AS bonusId
				,SUM(balance)
		FROM @tmpTransInfo
		GROUP BY custid
		HAVING SUM(balance) != 0;

		EXEC NAP_Admin_Settlement_BalanceUpd 
			@BalanceChanged = @BalanceChanged
			,@ActionID		= @ActionID
			,@ErrMessage	= @ErrMessage OUTPUT
			,@ErrCode		= @ErrCode	  OUTPUT
	END

END
GO
