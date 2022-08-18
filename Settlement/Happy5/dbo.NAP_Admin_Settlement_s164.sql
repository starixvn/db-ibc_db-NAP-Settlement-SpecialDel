/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Casino" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_s164
	@MatchId		INT
	,@Action		VARCHAR(20)		= 'CAL'
	,@AdminId		INT
	,@IsAuto		BIT				= 1
	--,@Resources		VARCHAR(MAX)	= NULL
	,@strOldResult	VARCHAR(MAX)	= NULL
	,@IP			VARCHAR(50)		= ''
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created by: Vicky.phan
	Date: 20181015
	Task: change the result of Happy 5
	DB: DBTXN/BODB02
	
	Revisions:
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		- 20200713@Kathy: Add more param for function f_Set_Calculate_modds [Redmine:#135846]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:	
		@Action: CAL, REFUND
		@Resources = '<Resources>
						<Resource Id="1" Result="1" />
						<Resource Id="2" Result="2" />
						<Resource Id="3" Result="3" />
						<Resource Id="4" Result="4" />
						<Resource Id="5" Result="5" />
					  </Resources>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime				DATETIME
			,@EndTime				DATETIME
			,@Remark				VARCHAR(200)
			,@avaiableProcess		BIT
			,@ActionId				INT
			,@batchCount			INT = 2000	
			,@Sporttype				TINYINT
			,@strTransIds			VARCHAR(MAX)
			,@MaxTransID			BIGINT
			,@delegateBettype		SMALLINT
			,@IsCentral				BIT
			
	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, isFinish BIT)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT)
	
	DECLARE @BalanceWalletBefore 	TVP_BalanceWalletChange
	DECLARE @BalanceWalletAfter 	TVP_BalanceWalletChange
	DECLARE @tmpBetTickets 			TVP_Settlement_BetTicket
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	DECLARE @tmpResultDetail TABLE (pfID INT, ResourceID VARCHAR(20), Bettype SMALLINT, Result1 VARCHAR(50), Result2 VARCHAR(50), OddsType SMALLINT, isSourceFromDB BIT)
	DECLARE @tmpOldResultDetail TABLE (Seq TINYINT, Number TINYINT)
	----------------------------------------------------------------------------------------------
	SET @delegateBettype = 81
	
	SELECT	@StartTime = GETDATE()
			,@ActionId = CASE @Action 
							WHEN 'CAL' THEN 81000
							WHEN 'REFUND' THEN 81001 
						END
			,@Remark = ''
	
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	--get info of match
	SELECT @sportType	   = sportType
	FROM   DBPRO.BODB02.dbo.match WITH (NOLOCK)
	WHERE  matchid = @matchid
	
	
	-------------------------BEGIN TRY------------------------------------------------------------------------
	BEGIN TRY
		-- check and not allow attempt to settlement same game while it's still not finish
		INSERT INTO #tblMatchProcess (matchid, KeyID)
		SELECT	@matchid AS matchid, 1 AS KeyID
		----------------------------------------------------------------------------------------------
		
		--check settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch = 1
			,@avaiableProcess = @avaiableProcess OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			
		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN
			SELECT	@ErrCode = 1000000
					,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
	
			RETURN
		END
		-------------------------------------------parse XML and add more info----------------------------------
		INSERT INTO @tmpResultDetail(pfID, ResourceID, Bettype, Result1, Result2, OddsType, isSourceFromDB)
		EXEC DBPRO.bodb02.dbo.[NAP_Set_Resource_Parsing] 
			@Sporttype = @Sporttype
			,@MatchID	= @MatchID
			,@Action	= @Action
			,@ErrCode 	= @ErrCode OUTPUT
			,@ErrMsg	= @ErrMsg OUTPUT
		
		IF @ErrCode IS NOT NULL AND @ErrCode > 0
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch		= 1
				,@IsReleased		= 1
			RETURN
		END
		----------------------------------------------------------------------------------------------------
		
		--get transid
		IF @Action LIKE 'CAL%'
		BEGIN
			INSERT INTO #tmpTransID (TransID, modds, OddsType)
			SELECT transid, m.modds, sr.OddsType
			FROM bettrans b WITH (NOLOCK)
				CROSS APPLY(
								SELECT TOP 1 pfID, Result1, Result2, OddsType
								FROM @tmpResultDetail t
								WHERE b.BetType = t.BetType
							) sr
				CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, NULL, NULL, sr.Result1, sr.Result2, NULL, NULL, NULL, NULL) m
			WHERE b.matchid = @MatchId
				AND b.statusID NOT IN (101,102)
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		END
		ELSE IF @Action LIKE 'REFUND%'
		BEGIN
			
			INSERT INTO #tmpTransID(TransID)
			SELECT transid
			FROM bettrans b WITH (NOLOCK) 
			WHERE b.matchid = @MatchId
				AND	b.statusID NOT IN (103, 101, 102)
				AND EXISTS (
							SELECT 1
							FROM @tmpResultDetail t
							WHERE b.BetType = t.BetType
							)
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		END 
		
		
		--//MB is running?
		IF EXISTS (
			SELECT 1 FROM dbo.SystemSettings WITH(NOLOCK)
			WHERE VName = 'isMovingBet' AND VValue = '1'
		)
		BEGIN
			-- waiting for releasing lock on bettrans table
			SELECT @MaxTransID = MAX(transid)
			FROM dbo.bettrans WITH(ROWLOCK)
			WHERE matchid = @MatchId
			
			WAITFOR DELAY '00:00:02:000'
		END	
	
		SELECT @MaxTransID = MAX(transid)
		FROM #tmpTransID

		-------------------------------------------------------------
		---		CAPTURE value BALANCE before settlement		---
		---------------------------VVVV------------------------------
		CREATE TABLE #BalanceBefore (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)

		--===
		INSERT INTO #BalanceBefore(custid, balance, winlost, winlostdate, gametypeid)
		SELECT custid
			,SUM(winlost - actual_stake + playercomm)
			,SUM(CASE
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0 
				END) AS winlost
			,winlostdate
			,bettype
		FROM dbo.bettrans bt WITH (ROWLOCK)
		WHERE matchid = @matchid AND transid <= @MaxTransID
			AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
		GROUP BY custid, winlostdate, bettype
		
		
		------START UPDATE BETTRANS---------------------------------------------------------------------------
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchCount) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds, deleted.OddsType
			INTO @tmpTransIDBatch(transid, modds, OddsType)
			FROM #tmpTransID t 
			WHERE isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
				  --,@ticketCount	+= @batchCount
			
			IF @batchCount = 0 BREAK

			--filter selectedRID by current Profile and BetType
			IF @Action LIKE 'CAL%'
			BEGIN
				SET @strTransIds 		= (SELECT transid		AS '@t'
													,modds		AS '@m'
													,OddsType	AS '@ot'
										   FROM @tmpTransIDBatch
										   FOR XML PATH('r'), ROOT( 'root' ))
			END
			ELSE 
			BEGIN
				SET @strTransIds 		= (SELECT transid		AS '@t'
										   FROM @tmpTransIDBatch
										   FOR XML PATH('r'), ROOT( 'root' ))
			END
			

			EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = @action
			   ,@strTransIds		 = @strTransIds
		END

		------END UPDATE BETTRANS-----------------------------------------------
	
		-------------------------------------------------------------
		---		 CAPTURE value BALANCE after settlement		---
		---------------------------VVVV------------------------------
		
		CREATE TABLE #BalanceAfter (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)

		INSERT INTO #BalanceAfter(custid, balance, winlost, winlostdate, gametypeid)
		SELECT custid
			,SUM(winlost - actual_stake + playercomm)
			,SUM(CASE 
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0
				END) AS winlost
			,winlostdate
			,bettype
		FROM dbo.bettrans bt WITH (ROWLOCK)
		WHERE matchid = @matchid AND transid <= @MaxTransID
			AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
		GROUP BY custid, winlostdate, bettype
		
		-------------------------------------------------------------
		---                   compare BALANCE                     ---
		---------------------------VVVV------------------------------
		CREATE TABLE #Balance (custid INT, balance MONEY, Increased BIT)
	
		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
			
		CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
	
		INSERT INTO #Balance
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM	#BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	b.custid = a.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE	b.balance <> a.balance
	
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT	custid, ABS(balance)
		FROM	#Balance
		WHERE	Increased = 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 4 -- Others
		
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT	custid, balance
		FROM	#Balance
		WHERE	Increased = 1
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 4 -- Others
	
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
			,@delegateBettype
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
			,@delegateBettype
			,a.gametypeid
		FROM #BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	a.custid = b.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE (a.winlost - b.winlost) < 0
		
		DROP TABLE #Balance
		DROP TABLE #BalanceBefore
		DROP TABLE #BalanceAfter
	
		
		
		-- Releasing settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			,@IsReleased		= 1
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()
				
		-- Releasing settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			,@IsReleased		= 1
	END CATCH
	
	
	IF @IsCentral = 1
	BEGIN
		SET @EndTime = GETDATE()
		
		DECLARE @doing NVARCHAR(300) = 'Settlement for matchid: ' + CAST(@MatchId AS VARCHAR)
		EXEC dbo.Logfile_V2 
			@UserID = @AdminId
			,@Doing = @doing
			,@extend = @MatchId
		
	BEGIN TRY
		
		DECLARE @remarkNewValue VARCHAR(MAX) = ''
		SET @Remark = ''

		SELECT @remarkNewValue = @remarkNewValue + ', B' +ResourceID + '(' + Result1 + ')'
		FROM @tmpResultDetail
		WHERE ISNULL(isSourceFromDB,0) = 1 AND Result1 > 0
		
		SELECT @Remark =  'IsAuto: ' + CAST(@IsAuto AS VARCHAR(2)) + '<br/>' 
						+ CASE WHEN ISNULL(@strOldResult,'') <> '' THEN 'Old Results: ' + SUBSTRING(@strOldResult, 2, LEN(@strOldResult))  + '<br/> ' ELSE '' END
						+ CASE WHEN @remarkNewValue <> '' THEN 'Results: ' + SUBSTRING(@remarkNewValue, 2, LEN(@remarkNewValue))  + '<br/> ' ELSE '' END
						+ 'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms' 
		
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			,@Matchid = @matchid
			,@ActionID = @ActionID
			,@finalhomescore = NULL
			,@finalawayscore = NULL
			,@hthomescore = NULL
			,@htawayscore = NULL
			,@GoalRecord = NULL
			,@betstatus = NULL
			,@Remark = @Remark
			,@IP = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 200)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
				,@Matchid = @matchid
				,@ActionID = @ActionID
				,@finalhomescore = NULL
				,@finalawayscore = NULL
				,@hthomescore = NULL
				,@htawayscore = NULL
				,@GoalRecord = NULL
				,@betstatus = NULL
				,@Remark = @Remark
				,@IP = @IP
		END CATCH

	END
END
GO
