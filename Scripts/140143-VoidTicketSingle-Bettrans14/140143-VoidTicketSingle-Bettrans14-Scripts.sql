/*	
	Created by: Helen
	Date 20200823
	Task: Void abnormal ticket in bettrans14 - [Redmine: 140143]
	DB: DBTXN/bodb02
	
*/ 
DECLARE @TransIds			VARCHAR(MAX) = ''
	,@TransIdSolds		VARCHAR(MAX)	= '' -- just for BetTrade's subticket (transid of bettype 901)  
	,@UserName			VARCHAR(30) = 'starixIT'
	,@UserId			INT = 10278938 -- custid of Admin
	,@IP				VARCHAR(15) ='125.227.140.97'
	,@Reason			NVARCHAR(500) = '@@'
	,@ReasonSC			NVARCHAR(500) = '@@'
	,@IsAbnormalBet		BIT = 1

DECLARE	@LogData					NVARCHAR(500)
		
DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))					
DECLARE @BeforeUpd TVP_BalanceWalletChange
DECLARE @AfterUpd  TVP_BalanceWalletChange

DECLARE @BalanceInfoBeforeUpd TABLE (
	CustId			INT
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
	CustId			INT
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

					
--SELECT @TransIds					

CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	

CREATE TABLE #BetDelete (
	GroupTransId	BIGINT -- parent Id (translog.traslogid | bettrans.transid)
	,transid		BIGINT PRIMARY KEY --bettrans.transid
	,matchid		INT
	,Bettype		SMALLINT
	,OriginalBetType SMALLINT
	,betid			BIGINT
	,stake			MONEY
	,odds			MONEY
	,oddsspread 	MONEY
	,refno			BIGINT -- translog.traslogid | bettrans.transid
	,betfrom		NVARCHAR(10)
	,statusid		TINYINT
	,betdaqid		BIGINT		
	,winlostdate	SMALLDATETIME
	,status			VARCHAR(10)
	,oddstype		TINYINT
	,transdate		DATETIME
	,betteam		NVARCHAR(10)
	,betcheck		NVARCHAR(50)
	,hdp1			SMALLMONEY
	,hdp2			SMALLMONEY
	,livehomescore	SMALLINT
	,liveawayscore	SMALLINT
	,liveindicator	BIT
	,winlost		MONEY
	,playercomm		MONEY
	,currency		TINYINT
	,transdesc		NVARCHAR(1000)
	,custid			INT
	,creator		INT
	,homeid			INT DEFAULT (0)
	,awayid			INT DEFAULT (0)
	,matchcode		NVARCHAR(50)
	,eventdate		DATETIME
	,leagueid		INT DEFAULT (0)
	,isNeutral		BIT
	,showtime		NVARCHAR(50)
	,username		VARCHAR(30)
	,username2		VARCHAR(50)
	,recommend		INT
	,mrecommend		INT
	,srecommend		INT
	,sporttype		SMALLINT
	,IsHideComm		BIT DEFAULT(0)
	,oddsid			INT
	,ExtraInfo		VARCHAR(1000)
	,IsBetTrade		BIT DEFAULT 0
	,IsCashOutMemberTicket BIT DEFAULT 0
	,MainCashoutId	BIGINT
	,awinlost		MONEY
	,SiteId			VARCHAR(7)
	,CurrencyName	NVARCHAR(50)
	,IsMetricGaming	BIT
	,modds			SMALLMONEY
	,WalletType		TINYINT
	,RefCode		BIGINT
	,BonusID		INT
	,MainTransId	BIGINT
)

CREATE TABLE #tblMatch (matchid INT)

INSERT INTO #tblTransIds (transid)
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN custdb.dbo.Customer c with (nolock) on b.custid = c.custid
WHERE c.recommend = 38611878 and b.bettype < 19999 
	and b.winlostdate >= '20200817'
	and b.statusid in (111,112,113)

