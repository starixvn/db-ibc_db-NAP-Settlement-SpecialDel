/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Casino" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_s164
	@MatchId		INT
	,@Action		VARCHAR(20)		= 'CAL'
	,@AdminId		INT
	,@IsAuto		BIT				= 1
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
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		- 20230905@Aries: Set Max Payout for Non-sports Products [Redmine:#193259]

	Param's Explanation:	
		@Action: CAL, REFUND
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
			,@SiteDBGroupId			SMALLINT
			,@TransInfoMaxPO		VARCHAR(MAX)
			,@TotalTransMaxPO		INT = 0
			,@batchPO				SMALLINT = 500
	
	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, isFinish BIT
		,custid INT, currency TINYINT, actualPO MONEY, winlost MONEY, IsApplyMaxPO BIT
		,transdate DATETIME, bettype SMALLINT
	)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, winlost MONEY, actualPO MONEY, IsApplyMaxPO BIT)
	DECLARE @tmpMaxWinLimit	TABLE( CustId INT, MaxWinLimit MONEY)
	DECLARE @tmpTransIDMaxPO TABLE (TransID BIGINT
		,custid INT, actualPO MONEY, winlost MONEY
		,transdate DATETIME, bettype SMALLINT
	)

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

	SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())

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
			SELECT	@ErrCode 
					,@ErrMsg
	
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
			INSERT INTO #tmpTransID (TransID, modds, OddsType, custid, currency, actualPO, transdate, bettype)
			SELECT b.transid
				  ,m.modds
				  ,sr.OddsType
				  ,b.custid					
				  ,b.currency
				  ,CASE
				  		WHEN m.modds >  0.25 THEN b.actual_stake + b.stake * (CASE WHEN b.odds < 0 THEN 1  
																				   WHEN sr.oddstype = 1 THEN b.odds - 1 
																				   ELSE b.odds 
																				END)
				  		WHEN m.modds =  0.25 THEN b.actual_stake + b.stake * 0.5 * (CASE WHEN b.odds < 0 THEN 1  
																						 WHEN sr.oddstype = 1 THEN b.odds - 1 
																						 ELSE b.odds 
																					END)
				  		ELSE NULL
				   END actualPO	
				  ,b.transdate
				  ,b.bettype
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

			-- check if winlost reaches the maxpayout
			IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
			BEGIN
				;WITH cteCustIds
				AS(
					SELECT DISTINCT custid, currency
					FROM	#tmpTransID t
					WHERE	modds >= 0.25
				)
				INSERT INTO @tmpMaxWinLimit (CustId, MaxWinLimit)
				SELECT	t.custid, fc.MaxWinLimit
				FROM	CustDB.dbo.Customer c WITH(NOLOCK)
					INNER JOIN cteCustIds t
						ON t.custid = c.custid
					INNER JOIN CustDB.dbo.Site s WITH(NOLOCK)
						ON s.site = c.site
					INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs
						ON s.siteid = fs.siteid
					INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc
						ON	t.currency = fc.ExchangeId
							AND fc.SiteDBGroupId = @SiteDBGroupId

				IF @@ROWCOUNT > 0
				BEGIN
					UPDATE t 
						SET IsApplyMaxPO = 1
							,winlost = m.MaxWinLimit
					FROM	#tmpTransID t
						INNER JOIN	@tmpMaxWinLimit m
							ON t.CustId = m.CustId
					WHERE	t.actualPO > m.MaxWinLimit

					SET @TotalTransMaxPO = @@ROWCOUNT
				END
					
			END
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
		SELECT bt.custid
			,SUM(bt.winlost - bt.actual_stake + bt.playercomm)
			,SUM(CASE
					WHEN ruben = 1 THEN bt.winlost - bt.actual_stake 
					ELSE 0 
				END) AS winlost
			,bt.winlostdate
			,bt.bettype
		FROM dbo.bettrans bt WITH (ROWLOCK)
		WHERE matchid = @matchid AND transid <= @MaxTransID
			AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
		GROUP BY bt.custid, bt.winlostdate, bt.bettype
		
		
		------START UPDATE BETTRANS---------------------------------------------------------------------------
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchCount) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds, deleted.OddsType, deleted.winlost, deleted.actualPO, deleted.IsApplyMaxPO
			INTO @tmpTransIDBatch(transid, modds, OddsType, winlost, actualPO, IsApplyMaxPO)
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
													,CASE WHEN IsApplyMaxPO = 1 THEN winlost ELSE NULL END AS '@wl'
													,CASE WHEN IsApplyMaxPO = 1 THEN actualPO ELSE NULL END AS '@apo'
													,IsApplyMaxPO AS '@iMPO'
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
			   ,@Is3rd				 = 1
		END

		------END UPDATE BETTRANS-----------------------------------------------
	
		-------------------------------------------------------------
		---		 CAPTURE value BALANCE after settlement		---
		---------------------------VVVV------------------------------
		
		CREATE TABLE #BalanceAfter (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)

		INSERT INTO #BalanceAfter(custid, balance, winlost, winlostdate, gametypeid)
		SELECT bt.custid
			,SUM(bt.winlost - bt.actual_stake + bt.playercomm)
			,SUM(CASE 
					WHEN bt.ruben = 1 THEN bt.winlost - bt.actual_stake 
					ELSE 0
				END) AS winlost
			,bt.winlostdate
			,bt.bettype
		FROM dbo.bettrans bt WITH (ROWLOCK)
		WHERE matchid = @matchid AND transid <= @MaxTransID
			AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
		GROUP BY bt.custid, bt.winlostdate, bt.bettype
		
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

	-- notify
	WHILE (@TotalTransMaxPO > 0)
	BEGIN
		IF @TotalTransMaxPO > @batchPO
		BEGIN
			DELETE @tmpTransIDMaxPO

			DELETE TOP (@batchPO) t
				OUTPUT deleted.custid, deleted.winlost, deleted.actualPO, deleted.transdate, deleted.bettype, deleted.transid 
				INTO @tmpTransIDMaxPO(custid, winlost, actualPO, transdate, bettype, transid)
			FROM	#tmpTransID t
			WHERE	IsApplyMaxPO = 1

			SET @TransInfoMaxPO = CAST((
									SELECT	TOP (@batchPO) CustId AS a1
											,164 AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,@AdminId AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	@tmpTransIDMaxPO
									FOR XML PATH('r'), ROOT('root')
							) AS VARCHAR(MAX))
		END
		ELSE
		BEGIN
			SET @TransInfoMaxPO = CAST((
									SELECT	CustId AS a1
											,164 AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,@AdminId AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	#tmpTransID
									WHERE	IsApplyMaxPO = 1
									FOR XML PATH('r'), ROOT('root')
							) AS VARCHAR(MAX))
		END

		SET @TotalTransMaxPO = @TotalTransMaxPO - @batchPO

		BEGIN TRY
			EXEC DBCUST.CustDB.dbo.Task_Winlimit_InsertHistoryData
				@XmlData = @TransInfoMaxPO
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = ERROR_MESSAGE()				
		END CATCH
	END
	
	SET @EndTime = GETDATE()
	
	IF @IsCentral = 1
	BEGIN		
		DECLARE @remarkNewValue VARCHAR(MAX) = ''
		SET @Remark = ''

		SELECT @remarkNewValue = @remarkNewValue + ', B' +ResourceID + '(' + Result1 + ')'
		FROM @tmpResultDetail
		WHERE ISNULL(isSourceFromDB,0) = 1 AND Result1 > 0
		
		SELECT @Remark =  'IsAuto: ' + CAST(@IsAuto AS VARCHAR(2)) + '<br/>' 
						+ CASE WHEN ISNULL(@strOldResult,'') <> '' THEN 'Old Results: ' + SUBSTRING(@strOldResult, 2, LEN(@strOldResult))  + '<br/> ' ELSE '' END
						+ CASE WHEN @remarkNewValue <> '' THEN 'Results: ' + SUBSTRING(@remarkNewValue, 2, LEN(@remarkNewValue))  + '<br/> ' ELSE '' END
						+ 'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms' 
		
		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle @UserID = @AdminId
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
	
	END
END
GO
