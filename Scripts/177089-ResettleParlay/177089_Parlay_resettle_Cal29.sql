/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Creator: Helen
	Date: 20220826
	DB: DBTXN/bodb02

	Revisions:
		- 20220826@Helen: Resettle ticket for parlay  [Redmine:#177089]

*/
-- keep refno, transid will be RECALCULATED
DECLARE 			
		@statusId			TINYINT
		,@winlost			MONEY
		,@settlementTime	DATETIME
			
DECLARE @tmpSource TABLE (TransId BIGINT PRIMARY KEY, WinlostDate SMALLDATETIME
	, totalStake MONEY, Winlost MONEY, aWinlost MONEY, mWinlost MONEY, sWinlost MONEY
	, playerComm MONEY, comm MONEY, aComm MONEY, sComm MONEY
	, ruben TINYINT, IsMarked BIT)

CREATE TABLE #tmpParlayBalanceBefore (transid BIGINT PRIMARY KEY, custid INT, balance money)
CREATE TABLE #tmpParlayBalanceAfter (transid BIGINT PRIMARY KEY, custid INT, balance money)
CREATE TABLE #tmpParlayBalance (custid int, balance money)
DECLARE @tmpParlayDebitPending		TVP_BalanceList
		,@tmpParlayCreditPending	TVP_BalanceList

CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT, IsMarked BIT DEFAULT(0))
	
INSERT INTO #Refno (refno, transid)
SELECT DISTINCT refno, transid
FROM ParlayBettransResettle_tmp (NOLOCK)
	
SET @settlementTime = GETDATE();

INSERT INTO #tmpParlayBalanceBefore (transid, custid, balance)
SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
FROM	dbo.bettrans b WITH(ROWLOCK)
WHERE	b.transid IN (SELECT transid FROM #Refno)


INSERT INTO @tmpSource (TransId, WinlostDate, totalStake
	,Winlost, aWinlost, mWinlost, sWinlost
	,playerComm, comm, aComm, sComm
	,ruben, IsMarked
)
SELECT b.transid, MAX(pr.winlostdate), SUM(pr.stake)
	,SUM(pr.winlost), SUM(pr.awinlost), SUM(pr.mwinlost),  SUM(pr.swinlost) 
	,SUM(pr.playercomm), SUM(pr.comm), SUM(pr.acomm), SUM(pr.scomm) 			
	,CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
	,b.IsMarked
FROM #Refno b 
	INNER JOIN dbo.BetParlayResult pr WITH(NOLOCK)
		ON pr.refno = b.refno
GROUP BY b.refno, b.transid, b.IsMarked
	
UPDATE b WITH(ROWLOCK, UPDLOCK)
SET @statusId = CASE
				WHEN s.ruben = 0 THEN 0
				WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
														WHEN s.winlost = b.actual_Stake THEN 111
														WHEN s.winlost > b.actual_Stake THEN 112
														WHEN s.winlost < b.actual_stake THEN 113 
														END
				ELSE	CASE				
						WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
						WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
						WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
						ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
						END
				END
	,@winlost = s.winlost * s.ruben
	,SettlementTime = @settlementTime
					--CASE 
					--	WHEN s.IsMarked = 1 THEN b.SettlementTime
					--	WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime 
					--	ELSE SettlementTime 
					--END
	,statusID = CASE WHEN s.IsMarked = 1 THEN b.statusID ELSE @statusId END
	,[status] = CASE 
					WHEN s.IsMarked = 1 THEN b.status 
					WHEN @statusId = 0 THEN 'running' 
					WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
					WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
					WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
					ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
				END
	--,winlostdate = CASE 
	--					WHEN s.IsMarked = 1 THEN b.winlostdate
	--					WHEN @statusId <> b.statusID THEN s.winlostdate 
	--					ELSE b.winlostdate 
	--				END
	--,modds = s.modds
	---,actual_stake = s.totalStake
	,betdaqid = CASE WHEN s.IsMarked = 1 THEN b.betdaqid ELSE s.totalStake END						
	,ruben = CASE WHEN s.IsMarked = 1 THEN b.ruben ELSE s.ruben END
	,winlost =  CASE WHEN s.IsMarked = 1 THEN b.winlost ELSE @winlost END
	,awinlost = CASE WHEN s.IsMarked = 1 THEN b.awinlost ELSE s.awinlost * s.ruben END
	,mwinlost = CASE WHEN s.IsMarked = 1 THEN b.mwinlost ELSE s.mwinlost * s.ruben END
	,swinlost = CASE WHEN s.IsMarked = 1 THEN b.swinlost ELSE s.swinlost * s.ruben END
	,playercomm = CASE WHEN s.IsMarked = 1 THEN b.playercomm ELSE s.playercomm * s.ruben END
	,comm = CASE WHEN s.IsMarked = 1 THEN b.comm ELSE s.comm * s.ruben END
	,acomm = CASE WHEN s.IsMarked = 1 THEN b.acomm ELSE s.acomm * s.ruben END
	,scomm = CASE WHEN s.IsMarked = 1 THEN b.scomm ELSE s.scomm * s.ruben END
	,statuswinlost = CASE 
						WHEN @statusId = 112 THEN 2							
						WHEN @statusId = 111 THEN 0 							
						WHEN @statusId = 113 THEN 4								
						WHEN @statusId = 0 THEN NULL
					END 
FROM @tmpSource s
	INNER JOIN dbo.bettrans b
		ON b.transid = s.transid

---- CAPTURE value BALANCE after udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
INSERT INTO #tmpParlayBalanceAfter (transid, custid, balance)
SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
FROM	dbo.bettrans b WITH(ROWLOCK)
WHERE	b.transid IN (SELECT transid FROM #Refno)

INSERT INTO #tmpParlayBalance (custid, balance)
SELECT b.custid, SUM(a.balance - b.balance)
FROM #tmpParlayBalanceBefore b
	INNER JOIN #tmpParlayBalanceAfter a ON b.transid = a.transid
GROUP BY b.custid

INSERT INTO @tmpParlayDebitPending (custID, balance)
SELECT t.custid, ABS(t.balance)
FROM (
	SELECT	custID, SUM(balance) AS balance
	FROM	#tmpParlayBalance
	GROUP BY custID
) t
WHERE t.balance < 0

IF @@ROWCOUNT <> 0
	EXEC dbo.Dot_BalancePendingDebitIns
		@BalancePending = @tmpParlayDebitPending
		,@Type			= 1 -- Sports

INSERT INTO @tmpParlayCreditPending (custID, balance)
SELECT t.custid, ABS(t.balance)
FROM (
	SELECT	custID, SUM(balance) AS balance
	FROM	#tmpParlayBalance
	GROUP BY custID
) t
WHERE t.balance > 0

IF @@ROWCOUNT <> 0
	EXEC dbo.Dot_BalancePendingCreditIns
		@BalancePending = @tmpParlayCreditPending
		,@Type			= 1 -- Sports

INSERT INTO [bodb02].[dbo].[BalanceNegative] ([ExecDate], [MatchID], [ActionID], [GroupID], [CustID], [Balance], [StatusID], [Remark])
SELECT GETDATE()
	,0
	,104 -- CAL
	,2 -- Sportsbook Parlay Settlement
	,t.CustID
	,t.Balance
	,0
	,''
FROM (	SELECT	custID, SUM(balance) AS balance
		FROM	#tmpParlayBalance
		GROUP BY custID) t
WHERE t.balance < 0