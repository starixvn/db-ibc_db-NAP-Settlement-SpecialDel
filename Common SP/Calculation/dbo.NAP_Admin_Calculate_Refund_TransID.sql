/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Refund_TransID]
	@transIds			VARCHAR(MAX)
	,@MatchId			INT = 0
	,@EventTable		TINYINT = 1 -- match
	,@Is3rd				BIT =  0
	,@ActionID				INT = NULL
	,@IsCalculateBalance	BIT =  0
	,@CWLBettype			SMALLINT = 0
	,@BalanceType			TINYINT  = 1 --sport
	,@BroadcastSessionId	VARCHAR(50)	= NULL
	,@ErrMessage			VARCHAR(300) = '' OUTPUT
	,@ErrCode				INT			 = 0  OUTPUT

AS
/*  Created by: Vicky
	Date: 20180801
	Task: Refund for esport
	DB: DBTXN/BODB02
	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200428@Kathy: PHAIO 5 - Add new penalty bettype[Redmine:#132805]
		- 20211104@Kathy: Upd RepUpdateTime [Redmine:#164184]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20230214@Louisa: New way to update balance [Redmine:#182677]
		- 20230704@Louisa:  CWL for Virtual Leap Gaming [Redmine:#189854]
		- 20231214@Aries: Result Amendment [Redmine: #196401]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
		- 20241211@Louisa: add matchid for BalancePendingCreditGame [Redmine:#215066]

	Param's Explanation:
			@transIds = '<root>
						<r t="104730774034"/>
						<r t="104729373985"/>
					</root>'
*/
BEGIN
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowRefund		BIT
			,@IsUpd_Void BIT = 0
			,@IsSiteDB	BIT = 0
			,@IsCentral BIT = 0
		SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowRefund		= @AllowRefund		OUTPUT

		IF @AllowRefund = 0
			RETURN
	END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT	

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL AND OBJECT_ID('SiteDB_SettlementService_CalculationLog_3rd','U') IS NOT NULL
	SET @IsSiteDB = 1

	-----------------------CHECK SERVER-----------------------------------------

	DECLARE @tempTrans TABLE (TransID BIGINT)
	DECLARE @tmpTransInfo TABLE (transId BIGINT
								,CustId INT, Balance MONEY
								,odds SMALLMONEY, statuswinlost TINYINT
								,SettlementTime DATETIME
								,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
								,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
								,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT, before_ruben TINYINT
								,FcUpdateTime DATETIME2
								,bef_winlost MONEY,bef_statusid TINYINT, bettype SMALLINT, winlostdate	SMALLDATETIME
								,actual_stake MONEY
								,betid BIGINT,refno BIGINT
								)

	DECLARE @handle INT
			,@transinfoJson NVARCHAR(MAX)
			,@BalanceChanged		TVP_BalanceWalletChange
			,@EndTime DATETIME2
			,@AffectedTicket INT
			,@MessageBody VARCHAR(MAX)
			
	---parse XML
	EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
	INSERT INTO @tempTrans(TransID)
	SELECT t
	FROM OPENXML(@handle,'root/r',1) WITH(t BIGINT) tbl
	EXEC sp_xml_removedocument @handle  

	DECLARE @settlementTime DATETIME
			,@FcUpdateTime DATETIME2

	SET @settlementTime = GETDATE();
	SET @FcUpdateTime = SYSDATETIME()

	UPDATE	b
		SET				
			@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
			,[status] = CASE 
							WHEN @IsUpd_Void = 0 THEN [status] 
							ELSE N'Refund'
						END
					
			,SettlementTime = CASE WHEN @IsUpd_Void = 0 THEN SettlementTime
									ELSE CASE WHEN winlost <> actual_stake OR statusID <> 103 THEN @settlementTime ELSE SettlementTime END
							 END
			,statusID = CASE 
							WHEN @IsUpd_Void = 0 THEN statusID 
							ELSE 103
						END
			,winlost = actual_stake
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0
			,ruben = 1
			,statuswinlost = 6
			,odds = CASE WHEN b.bettype = 376 THEN b.oddsspread ELSE b.odds END
			,FcUpdateTime = CASE WHEN b.statusId = 103 THEN b.FcUpdateTime ELSE @FcUpdateTime END
		OUTPUT	inserted.transid
				,deleted.custid, (inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
				,inserted.odds, inserted.statuswinlost
				,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben, deleted.ruben
				,CASE WHEN inserted.FcUpdateTime <> deleted.FcUpdateTime THEN inserted.FcUpdateTime ELSE NULL END
				,deleted.winlost,deleted.statusid	
				,deleted.bettype,deleted.betid,deleted.refno
				,deleted.winlostdate
				,deleted.actual_stake
		INTO @tmpTransInfo (
				 transId
				,custid, Balance
				,odds, statuswinlost
				,SettlementTime
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID,ruben, before_ruben
				,FcUpdateTime
				,bef_winlost, bef_statusid
				,bettype,betid,refno
				,winlostdate
				,actual_stake
		)
	FROM @tempTrans sr
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
		
	SET @EndTime = SYSDATETIME()
	
	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		SET @transinfoJson = (
				SELECT	transId AS 't'		
						,odds AS 'o' 
						,statuswinlost AS 'statuswl' 
						,SettlementTime AS 'st' 
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
						,ruben AS 'r' 
						,FcUpdateTime AS 'rut'
						,bef_winlost AS 'bef_w' 
						,bef_statusid AS 'bef_sid' 
						,bettype AS 'bt'
						,betid AS 'bi' 
						,refno AS 'rf'
					
				FROM	@tmpTransInfo
				FOR JSON AUTO )

		IF @Is3rd = 1
		BEGIN
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'RefundOtherSport'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@transinfoJson = @transinfoJson
				,@SettlementAction = 'REFUND'
				,@TicketType = 's'
				,@EventTable = @EventTable
		END
		ELSE
		BEGIN
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns
				@SystemName = 'Settlement' 
				,@FunctionName = 'RefundOtherSport'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@transinfoJson = @transinfoJson
				,@SettlementAction = 'REFUND'			
				,@TicketType = 's'
				,@BroadcastSessionId = @BroadcastSessionId

		END
	END
	
	IF @IsCalculateBalance = 1 AND (@IsCentral = 1 OR @IsSiteDB = 1)
	BEGIN
		
		IF(@CWLBettype > 0)
		BEGIN
			CREATE TABLE #Balance (custid INT, bef_winlost MONEY, after_winlost MONEY,winlostdate SMALLDATETIME, gametypeid SMALLINT)	

			INSERT INTO #Balance (custid, bef_winlost, after_winlost, winlostdate, gametypeid)
			SELECT custid
				,SUM(CASE
						WHEN before_ruben = 1 THEN t.bef_winlost - actual_stake 
						ELSE 0 
					END) AS bef_winlost
				,SUM(CASE
						WHEN t.ruben = 1 THEN t.winlost - actual_stake 
						ELSE 0 
					END) AS after_winlost
				,winlostdate
				,bettype AS gametypeid
			FROM @tmpTransInfo t
			GROUP BY custid, winlostdate, bettype

			INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,bettype
				,GameTypeID
				,balance
				,RefID
			)
			SELECT custid
				,winlostdate
				,@CWLBettype
				,GameTypeID
				,(after_winlost - bef_winlost) AS Balance
				,@MatchId
			FROM #Balance t
			WHERE (after_winlost - bef_winlost) > 0
			
			--CAPTURE decrease
			INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,bettype
				,GameTypeID
				,balance
				,RefID
			)
			SELECT custid
				,winlostdate
				,@CWLBettype
				,GameTypeID
				,ABS(after_winlost - bef_winlost) AS Balance
				,@MatchId
			FROM #Balance
			WHERE (after_winlost - bef_winlost) < 0
		END
		
		INSERT INTO @BalanceChanged (matchid,custid, walletType, bonusId, balance)
		SELECT	 @MatchId
				,custid
				,2 AS walletType
				,0 AS bonusId
				,SUM(balance)
		FROM @tmpTransInfo
		GROUP BY custid
		HAVING SUM(balance) != 0;

		EXEC NAP_Admin_Settlement_BalanceUpd @BalanceChanged =	@BalanceChanged
											,@ActionID		 = @ActionID
											,@BalanceType	 = @BalanceType
											,@BroadcastSessionId  = @BroadcastSessionId
											,@ErrMessage	 = @ErrMessage OUTPUT
											,@ErrCode		 = @ErrCode OUTPUT
	END
	
	SELECT @AffectedTicket = COUNT(1)
	FROM	@tmpTransInfo
	
	IF OBJECT_ID('SSB_Settlement_WriteLogs','P') IS NOT NULL 
	BEGIN 
		SET @MessageBody = 'EXEC NAP_Admin_Calculate_Refund_TransID @MatchId = ' + CAST(@MatchId AS VARCHAR)
								+ ',@EventTable = ' + CAST(@EventTable AS VARCHAR)
								+ ',@Is3rd = ' + CAST(@Is3rd AS VARCHAR)
								+ CASE WHEN @ActionId IS NOT NULL THEN ',@ActionID = ' + CAST(@ActionID AS VARCHAR) ELSE '' END
								+ ',@IsCalculateBalance = ' + CAST(@IsCalculateBalance AS VARCHAR)
								+ ',@CWLBettype = ' + CAST(@CWLBettype AS VARCHAR)
								+ ',@BalanceType = ' + CAST(@BalanceType AS VARCHAR)
								+ CASE WHEN @BroadcastSessionId IS NOT NULL THEN ',@BroadcastSessionId = ''' + @BroadcastSessionId + '''' ELSE '' END
								+ ',@transIds = ''' + @transIds + ''''
		exec dbo.SSB_Settlement_WriteLogs @MessageId = NULL
			, @MessageType			= NULL
			, @MessageBody			= @MessageBody
			, @StartTime			= @FcUpdateTime
			, @EndTime				= @EndTime
			, @SessionId			= NULL
			, @ErrorMessage			= NULL
			, @ConversationHandle	= NULL
			, @QueueNo				= 0
			, @SiteDBGroupId		= 0
			, @matchid				= @matchid
			, @AffectedTicket 		= @AffectedTicket 
			, @TableType			= 1 -- bettrans
			, @EventTable			= @EventTable
	END
END
GO