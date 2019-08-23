ALTER PROCEDURE [dbo].[NAP_InvalidGoalScorerTicketVoid]
	@MatchId	INT,
	@BetType	SMALLINT,
	@BetTeam	NVARCHAR(200),
    @UserID		INT = 111,
	@ErrMsg		NVARCHAR(200)	OUTPUT,
    @ErrCode	INT			OUTPUT
AS
/*
	Created by: Dominic@20150415
	Task : Void invalid unsettled tickets belonging to these 2 following bet types :
			- Goal Scorer - Anytime (216)
			- Goal Scorer - First (217 )
	DB: DBTXN/bodb02
	Original:
		
	Revisions:	
		- 20150810@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
	
	Param's Explanation:
		- @UserID : 111 (oddsfeedlog) is used when this SP is called automatically by a program
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @LogData NVARCHAR(500)
	SELECT @ErrCode = 0, @ErrMsg = ''
	
	SELECT @UserID = 111
/*******************************************************************
****************             A.CHECKING                ************* 	
********************************************************************/
	------------------***** Check Invalid Parameter *****------------------
	IF @MatchId IS NULL OR @BetType IS NULL OR @BetTeam IS NULL OR @BetTeam = ''
	BEGIN
		SELECT @ErrMsg = 'Input parameters must be specified (not NULL or EMPTY) !'
			,@ErrCode  = 101
		RETURN
	END
	
	IF @BetType NOT IN (216,217)
	BEGIN
		SELECT @ErrMsg = 'Wrong input parameter of bet type, only support for Goal Scorer(Anytime & First) !'
			,@ErrCode  = 102
		RETURN
	END
	
	--Check Invalid Match
	DECLARE @Sporttype INT	
		
	SET @Sporttype = 0
	
	SELECT @Sporttype = sporttype
	FROM match WITH (NOLOCK)
	WHERE matchid = @MatchID
	
	IF (@Sporttype <> 1)
	BEGIN 
		SET @ErrCode = 100
		SET @ErrMsg ='Invalid match!' 
		RETURN
	END 

	--Check if the match do not offer the specified bet type
	IF NOT EXISTS( SELECT  TOP 1 1
		FROM dbo.bettype b WITH(NOLOCK) 
		INNER JOIN dbo.odds o WITH(NOLOCK) ON b.typeid = o.bettype
		INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = o.matchid
		WHERE m.matchid = @MatchId
		AND b.typeid = @BetType
		AND m.sporttype = 1)
	BEGIN
		SELECT @ErrMsg = 'This match does not offer the specfied bet type (' + CAST(@BetType AS VARCHAR(10)) +  ')' 
			,@ErrCode  = 106
		RETURN
	END
	
	------------------***** Check winlostdate before resettle, delete transaction, recover bet...   *****------------------
	DECLARE @eventdate DATETIME 
	
	SELECT @eventdate = eventdate
	FROM match WITH(NOLOCK)
	WHERE matchid = @MatchId
			
	EXEC dbo.Acc_CheckSettledDate
		@winlostdate	= @eventdate, 
		@UserID			= @UserID, 
		@ErrCode		= @ErrCode OUTPUT, 
		@ErrMsg			= @ErrMsg OUTPUT
		
	If @ErrCode <> 0
		RETURN
	
	
	------------------*****  check AND not allow attempt to delete same game while it's still not finish *****------------------
	DECLARE @Remark VARCHAR(500)
			,@KeyID INT

	SET @KeyID = 1

	
	IF EXISTS (SELECT 1 FROM dbo.TempVariableNumber WHERE KeyID = @KeyID AND KeyValue = @MatchId)
	BEGIN
		SELECT  @ErrCode = 103,
				@ErrMsg = 'This match is being calculated or some tickets of this match are being voided, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END
	
	INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue) VALUES (@KeyID, @MatchId)
	
	IF EXISTS(SELECT 1 FROM SystemSettings WITH (NOLOCK) WHERE VValue = 1 AND VName = 'isCalculatingParlay')
	BEGIN
		SELECT @ErrCode = 107
			,@ErrMsg	= 'Another parlay settlement is in progress or some parlay tickets are being voided, please wait a few seconds until the on-going process has finished and try again.'
		
		DELETE FROM dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK)
		WHERE KeyID = @KeyID AND KeyValue = @MatchId
	 
		RETURN
	END
	ELSE 
	BEGIN
		UPDATE SystemSettings WITH (ROWLOCK, UPDLOCK)
			SET VValue = '1'
		WHERE VName = 'isCalculatingParlay'
	END
	
	IF (@@Error = 0)
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID		= @UserID, 
			@MatchId	= @MatchId, 
			@KeyID		= @KeyID,
			@ActionID	= 0, 
			@Remark		= 'ADD SUCCESS SPName=NAP_InvalidGoalScorerTicketVoid'
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ADD SUCCESS SPName=NAP_InvalidGoalScorerTicketVoid ErrMsg=' + LEFT(error_message(), 400)
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID		= @UserID, 
			@MatchId	= @MatchId, 
			@KeyID		= @KeyID,
			@ActionID	= 0, 
			@Remark		= @Remark
	END CATCH
	ELSE 
	BEGIN
		SELECT @ErrCode = 104, 
			@ErrMsg		= 'This match is being calculated or some tickets of this match are being voided, please wait a few seconds until the on-going process is completed and try again.'
			
		RETURN
	END

