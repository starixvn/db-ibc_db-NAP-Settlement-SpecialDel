/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE dbo.Bet_ExecRep_NAP_Admin_02
	@BetTicketJson		VARCHAR(MAX)
	,@Action			VARCHAR(20)		= NULL
	,@ActionID			INT				= NULL
	,@CWLBettype		SMALLINT 		= 0
	,@IsCalBalance		BIT				= 1
	,@matchid			INT				= 0
	,@transMPO			VARCHAR(MAX)	= NULL 	
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*
    Created by: 20201006@Louisa
    Task: execRep SP for Settlement Redmine:#140452
    DB: DBTXN/bodb02
    
    Revisions:
        - 20201006@Louisa: SP for Settlement Redmine:#140452
		- 20240118@Louisa: Integrate VS4 - Cock Fighting [Redmine:#199700]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
		- 20240410@Kathy: support parlay - write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
		- 20241211@Louisa: add matchid for BalancePendingCreditGame [Redmine:#215066]

    Param's Explanation:
        - ExecRep SP: DBTrans_Bet
		- Settle pass @IsCalBalance = 1, Recover pass @IsCalBalance = 0
*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @handle 			INT
			,@ServerName		SYSNAME 
			,@AllowExec			BIT 
			,@transInfoJson		NVARCHAR(MAX)
			,@IsCentral			BIT  = 0
			,@IsSiteDB			BIT = 0
			,@BalanceChanged	TVP_BalanceWalletChange
			,@BalanceType		TINYINT = 4 --other
			
			,@StartTime			DATETIME2
			,@EndTime			DATETIME2
			,@AffectedTicket	INT
			,@MessageBody		VARCHAR(MAX)
			,@MainIDParlay		INT

	DECLARE @tmpMainParlayInfo TABLE (
		 matchid 		INT
		, custid 		INT
		, bettype 		SMALLINT
		, transid 		BIGINT
		, winlost 		MONEY
		, awinlost 		MONEY
		, mwinlost 		MONEY
		, swinlost 		MONEY
		, playercomm 	MONEY
		, comm 			MONEY
		, acomm 		MONEY
		, scomm 		MONEY
		, statusid 		TINYINT
		, modds 		SMALLMONEY
		, winlostdate 	SMALLDATETIME
		, actualPO		MONEY
	)

	DECLARE @tmpTransInfo TABLE (transId BIGINT, bettype SMALLINT
		,modds MONEY, statuswinlost TINYINT, winlostdate SMALLDATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT
		,bef_winlost MONEY ,bef_statusid TINYINT, actual_stake MONEY
		,extrainfo VARCHAR(1000) ,ruben TINYINT, before_ruben TINYINT,CustId INT, Balance MONEY
	)
			
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog_3rd','U') IS NOT NULL 
	SET @IsSiteDB = 1

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC dbo.NAP_Set_ServerAction
			@ServerName	= @ServerName
			,@AllowExec	= @AllowExec OUTPUT

		IF @AllowExec = 0
			RETURN
	END

	INSERT INTO @tmpMainParlayInfo (
		matchid
		, transid
		, WinLost
		, aWinLost
		, mWinLost
		, sWinLost
		, PlayerComm
		, comm
		, acomm
		, scomm
		, StatusID
		, modds
		, winlostdate
		, actualPO
	)
	SELECT *
	FROM OPENJSON(@BetTicketJson)
	WITH (
			mi		INT
			,ti		BIGINT
			,wl		MONEY
			,awl	MONEY
			,mwl	MONEY
			,swl	MONEY
			,pcomm	MONEY
			,comm	MONEY
			,acomm	MONEY
			,scomm	MONEY
			,st		TINYINT
			,mo		SMALLMONEY
			,wd		SMALLDATETIME
			,apo	MONEY
	)	
	
	SELECT @MainIDParlay  = ( SELECT TOP(1) matchid FROM @tmpMainParlayInfo)
	
	BEGIN TRY
		SET @StartTime = SYSDATETIME()

		UPDATE b 
		SET winlost 		= s.winlost
			,awinlost 		= s.awinlost
			,mwinlost 		= s.mwinlost
			,swinlost 		= s.swinlost
			,playercomm 	= s.playercomm
			,comm 			= s.comm
			,acomm 			= s.acomm
			,scomm 			= s.scomm
			,statusID 		= s.statusid
			,modds 			= s.modds
			,status 		= CASE s.statusid
								WHEN 112 THEN 'WON'
								WHEN 111 THEN 'DRAW'
								WHEN 113 THEN 'LOSE'
								WHEN 103 THEN 'Refund'
								WHEN 0 THEN 'Running'
							END 			
			,ruben 			= CASE 
								WHEN s.statusid IN (111,112,113,103) THEN 1
								ELSE 0 
							END
			,winlostdate 	= ISNULL(s.winlostdate, b.winlostdate)
			,statuswinlost	= CASE 
								WHEN s.statusid IN (103) THEN 0 --REFUND
								ELSE b.statuswinlost 
							END
			,ExtraInfo = CASE WHEN ISNULL(s.actualPO,0) > 0 THEN ISNULL(b.ExtraInfo,'') + '<l255 apo="'+ CAST(s.actualPO AS VARCHAR(100)) +'" />' ELSE  b.ExtraInfo END
		OUTPUT inserted.transid, deleted.bettype	
				,inserted.modds ,inserted.statuswinlost	,inserted.winlostdate 
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm		
				,inserted.status 			
				,inserted.statusID 
				,deleted.winlost
				,deleted.statusid
				,inserted.extrainfo,deleted.actual_stake
				,inserted.ruben, deleted.ruben
				,inserted.custid
				,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
		INTO @tmpTransInfo (transId, bettype
				,modds, statuswinlost, winlostdate 
				,WinLost,aWinLost,mWinLost,sWinLost 
				,PlayerComm, Comm,aComm,sComm 
				,Status ,StatusID 
				,bef_winlost  ,bef_statusid
				,extrainfo, actual_stake, ruben, before_ruben, CustId, Balance)
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmpMainParlayInfo s 
			ON b.matchid 		= s.matchid
				AND b.transid 	= s.transid
		
		SET @EndTime = SYSDATETIME()

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @transInfoJson = (
				SELECT	transId AS 't'	
						,modds AS 'm'
						,statuswinlost AS 'statuswl' 
						,winlostdate AS 'wld'
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
						,extrainfo AS 'ex'
						,bef_winlost AS 'bef_w' 
						,bef_statusid AS 'bef_sid' 				
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)

			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName			= 'Settlement' 
				,@FunctionName		= 'CalculateVS'
				,@TableName			= 'bettrans'
				,@MatchId			= @MatchId
				,@transinfoJson		= @transinfoJson
				,@SettlementAction  = @Action
				,@TicketType		= 'p'
				,@EventTable		= 1
		END
		
		IF @IsCentral = 1 OR @IsSiteDB = 1
		BEGIN
			IF(@CWLBettype > 0)
			BEGIN
				DECLARE @BalanceCWL  TABLE (custid INT, bef_winlost MONEY, after_winlost MONEY,winlostdate SMALLDATETIME, gametypeid SMALLINT)	

				INSERT INTO @BalanceCWL (custid, bef_winlost, after_winlost, winlostdate, gametypeid)
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
					,@MainIDParlay
				FROM @BalanceCWL t
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
					,@MainIDParlay
				FROM @BalanceCWL
				WHERE (after_winlost - bef_winlost) < 0

			END

			IF @IsCalBalance =  1
			BEGIN
				INSERT INTO @BalanceChanged (matchid,custid, balance)
				SELECT	 @MatchId
						,custid
						,SUM(balance)
				FROM @tmpTransInfo
				GROUP BY custid
				HAVING SUM(balance) != 0;
 
				EXEC NAP_Admin_Settlement_BalanceUpd @BalanceChanged =	@BalanceChanged
													,@ActionID		=   @ActionID
													,@BalanceType	=	@BalanceType
													,@ErrMessage	=   @ErrMsg		OUTPUT
													,@ErrCode		=   @ErrCode	OUTPUT
			END
		END
		
		SELECT @AffectedTicket = COUNT(1)
		FROM	@tmpTransInfo
	
		IF OBJECT_ID('SSB_Settlement_WriteLogs','P') IS NOT NULL 
		BEGIN 
			SET @MessageBody = 'EXEC Bet_ExecRep_NAP_Admin_02 @BetTicketJson = ''' + @BetTicketJson + ''''
									+ CASE WHEN @Action IS NOT NULL THEN ',@Action = ''' + @Action + '''' ELSE '' END
									+ CASE WHEN @ActionId IS NOT NULL THEN ',@ActionID = ' + CAST(@ActionID AS VARCHAR)  ELSE '' END
									+ ',@CWLBettype = ' + CAST(@CWLBettype AS VARCHAR)
									+ ',@IsCalBalance = ' + CAST(@IsCalBalance AS VARCHAR)
									+ ',@matchid = ' + CAST(@matchid AS VARCHAR)
									+ ',@ActionID = ' + CAST(@ActionID AS VARCHAR)
									+ CASE WHEN @transMPO IS NOT NULL THEN  ',@transMPO = ''' + @transMPO + '''' ELSE '' END
								
			exec dbo.SSB_Settlement_WriteLogs @MessageId = NULL
				, @MessageType			= NULL
				, @MessageBody			= @MessageBody
				, @StartTime			= @StartTime
				, @EndTime				= @EndTime
				, @SessionId			= NULL
				, @ErrorMessage			= NULL
				, @ConversationHandle	= NULL
				, @QueueNo				= 0
				, @SiteDBGroupId		= 0
				, @matchid				= @matchid
				, @AffectedTicket 		= @AffectedTicket 
				, @TableType			= 1
				, @EventTable			= 1
		END
			
	END TRY
	BEGIN CATCH
	
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
			
	END CATCH
END
GO