/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date: 20210627
	Task: Support to void tickets in bettrans14 - [Redmine: #157566]
	DB: DBTXN/bodb02
	
*/ 
USE bodb02
GO
DECLARE @TransIds			VARCHAR(MAX) = '112322506350,112322513340,112322522064,112322535539,112322542637,112322561794,112322693828,112323551883,112323579206,112323591449,112323607587,112323620900,112323634905,112323644936,112323665033,112323674653,112323683451,112323747685,112323765147,112323775092,112323794215,112323806172,112323830523,112323850445,112324086619,112324108786,112324203313,112324224514,112324320358,112324341605,112324376396,112324402579,112324420313,112324438113,112324446600,112324455829,112324483400,112324493561,112324587808,112324600376,112324619921,112324634210,112324670699,112324692416,112324713211,112324747115,112324771743,112324784876,112324822596,112324836205,112324848870,112324862986,112324886944,112324895542,112324903641,112324915125,112324931922,112324940865,112324950981,112324964879,112324972567,112324982049,112325003586,112325360576,112325368115,112325392893,112325474102,112325506634,112325514674,112325529254,112325536393,112325555981,112325561372,112325575957,112325588293,112325594335,112325610311,112325617486,112325622724,112325632946,112325644355,112325650018,112325654656,112325662064,112325668294,112325680782,112325690838,112325706602,112325710213,112325720162,112325731350,112325735412,112325750609,112325754900,112325765902,112325779562,112325785714,112325790543,112325795342,112325800924,112325806936,112325810887,112325819377,112325832043,112325851905,112325855603,112325864900,112325869234,112325872859,112325885089,112325893876,112325899066,112325907482,112325912418,112325925654,112325938317,112325947659,112325970339,112325974797,112326002881,112326009200,112326017887,112326063914,112326071025,112326075464,112326085066,112326092062,112326163322,112326954728,112327845302,112328837356,112329017702,112329179789,112329507250,112329954553,112330601854'
	,@TransIdSolds		VARCHAR(MAX)	= '' -- just for BetTrade's subticket (transid of bettype 901)  
	,@UserName			VARCHAR(30) = 'starixIT'
	,@UserId			INT = 10278938 -- custid of Admin
	,@IP				VARCHAR(15) ='125.227.140.97'
	,@Reason			NVARCHAR(500) = 'Technical Issue'
	,@ReasonSC			NVARCHAR(500) = N'技术问题'
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
	INNER JOIN #tblMatch tm ON main.matchid = tm.matchid
	INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK) ON main.transid = tmpmain.transid AND main.matchid = tmpmain.matchid		

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
 