/*******************************************************************
*********             B.GET INVALID TICKETS                ********* 	
********************************************************************/
	IF OBJECT_ID('tempdb..#BetDeleteSingle') IS NOT NULL  DROP TABLE #BetDeleteSingle		
	CREATE TABLE #BetDeleteSingle (
		transid				BIGINT PRIMARY KEY, 
		custid				INT, 
		recommend			INT, 
		mrecommend			INT, 
		srecommend			INT, 
		betfrom				NVARCHAR(1),
		statusID			INT, 
		status				NVARCHAR(10), 
		SecAcceptFlag		BIT, 
		username			VARCHAR(30),
		creator				VARCHAR(30), 
		hdp1 				SMALLMONEY,  
		hdp2 				SMALLMONEY,
		bettype 			SMALLINT, 
		betteam 			NVARCHAR(10),
		betcheck			NVARCHAR(50),
		odds				MONEY, 
		OddsType			INT,
		transdate			DATETIME,
		IsLiveIndicator		BIT,
		livehomescore 		SMALLINT, 
		liveawayscore 		SMALLINT,
		Stake				MONEY,
		CurrencyName		VARCHAR(10),
		betid				BIGINT
		)
	
	
	IF OBJECT_ID('tempdb..#Ref') IS NOT NULL DROP TABLE #Ref
	CREATE TABLE #Ref (	refno			BIGINT, 
						transid			BIGINT, 
						custid			INT, 
						srecommend		INT, 
						mrecommend		INT, 
						recommend		INT, 
						betfrom			NVARCHAR(1), 
						bettype			SMALLINT, 
						hdp1			SMALLMONEY, 
						hdp2			SMALLMONEY, 
						odds			MONEY, 
						betteam			NVARCHAR(20), 
						livehomescore	SMALLINT,
						liveawayscore	SMALLINT, 
						liveindicator	BIT, 
						org_betteam		NVARCHAR(10), 
						statusID		INT,		
						betcheck		NVARCHAR(50)				
					)
					
						
	DECLARE @Status				TABLE (StatusID TINYINT)
	
	INSERT INTO @Status
	SELECT 102 UNION ALL -- Void
	SELECT 101 UNION ALL -- Reject
	SELECT 112 UNION ALL -- Won
	SELECT 113 UNION ALL -- Lose
	SELECT 111 -- Draw
	
	
	------------------***** Get Invalid Tickets *****------------------
	--Get Single Ticket
	INSERT INTO #BetDeleteSingle 
	SELECT DISTINCT transid, custid, recommend, mrecommend, srecommend, betfrom, statusID, status, SecAcceptFlag,
		Username, creator, hdp1,hdp2, bettype, betteam, betcheck, b.odds, b.oddstype, b.transdate, b.liveindicator, b.livehomescore, 
		b.liveawayscore, b.stake, b.CurrencyName, b.betid
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.matchid=@matchid
		AND b.bettype = @BetType
		AND b.betteam IN (SELECT CONVERT(VARCHAR, val) FROM dbo.strSplit(@BetTeam,'^'))
		AND b.statusID NOT IN (SELECT * FROM @Status)
		
	--Get Parlay Ticket
	INSERT INTO #Ref ( 	refno, transid, custid, srecommend, mrecommend, recommend, betfrom, bettype, hdp1
						,hdp2, odds, betteam, livehomescore, liveawayscore, liveindicator, org_betteam, statusID, betcheck)
	SELECT b.refno
		,b.transid
		,c.custid
		,c.srecommend
		,c.mrecommend
		,c.recommend
		,b.betfrom
		,b.bettype
		,b.hdp1
		,b.hdp2

		,b.odds
		,b.betteam		
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.betteam		
		,b.statusID
		,b.betcheck
	FROM dbo.bettransm AS b WITH(NOLOCK)		 
		 INNER JOIN custDB.dbo.customer AS c WITH(NOLOCK) ON c.custid=b.custid		
	WHERE b.matchid=@MatchID	
		AND b.bettype = @BetType
		AND b.betteam IN (SELECT CONVERT(VARCHAR, val) FROM dbo.strSplit(@BetTeam,'^'))
		AND b.statusID IN (0, 1, 103)
	
	
	