SET @TransIds = STUFF((SELECT ',' + CONVERT(VARCHAR(20), transid)
				 FROM #tblTransIds WITH (NOLOCK)
				 FOR XML PATH ('')
					),1,1,'')
					
INSERT INTO #BetDelete(
	GroupTransId	
	,transid			
	,matchid		
	,Bettype		
	,betid			
	,stake			
	,odds	
	,oddsspread		
	,refno			
	,betfrom		
	,statusid				
	,betdaqid		
	,winlostdate
	,status		
	,oddstype		
	,transdate		
	,betteam		
	,betcheck		
	,hdp1			
	,hdp2			
	,livehomescore	
	,liveawayscore	
	,liveindicator	
	,winlost		
	,playercomm		
	,currency	
	,transdesc		
	,custid			
	,creator	
	,recommend
	,mrecommend
	,srecommend
	,IsHideComm
	,eventdate
	,oddsid
	,ExtraInfo
	,MainCashoutId
	,awinlost
	,IsBetTrade
	,SiteId
	,CurrencyName
	,IsMetricGaming
	,modds
	,WalletType
	,RefCode
	,BonusID
)
SELECT	
	b.transid AS groupTransId
	,b.transid
	,b.matchid
	,b.bettype
	,b.betid
	,b.stake
	,b.odds
	,b.oddsspread
	,b.refno
	,b.betfrom
	,b.statusID
	,b.betdaqid
	,b.winlostdate
	,b.status
	,b.oddstype
	,b.transdate
	,b.betteam
	,b.betcheck
	,b.hdp1
	,b.hdp2
	,b.livehomescore
	,b.liveawayscore
	,b.liveindicator
	,b.winlost - b.actual_stake
	,b.playercomm
	,b.currency
	,b.transdesc
	,b.custid
	,b.creator
	,b.recommend
	,b.mrecommend
	,b.srecommend
	,CASE 
		WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1 			 
		ELSE 0 
	 END AS IsHideComm
	,b.winlostdate
	,b.oddsid
	,b.ExtraInfo
	,CASE
		WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
				THEN b.transid
		ELSE NULL
	 END AS MainCashoutId
	,b.awinlost
	,CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsBetTrade
	,NULL AS SiteId
	,b.CurrencyName
	,0 AS IsMetricGaming
	,b.modds
	,b.WalletType
	,b.RefCode
	,b.BonusID
FROM dbo.bettrans14 b WITH(NOLOCK)
	INNER JOIN #tblTransIds t ON b.transid = t.transid

-- UPDATE eventtype = 1
UPDATE	b
SET homeid 		= m.homeid
	,awayid 	= m.awayid
	,matchcode 	= m.matchcode
	,eventdate 	= m.eventdate
	,leagueid 	= m.leagueid
	,isNeutral 	= ISNULL(m.IsNeutral,CAST(0 AS BIT))
	,showtime 	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') 
	,sporttype 	= m.sporttype
FROM	#BetDelete b
	INNER JOIN dbo.match14 m WITH(NOLOCK)
		ON	b.matchid = m.matchid

-- gather match Ids
INSERT INTO #tblMatch (matchid)
SELECT	matchid
FROM	#BetDelete
GROUP BY matchid

-- STEP 1 : BackUp bettrans
-- 1.1  backup for normal ticket, main bettrade, main cash-out, cash-out member bet tickets
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
	)
SELECT main.transid
	,main.custid
	,CURRENT_TIMESTAMP
	,main.oddsid
	,main.hdp1
	,main.hdp2
	,main.odds
	,main.stake
	,main.STATUS
	,main.winlost
	,main.livehomescore
	,main.liveawayscore
	,main.liveindicator
	,main.betteam
	,main.creator
	,main.refno
	,main.winlostdate
	,main.betfrom
	,CASE
		WHEN (tmpmain.betdaqid = 0 AND charindex ('p25',tmpmain.extrainfo)> 0) -- main ticket is Cash-out
			 OR tmpmain.IsCashOutMemberTicket = 1
				THEN @session
		ELSE main.betcheck
	 END AS betcheck
	,main.checktime
	,main.matchid
	,main.bettype
