/*<info serverAlias="DBTXN-bodb02" executers="dot_intg,bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_s175
	@MatchId		INT
	,@Action		VARCHAR(20)		= 'CAL'
	,@ResultId		INT				
	,@GameResult	VARCHAR(50)		= ''	
	,@IsAuto		BIT				= 1
	,@AdminId		INT
	,@IP			VARCHAR(50)		= ''
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20210810@Kathy
	Task: Settlement for Bitcoin
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210810@Kathy: Incorporate Bitcoin  [Redmine:#159714]
		- 20210930@Kathy: Change BalanceType  [Redmine:#159714]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		- 20230901@Helen: Bitcoin issue [Redmine: #193538]

	Param's Explanation:	
		@Action: CAL, REFUND
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime				DATETIME
			,@EndTime				DATETIME
			,@avaiableProcess		BIT
			,@ActionId				INT
			,@batchCount			INT = 2000	
			,@strTransIds			VARCHAR(MAX)
			,@bettype				SMALLINT
		
			,@procName				SYSNAME
			,@recipients			VARCHAR(250)
			,@remark				VARCHAR(200)
			,@IsCentral				BIT
	
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY)	
	DECLARE @BalanceWalletBefore 	TVP_BalanceWalletChange
	DECLARE @BalanceWalletAfter 	TVP_BalanceWalletChange	

	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, isFinish BIT)
	CREATE TABLE #BalanceBefore (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)
	CREATE TABLE #BalanceAfter (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)	
	CREATE TABLE #Balance_Bitcoin_175(custid INT, balance MONEY, Increased BIT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
		
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
			
	CREATE INDEX IX_Balance_Increased ON #Balance_Bitcoin_175(Increased)
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	SELECT	@StartTime = GETDATE()
			,@ActionId = CASE @Action 
							WHEN 'CAL' THEN 81033
							WHEN 'REFUND' THEN 81034
						END
			,@Remark = ''
			,@Bettype = 7901
			,@procName =  OBJECT_NAME(@@procid)
			
	-------------------------BEGIN TRY------------------------------------------------------------------------
	BEGIN TRY
		-- check and not allow attempt to settlement same game while it's still not finish
		INSERT INTO #tblMatchProcess (matchid, KeyID)
		SELECT	@matchid AS matchid, 8 AS KeyID
		----------------------------------------------------------------------------------------------	
	
		--check settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch3rd = 1
			,@avaiableProcess = @avaiableProcess OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			
		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN
			SELECT	@ErrCode
					,@ErrMsg
	
			RETURN
		END		

		--get transid
		IF @Action LIKE 'CAL%'
		BEGIN
			IF ISNULL(@GameResult,'') = ''
			BEGIN
				SELECT	@GameResult = GameResult
				FROM	DBPRO.bodb02.dbo.ResultDetail3rd WITH(NOLOCK)
				WHERE	MatchID = @MatchId
						AND ResultID = @ResultId
			END

			INSERT INTO #tmpTransID (TransID, modds)
			SELECT	transid, m.modds
			FROM	dbo.bettrans b WITH (NOLOCK)
				CROSS APPLY dbo.f_Set_Calculate_modds(b.bettype, b.betteam, b.hdp1, NULL, @GameResult,NULL, NULL, NULL, NULL, NULL) m
			WHERE	b.matchid = @MatchId
					AND b.bettype = @bettype
					AND b.statusID NOT IN (101,102)
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		END
		ELSE IF @Action LIKE 'REFUND%'
		BEGIN
			
			INSERT INTO #tmpTransID(TransID)
			SELECT	transid
			FROM	dbo.bettrans b WITH (NOLOCK) 
			WHERE	b.matchid = @MatchId
					AND b.bettype = @bettype
					AND	b.statusID NOT IN (103, 101, 102)
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		END 		
			 
		INSERT INTO #BalanceBefore(custid, balance, winlost, winlostdate, gametypeid)
		SELECT	custid
				,SUM(winlost - actual_stake + playercomm)
				,SUM(CASE
						WHEN ruben = 1 THEN winlost - actual_stake 
						ELSE 0 
					END) AS winlost
				,winlostdate
				,bettype
		FROM	dbo.bettrans bt WITH (ROWLOCK)
			INNER JOIN #tmpTransId t
				ON bt.transid = t.transid
		WHERE	bt.matchid = @matchid
				AND bt.bettype = @bettype
		GROUP BY custid, winlostdate, bettype		
		
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchCount) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds
			INTO @tmpTransIDBatch(transid, modds)
			FROM #tmpTransID t 
			WHERE isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
			
			IF @batchCount = 0 BREAK

			--filter selectedRID by current Profile and BetType
			SET @strTransIds = (SELECT transid		AS '@t'
										,modds		AS '@m'
										,1			AS '@ot'
								FROM @tmpTransIDBatch
								FOR XML PATH('r'), ROOT( 'root' ))

			EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = @action
			   ,@strTransIds		 = @strTransIds
			   ,@EventTable			 = 3 -- match3rd
			   ,@Is3rd				 = 1 
		END	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()
				
	END CATCH

	INSERT INTO #BalanceAfter(custid, balance, winlost, winlostdate, gametypeid)
	SELECT	custid
			,SUM(winlost - actual_stake + playercomm)
			,SUM(CASE 
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0
				END) AS winlost
			,winlostdate
			,bettype
	FROM	dbo.bettrans bt WITH (ROWLOCK)
		INNER JOIN #tmpTransId t
			ON bt.transid = t.transid
	WHERE matchid = @matchid 
			AND bt.bettype = @bettype
	GROUP BY custid, winlostdate, bettype
		
	INSERT INTO #Balance_Bitcoin_175
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM	#BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON	b.custid = a.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE	b.balance <> a.balance
	
	INSERT INTO @tblDebitPending (custID, balance)
	SELECT	custid, ABS(balance)
	FROM	#Balance_Bitcoin_175
	WHERE	Increased = 0
		
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitPending
			,@Type			= 4 
		
	INSERT INTO @tblCreditPending (custID, balance)
	SELECT	custid, balance
	FROM	#Balance_Bitcoin_175
	WHERE	Increased = 1
		
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditPending
			,@Type			= 4 
	
	---insert data into pending balance game table 
	INSERT INTO BalancePendingCreditGame (
		custid
		,winlostdate
		,balance
		,bettype
		,GameTypeID
		)
	SELECT a.custid
		,a.winlostdate
		,(a.winlost - b.winlost) AS Balance
		,@bettype
		,a.gametypeid
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON	a.custid = b.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE (a.winlost - b.winlost) > 0
	
	INSERT INTO BalancePendingDebitGame (
		custid
		,winlostdate
		,balance
		,bettype
		,GameTypeID
		)
	SELECT a.custid
		,a.winlostdate
		,ABS(a.winlost - b.winlost) AS Balance
		,@bettype
		,a.gametypeid
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON	a.custid = b.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE (a.winlost - b.winlost) < 0
		
	DROP TABLE #Balance_Bitcoin_175
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter
	
	-- Releasing settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch3rd	= 1
		,@IsReleased		= 1

	-- send email incase of failed	
	IF @ErrCode <> 0
	BEGIN
		SELECT @recipients	= Recipients
		FROM [dbo].[f_Set_Bitcoin_EmailConfig] ()
		WHERE GroupName = 'ERROR'

		SET @Remark = 'NAP: Settlement Bitcoin - Error: ' + @ErrMsg
		
		--SEND error message				
		EXEC [dbo].[NAP_Admin_SendMail]
			@SourceName 		= 'NAP-Settlement-Bitcoin'
			,@matchid		= @matchid
			,@AdminId		= @AdminId
			,@ActionId		= @ActionId
			,@message		= @ErrMsg
			,@severity		= 'Error'
			,@procName 		= @procName
			,@Remark		= @Remark
			,@recipients	= @recipients

		RETURN
	END
	
	SET @EndTime = GETDATE()	
	
	IF @IsCentral = 1
	BEGIN		
		SELECT @Remark =  'IsAuto: ' + CAST(@IsAuto AS VARCHAR(2)) + '<br/>' 
							+ CASE WHEN @GameResult <> '' THEN 'GameResult: ' + @GameResult  + '<br/> ' ELSE '' END
							+ 'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms' 
			
		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle @UserID = @AdminId
			,@Matchid = @matchid
			,@ActionID = @ActionID
			,@Remark = @Remark
			,@IP = @IP

	END

END
GO
