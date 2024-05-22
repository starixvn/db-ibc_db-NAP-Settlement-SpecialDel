/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Bet_ExecRep_NAP_Admin_03]
	 @MatchId			    INT             
	,@TransJson		        VARCHAR(MAX)	
	,@EventTable		    TINYINT         = 1 
	,@Is3rd				    BIT             = 0	
	,@Action				VARCHAR(20)     = 'CAL'
	,@ActionID				INT				= 0
	,@IsCalculateBalance	BIT             = 0
	,@CWLBettype			SMALLINT        = 0
	,@BalanceType			TINYINT         = 1 
	,@BroadcastSessionId	VARCHAR(50)		= NULL

	,@ErrMessage			VARCHAR(300)	= ''	OUTPUT
	,@ErrCode				INT				= 0		OUTPUT
AS
/*
	Created by: 20240520@Aries
	Task: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]
	DB: DBTXN/bodb02

	Revisions:
		- 20240520@Aries: Created  [Redmine:#202389]

	Param's Explanation:
		
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE  @ServerName				SYSNAME 
			,@AllowCalculation			BIT
			,@IsSiteDB					BIT = 0
			,@IsCentral					BIT = 0
			,@transInfoJson				NVARCHAR(MAX)
			,@BalanceChanged			TVP_BalanceWalletChange

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
		BEGIN
			RETURN
		END

	END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT	
	
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL AND OBJECT_ID('SiteDB_SettlementService_CalculationLog_3rd','U') IS NOT NULL
	BEGIN
		SET @IsSiteDB = 1
	END

	DECLARE @tmpTrans TABLE (
				transId				BIGINT
			   ,odds				SMALLMONEY
			   ,modds				SMALLMONEY
			   ,statuswinlost		TINYINT
			   ,SettlementTime		DATETIME
			   ,WinLost				MONEY
			   ,aWinLost			MONEY
			   ,mWinLost			MONEY
			   ,sWinLost			MONEY
			   ,PlayerComm			MONEY
			   ,Comm				MONEY
			   ,aComm				MONEY
			   ,sComm				MONEY
			   ,Status				NVARCHAR(20)
			   ,StatusID			TINYINT
			   ,ruben				TINYINT
			   ,ExtraInfo			VARCHAR(1000)
			   ,FcUpdateTime		DATETIME2
	
	)

	DECLARE @tmpTransOutput TABLE (  transId BIGINT
									,CustId INT, Balance MONEY
									,modds MONEY, odds SMALLMONEY, statuswinlost TINYINT,SettlementTime DATETIME
									,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
									,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
									,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT, before_ruben TINYINT, extrainfo VARCHAR(1000)
									,bef_winlost MONEY,bef_statusid TINYINT, bettype SMALLINT, winlostdate	SMALLDATETIME
									,actual_stake MONEY
									,betid BIGINT,refno BIGINT
									,FcUpdateTime DATETIME2)
	
	INSERT INTO @tmpTrans(transId,odds,modds,statuswinlost,SettlementTime,WinLost,aWinLost,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,ExtraInfo,FcUpdateTime)
	SELECT   t.t		AS transId
			,t.o		AS odds
			,t.mo	    AS modds 	
			,t.sw	    AS statuswinlost 
			,t.tm	    AS SettlementTime 
			,t.wi	    AS WinLost 
			,t.awi	    AS aWinLost 
			,t.mwi	    AS mWinLost 
			,t.swi	    AS sWinLost 
			,t.pco	    AS PlayerComm 
			,t.co	    AS Comm 
			,t.aco	    AS aComm 
			,t.sco	    AS sComm
			,t.stn	    AS Status
			,t.sti	    AS StatusID
			,t.r	    AS ruben
			,t.e	    AS ExtraInfo
			,t.ut		AS FcUpdateTime
	FROM OPENJSON(@TransJson) WITH (
				t		BIGINT
			   ,o		SMALLMONEY
			   ,mo		SMALLMONEY
			   ,sw		TINYINT
			   ,tm		DATETIME
			   ,wi		MONEY
			   ,awi		MONEY
			   ,mwi		MONEY
			   ,swi		MONEY
			   ,pco		MONEY
			   ,co		MONEY
			   ,aco		MONEY
			   ,sco		MONEY
			   ,stn		NVARCHAR(20)
			   ,sti		TINYINT
			   ,r		TINYINT
			   ,e		VARCHAR(1000)
			   ,ut		DATETIME2
	) AS t

	IF @Action = 'CAL'
	BEGIN
		UPDATE  b
		SET  b.odds				= t.odds
			,b.modds			= t.modds
			,b.statuswinlost	= t.statuswinlost
			,b.SettlementTime	= t.SettlementTime			
			,b.WinLost			= t.WinLost
			,b.aWinLost			= t.aWinLost				
			,b.mWinLost			= t.mWinLost		
			,b.sWinLost			= t.sWinLost
			,b.PlayerComm		= t.PlayerComm	
			,b.Comm				= t.Comm	
			,b.aComm			= t.aComm	
			,b.sComm			= t.sComm	
			,b.Status			= t.Status
			,b.StatusID			= t.StatusID
			,b.ruben			= t.ruben
			,b.ExtraInfo		= t.ExtraInfo
		OUTPUT	 inserted.transid
				,deleted.custid, (inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
				,inserted.modds, inserted.odds, inserted.statuswinlost
				,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben, deleted.ruben, inserted.ExtraInfo
				,deleted.winlost,deleted.statusid	
				,deleted.bettype,deleted.betid,deleted.refno
				,deleted.winlostdate
				,deleted.actual_stake
		INTO @tmpTransOutput (
				transId
				,custid, Balance
				,modds, odds, statuswinlost
				,SettlementTime
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID,ruben, before_ruben, extrainfo
				,bef_winlost, bef_statusid	
				,bettype,betid,refno
				,winlostdate
				,actual_stake
			)
		FROM @tmpTrans AS t
			INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON  t.transid = b.transid
		WHERE ISNULL(b.betdaqid,0) <> -2
	END
	ELSE IF @Action = 'REFUND'
	BEGIN
		UPDATE	b
		SET	 b.Status			= t.Status
			,b.statusID			= t.statusID	
			,b.SettlementTime	= t.SettlementTime					
			,b.winlost			= t.winlost
			,b.awinlost			= t.awinlost
			,b.mwinlost			= t.mwinlost
			,b.swinlost			= t.swinlost
			,b.playercomm		= t.playercomm
			,b.comm				= t.comm
			,b.acomm			= t.acomm
			,b.scomm			= t.scomm
			,b.ruben			= t.ruben
			,b.statuswinlost	= t.statuswinlost
			,b.odds				= t.odds
			,b.FcUpdateTime		= t.FcUpdateTime
		OUTPUT	 inserted.transid
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
		INTO @tmpTransOutput (
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
		FROM @tmpTrans AS t
			INNER JOIN dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK) ON  t.transid = b.transid
	END

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransOutput)
	BEGIN
		SET @transInfoJson = (
				SELECT	transId AS 't'
						,modds AS 'm'
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
						,extrainfo AS 'ex'
						,bef_winlost AS 'bef_w' 
						,bef_statusid AS 'bef_sid' 
						,bettype AS 'bt'
						,betid AS 'bi' 
						,refno AS 'rf' 
				
			FROM	@tmpTransOutput
			FOR JSON AUTO
		)

		IF @Is3rd = 1
		BEGIN			
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateOtherSport'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@SettlementAction = @Action
				,@TicketType = 's'
				,@EventTable = @EventTable
		END
		ELSE
		BEGIN
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateOtherSport'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@SettlementAction = @Action
				,@TicketType = 's'
				,@BroadcastSessionId = @BroadcastSessionId

		END
	END
		
	IF @IsCalculateBalance = 1  AND (@IsCentral = 1 OR @IsSiteDB = 1)
	BEGIN
		
		IF(@CWLBettype > 0)
		BEGIN
			DECLARE @BalanceCWL  TABLE (custid INT, bef_winlost MONEY, after_winlost MONEY,winlostdate SMALLDATETIME, gametypeid SMALLINT)	

			INSERT INTO @BalanceCWL (custid, bef_winlost, after_winlost, winlostdate, gametypeid)
			SELECT custid
				,SUM(IIF(before_ruben = 1,t.bef_winlost - actual_stake,0)) AS bef_winlost
				,SUM(IIF(t.ruben = 1,t.winlost - actual_stake,0)) AS after_winlost
				,winlostdate
				,bettype AS gametypeid
			FROM @tmpTransOutput t
			GROUP BY custid, winlostdate, bettype

			INSERT INTO dbo.BalancePendingCreditGame (custid,winlostdate,bettype,GameTypeID,balance)
			SELECT custid
				,winlostdate
				,@CWLBettype
				,GameTypeID
				,(after_winlost - bef_winlost) AS Balance
			FROM @BalanceCWL t
			WHERE (after_winlost - bef_winlost) > 0
			
			INSERT INTO dbo.BalancePendingDebitGame (custid,winlostdate,bettype,GameTypeID,balance)
			SELECT custid
				,winlostdate
				,@CWLBettype
				,GameTypeID
				,ABS(after_winlost - bef_winlost) AS Balance
			FROM @BalanceCWL
			WHERE (after_winlost - bef_winlost) < 0

		END

		INSERT INTO @BalanceChanged (matchid,custid, walletType, bonusId, balance)
		SELECT	 @MatchId
				,custid
				,2 AS walletType
				,0 AS bonusId
				,SUM(balance)
		FROM @tmpTransOutput
		GROUP BY custid
		HAVING SUM(balance) != 0;
 
		EXEC NAP_Admin_Settlement_BalanceUpd @BalanceChanged		=	@BalanceChanged
											,@ActionID				=   @ActionID
											,@BalanceType			=	@BalanceType
											,@BroadcastSessionId	=	@BroadcastSessionId
											,@ErrMessage			=   @ErrMessage			OUTPUT
											,@ErrCode				=   @ErrCode			OUTPUT
	END
	
END
GO