FROM dbo.bettrans14 AS main WITH (NOLOCK)
	INNER JOIN #tblMatch tm 
	ON main.matchid = tm.matchid
	INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK) 
	ON	main.transid = tmpmain.transid 
	AND main.matchid = tmpmain.matchid		

--capture balance before
INSERT INTO @BalanceInfoBeforeUpd (CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
SELECT	b14.custid
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
	INNER JOIN #BetDelete t
		ON t.TransId = b14.transid
GROUP BY b14.custid
		,b14.matchid
		,b14.winlostdate

INSERT INTO @BeforeUpd (matchid, custid, balanceType, bonusId, walletType, balance)
SELECT	b14.matchid
		,b14.custid
		,1 AS BalanceType
		,0 AS BonusID
		,2 AS WalletType -- normal tickets are treated as cash tickets
		,SUM(b14.balance) AS balance
FROM	@BalanceInfoBeforeUpd b14
GROUP BY b14.custid
		,b14.matchid

UPDATE main
	SET 
		winlost = main.actual_stake
		,ruben = 1
		--,statuswinlost = 6
		,creator = @UserID
		,mwinlost = 0
		,swinlost = 0
		,awinlost = 0 -- awinlost main ticket
		,playercomm = 0
		,comm = 0
		,acomm = 0
		,scomm = 0
		,statusID = 102
		,status = 'VOID'
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(@IsAbnormalBet,'void',main.ExtraInfo,tmpmain.sporttype,main.bettype) 
FROM dbo.bettrans14 AS main WITH (ROWLOCK, UPDLOCK)
	INNER JOIN #tblMatch tm ON main.matchid = tm.matchid
	INNER JOIN #BetDelete AS tmpmain ON	main.transid = tmpmain.transid AND main.matchid = tmpmain.matchid			

INSERT INTO @BalanceInfoAfterUpd (CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
SELECT	b14.custid
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
	INNER JOIN #BetDelete t
		ON t.TransId = b14.transid
GROUP BY b14.custid
		,b14.matchid
		,b14.winlostdate

INSERT INTO @AfterUpd (matchid, custid, balanceType, bonusId, walletType, balance)
SELECT	b14.matchid
		,b14.custid
		,1 AS BalanceType
		,0 BonusID
		,2 AS WalletType -- normal tickets are treated as cash tickets
		,SUM(b14.balance) AS balance
FROM	@BalanceInfoAfterUpd b14
GROUP BY b14.custid
		,b14.matchid

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
			,SUM(stake) AS '@st'
			,SUM(actual_stake) AS '@ast'
			,SUM(Winlost) AS '@w_dif'
			,SUM(aWinlost) AS '@aw_dif'
			,SUM(mWinlost) AS '@mw_dif'
			,SUM(sWinlost) AS '@sw_dif'
			,SUM(playerComm) AS '@pc_dif'
			,SUM(Comm) AS '@c_dif'
			,SUM(aComm) AS '@ac_dif'
			,SUM(sComm) AS '@sc_dif'
	FROM	@BalanceInfoAfterUpd 
	GROUP BY CustId
			,WinlostDate
	FOR XML PATH('r'), ROOT('root'), TYPE
) AS VARCHAR(MAX))
	
EXEC dbo.TicketVoiding_Admin_Bet14_19999 
	@AffectedList = @AffectedList

-- insert routine task
EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
	@AffectedList = @AffectedList

SELECT @LogData = 'Delete transaction transid:' + cast(@TransIds as varchar(MAX))+ ' by_login:' + @username 
	+ 'IP:' + cast(@IP as varchar(15)) + ' reason: ' + @reason  + ' - -' + @ReasonSC
EXEC dbo.WriteLog_UserLog @UserID = @UserID, @Doing = @LogData  

DROP TABLE #BetDelete
DROP TABLE #tblMatch
DROP TABLE #tblTransIds  
 



