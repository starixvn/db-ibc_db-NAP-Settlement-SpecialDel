/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date: 20240208
	Task: Support to void tickets in bettrans14 - [Redmine: #200940]
	DB: DBCTG/bodb02 - batch 2
	
*/ 
USE bodb02
GO
DECLARE @TransIds			VARCHAR(MAX) = '214669371774074907,214671523552690182,214673718280978443,214695687038697480,214712308562133009,214712725173960712,214757929704751136,214758595424681992,214794093329383424,214805698331017248,214854175626887169,215030234926284807,215032829086531599,215044885059731479,215052508626681878,215054480016670756,215055227340980264,215078974215159815,215140950593241114,215156880626941980,215171410501304350,215202518949429251,215207054434893825,215227859256475654,215448912633266181,215469502706483203,215492626810404880,215505954093924390,215517683649609746,215551094200205312,215571100157870083,215580299977818117,215588181242806279,215594847032049680,215596431874981896,215736327549747220,215738440673656843,215787102653120541,215826315704533032,215868324779655191,215888193298366485,215910265135300626,215910509948436486,215917068363497474,215921500769746954,215926963968147457,215929566718328837,215929622552903697,215930052049633286,215933230325432322,215950281345597445'
	,@TransIdSolds		VARCHAR(MAX)	= '' -- just for BetTrade's subticket (transid of bettype 901)  
	,@UserName			VARCHAR(30) = 'starixIT'
	,@UserId			INT = 10278938 -- custid of Admin
	,@IP				VARCHAR(15) ='125.227.140.97'
	,@Reason			NVARCHAR(500) = N'Technical Error'
	,@ReasonSC			NVARCHAR(500) = N'技术有误'
	,@IsAbnormalBet		BIT = 0

DECLARE	@LogData					NVARCHAR(500)
		
DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))					
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
SELECT DISTINCT val
FROM dbo.f_SplitString(@TransIds, ',')
WHERE val <> ''
OPTION (MAXRECURSION 0)

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
IF(EXISTS (SELECT 1 FROM #BetDelete WHERE bettype NOT IN (9, 29, 2799)))
BEGIN
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
	WHERE bettype NOT IN (9, 29, 2799)
END

-- gather match Ids
INSERT INTO #tblMatch (matchid)
SELECT	matchid
FROM	#BetDelete
GROUP BY matchid

-- STEP 1 : BackUp bettrans
--capture balance before
INSERT INTO @BalanceInfoBeforeUpd (sporttype, CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
SELECT	t.sporttype
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
	INNER JOIN #BetDelete t
		ON t.TransId = b14.transid
GROUP BY b14.custid
		,b14.matchid
		,b14.winlostdate
		,t.sporttype

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
		--,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(@IsAbnormalBet,'void',main.ExtraInfo,tmpmain.sporttype,main.bettype) 
FROM dbo.bettrans14 AS main WITH (ROWLOCK, UPDLOCK)
	INNER JOIN #tblMatch tm ON main.matchid = tm.matchid
	INNER JOIN #BetDelete AS tmpmain ON	main.transid = tmpmain.transid AND main.matchid = tmpmain.matchid			

INSERT INTO @BalanceInfoAfterUpd (sporttype, CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
SELECT	t.sporttype
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
	INNER JOIN #BetDelete t
		ON t.TransId = b14.transid
GROUP BY b14.custid
		,b14.matchid
		,b14.winlostdate
		,t.sporttype

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

-----INSERT data into pending balance table   
--EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
--	  @BalanceWalletBefore	= @BeforeUpd
--	, @BalanceWalletAfter	= @AfterUpd
--	, @ActionId				= 0

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
	
EXEC dbo.TicketVoiding_Admin_Bet14_19999 
	@AffectedList = @AffectedList

-- insert routine task
EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
	@AffectedList = @AffectedList

--SELECT @LogData = 'Delete transaction transid:' + cast(@TransIds as varchar(MAX))+ ' by_login:' + @username 
--	+ 'IP:' + cast(@IP as varchar(15)) + ' reason: ' + @reason  + ' - -' + @ReasonSC
--EXEC dbo.WriteLog_UserLog @UserID = @UserID, @Doing = @LogData  

DROP TABLE #BetDelete
DROP TABLE #tblMatch
DROP TABLE #tblTransIds  
 



