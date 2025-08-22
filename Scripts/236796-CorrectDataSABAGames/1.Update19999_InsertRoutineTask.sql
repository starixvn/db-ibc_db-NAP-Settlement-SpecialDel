﻿/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Max
	Date: 20250822
	Task: Fix data 2 tickets SABA.games wrong stake,actual_stake - [Redmine: #236796]
	DB: DBSIC/bodb02
	
*/ 
USE bodb02
GO
			
DECLARE @BeforeUpd TVP_BalanceWalletChange
DECLARE @AfterUpd  TVP_BalanceWalletChange

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
DECLARE @BalanceInfoAfterUpd TABLE (
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

--capture balance before
INSERT INTO @BalanceInfoBeforeUpd (sporttype, CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
SELECT	200 --SABA Games
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
WHERE b14.transid IN (423594241957036040,423600439594844165)
GROUP BY b14.custid
		,b14.matchid
		,b14.winlostdate

INSERT INTO @BeforeUpd (matchid, custid, balanceType, bonusId, walletType, balance)
SELECT	b14.matchid
		,b14.custid
		, CASE 
				WHEN b14.sporttype BETWEEN 1 AND 99  THEN 1 -- Sports
				WHEN b14.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		,0 AS BonusID
		,2 AS WalletType -- normal tickets are treated as cash tickets
		,SUM(b14.balance) AS balance
FROM	@BalanceInfoBeforeUpd b14
GROUP BY b14.custid
		,b14.matchid
		, CASE 
				WHEN b14.sporttype BETWEEN 1 AND 99  THEN 1 -- Sports
				WHEN b14.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END 

--Update Stake, Actual_stake = oddsspread
INSERT INTO @BalanceInfoAfterUpd (sporttype, CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
SELECT	200 --SABA Games
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
		,SUM(b14.oddsspread) --stake
		,SUM(b14.oddsspread) --actual_stake

		,SUM(b14.winlost - b14.oddsspread + b14.playercomm) --balance
FROM	dbo.bettrans14 b14 WITH(NOLOCK)
WHERE  b14.transid IN (423594241957036040,423600439594844165)
GROUP BY b14.custid
		,b14.matchid
		,b14.winlostdate

INSERT INTO @AfterUpd (matchid, custid, balanceType, bonusId, walletType, balance)
SELECT	b14.matchid
		,b14.custid
		, CASE 
				WHEN b14.sporttype BETWEEN 1 AND 99  THEN 1 -- Sports
				WHEN b14.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		,0 BonusID
		,2 AS WalletType -- normal tickets are treated as cash tickets
		,SUM(b14.balance) AS balance
FROM	@BalanceInfoAfterUpd b14
GROUP BY b14.custid
		,b14.matchid
		, CASE 
				WHEN b14.sporttype BETWEEN 1 AND 99  THEN 1 -- Sports
				WHEN b14.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END

---INSERT data into pending balance table   
EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
	  @BalanceWalletBefore	= @BeforeUpd
	, @BalanceWalletAfter	= @AfterUpd
	, @ActionId				= 0

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

--update 19999	
EXEC dbo.TicketVoiding_Admin_Bet14_19999 
	@AffectedList = @AffectedList

-- insert routine task
EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
	@AffectedList = @AffectedList



