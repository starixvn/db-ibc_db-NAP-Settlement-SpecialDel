/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverBet_NumberGame]
	@TransIds VARCHAR(MAX),
	@UserId INT,
	@IP VARCHAR(50),
	@HasCompletedMatch BIT = 0 OUTPUT,
	@ErrCode INT OUTPUT,
	@ErrMsg NVARCHAR(200) OUTPUT
AS
/*
	Created: Kathy
	Date: 20131202
	DB: DBTXN/bodb02

	Revisions:   				   
		- 20140210@Kathy: Correct winlost value
		- 20140515@Kathy: Apply LAS system [Redmine:#14287]
		- 20141204@Kathy: Remove codes which are used in checking permission on DBPolicy [Redmine:#27058]	
		- 20150810@Kathy: Using new balance table (BalCreditOthersPending,BalDebitOthersPending) [Redmine:#40125]
		- 20150917@Patrick: #43565: Show error-message in case user clicks void button but no tickets are found
		- 20171215@Kent: Number Game Ball Sequence [RedmineID: #54346]
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20180528@Alan: Return MatchCode Column [Redmine:#95949 ]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181122@Alan: Incorporate Happy 5 into Number Game [102845]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SELECT @ErrCode = 0,
	       @ErrMsg = ''
	
	DECLARE @LogData NVARCHAR(MAX)
		  , @Remark VARCHAR(500)
		  , @today DATETIME
		  , @isITAdmin BIT = 0	
		
	CREATE TABLE #tblTransId (transid BIGINT PRIMARY KEY)
	DECLARE @tblTransInfo TABLE (transid BIGINT PRIMARY KEY,
								 custid  INT,
								 matchid INT, 
								 bettype SMALLINT,
								 winlost MONEY,
								 status  VARCHAR(20)
								 )
								 
	SELECT @today = convert(varchar(10), getdate(),120)
	
	INSERT INTO #tblTransId (transid) 
	SELECT DISTINCT CONVERT(BIGINT, val) 
	FROM dbo.f_SplitString(ISNULL(@TransIds, ''), ',') s
	OPTION (maxrecursion 0)								 

	IF EXISTS(SELECT 1 FROM bettrans with(NOLOCK)
			  WHERE transid IN ( select s.transid from #tblTransId s )
			  AND winlostdate <> @today )
	BEGIN
		SELECT  @ErrCode = 103,
				@ErrMsg = 'You are only allowed to recover today tickets.'
		RETURN
	END
	
	BEGIN TRY	
		INSERT INTO @tblTransInfo
		SELECT s.transid,
			   z.custid,
			   z.matchid,
			   z.bettype,
			   z.winlost - b.actual_stake as winlost,
			   z.status
		FROM   #tblTransId s
			   INNER JOIN bettrans b WITH(NOLOCK)
					ON  b.transid = s.transid
			   INNER JOIN zzzbettrans z WITH (NOLOCK)
					ON  z.custid = b.custid
						AND z.matchid = b.matchid
						AND z.bettype = b.bettype
						AND z.transid = b.transid									   
		WHERE (z.bettype BETWEEN 81 AND 120 OR z.bettype BETWEEN 8101 AND 8105)
		AND z.winlostdate = @today

		IF @@Rowcount = 0
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'
			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100,
				@ErrMsg = 'Invalid TransIds: '+ ERROR_MESSAGE()
		RETURN
	END CATCH
	
	
	-- Check concurrent running
	IF EXISTS(
	       SELECT 1
	       FROM   dbo.TempVariableNumber v with(NOLOCK)
	              INNER JOIN @tblTransInfo t
	                   ON  v.KeyValue = t.matchid
	                   AND v.KeyID = 1
	   )
	BEGIN
	    SELECT @ErrCode = 101,
	           @ErrMsg = 
	           'This match is being calculated or some tickets of this match are being voided, please wait a few seconds until the on-going process is completed and try again.'
	           RETURN
	END
	
	DECLARE @MatchId     INT,
	        @KeyId       TINYINT
	
	WHILE (1 = 1)
	BEGIN
	    SELECT TOP 1 @KeyId = 1, @MatchId = t.matchid
	    FROM   @tblTransInfo t
	    WHERE  t.matchid NOT IN (SELECT v.KeyValue
	                             FROM   dbo.TempVariableNumber v with(NOLOCK)
	                             WHERE  v.KeyID = 1)
	    
	    IF @@rowcount = 0
	        BREAK
	    
	    INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue)
	    VALUES (@KeyId, @MatchId)		
	    IF (@@Error = 0)
	    BEGIN
	        TRY
	        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
	             @UserID = @UserID,
	             @Matchid = @matchid,
	             @KeyID = @KeyID,
	             @ActionID = 0,
	             @Remark = 'ADD SUCCESS SPName= NAP_BettransRecoverBet_NumberGame'
	    END TRY	    
	    BEGIN CATCH
	    	SELECT @Remark = 'ADD SUCCESS SPName=NAP_BettransRecoverBet_NumberGame ErrMsg=' 
	    	       + LEFT(ERROR_MESSAGE(), 400)
	    	
	    	EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
	    	     @UserID = @UserID,
	    	     @Matchid = @matchid,
	    	     @KeyID = @KeyID,
	    	     @ActionID = 0,
	    	     @Remark = @Remark
	    END CATCH
	    ELSE 
	    BEGIN
	    	SELECT @ErrCode = 100,
	    	       @ErrMsg = 
	    	       'This match is being calculated or some tickets of this match are being voided, please wait a few seconds until the on-going process is completed and try again.'
	    	       RETURN
	    END
	END

	IF EXISTS(SELECT 1 from @tblTransInfo where (bettype BETWEEN 81 AND 120) OR (bettype BETWEEN 8101 AND 8105))
	BEGIN
		IF EXISTS(SELECT 1 FROM SystemSettings WITH (NOLOCK) WHERE VValue = 1 AND VName = 'isCalculatingNGManual')
		BEGIN
			SELECT @ErrCode = 102 , 
				@ErrMsg = 'Another number game re-calculation is in progress or some tickets of this match are being voided, please wait a few seconds until the on-going process has finished and try again.'
			
			DELETE FROM dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK)
			WHERE KeyID = 1 AND KeyValue = @matchid
			IF (@@Error = 0)
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserId = @UserId, 
					@Matchid = @matchid, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = 'VOID SUCCESS SPName=NAP_BettransRecoverBet_NumberGame'
			END TRY
			BEGIN CATCH
				SELECT @Remark = 'VOID SUCCESS SPName=NAP_BettransRecoverBet_NumberGame ErrMsg=' + left(error_message(), 400)
				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserId = @UserId, 
					@Matchid = @matchid, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = @Remark
			END CATCH	
			ELSE
			BEGIN
				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
						@UserId = @UserId, 
						@Matchid = @matchid, 
						@KeyID = 1,
						@ActionID = 0, 
						@Remark = 'VOID FAILED SPName=NAP_BettransRecoverBet_NumberGame'
				END TRY
				BEGIN CATCH
					SELECT @Remark = 'VOID FAILED SPName=NAP_BettransRecoverBet_NumberGame ErrMsg=' + left(error_message(), 400)
					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
						@UserId = @UserId, 
						@Matchid = @matchid, 
						@KeyID = 1,
						@ActionID = 0, 
						@Remark = @Remark
				END CATCH
			END
			RETURN
		END 
		ELSE 
		BEGIN
			UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
			SET		VValue = '1'
			WHERE	VName = 'isCalculatingNGManual'
		END
	END

	
	-- check customer who have negative amount of bet credit
	-- calculate a balance of customer
	DECLARE @tblBeforeBalance TABLE (custid INT, balance MONEY)
	DECLARE @tblAfterBalance TABLE (custid INT, balance MONEY)
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	INSERT INTO @tblBeforeBalance
	SELECT b.custid,
	       SUM(b.winlost - b.actual_stake + b.playercomm)
	FROM   bettrans b WITH(NOLOCK)
	WHERE  b.transid IN (SELECT r.transid
	                     FROM   @tblTransInfo r)
	GROUP BY
	       b.custid
	
	
	---- recover
	UPDATE bettrans WITH(ROWLOCK, UPDLOCK)
	SET    winlost = 0,
	       ruben = 0,
	       statuswinlost = NULL,
	       STATUS = 'running',
	       statusID = 0,
	       creator = z.creator
	FROM   bettrans b 
	       INNER JOIN zzzbettrans z WITH(NOLOCK)
	            ON  z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype
					AND z.transid = b.transid
	WHERE  z.transid IN (SELECT r.transid
	                     FROM   @tblTransInfo r)
	
	-- get data after update
	INSERT INTO @tblAfterBalance
	SELECT b.custid,
	       SUM(b.winlost - b.actual_stake + b.playercomm)
	FROM   bettrans b WITH(NOLOCK)
	WHERE  b.transid  IN (SELECT r.transid
	                     FROM   @tblTransInfo r)
	GROUP BY
	       b.custid
	
	---INSERT data into pending balance table 	
	--INSERT INTO BalancePendingCredit
	--  (
	--    custid,
	--    Balance
	--  )
	--SELECT a.custid,
	--       (a.balance - b.balance)
	--FROM   @tblBeforeBalance b
	--       INNER JOIN @tblAfterBalance a
	--            ON  b.custid = a.custid
	--WHERE  (a.balance - b.balance) > 0
	
	INSERT INTO @tblCreditPending (custID, balance)
	SELECT a.custid,
	       (a.balance - b.balance)
	FROM   @tblBeforeBalance b
	       INNER JOIN @tblAfterBalance a
	            ON  b.custid = a.custid
	WHERE  (a.balance - b.balance) > 0
	
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditPending
			,@Type			= 4 -- Others
	
	--INSERT INTO BalancePendingDebit
	--  (
	--    custid,
	--    Balance
	--  )
	--SELECT a.custid,
	--       (a.balance - b.balance)
	--FROM   @tblBeforeBalance b
	--       INNER JOIN @tblAfterBalance a
	--            ON  b.custid = a.custid
	--WHERE  (a.balance - b.balance) < 0
	
	INSERT INTO @tblDebitPending (custID, balance)
	SELECT a.custid,
	       ABS(a.balance - b.balance)
	FROM   @tblBeforeBalance b
	       INNER JOIN @tblAfterBalance a
	            ON  b.custid = a.custid
	WHERE  (a.balance - b.balance) < 0
	
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitPending
			,@Type			= 4 -- Others
	
	DECLARE @UUSCust TABLE (custid int)
	DECLARE @RealCurrCust TABLE (custid int)

	 ---- get UUS customer 
	 INSERT INTO @UUSCust(custid)
		SELECT INF.custid 
		FROM custDB.dbo.custinfo INF WITH(nolock) 
		INNER JOIN zzzbettrans z WITH(NOLOCK) ON z.custid = INF.custid
		INNER JOIN @tblTransInfo t ON t.transid = z.transid
									  AND t.custid = z.custid
									  AND t.matchid = z.matchid
									  AND t.bettype = z.bettype		
		WHERE INF.srecommend IN( SELECT custid FROM custDB.dbo.customer WITH(nolock) WHERE CURRENCY = 20 AND roleid = 4 ) 
		AND INF.roleid = 1

	 ---- get customers have real ticket
	 INSERT INTO @RealCurrCust (CustID)
		SELECT INF.custid 
		FROM custDB.dbo.custInfo INF WITH (NOLOCK) 
		INNER JOIN zzzbettrans z WITH(NOLOCK) ON z.custid = INF.custid
		INNER JOIN @tblTransInfo t ON t.transid = z.transid	
									  AND t.custid = z.custid
									  AND t.matchid = z.matchid
									  AND t.bettype = z.bettype	
		WHERE INF.srecommend IN( SELECT custid FROM custDB.dbo.customer WITH(NOLOCK) WHERE CURRENCY <> 20 AND roleid = 4)	
		AND INF.roleid = 1 
		
	---- list ticket: match is completed
	SET @HasCompletedMatch = 0
	IF EXISTS (SELECT TOP 1 1
			   FROM @tblTransInfo t
					INNER JOIN match m WITH(NOLOCK) ON t.matchid = m.matchid
			   WHERE m.eventstatus = 'completed')
		SET @HasCompletedMatch = 1	
		
	-- CHECK IT GROUP or NOT ?   
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
	
	-- output data
	SELECT  ag.site as site,
		   t.transid as transid,
		   t.winlost,
		   t.status,
		   b.custid,
		   c.username ,
		   c.username2 ,
		   b.transdate,
	       b.odds,
	       b.oddstype,	      
	       b.bettype,		   
	       b.betteam,
	       b.hdp1,
	       b.hdp2,
	       b.betfrom,
		   b.stake,		
		   b.liveindicator as IsLiveIndicator,   		 
	       b.livehomescore,
	       b.liveawayscore,
	       cr.username AS creator,	      
	       b.CurrencyName,	      
		   b.matchid,
		   m.leagueid,
		   m.homeid,
		   m.awayid,
		   m.matchCode,
		   b.betid,
		   CURRENT_TIMESTAMP as DATETIME,
		   @isITAdmin AS IsITSupport,
		   b.CurrencyName AS CurrencyCode,
		   BS_tmp.BallSequence,
		   m.sporttype AS SportTypeId
		   
	FROM   @tblTransInfo t
	       INNER JOIN bettrans b WITH (NOLOCK) ON  t.transid = b.transid
	       INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON  b.custid = c.custid
	       INNER JOIN CustDB.dbo.Customer cr WITH(NOLOCK) ON  b.creator = cr.custid
	       INNER JOIN CustDB.dbo.Customer ag WITH(NOLOCK) ON  c.recommend = ag.custid
		   INNER JOIN match m WITH(NOLOCK)	ON b.matchid = m.matchid
		   OUTER APPLY (SELECT BallSequence 
						FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore)
						WHERE b.bettype IN (85, 86, 87, 88, 89, 90)
						) AS BS_tmp		
						  
	WHERE b.custid IN (SELECT [@RealCurrCust].custid FROM @RealCurrCust)
	   OR b.custid IN (SELECT [@UUSCust].custid FROM @UUSCust)				   		  
	ORDER BY site, transid	

	DELETE z WITH(ROWLOCK, UPDLOCK)
	FROM   @tblTransInfo t
		   INNER JOIN zzzbettrans z 
					ON t.transid = z.transid	
					   AND t.custid = z.custid
					   AND t.matchid = z.matchid
					   AND t.bettype = z.bettype

	SELECT @LogData = 'Recover bet have transid: ' + @TransIds + ' IP: ' + @Ip
	EXEC WriteLog_UserLog 
	     @UserId = @UserId,
	     @Doing = @LogData 
	
	------ release data of TempVariableNumBer table		
	WHILE (1 = 1)
	BEGIN
	    SELECT TOP 1 @KeyId = v.KeyID,
	           @MatchId = t.matchid
	    FROM   TempVariableNumber v with(NOLOCK)
	           INNER JOIN @tblTransInfo t
	                ON  t.matchid = v.keyvalue
	                AND v.keyid = 1
	    
	    IF @@rowcount = 0
	        BREAK;
	    DELETE 
	    FROM   TempVariableNumber 
	    WHERE  KeyID = @KeyId
	           AND KeyValue = @MatchId
	    
	    IF @@Error = 0
	    BEGIN
	        TRY
	        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
	             @UserID = @UserID,
	             @Matchid = @MatchId,
	             @KeyID = @KeyID,
	             @ActionID = 0,
	             @Remark = 'VOID SUCCESS SPName=NAP_BettransRecoverBet_NumberGame'
	    END TRY
	    
	    BEGIN CATCH
	    	SELECT @Remark = 'VOID SUCCESS SPName=NAP_BettransRecoverBet_NumberGame ErrMsg=' 
	    	       + LEFT(ERROR_MESSAGE(), 400)
	    	
	    	EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
	    	     @UserID = @UserID,
	    	     @Matchid = @MatchId,
	    	     @KeyID = @KeyID,
	    	     @ActionID = 0,
	    	     @Remark = @Remark
	    END CATCH
	    ELSE
	    BEGIN TRY
	    	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
	    	     @UserID = @UserID,
	    	     @Matchid = @MatchId,
	    	     @KeyID = @KeyID,
	    	     @ActionID = 0,
	    	     @Remark = 'VOID FAILED SPName=NAP_BettransRecoverBet_NumberGame'
	    END TRY
	    BEGIN CATCH
	    	SELECT @Remark = 'VOID FAILED SPName=NAP_BettransRecoverBet_NumberGame ErrMsg=' 
	    	       + LEFT(ERROR_MESSAGE(), 400)
	    	
	    	EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
	    	     @UserID = @UserID,
	    	     @Matchid = @MatchId,
	    	     @KeyID = @KeyID,
	    	     @ActionID = 0,
	    	     @Remark = @Remark
	    END CATCH
	END

	UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
	SET		VValue = '0'
	WHERE	VName = 'isCalculatingNGManual'
	
	DROP TABLE #tblTransId
	
END
GO