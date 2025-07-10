/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransDelSpecial_NumberGame] 
	@Option			BIT = 0
	,@MatchId		INT
	,@FromTransDate	DATETIME = NULL
	,@ToTransDate	DATETIME = NULL
	,@BetTypes		VARCHAR(100) = ''
	,@BallSequence	VARCHAR(200)	= ''
	,@TransIds		VARCHAR(MAX) = ''
	,@UserName		NVARCHAR(50)
	,@UserPwd		NVARCHAR(50)
	,@UserID		INT
	,@IP			VARCHAR(15) = ''
	,@Reason		NVARCHAR(500) = ''
	,@ReasonSC		NVARCHAR(500)	= ''
AS
/*
	Created by: 20131015@Kathy
	Task : SP deletebet (Number Game)
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	Original:account\deletebet.asp

	Revisions:
		- 20140307@Kathy: Enhancement to Void Number Game Bet [Redmine:#11992]
		- 20140514@Kathy: Apply LAS system [Redmine:#14287]
		- 20141204@Kathy: Remove codes which are used in checking permission on DBPolicy [Redmine:#27058]	
		- 20150810@Kathy: Using new balance table (BalCreditOthersPending,BalDebitOthersPending) [Redmine:#40125]
		- 20150917@Patrick: #43565: Show error-message in case user clicks void button but no tickets are found
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20160401@Bobby: #55354 - Update changes for new message structure
		- 20161201@Kathy: Company win limit [Redmine:#66599]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181122@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20190718@Charles: Drop table #CTE_CustInfo [115870]
		- 20200811@Charles: Implement Next R/B bet type for NG Color Ball - [128215]
		- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220712@Kathy: Do not using SELECT INTO [Redmine:#175349]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]		
		- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185245]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230705@July: [SD] Enhance void log to detect more information [Redmine: #190590]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20241125@Lani: [TVS] Change join type, serverAlias [Redmine: #213451]
		- 20241211@Louisa: Enhance Winlimit - add matchid/transid for BalancePendingCreditGame [Redmine:#215066]
		- 20250402@Mike: [TVS] Upgrade ExchangeID data type [Redmine:#222191]
		- 20250623@Lani: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

	Param's Explanation: 
		- @Opition: 
			0: By MatchID
			1: By BetID(s)

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
			,@SB_Error			BIT
			,@ActionId			INT = 90999 --TVS - Agency Cash Service

	SET @StartTime = GETDATE()
	SET @LogActionId = 90518
	SET @SB_Error = 0

	SET @LogData = CASE WHEN @Option IS NULL THEN '' ELSE '@Option = ' + CONVERT(NVARCHAR(50), @Option) END
					+ CASE WHEN @MatchId IS NULL THEN '' ELSE ',@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
					+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
					+ CASE WHEN @FromTransdate IS NULL THEN '' ELSE ',@FromTransdate = ''' + CONVERT(NVARCHAR(50), @FromTransdate, 21) + '''' END
					+ CASE WHEN @ToTransdate IS NULL THEN '' ELSE ',@ToTransdate = ''' + CONVERT(NVARCHAR(50), @ToTransdate, 21) + '''' END
					+ CASE WHEN @BetTypes IS NULL THEN '' ELSE ',@BetTypes = ''' + CONVERT(NVARCHAR(MAX), @BetTypes) + '''' END
					+ CASE WHEN @BallSequence IS NULL THEN '' ELSE ',@BallSequence = ''' + CONVERT(NVARCHAR(200), @BallSequence) + ''''  END
					+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
					+ CASE WHEN @UserPwd IS NULL THEN '' ELSE ',@UserPwd = ''' + CONVERT(NVARCHAR(50), @UserPwd) + '''' END
					+ CASE WHEN @UserID IS NULL THEN '' ELSE ',@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
					+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
					+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
					+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_BettransDelSpecial_NumberGame ' + @LogData
				
			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH

	DECLARE @Remark 			VARCHAR(500)
		, @avaiableProcess 	BIT = 0
		, @ErrMsg					NVARCHAR(200)	= ''
		, @ErrCode				INT				= 0	
		, @SiteDBGroupID		SMALLINT
		, @transInfo			VARBINARY(MAX)

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpTransInfo TABLE (transId BIGINT, matchId INT
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,statusID TINYINT, status NVARCHAR(20), ruben TINYINT
			,creator INT
			)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)

	IF NOT EXISTS (
			SELECT 1
			FROM CustDB.dbo.customer WITH (NOLOCK)
			WHERE userpwd = @UserPwd AND custid = @UserID AND roleid >= 5
			)
	BEGIN
		
		SELECT @ErrMsg = 'Sorry. You can not process void bet due to either wrong password or insufficient permission!'
			,@ErrCode = 113

		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg

		RETURN
	END

	CREATE TABLE #tblTransId (transid BIGINT PRIMARY KEY)	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)	
	CREATE TABLE #TmpBallSequence (Seq	TINYINT)
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, increased BIT)
	
	DECLARE @tblMatch TABLE (matchid INT PRIMARY KEY, seq INT)

	BEGIN TRY
		INSERT INTO #tblTransId (transid) 
		SELECT DISTINCT CONVERT(BIGINT, value) 
		FROM STRING_SPLIT(ISNULL(@TransIds, ''), ',') s
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 114
			,@ErrMsg = 'Invalid TransIds ' + ERROR_MESSAGE()

		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
		RETURN
	END CATCH
	
	INSERT INTO #TmpBallSequence(Seq)
	SELECT value
	FROM STRING_SPLIT(@BallSequence, ',')

	INSERT INTO @tblMatch
	SELECT  b.matchid
		   ,ROW_NUMBER() OVER (ORDER BY b.matchid) AS seq
	FROM bettrans b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
	WHERE (
			b.transid IN (
				SELECT transid
				FROM #tblTransId
			) 
			AND @Option = 1
		) 
		OR (b.matchid = @matchid AND @Option = 0)
	GROUP BY b.matchid

	DECLARE @today SMALLDATETIME

	SET @today = CONVERT(NVARCHAR(10), CURRENT_TIMESTAMP, 120)

	--Check settled Date
	DECLARE @seq INT
		,@max_seq INT

	SELECT @seq = 1
		,@max_seq = 0

	SELECT @max_seq = COUNT(matchid)
	FROM @tblMatch

	IF @max_seq = 0
	BEGIN
		SELECT @ErrCode = 114
			,@ErrMsg = 'Invalid TransIds'

		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg

		RETURN
	END
	
	IF (EXISTS (
			SELECT 1 
			FROM match m WITH (NOLOCK)
				INNER JOIN @tblMatch tm ON m.matchid = tm.matchid
			WHERE m.eventdate <> @today
		)
	)
	BEGIN
		SELECT @ErrCode = 115
			,@ErrMsg = 'You are only allowed to void today tickets.'

		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg

		RETURN
	END
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		, 1 AS KeyID
	FROM @tblMatch
	
	-- check and not allow attempt to void tickets of this match while it's being calculated
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @isExistNG		= 1
		, @spName			= @spName
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg

		RETURN
	END	

	CREATE TABLE #BetDelete (
		transid BIGINT
		,custid INT
		,recommend INT
		,mrecommend INT
		,srecommend INT
		,odds SMALLMONEY
		,oddstype TINYINT
		,transdate DATETIME
		,bettype INT
		,betteam NVARCHAR(20)
		,hdp1 SMALLMONEY
		,hdp2 SMALLMONEY
		,betfrom NVARCHAR(4)
		,stake MONEY
		,winlost MONEY
		,comm MONEY
		,STATUS NVARCHAR(20)
		,currency SMALLINT
		,CurrencyName NVARCHAR(50)
		,IsLiveIndicator BIT
		,livehomescore SMALLINT
		,liveawayscore SMALLINT
		,creator INT
		,betid BIGINT
		,matchid INT
		,BallSequence TINYINT
		,SportTypeId INT
		,modds SMALLMONEY
	)		

	IF @Option = 0 AND EXISTS(SELECT TOP 1 1 FROM dbo.match m WHERE m.matchid = @MatchID AND m.sporttype = 164)
	BEGIN
		INSERT INTO #BetDelete (
			transid
			,custid
			,recommend
			,mrecommend
			,srecommend
			,odds
			,oddstype
			,transdate
			,bettype
			,betteam
			,hdp1
			,hdp2
			,betfrom
			,stake
			,winlost
			,comm
			,STATUS
			,currency
			,CurrencyName
			,IsLiveIndicator
			,livehomescore
			,liveawayscore
			,creator
			,betid
			,matchid
			,BallSequence
			,SportTypeId
			,modds
		)
		SELECT DISTINCT b.transid
			,b.custid
			,b.recommend
			,b.mrecommend
			,b.srecommend
			,b.odds
			,b.oddstype
			,b.transdate
			,b.bettype
			,b.betteam
			,b.hdp1
			,b.hdp2
			,b.betfrom
			,b.stake
			,b.winlost - b.actual_stake
			,b.playercomm
			,b.STATUS
			,b.currency
			,b.CurrencyName
			,b.liveindicator
			,b.livehomescore
			,b.liveawayscore
			,b.creator
			,b.betid
			,m.matchid
			,NULL AS BallSequence
			,m.sporttype
			,b.modds
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid			
		WHERE	b.matchid = @MatchId 
				AND b.transdate BETWEEN @FromTransDate AND @ToTransDate
				AND b.bettype IN (SELECT CONVERT(INT, value) FROM STRING_SPLIT(ISNULL(@BetTypes, ''), ','))
				AND winlostdate = @today 
				AND statusID NOT IN (101, 102, 121) 
				AND b.transid IN ( SELECT t1.transid FROM #tblTransId t1 WITH (NOLOCK) )
				AND b.SiteDBGroupID = @SiteDBGroupID
	END
	ELSE
	BEGIN
		INSERT INTO #BetDelete (
			transid
			,custid
			,recommend
			,mrecommend
			,srecommend
			,odds
			,oddstype
			,transdate
			,bettype
			,betteam
			,hdp1
			,hdp2
			,betfrom
			,stake
			,winlost
			,comm
			,STATUS
			,currency
			,CurrencyName
			,IsLiveIndicator
			,livehomescore
			,liveawayscore
			,creator
			,betid
			,matchid
			,BallSequence
			,SportTypeId
			,modds
		)
		SELECT DISTINCT b.transid
			,b.custid
			,b.recommend
			,b.mrecommend
			,b.srecommend
			,b.odds
			,b.oddstype
			,b.transdate
			,b.bettype
			,b.betteam
			,b.hdp1
			,b.hdp2
			,b.betfrom
			,b.stake
			,b.winlost - b.actual_stake
			,b.playercomm
			,b.STATUS
			,b.currency
			,b.CurrencyName
			,b.liveindicator
			,b.livehomescore
			,b.liveawayscore
			,b.creator
			,b.betid
			,m.matchid
			,BS_tmp.BallSequence
			,m.sporttype
			,b.modds
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
			OUTER APPLY (SELECT BallSequence 
							FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore)
							WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
							) AS BS_tmp
		WHERE	(
					(
					@Option = 0 
						AND b.matchid = @MatchId 
						AND b.transdate BETWEEN @FromTransDate AND @ToTransDate
						AND b.bettype IN (SELECT CONVERT(INT, value) 
										  FROM STRING_SPLIT(ISNULL(@BetTypes, ''), ','))
						AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WHERE Seq = BS_tmp.BallSequence)						
					) OR (@Option = 1)
				) 
				AND (b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120)
				AND winlostdate = @today 
				AND statusID NOT IN (101, 102, 121) 
				AND b.transid IN ( SELECT t1.transid FROM #tblTransId t1 WITH (NOLOCK) )
				AND b.SiteDBGroupID = @SiteDBGroupID
	END

	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)
	BEGIN
		SELECT @ErrCode = 99
		, @ErrMsg 		= 'No ticket found.'

		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
	END
	ELSE
	BEGIN
		-- STEP 1 : BackUp
		INSERT INTO zzzbettrans (
			transid
			,custid
			,transdate
			,oddsid
			,hdp1
			,hdp2
			,odds
			,stake
			,STATUS
			,winlost
			,livehomescore
			,liveawayscore
			,liveindicator
			,betteam
			,creator
			,refno
			,winlostdate
			,betfrom
			,betcheck
			,checktime
			,matchid
			,bettype
			,RepUpdateTime
			,SiteDBGroupID
			)
		SELECT transid
			,custid
			,CURRENT_TIMESTAMP
			,oddsid
			,hdp1
			,hdp2
			,odds
			,stake
			,STATUS
			,winlost
			,livehomescore
			,liveawayscore
			,liveindicator
			,betteam
			,creator
			,refno
			,winlostdate
			,betfrom
			,betcheck
			,checktime
			,matchid
			,bettype
			,SYSDATETIME()
			,b.SiteDBGroupID
		FROM bettrans b WITH (NOLOCK)
		WHERE b.transid IN (
				SELECT transid
				FROM #BetDelete
				)
		
		CREATE TABLE #BetBefore (transid bigint, custid INT,winlostdate SMALLDATETIME,balance MONEY,winlost MONEY,gametypeid SMALLINT)
		CREATE TABLE #BetAfter (transid bigint, custid INT,winlostdate SMALLDATETIME,balance MONEY,winlost MONEY,gametypeid SMALLINT)
		
		CREATE TABLE #BeforeUpd (
			custid INT
			,winlostdate SMALLDATETIME
			,balance MONEY
			,winlost MONEY
			,gametypeid SMALLINT
			)

		CREATE TABLE #AfterUpd (
			custid INT
			,winlostdate SMALLDATETIME
			,balance MONEY
			,winlost MONEY
			,gametypeid SMALLINT
			)

		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
		
		--Get data before update
		INSERT INTO #BetBefore (transid,custid,winlostdate,balance,winlost,gametypeid )
		SELECT b.transid, b.custid,b.winlostdate,(b.winlost - b.actual_stake + b.playercomm) AS balance
					,CASE 
						WHEN b.ruben = 1 THEN b.winlost - b.actual_stake
						ELSE 0
					END AS winlost
				,b.bettype AS gametypeid
		FROM bettrans b WITH (NOLOCK)
		WHERE b.transid IN (SELECT transid FROM #BetDelete	)

		INSERT INTO #BeforeUpd (
			custid
			,winlostdate
			,balance
			,winlost
			,gametypeid
			)
		SELECT custid
			,winlostdate
			,SUM(balance)
			,SUM(winlost)
			,gametypeid
		FROM #BetBefore
		GROUP BY  CustID,  winlostdate, gametypeid

		-- STEP 2 : Update
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET winlost = actual_stake
			,ruben = 1
			,STATUS = 'VOID'
			,creator = @UserID
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0
			,statusID = 102
			OUTPUT inserted.TransId, inserted.matchid, inserted.winlost, inserted.ruben, inserted.status, inserted.creator, inserted.awinlost, inserted.mwinlost, inserted.swinlost
				, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm, inserted.statusID
			INTO @tmpTransInfo (transId, matchId, WinLost, ruben, status, creator, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, statusID)
		WHERE transid IN ( SELECT transid FROM #BetDelete)
		
		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			INSERT INTO @tmpMatchidInfo (MatchId)
			SELECT DISTINCT MatchId FROM @tmpTransInfo

			WHILE (1=1)
			BEGIN
				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId 
				FROM @tmpMatchidInfo m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;

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
				FROM	@tmpTransInfo b WHERE matchid = @MatchId
				FOR JSON PATH))
		
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd(SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'VoidNumberGame', 'bettrans', 'U', @MatchId, @transInfo, 's', 1
			END
		END

		--Get data after update
		INSERT INTO #BetAfter (transid, custid,winlostdate,balance,winlost,gametypeid)
		SELECT b.transid, b.custid,b.winlostdate,(b.winlost - b.actual_stake + b.playercomm) AS balance
			,CASE 
				WHEN b.ruben = 1 THEN b.winlost - b.actual_stake 
				ELSE 0 
			END AS winlost
			,b.bettype AS gametypeid
		FROM bettrans b WITH (NOLOCK)
		WHERE b.transid IN (SELECT transid	FROM #BetDelete	)

		INSERT INTO #AfterUpd (
			custid
			,winlostdate
			,balance
			,winlost
			,gametypeid
			)
		SELECT custid
			,winlostdate
			,SUM(balance)
			,SUM(winlost)
			,gametypeid
		FROM #BetAfter
		GROUP BY CustID, winlostdate, gametypeid

		INSERT INTO @tblCreditPending (custID, balance)
		SELECT a.custid
			,(a.balance - b.balance) AS Balance
		FROM #BeforeUpd b
			INNER JOIN #AfterUpd a 
				ON	a.custid = b.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE (a.balance - b.balance) > 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 4 -- Others
				
		
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT a.custid
			,ABS(a.balance - b.balance) AS Balance
		FROM #BeforeUpd b
			INNER JOIN #AfterUpd a 
				ON	a.custid = b.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE (a.balance - b.balance) < 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 4 -- Others

		
		---insert data into pending balance game table 
		INSERT INTO BalancePendingCreditGame (
			custid
			,winlostdate
			,balance
			,bettype
			,GameTypeID
			,RefID
			)
		SELECT a.custid
			,a.winlostdate
			,(a.winlost - b.winlost) AS Balance
			,81
			,a.gametypeid
			,b.transid
		FROM #BetBefore b
			INNER JOIN #BetAfter a 
				ON a.transid = b.transid
		WHERE (a.winlost - b.winlost) > 0

		INSERT INTO BalancePendingDebitGame (
			custid
			,winlostdate
			,balance
			,bettype
			,GameTypeID
			,RefID
			)
		SELECT a.custid
			,a.winlostdate
			,ABS(a.winlost - b.winlost) AS Balance
			,81
			,a.gametypeid
			,b.transid
		FROM #BetBefore b
			INNER JOIN #BetAfter a 
				ON	a.transid = b.transid
		WHERE (a.winlost - b.winlost) < 0
		
		INSERT INTO #Balance (custid, balance, increased)
		SELECT b.custid, SUM(a.balance - b.balance) AS balance, CASE WHEN SUM(a.balance) > SUM(b.balance) THEN 1 ELSE 0 END
		FROM #BeforeUpd AS b
			INNER JOIN #AfterUpd AS a ON b.custid = a.custid 
										AND b.winlostdate = a.winlostdate 
										AND b.gametypeid = a.gametypeid
		WHERE a.balance <> b.balance
		GROUP BY b.custid

		--> Add Agency Cash Service - Negative Balance into BalanceNegative table  [#225390]
		IF OBJECT_ID('BalanceNegative','U') IS NOT NULL AND @SiteDBGroupID = 3 --Credit
		BEGIN
			INSERT INTO [dbo].[BalanceNegative]
					   ([ExecDate]
					   ,[MatchID]
					   ,[ActionID]
					   ,[GroupID]
					   ,[CustID]
					   ,[Balance]
					   ,[StatusID]
					   ,[Remark])
			SELECT	 GETDATE()
					,CASE WHEN @Option = 0 THEN @MatchId ELSE 0 END
					,@ActionID
					,0		-- For Void/Recover
					,CustID
					,Balance
					,0
					,@spName
			FROM	#Balance
			WHERE	increased = 0
		END		        
		DROP TABLE #Balance
		
		----------------Insert Max Payout Queue----------------
		DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL, @sporttype SMALLINT = NULL
		DECLARE @Match_tmp AS TABLE (matchId INT, sporttype SMALLINT, IsFinish BIT)

		INSERT INTO @Match_tmp (MatchId, sporttype)
		SELECT DISTINCT mt.matchid, m.sporttype
		FROM @tblMatch mt
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = mt.matchid

		WHILE (1=1)
		BEGIN
			SELECT @TransIds_MaxPO = '', @MatchId_MaxPO = NULL, @sporttype = NULL
		
			UPDATE TOP(1) mt SET mt.IsFinish = 1, @MatchId_MaxPO = mt.matchid, @sporttype = mt.sporttype
			FROM @Match_tmp mt
			WHERE mt.IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK
			SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
							,CASE 
								WHEN dp.custid IS NOT NULL THEN 3 --deposit 
								WHEN s.SiteLabel = '789y' THEN 2 --789y
								ELSE 1 END AS '@sitetype'
							,b.TransId AS '@transid'
							,b.bettype AS '@bettype'
						FROM #BetDelete b
							INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
							INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON c.site = s.site
							LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
						WHERE b.matchid = @MatchId_MaxPO
						FOR XML PATH('r'), ROOT('root')
					)

			IF @sporttype IN (164,168)
			BEGIN
				EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
					@MatchId = @MatchId_MaxPO
					,@sporttype = @sporttype
					,@TransidList = @TransIds_MaxPO
			END
		END
		DECLARE @isITAdmin BIT 
		
		-- CHECK IT GROUP or NOT ?   
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
		
		CREATE TABLE #CTE_CustInfo (CustId INT, UserName VARCHAR(30), Username2 VARCHAR(50), Site VARCHAR(10))

		--1. Return table validate
		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg

		;WITH CTE_CustIdAll AS (
			SELECT DISTINCT t.custid
			FROM #BetDelete b
			CROSS APPLY (
				VALUES (custid)
				,(creator)
				,(recommend)
				,(mrecommend)
				,(srecommend)
			) AS t (custid)
		), CTE_CustInfo AS (
			SELECT ci.custid
				, ci.username
				, ci.username2
				, ci.site
			FROM CustDB.dbo.Customer ci WITH(NOLOCK)
				INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid
			
		)
		INSERT INTO #CTE_CustInfo(CustId, UserName, Username2, Site)
		SELECT custid, username, username2, site
		FROM CTE_CustInfo
		
		SELECT b.transid
			,b.transdate
			,b.bettype AS BetTypeId
			,b.betfrom
			,b.odds
			,b.stake
			,b.winlost
			,b.currency
			,b.CurrencyName
			,b.STATUS
			,b.oddstype
			,b.betteam
			,b.hdp1 AS Handicap1
			,b.hdp2 AS Handicap2
			,b.comm
			,b.IsLiveIndicator AS IsLive
			,b.livehomescore
			,b.liveawayscore
			,b.betid
			,m.matchid
			,m.leagueid
			,m.homeid
			,m.awayid
			,b.custid
			,b.recommend
			,b.mrecommend
			,b.srecommend
			,ci.username
			,ci.username2
			,cr.username AS creator
			,ci.username AS CustUserName
			,ci.username2 as CustUserName2
			,ag.UserName AS AgUserName
			,ma.UserName AS MagUserName
			,su.Username AS SagUserName
			,CASE 
				WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
				ELSE ci.site 
			END AS EmailGroup
			,ci.site 
			,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
			,@isITAdmin	AS IsITSupport
			,m.MatchCode
			,m.ShowTime
			,b.BallSequence
			,b.SportTypeId
			,b.modds AS MasterOdds
		FROM #BetDelete b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) 
				ON m.matchid = b.matchid
			INNER JOIN #CTE_CustInfo ci WITH(NOLOCK)
				ON b.custid = ci.custid
			INNER JOIN #CTE_CustInfo cr WITH(NOLOCK)
				ON b.creator = cr.custid	
			LEFT JOIN #CTE_CustInfo ag WITH(NOLOCK)
				ON b.recommend = ag.custid
			LEFT JOIN #CTE_CustInfo ma WITH(NOLOCK)
				ON b.mrecommend = ma.custid
			INNER JOIN #CTE_CustInfo su WITH(NOLOCK)
				ON b.srecommend = su.custid
			LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) 
				ON b.srecommend = s.custid

		DROP TABLE #BeforeUpd
		DROP TABLE #AfterUpd
		DROP TABLE #CTE_CustInfo
		DROP TABLE #BetBefore
		DROP TABLE #BetAfter

	END
	
	------ releasing SD process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		,@IsExistNG			= 1
		,@IsReleased		= 1

	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN       
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, CASE WHEN @Option = 0 THEN @MatchId ELSE 0 END, GETDATE(),@SubmittedDate)
        END        
	END TRY
	BEGIN CATCH
	END CATCH

	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'
							,CASE WHEN @Option = 0 THEN @MatchId ELSE 0 END AS '@MatchId'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.'
								+ @LogData
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT


	DROP TABLE #tblMatchProcess
	DROP TABLE #tblTransId
	DROP TABLE #BetDelete
	DROP TABLE #TmpBallSequence
	
END
GO