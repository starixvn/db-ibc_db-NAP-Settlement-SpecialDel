/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransCheckNegativeBalance]
	@TransIds VARCHAR(MAX) = '',
	@Type BIT,
	@ExcludeRunning BIT = 0
AS
	/*
	Created by: 20131119@Kathy
	Task : Check if a bet credit of customer is negative
	DB: DBTXN.bodb02

	Revisions:   
		- 20140515@Kathy: Calculate balance from translog (for running tickets) and bettrans
		- 20140919@Kathy: Correct balance formula of translog 
		- 20150606@Kathy: Migrate custDB to new server DBCust(Get credit from DBCust.CustDB) [Redmine:#36216] 
		- 20150612@Dominic: Exclude BetTrade members
		- 20150630@Dominic: Remove duplicated running Metric Gaming tickets [Redmine:#38200]
		- 20160118@Kathy: get balance from bettransRNG & bettransLC [Redmine:#50674]
		- 20160112@Patrick: Support Cricket [Redmine: #50688] & [Redmine: #52109]
		- 20170112@Kent: Tune performance to calculate for 3K ticket [Redmine: #67987]
		- 20170321@Kent: Integrate cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20190321@Alan: Do not check negative balance for CN88 [109858]
		- 20210326@Kathy: Tuning SP for EC [Redmine:#151103]
		- 20210517@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
	
	Param's Explanation: Special bet delete option
		@transids: All ticket of customers who need to be check negative bet credit
				   For bettrade : main + 901
				   For cash-out : main
				   For bonus	: cash or bonus tickets that are enabled and checked
		@Type: 
			- 0: Check negative bet credit for special delete funcion
			- 1: Check negative bet credit for recover funcion
		@ExcludeRunning: Indicate status of tickets for special delete fuction
			- 0: Check negative bet credit of running tickets and settled tickets
			- 1: Check negative bet credit of settled tickets

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @tmpTransId TABLE (transid BIGINT PRIMARY KEY)
	
	DECLARE @tmpCurrentBalance TABLE (
		custid		INT
		,username	nvarchar(50)
		,balance	money
	)
	
	DECLARE @tmpChangedBalance TABLE (
		custid		INT
		,balance	money
	)	
	
	CREATE TABLE #BetDelete (
		transid			BIGINT PRIMARY KEY
		,custid			INT
		,winlost		MONEY
		,actual_stake	MONEY
		,playercomm		MONEY
		,bettype		SMALLINT
		,matchid		INT
		,refno			BIGINT	
		,betdaqid		BIGINT
		,ExtraInfo		VARCHAR(1000)
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT
	)
	
	DECLARE @tmpAffectedCustId TABLE (CustId INT)
	DECLARE @movebetdate SMALLDATETIME

	INSERT INTO @tmpTransId(transid)
	SELECT val FROM dbo.f_SplitString(@TransIds, ',')
	OPTION (maxrecursion 0)

	INSERT INTO #BetDelete(
			transid
			,custid
			,winlost
			,actual_stake
			,playercomm
			,bettype
			,matchid
			,refno
			,betdaqid
			,ExtraInfo
			,WalletType
			,RefCode
			,BonusID
	)
	SELECT	b.transid -- normal ticket 
			,b.custid
			,b.winlost
			,b.actual_stake
			,b.playercomm
			,b.bettype
			,b.matchid
			,b.refno
			,b.betdaqid
			,b.ExtraInfo
			,b.WalletType
			,b.RefCode
			,b.BonusID
	FROM	@tmpTransId t
		INNER JOIN bettrans b WITH(NOLOCK)
			ON	b.transid = t.transid		
	WHERE	1 = CASE 
					WHEN @Type = 0 AND @ExcludeRunning = 0 AND b.statusID IN (0, 1,111,112,113) THEN 1 
					WHEN @Type = 0 AND @ExcludeRunning = 1 AND b.statusID IN (111, 112, 113) THEN 1
					WHEN @Type = 1 AND b.statusID = 102 THEN 1
					ELSE 0 
					END 
			AND b.bettype NOT IN (801,803,804,805,806)
			AND CASE					
					WHEN b.betdaqid = 0 AND b.extrainfo IS NULL THEN 0					
					ELSE 1
				END = 1 -- exclude BT member
			AND b.bettype NOT IN (911,912,913,914)			
	
	INSERT INTO #BetDelete(
		transid
		,custid
		,winlost
		,actual_stake
		,playercomm
		,bettype
		,matchid
		,refno
		,betdaqid
	)
	SELECT	ISNULL(b.transId,tl.translogid) AS transid
			,tl.custid
			,ISNULL(b.winlost,0) AS winlost
			,tl.actual_stake
			,ISNULL(b.playercomm,0) AS playercomm
			,tl.gameID
			,tl.eventID
			,ISNULL(b.refno, tl.translogid) as refno
			,-1 AS betdaqid			
	FROM	@tmpTransId t
		INNER JOIN translog tl WITH(NOLOCK)
			ON	tl.translogid = t.transid		
		LEFT JOIN dbo.bettrans b WITH(NOLOCK)
			ON	b.matchid = tl.eventID
				AND b.custid = tl.custid
				AND b.bettype = tl.gameID
				AND b.refno = tl.translogid
	WHERE	1 = CASE 
					WHEN @Type = 0 AND @ExcludeRunning = 0 AND b.statusID IN (0, 1,111,112,113) THEN 1 
					WHEN @Type = 0 AND @ExcludeRunning = 1 AND b.statusID IN (111, 112, 113) THEN 1
					WHEN @Type = 1 AND b.statusID = 102 THEN 1
					ELSE 0 
					END 
			AND b.bettype IN (801,803,804,805,806)

	-- Insert more bonus or cash ticket in case only one ticket appears in #BetDelete
	;WITH CTE_RefCodeSummary AS
	(
		SELECT RefCode, matchid, custid, bettype			 
			 , transid
		FROM #BetDelete
		WHERE RefCode IS NOT NULL		
	)	
	INSERT INTO #BetDelete(
			transid
			,custid
			,winlost
			,actual_stake
			,playercomm
			,bettype
			,matchid
			,refno
			,betdaqid
			,ExtraInfo
			,WalletType
			,RefCode
			,BonusID
	)
	SELECT	b.transid  
			,b.custid
			,b.winlost
			,b.actual_stake
			,b.playercomm
			,b.bettype
			,b.matchid
			,b.refno
			,b.betdaqid
			,b.ExtraInfo
			,b.WalletType
			,b.RefCode
			,b.BonusID
	FROM CTE_RefCodeSummary r
		 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				 ON b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = r.matchid
					AND b.custid = r.custid
					AND b.bettype = r.bettype	
	WHERE 1 = CASE 
					WHEN @Type = 0 AND @ExcludeRunning = 0 AND b.statusID IN (0, 1,111,112,113) THEN 1 
					WHEN @Type = 0 AND @ExcludeRunning = 1 AND b.statusID IN (111, 112, 113) THEN 1
					WHEN @Type = 1 AND b.statusID = 102 THEN 1
					ELSE 0 
			  END												

	-- insert 911		
	INSERT INTO #BetDelete(
			transid
			,custid
			,winlost
			,actual_stake
			,playercomm
			,bettype
			,matchid
			,refno
			,betdaqid
			,ExtraInfo
			,WalletType
			,RefCode
			,BonusID
	)
	SELECT	b.transid
			,b.custid
			,b.winlost
			,b.actual_stake
			,b.playercomm
			,b.bettype
			,b.matchid
			,b.refno
			,b.betdaqid
			,b.ExtraInfo
			,b.WalletType
			,b.RefCode
			,b.BonusID
	FROM #BetDelete AS tmpmain
		 INNER JOIN bettrans b (NOLOCK)
				 ON	b.refno = tmpmain.transid
					AND b.custid = tmpmain.custid
					AND b.matchid = tmpmain.matchid	
					AND tmpmain.betdaqid = 0
					AND charindex ('p25',tmpmain.extrainfo)> 0
					AND b.bettype = 911
	WHERE CASE 
				WHEN @Type = 0 AND b.statusID IN (111,112,113) THEN 1
				WHEN @Type = 1 AND b.statusID IN (102) THEN 1
				ELSE 0
		  END = 1
		  
	-- delete cash-out member bet tickets
	DELETE t
	FROM #BetDelete t
	WHERE EXISTS (SELECT TOP 1 1
				  FROM #BetDelete sub911 
				  WHERE sub911.bettype = 911
				    AND sub911.transid = t.refno)
				    
	-- delete bonus tickets belonging to canceled/expired campaign
	DELETE t
	FROM #BetDelete t
		 LEFT JOIN dbo.BonusWalletCredit AS bwc WITH(NOLOCK)
			ON	t.BonusID = bwc.BonusID
				AND t.custid = bwc.CustID
		 LEFT JOIN dbo.f_Set_BonusWallet_StatusSel() st
			ON	bwc.StatusID = st.StatusId
	WHERE t.BonusID > 0 
	  AND t.WalletType = 1 
	  AND st.BonusFlag = 2				    				    		  		  			 				    		  

	INSERT INTO @tmpAffectedCustId(CustId)
	SELECT	DISTINCT custid
	FROM	#BetDelete

	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT

	-- calculate sum of members' balance on bettrans tables
	INSERT INTO @tmpCurrentBalance(custid, username, balance)
	SELECT b.custid, b.Username, SUM(b.balance)
	FROM 
	(
		SELECT	b.custid, b.Username, (b.winlost - b.actual_stake + b.playercomm ) AS balance
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN dbo.translog tl WITH(NOLOCK)
				ON	b.refno = tl.translogid
					AND b.matchid = tl.eventID						
		WHERE	b.custid IN (SELECT custid FROM #BetDelete)
				AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))	
				AND 1 = CASE
							WHEN b.bettype = 19999 AND b.winlostdate > @movebetdate THEN 0 --new sum
							WHEN b.bettype < 19999 AND b.winlostdate <= @movebetdate THEN 0 -- old bet
							ELSE 1
						END
		UNION ALL 
		SELECT	tl.custid, tl.Username, (0 - tl.actual_stake + 0 ) AS balance
		FROM	dbo.translog tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM @tmpAffectedCustId)
				AND tl.statusID IN (0, 1)				
		UNION ALL
		SELECT	b.custid, b.Username, (b.winlost - b.actual_stake + b.playercomm ) AS balance
		FROM	dbo.bettransRnG b WITH(NOLOCK)
		WHERE	b.custid IN (SELECT custid FROM @tmpAffectedCustId)
				AND b.IsSum=0				
		UNION ALL
		SELECT	b.custid, b.Username, (b.winlost - b.actual_stake + b.playercomm ) AS balance
		FROM	dbo.bettransLC b WITH(NOLOCK)
		WHERE	b.custid IN (SELECT custid FROM @tmpAffectedCustId) 
				AND b.IsSum=0	
	) b
	GROUP BY b.custid, b.Username

	--calc chargecomm
	DECLARE @ChargeComm TABLE (custid INT, matchid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY)
	
	INSERT INTO @ChargeComm (custid, matchid, winlost, actual_stake, playercomm)
	SELECT t.custid, t.matchid, t.NetWin AS winlost, t.NetWin AS actual_stake, (t.NetWin * b.playerdiscount) AS playercomm
	FROM (
		SELECT MIN(transid) AS FirstTransId, SUM(winlost - actual_stake) AS NetWin, custid, matchid
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM #BetDelete bb WHERE b.custid = bb.custid)  
			AND NOT EXISTS (SELECT TOP 1 1 FROM @tmpTransId bb WHERE b.transid = bb.transid)
			AND bettype = 501
			AND playerdiscount < 0
		GROUP BY custid, matchid
	)t
	INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.FirstTransId = b.transid
	WHERE t.NetWin > 0

	UNION ALL
	SELECT DISTINCT b.custid, b.matchid, b.winlost, b.actual_stake, -b.playercomm
	From dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #BetDelete bd on bd.matchid = b.matchid AND bd.custid = b.custid
	WHERE b.bettype = 500

	IF(@Type = 0)
	BEGIN
		INSERT INTO @tmpChangedBalance (custid, balance)
		SELECT t.custid, SUM(t.winlost - t.actual_stake + t.playercomm) AS balance
		FROM (
			SELECT b.custid, b.winlost, b.actual_stake, b.playercomm
			FROM #BetDelete b
			
			
			UNION ALL
			SELECT b.custid, b.winlost, b.actual_stake, -b.playercomm
			FROM @ChargeComm b
		)t
		GROUP BY t.custid
	END
	ELSE -- recover
	BEGIN
		INSERT INTO @tmpChangedBalance(custid, balance)
		SELECT tmp.custid, SUM(tmp.balance)
		FROM (
			SELECT	b.custid, b.actual_stake AS balance
			FROM	#BetDelete b
			WHERE	b.bettype NOT IN (901,911)					
			UNION ALL
			SELECT  b901.custid, -(b902.actual_stake - b901.actual_stake) AS balance
			FROM	#BetDelete b901
				INNER JOIN dbo.bettrans b902 WITH(NOLOCK)
					ON	b902.refno = b901.refno
						AND b901.bettype = 901
						AND b902.bettype = 902
						AND b902.matchid = b901.matchid
			UNION ALL
			SELECT  b911.custid, -(b912.actual_stake - b911.actual_stake) AS balance
			FROM	#BetDelete b911
				INNER JOIN dbo.bettrans b912 WITH(NOLOCK)
					ON	b912.refno = b911.transid
						AND b911.bettype = 911
						AND b912.bettype = 912
						AND b912.matchid = b911.matchid						
		) tmp
		GROUP BY tmp.custid
	END		

	--netposition bal
	DECLARE @BalNetPositionTmp TABLE(CustId INT, Balance MONEY)

	INSERT INTO @BalNetPositionTmp(CustId, Balance)
	SELECT bal.CustId, SUM(Credit - Debit) AS Balance
	FROM dbo.BalNetPosition bal WITH(NOLOCK)
		INNER JOIN #BetDelete d ON bal.CustId = d.CustId AND bal.MatchId = d.MatchId AND bal.Bettype = d.bettype
	GROUP BY bal.CustId
	
	SELECT	bal.custid
			,bal.username
			,c.site
	FROM	@tmpChangedBalance t
		INNER JOIN @tmpCurrentBalance bal 
			on	t.custid = bal.custid
		INNER JOIN DBCUST.custDB.dbo.custInfo ci WITH(NOLOCK ) 
			ON	bal.custid = ci.custid
		INNER JOIN custDB.dbo.Customer c WITH(NOLOCK) 
			ON	c.custid = ci.custid AND c.site <> 'CN88'
		LEFT JOIN @BalNetPositionTmp tt ON t.CustId = tt.CustId
	WHERE	t.balance > 0 
			AND (ci.credit + bal.balance - t.balance + ISNULL(tt.Balance, 0)) < 0	
			
	DROP TABLE #BetDelete
END
GO
