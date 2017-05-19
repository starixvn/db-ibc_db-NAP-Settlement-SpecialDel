USE [bodb02]
GO
ALTER PROCEDURE [dbo].[NAP_Admin_VoidBettrans_s213] 
	@transids	vARCHAR(MAX),
	@matchid 	INT = 0,
	@statusid 	TINYINT,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(200) = '' OUTPUT    
AS
	/*
		Created by:[Johnson]
		Date:[20160829]
		Task: VOID/Reject tickets for NG2
		DB: DBTXN/BODB02
		
		Revisions:
		
		Parameter's Explanation:
			@transids: list transids separate by comma (,) ex: '1254280,12549450,1254720'
			@matchid: matchid of tickets need to reject(for reject case only)
	*/
BEGIN
	SET NOCOUNT ON
	
	IF @statusid NOT IN (101,102) 
	BEGIN
		SELECT  @ErrCode = 101,
				@ErrMsg = 'Invalid status.'
		RETURN;
	END
	
	DECLARE @xml XML, @cnt1 INT, @cnt2 INT
	DECLARE @tblTrans TABLE(transid BIGINT)
	DECLARE @tblRefno TABLE(refno BIGINT)
	
	SELECT @xml = CONVERT(XML,N'<root><r t="' + REPLACE(@transids,',','"/><r t="') + '"/></root>"')
	
	IF @statusid = 101
	BEGIN
		INSERT INTO @tblRefno
		SELECT T.C.value('./@t', 'bigint')			
		FROM @xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
		
		SELECT @cnt1 = @@ROWCOUNT
		
		INSERT INTO @tblTrans
		SELECT transid
		FROM bettrans WITH(NOLOCK)
		WHERE matchid = @matchid
			AND bettype BETWEEN 2501 AND 2699
			AND refno IN (SELECT refno FROM @tblRefno)
		
		SELECT @cnt2 = @@ROWCOUNT
		
		IF @cnt1 <> @cnt2
		BEGIN
			SELECT  @ErrCode = 102,
					@ErrMsg = 'Invalid transid.'
			RETURN
		END
	END
	ELSE
	BEGIN
		INSERT INTO @tblTrans
		SELECT T.C.value('./@t', 'bigint')			
		FROM @xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
		
		IF EXISTS (
				SELECT 1 
				FROM @tblTrans t 
					LEFT JOIN bettrans b WITH(NOLOCK) ON t.transid = b.transid
				WHERE b.transid IS NULL OR b.bettype NOT BETWEEN 2501 AND 2699)
		BEGIN
			SELECT  @ErrCode = 102,
					@ErrMsg = 'Invalid transid.'
			RETURN
		END
	END
		
	CREATE TABLE #BalanceBefore (custid INT PRIMARY KEY, balance MONEY)
	CREATE TABLE #BalanceAfter (custid INT PRIMARY KEY, balance MONEY)	
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
						
	-- STEP 1 : BackUp
	INSERT INTO zzzbettrans
		(transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno, winlostdate, betfrom, betcheck, checktime, matchid, bettype)
	SELECT
		 transid, custid, CURRENT_TIMESTAMP, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno, winlostdate, betfrom, betcheck, checktime, matchid, bettype
	FROM
		bettrans b WITH (nolock)
	WHERE
		b.transid IN (SELECT transid FROM @tblTrans)
	
	-- CAPTURE value BALANCE before udpate bettrans
	INSERT INTO #BalanceBefore
	SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
	FROM	dbo.bettrans b WITH(ROWLOCK)
	WHERE	transid IN (SELECT transid FROM @tblTrans)
	GROUP BY b.custid
	
	-- STEP 2 : Update ticket
	
	UPDATE 
		bettrans WITH (ROWLOCK, UPDLOCK)
	SET winlost=actual_stake,ruben=1,
		status = CASE WHEN @statusid = 101 then 'Reject'
					WHEN @statusid = 102 THEN 'VOID'  END,
		awinlost = 0, mwinlost = 0, swinlost = 0, playercomm = 0, comm  = 0, acomm = 0, scomm = 0, statusID =  @statusid        
	WHERE
		transid IN (SELECT transid FROM @tblTrans)
	
	-- CAPTURE value BALANCE after udpate bettrans
	INSERT INTO #BalanceAfter
	SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
	FROM	dbo.bettrans b WITH(ROWLOCK)
	WHERE	transid IN (SELECT transid FROM @tblTrans)
	GROUP BY b.custid
	
	INSERT INTO #Balance (custid, balance, Increased)
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a ON b.custid = a.custid
	WHERE b.balance <> a.balance
	
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
	
	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter
END