/*******************************************************************
********             C.DELETE SINGLE TICKET                ********* 	
********************************************************************/
	
	------------------***** Begin Special Delete *****------------------
	-- Step 1: backup
	INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
				winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
				winlostdate,betfrom,betcheck,checktime,matchid, bettype)
		SELECT  transid, custid, CURRENT_TIMESTAMP, oddsid, hdp1, hdp2, odds, stake, status, 
				winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno, 
				winlostdate, betfrom, betcheck, checktime, matchid, bettype
		FROM
			bettrans b WITH (nolock)
		WHERE
			b.transid IN (SELECT transid FROM #BetDeleteSingle)
			AND b.bettype = @Bettype
			AND b.matchid = @MatchId
	
	--Get before balance	
	IF OBJECT_ID('tempdb..#BeforeUpd') IS NOT NULL DROP TABLE #BeforeUpd	
	CREATE TABLE #BeforeUpd (
			custid		 INT,
			balance		 MONEY)
		
	IF OBJECT_ID('tempdb..#AfterUpd') IS NOT NULL DROP TABLE #AfterUpd
	CREATE TABLE #AfterUpd(
				custid		 INT,
				balance		 MONEY)
				
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList

	INSERT INTO #BeforeUpd (custid, balance)
	SELECT	b.custid, SUM (b.winlost - b.actual_stake + b.playercomm) balance
	FROM	bettrans b WITH (NOLOCK)
	WHERE	b.transid IN (SELECT transid FROM #BetDeleteSingle)
	GROUP BY b.CustID
	
	-- STEP 2 : Update
	UPDATE 
		bettrans WITH (ROWLOCK, UPDLOCK)
	SET winlost			= actual_stake
		,ruben			= 1
		,statuswinlost	= 6
		,status			= 'Void'
		,creator		= @UserID
		,awinlost		= 0
		,mwinlost		= 0
		,swinlost		= 0
		,playercomm		= 0
		,comm			= 0
		,acomm			= 0
		,scomm			= 0
		,statusID		= 102       
	WHERE
		transid IN (SELECT transid FROM #BetDeleteSingle)
	
	--Get data after update
	INSERT INTO #AfterUpd (custid, balance)
	SELECT	b.custid, SUM (b.winlost - b.actual_stake + b.playercomm) balance
	FROM	bettrans b WITH (NOLOCK)
	WHERE	b.transid IN (SELECT transid FROM #BetDeleteSingle)
	GROUP BY b.CustID

	---INSERT data into pending balance table 
	--INSERT INTO BalancePendingCredit (custid,Balance)
	--SELECT		a.custid, (a.balance - b.balance) as Balance
	--FROM		#BeforeUpd b
	--INNER JOIN	#AfterUpd a 	
	--		ON	a.custid = b.custid
	--WHERE	    (a.balance - b.balance) > 0
	
	INSERT INTO @tblCreditPending (custID, balance)
	SELECT		a.custid, (a.balance - b.balance) as Balance
	FROM		#BeforeUpd b
	INNER JOIN	#AfterUpd a 	
			ON	a.custid = b.custid
	WHERE	    (a.balance - b.balance) > 0
	
	IF @@rowcount <> 0
																																																																EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditPending
			,@Type			= 1 -- Sports	

	--INSERT INTO BalancePendingDebit (custid,Balance)
	--SELECT		a.custid, ABS(a.balance - b.balance) as Balance
	--FROM		#BeforeUpd b
	--INNER JOIN	#AfterUpd a 	
	--		ON	a.custid = b.custid
	--WHERE	    (a.balance - b.balance) < 0
	
	INSERT INTO @tblDebitPending (custID, balance)
	SELECT		a.custid, ABS(a.balance - b.balance) as Balance
	FROM		#BeforeUpd b
	INNER JOIN	#AfterUpd a 	
			ON	a.custid = b.custid
	WHERE	    (a.balance - b.balance) < 0
	
	IF @@rowcount <> 0
																																																																EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitPending
			,@Type			= 1 -- Sports
	
	------------------***** End of Special Delete *****------------------
	SELECT @LogData ='void bet for matchid ' + CONVERT(VARCHAR(20), 
			@MatchId) + ' bettype ' + CONVERT(VARCHAR(20), @bettype) + ' betteam ' + @BetTeam
			
	EXEC WriteLog_UserLog 
		@UserID = @UserID
		,@Doing = @LogData
		
	IF OBJECT_ID('tempdb..#BeforeUpd') IS NOT NULL DROP TABLE #BeforeUpd
	IF OBJECT_ID('tempdb..#AfterUpd') IS NOT NULL DROP TABLE #AfterUpd

	DELETE FROM dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK)
	WHERE KeyID = @KeyID AND KeyValue = @MatchId	
	
	IF (@@Error = 0)
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID		= @UserID, 
			@MatchId	= @MatchId, 
			@KeyID		= @KeyID,
			@ActionID	= 0, 
			@Remark		= 'VOID SUCCESS SPName=NAP_InvalidGoalScorerTicketVoid'
	END TRY
	BEGIN CATCH
		SELECT @Remark	= 'VOID SUCCESS SPName=NAP_InvalidGoalScorerTicketVoid ErrMsg=' + LEFT(error_message(), 400)
		
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID		= @UserID, 
			@MatchId	= @MatchId, 
			@KeyID		= @KeyID,
			@ActionID	= 0, 
			@Remark		= @Remark
	END CATCH
	ELSE
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @UserID, 
				@MatchId	= @MatchId, 
				@KeyID		= @KeyID,
				@ActionID	= 0, 
				@Remark		= 'VOID FAILED SPName=NAP_InvalidGoalScorerTicketVoid'
		END TRY
		BEGIN CATCH
			SELECT @Remark = 'VOID FAILED SPName=NAP_InvalidGoalScorerTicketVoid ErrMsg=' + LEFT(error_message(), 400)
			
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @UserID, 
				@MatchId	= @MatchId, 
				@KeyID		= @KeyID,
				@ActionID	= 0, 
				@Remark		= @Remark
		END CATCH
	END	

	IF OBJECT_ID('tempdb..#BetDeleteSingle') IS NOT NULL  DROP TABLE #BetDeleteSingle
	
/*******************************************************************
**********             D.DELETE PARLAY TICKET                ******** 	
********************************************************************/
	-- BackUp bettransm tickets into zzzbettrans
	INSERT INTO	zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, 
				winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno, 
				winlostdate, betfrom, betcheck, checktime, matchid, bettype)
		SELECT 	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype
		FROM dbo.bettransm AS b WITH (nolock)
		INNER JOIN #Ref AS r ON r.transid=b.transid
		
	--BackUp tickets of bettransm
	INSERT INTO	zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, 
				winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno, 
				winlostdate, betfrom, betcheck, checktime, matchid, bettype)
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, 
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno, 
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype
		FROM dbo.bettransm AS b WITH (nolock)
			INNER JOIN #Ref AS r ON r.transid=b.transid 
			
	DECLARE @matchdate DATETIME, @match_tmp VARCHAR(20), @rowcount INT, @step INT, @transid_tmp VARCHAR(2000)

	SELECT	@matchdate = eventdate,
			@match_tmp = CONVERT(VARCHAR(20),matchid),
			@step = 0
	FROM match WITH(NOLOCK) WHERE matchid = @matchid
	
	DECLARE @transtbl TABLE (id INT IDENTITY, transid BIGINT)
	INSERT INTO @transtbl (transid)
				SELECT transid
				FROM #Ref
	SELECT @rowcount = @@ROWCOUNT

	WHILE @step < @rowcount
	BEGIN

		SET @transid_tmp = ''

	    SELECT @transid_tmp  = @transid_tmp + CONVERT(VARCHAR(20),transid)  + ','	
		FROM @transtbl
		WHERE id > @step AND id <= @step + 100
		
		SET @step = @step + 100

		EXEC dbo.NAP_Admin_Calculate_Parlay @matchid = @matchId
			,@fth = 0
			,@fta = 0
			,@hth = 0
			,@hta = 0
			,@matchdate = @matchdate
			,@mode = 'VOID'
			,@VoidTransID = @transid_tmp
			,@UserId = @UserId
	END
	
	IF EXISTS (	SELECT TOP 1 1
				FROM bettrans b WITH(NOLOCK) 
					INNER JOIN #Ref r ON b.refno = r.refno
				WHERE b.matchid = 29 AND b.bettype = 29
			   ) 
	BEGIN
	
		EXEC dbo.NAP_Admin_Calculate_Parlay @matchids = @match_tmp
			,@mode = 'PRECAL-29'
		
		EXEC dbo.NAP_Admin_Calculate_Parlay @matchids = @match_tmp
			,@matchdate = @matchdate
			,@mode = 'CAL-29'

		---********* Calculate balance at bettrans table********---
		IF OBJECT_ID('tempdb..#BeforeUpd_Par') IS NOT NULL DROP TABLE #BeforeUpd_Par
		CREATE TABLE #BeforeUpd_Par (
					custid		 INT,
					balance		 MONEY)
		
		IF OBJECT_ID('tempdb..#AfterUpd_Par') IS NOT NULL DROP TABLE #AfterUpd_Par			
		CREATE TABLE #AfterUpd_Par(
						custid		 INT,
						balance		 MONEY)
							
		--Get data before update
		INSERT INTO #BeforeUpd_Par (custid, balance)
		SELECT	b.custid, SUM (b.wINlost - b.actual_stake + b.playercomm) balance
		FROM	bettrans b WITH (NOLOCK)
			INNER JOIN #Ref r ON b.refno = r.refno
		WHERE b.matchid = 29 AND b.bettype = 29
		GROUP BY b.CustID		

		--Settlement System parlay (changed balance)
		EXEC dbo.NAP_Admin_Calculate_29_Summary 

		--Get data after update
		INSERT INTO #AfterUpd_Par (custid, balance)
		SELECT	b.custid, SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM	bettrans b WITH (NOLOCK)
			INNER JOIN #Ref r ON b.refno = r.refno
		WHERE b.matchid = 29 AND b.bettype = 29
		GROUP BY b.CustID

		---Insert data into pending balance table 
		--INSERT INTO BalancePendingCredit (custid,Balance)
		--SELECT		a.custid, (a.balance - b.balance) AS Balance
		--FROM		#BeforeUpd_Par b
		--INNER JOIN	#AfterUpd_Par a 	
		--		ON	a.custid = b.custid
		--WHERE	    (a.balance - b.balance) > 0
		
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT		a.custid, (a.balance - b.balance) AS Balance
		FROM		#BeforeUpd_Par b
		INNER JOIN	#AfterUpd_Par a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) > 0
	
		IF @@rowcount <> 0
																																																																																																EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 1 -- Sports	

		--INSERT INTO BalancePendingDebit (custid,Balance)
		--SELECT		a.custid, ABS(a.balance - b.balance) AS Balance
		--FROM		#BeforeUpd_Par b
		--INNER JOIN	#AfterUpd_Par a 	
		--		ON	a.custid = b.custid
		--WHERE	    (a.balance - b.balance) < 0
		
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT		a.custid, ABS(a.balance - b.balance) AS Balance
		FROM		#BeforeUpd_Par b
		INNER JOIN	#AfterUpd_Par a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) < 0
	
		IF @@rowcount <> 0
																																																																																																EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 1 -- Sports
			
		DELETE #BeforeUpd_Par
		DELETE #AfterUpd_Par
	---********* End of calculate balance at bettrans table********---
	END
   
	SELECT @LogData ='Void bet for matchid ' + CONVERT(VARCHAR(20), @matchid) + ' for Mix Parlay Special Delete' 
					+ ' bettype ' + CONVERT(VARCHAR(20), @bettype) + ' betteam ' + @BetTeam
	EXEC WriteLog_UserLog @UserId = @UserId, @Doing = @LogData	
	
	UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
	SET		VValue  = '0'
    WHERE	VName = 'isCalculatingParlay'
    
	IF OBJECT_ID('tempdb..#Ref') IS NOT NULL DROP TABLE #Ref	
	IF OBJECT_ID('tempdb..#BeforeUpd_Par') IS NOT NULL DROP TABLE #BeforeUpd_Par
	IF OBJECT_ID('tempdb..#AfterUpd_Par') IS NOT NULL DROP TABLE #AfterUpd_Par

	
	SET NOCOUNT OFF
END
GO
