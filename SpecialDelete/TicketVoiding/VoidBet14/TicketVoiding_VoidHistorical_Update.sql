/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.TicketVoiding_VoidHistorical_Update
(
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX) 
	,@UserId			INT = 0 
	,@IP				VARCHAR(15) =''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(1000)	= ''	OUTPUT
	,@FailedTransIds    VARCHAR(MAX) = '' OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
)
AS
/*		
	Created by: Max
	Date 20211202
	Task: TVS - Void Archived Tickets [Redmine: #140180]
	DB: DBTXN/bodb02

	Revisions: 
		- 20211202@Max: Create new SP [Redmine:#140180]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE	 @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@IsAbnormalBet		TINYINT
			,@CustIds			VARCHAR(MAX)
			,@IsSiteDB			BIT 
			,@transInfo			VARBINARY(MAX)
			,@transInfo3rd			VARBINARY(MAX)
			,@SitedbgroupId				INT = 0

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))					

	SELECT @ErrCode				= 0
		, @ErrMsg				= ''
	
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange

	DECLARE @BalanceInfoBeforeUpd TABLE (
		sporttype		INT
		,CustId			INT
		,MatchId		INT
		,WinlostDate	DATETIME
		,Winlost		MONEY
		,aWinlost		MONEY
		,mWinlost		MONEY
		,sWinlost		MONEY
		,playerComm		MONEY
		,Comm			MONEY
		,aComm			MONEY
		,sComm			MONEY
		,stake			MONEY
		,actual_stake	MONEY
		,balance		MONEY
	)	
	DECLARE @tblInputTransId AS TABLE (transid BIGINT PRIMARY KEY)		
	DECLARE @tmpTransIdBatch TABLE (TransId	BIGINT,sporttype SMALLINT)

	DECLARE @tmpTransInfo AS TABLE (transid BIGINT, winlost MONEY, playercomm MONEY, comm MONEY, acomm MONEY, scomm MONEY
							, status VARCHAR(20), statusID TINYINT, betid BIGINT, ExtraInfo VARCHAR(1000)
							, ruben TINYINT, creator INT, awinlost MONEY, mwinlost MONEY, swinlost MONEY, bettype SMALLINT
						)

	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,Refno				BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,refcode			BIGINT
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
		,winlostdate		SMALLDATETIME
		,eventdate			DATETIME
		,isFinish			BIT
		,srecommend			INT
		,ruben				TINYINT
		,betdaqid			BIGINT
	)

	CREATE TABLE #tblMatch (matchid INT)
	
	SET @StartTime = GETDATE()
	SET @LogActionId = 90100
	SET @SB_Error = 0

	BEGIN TRY
		INSERT INTO @tblInputTransId (transid)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@TransIds,',')		
		
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = 'Invalid TransIds.'										
		
		RETURN
	END CATCH						
		
	INSERT INTO #tmpTransId(TransId, custid, bettype, extrainfo, refcode, matchid, oddsid, winlostdate, Refno, srecommend, ruben, betdaqid)
	SELECT	b.transid, b.custid, b.bettype
			,b.ExtraInfo, b.RefCode
			,b.matchid, b.oddsid
			,b.winlostdate, b.refno
			,b.srecommend
			,b.ruben, b.betdaqid
	FROM @tblInputTransId t 
		INNER JOIN dbo.bettrans14 b WITH(NOLOCK)
			ON b.transid = t.transid
	WHERE b.statusID NOT IN (101, 102)
		AND b.SiteDBGroupID = @SitedbgroupId

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE	b
		SET eventdate 	= m.eventdate
			,sporttype 	= m.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.match14 m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		WHERE bettype NOT IN (9, 29, 2799)		
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET eventdate 	= o.eventdate
			,sporttype	= l.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.outright14 AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid			
		WHERE bettype IN (10)
	END
		
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET eventdate	= o.eventdate
			,sporttype 	= r.sporttype	
		FROM	#tmpTransId b
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #tmpTransId b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END
	
	-- remove un-supported sports & bettype
	DELETE bd
	FROM #tmpTransId bd
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	-- gather match Ids
	INSERT INTO #tblMatch (matchid)
	SELECT	matchid
	FROM	#tmpTransId
	GROUP BY matchid
		
	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 99
 			,@ErrMsg = 'No ticket found.' 								
		
		RETURN
	END
	
	--Return Invalid TransId
	SELECT @FailedTransIds = ''
	;WITH t_invalid AS
	(
		SELECT	transid
		FROM @tblInputTransId temp
		WHERE NOT EXISTS (SELECT 1 
						  FROM #tmpTransId 
						  WHERE transid = temp.transid 
						     OR refno = temp.transid)
	)
	SELECT @FailedTransIds = @FailedTransIds + CASE WHEN @FailedTransIds <> '' THEN ',' ELSE '' END +  CAST(transid AS VARCHAR(100))								  
	FROM t_invalid

	IF @FailedTransIds <> ''
	BEGIN
		SELECT	@ErrCode = 100
 			,@ErrMsg = 'Some invalid tickets exist!'
			,@FailedTransIds = @FailedTransIds
		
		RETURN
	END

	-- STEP 1 : BackUp bettrans
	INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2
			,odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator  
			,betteam, creator, refno, winlostdate, betfrom
			,betcheck
			,comstatus
			,checktime, matchid, bettype  
			,VoidingHistoryId
			,RepUpdateTime
			,SiteDBGroupID
		)  
	SELECT b.transid, b.custid, GETDATE(), b.oddsid, b.hdp1, b.hdp2
		,b.odds, b.stake, b.STATUS, b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator
		,b.betteam, b.creator,b.refno, b.winlostdate, b.betfrom
		,b.betcheck
		,b.comstatus
		,b.checktime, b.matchid, b.bettype  
		,@VoidingHistoryId
		,SYSDATETIME()
		,b.SiteDBGroupID
	FROM	#tmpTransId AS t WITH (NOLOCK)  
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK)  
			ON b.transid = t.TransId
	
	--capture balance before voiding
	INSERT INTO @BeforeUpd(
		matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	)
	SELECT	b.matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	t.matchid
				,b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK)
				ON	t.TransId = b.transid
	)b
	GROUP BY b.matchid
			,b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--For insert rountine task
	INSERT INTO @BalanceInfoBeforeUpd (sporttype, CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
	SELECT	t.sporttype
			,b14.custid
			,b14.matchid
			,b14.winlostdate
			,SUM(b14.winlost)
			,SUM(b14.awinlost)
			,SUM(b14.mwinlost)
			,SUM(b14.swinlost)
			,SUM(b14.playercomm)
			,SUM(b14.comm)
			,SUM(b14.acomm)
			,SUM(b14.scomm)
			,SUM(b14.stake)
			,SUM(b14.actual_stake)
			,SUM(b14.winlost - b14.actual_stake + b14.playercomm) 
	FROM	dbo.bettrans14 b14 WITH(NOLOCK)
		INNER JOIN #tmpTransId t
			ON t.TransId = b14.transid
	GROUP BY b14.custid
			,b14.matchid
			,b14.winlostdate
			,t.sporttype

	/**********************************************   *************************************************************/
	SET @IsAbnormalBet = (SELECT TOP (1) CASE WHEN rd.FilterBy IS NULL THEN 0 ELSE 1 END FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) WHERE rd.RequestId = @RequestId)
	-- STEP 2 : Update bettrans14
	WHILE (1=1)
	BEGIN
		DELETE @tmpTransIdBatch

		UPDATE TOP(2000) t
			SET t.isFinish = 1
		OUTPUT deleted.TransId
			,deleted.sporttype
		INTO @tmpTransIdBatch(TransId, sporttype)
		FROM #tmpTransId t
		WHERE t.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		UPDATE main
			SET 
				winlost = main.actual_stake
				,ruben = 1
				,creator = @UserID
				,mwinlost = 0
				,swinlost = 0
				,awinlost = 0 -- awinlost main ticket
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,statusID = 102
				,status = 'VOID'
				,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(CASE WHEN @IsAbnormalBet = 1 AND @MatchId <> 29 THEN 1
																	WHEN @IsAbnormalBet = 1 AND @MatchId = 29 THEN 2
																	ELSE 0 END,'void',main.ExtraInfo,tmpmain.sporttype,main.bettype) 

			OUTPUT inserted.transid, inserted.winlost, inserted.ruben, inserted.creator, inserted.mwinlost, inserted.swinlost, inserted.awinlost
				, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm, inserted.statusID, inserted.status, inserted.ExtraInfo, inserted.bettype
			INTO @tmpTransInfo (transid, winlost, ruben, creator, mwinlost, swinlost, awinlost, playercomm, comm, acomm, scomm, statusID, status, ExtraInfo, bettype)
		FROM dbo.bettrans14 AS main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpTransIdBatch AS tmpmain ON main.transid = tmpmain.transid

		IF @IsSiteDB = 1
		BEGIN
			SET @transInfo = COMPRESS((
			SELECT	b.transId AS 't'
					, b.winlost AS 'w'
					, b.ruben AS 'r'
					, b.creator AS 'cr'
					, b.awinlost AS 'aw'
					, b.mwinlost AS 'mw'
					, b.swinlost AS 'sw'
					, b.playercomm AS 'pc'
					, b.comm AS 'c'
					, b.acomm AS 'ac'
					, b.scomm AS 'sc'
					, b.statusID AS 'sid'
					, b.status AS 's'
					, b.betid AS 'bid'
					, b.ExtraInfo AS 'ex'
			FROM	@tmpTransInfo b
			WHERE b.bettype NOT IN (10)
			FOR JSON PATH))

			SET @transInfo3rd = COMPRESS((
			SELECT	b.transId AS 't'
					, b.winlost AS 'w'
					, b.ruben AS 'r'
					, b.creator AS 'cr'
					, b.awinlost AS 'aw'
					, b.mwinlost AS 'mw'
					, b.swinlost AS 'sw'
					, b.playercomm AS 'pc'
					, b.comm AS 'c'
					, b.acomm AS 'ac'
					, b.scomm AS 'sc'
					, b.statusID AS 'sid'
					, b.status AS 's'
					, b.betid AS 'bid'
					, b.ExtraInfo AS 'ex'
			FROM	@tmpTransInfo b
			WHERE b.bettype IN (10)
			FOR JSON PATH))

			IF @transInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'Void_14', 'bettrans14', 'U', @matchid, @transInfo, CASE WHEN @MatchId IN (29, 2799) THEN 'p' ELSE 's' END
			END
			IF @transInfo3rd IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'Void_14', 'bettrans14', 'U', @matchid, @transInfo3rd, CASE WHEN @MatchId IN (29, 2799) THEN 'p' ELSE 's' END, 2
			END
		END

	END

	--capture balance after
	INSERT INTO @AfterUpd(
		matchid
		,custid
		,balanceType		
		,walletType
		,bonusId
		,balance
	)
	SELECT	b.matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	t.matchid
				,b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK)
				ON	t.TransId = b.transid
	)b
	GROUP BY b.matchid
			,b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType
	
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @BeforeUpd
		, @BalanceWalletAfter	= @AfterUpd
		, @ActionId				= 0
	
	UPDATE c
	SET CashOutStatus = 6 --Void
	   ,ChangeDate = GETDATE()
	FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpTransId b ON c.TransID = b.transid AND c.MatchID = b.matchid
	WHERE b.betdaqid = -2 

	-- update summary ticket
	DECLARE @AffectedList		VARCHAR(MAX)
	SET @AffectedList = CAST((
		SELECT	CustId AS '@c'
				,WinlostDate AS '@w'
				,-SUM(stake) AS '@st'
				,-SUM(actual_stake) AS '@ast'
				,-SUM(Winlost) AS '@w_dif'
				,-SUM(aWinlost) AS '@aw_dif'
				,-SUM(mWinlost) AS '@mw_dif'
				,-SUM(sWinlost) AS '@sw_dif'
				,-SUM(playerComm) AS '@pc_dif'
				,-SUM(Comm) AS '@c_dif'
				,-SUM(aComm) AS '@ac_dif'
				,-SUM(sComm) AS '@sc_dif'
		FROM	@BalanceInfoBeforeUpd 
		GROUP BY CustId
				,WinlostDate
		FOR XML PATH('r'), ROOT('root'), TYPE
	) AS VARCHAR(MAX))
	
	BEGIN TRY
		-- update summary ticket
		EXEC dbo.TicketVoiding_Admin_Bet14_19999 
			@AffectedList = @AffectedList
			,@IsSiteDB = @IsSiteDB

		-- insert routine task
		EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
			@AffectedList = @AffectedList
			,@IsSiteDB = @IsSiteDB
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = ERROR_PROCEDURE () + ERROR_MESSAGE()
	END CATCH
			 
	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	(
		SELECT DISTINCT b.custid
		FROM @BeforeUpd b
			INNER JOIN @AfterUpd a
				ON b.custid = a.custid
					AND b.matchid = a.matchid
					AND b.balanceType = a.balanceType
					AND b.bonusId = a.bonusId
					AND b.walletType = a.walletType
		WHERE	b.balance > a.balance
	)t

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
	
	--WriteLog
	SET @EndTime = GETDATE()
	BEGIN
		SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
								,@LogActionId AS '@LogActionId'
								,@UserId AS '@UserId'
								,@IP AS '@IP'
								,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
									+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
									+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
									+ CASE WHEN @MatchId = 29 THEN ' Main Parlay ticket with TransId: ' ELSE ' Single ticket with TransId: '  END + @TransIds
									AS '@LogData'
						FOR XML PATH ('r'), ROOT ('root'), TYPE
		) AS VARCHAR(MAX))

		EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	END

	DROP TABLE #tblMatch
END
GO
 



