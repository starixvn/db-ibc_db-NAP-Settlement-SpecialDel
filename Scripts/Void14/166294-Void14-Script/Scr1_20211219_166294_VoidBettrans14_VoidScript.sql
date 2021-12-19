/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date: 20211219
	Task: Support to void tickets in bettrans14 - [Redmine: #166294]
	DB: DBTXN/bodb02
	
*/ 
USE bodb02
GO
DECLARE @TransIds			VARCHAR(MAX) = '114170546542,114170550987,114170585626,114170683396,114170695210,114170698064,114171202669,114171235759,114171238030,114171257701,114175906485,114175923062,114176110066,114176121303,114176734687,114177269743,114177275012,114177730246,114177748394,114178489246,114178563210,114178572179,114178771003,114178794014,114178916976,114178953886,114178974757,114179542624,114179596192,114179614005,114179663165,114184717443,114185028254,114185032922,114185034906,114185213672,114185224401,114185230271,114185435090,114185462197,114185479816,114185521013,114185794479,114185810768,114185877901,114185887928,114185947466,114186468170,114186640451,114186745385,114186780693,114187250815,114187251425,114187326335,114187330701,114187669561,114187716969,114187759456,114187806665,114187901473,114187912468,114188520502,114188767242,114189115519,114189223910,114189250178,114189298722,114189324078,114189324916,114189380092,114189380804,114168127787,114168143118,114168183441,114168185243,114168263215,114168272413,114168284130,114168288568,114168298874,114168307185,114168462697,114168472641,114168498248,114168511224,114168511918,114170528193,114170538358,114170603486,114170717394,114170851064,114170879171,114170887423,114170911085,114170924737,114171406288,114171481934,114171541304,114171583024,114171595959,114171650319,114171655101,114171958240,114171959043,114171972255,114171976064,114171983237,114172060251,114172065338,114172357529,114172358115,114175585676,114175590127,114175593424,114175642129,114175658387,114175694684,114175846719,114175849040,114175864618,114175904832,114175922231,114175924798,114175933481,114175940247,114175941472,114175941933,114175942323,114175943233,114175945035,114175957324,114176092019,114176092230,114176109264,114176109456,114176123544,114176126952,114176149136,114176153075,114176156790,114176162394,114176168628,114176204982,114176214512,114176241806,114176255333,114176268735,114176271817,114176290288,114176294424,114176297067,114176324765,114176326906,114176444678,114176445254,114176457580,114176460671,114176682418,114176690317,114176697541,114176699151,114176700879,114176953994,114177110144,114177114680,114177124102,114177130365,114177170153,114177284023,114177285630,114177292977,114177306386,114177329980,114177614946,114177623111,114177636879,114177689221,114177698598,114177724741,114177725243,114177853720,114177867209,114177944311,114177962575,114177966908,114177978481,114177982973,114177995477,114178103042,114178427483,114178458228,114178497638,114178529206,114178590925,114178626005,114178764305,114178805672,114178854321,114178880964,114178907958,114178957985,114179200499,114179202334,114179301012,114179309301,114179372180,114179404257,114179543060,114179553421,114179592746,114179598676,114179604925,114179914348,114179952517,114184722684,114184997809,114185000888,114185024067,114185031579,114185034184,114185045784,114185052469,114185058537,114185083883,114185087582,114185088917,114185109559,114185215354,114185218420,114185225850,114185428717,114185433166,114185437738,114185467821,114185520151,114185743354,114185800547,114185803367,114186377241,114186399260,114186409065,114186474602,114186704582,114186860363,114187016253,114187070722,114187094480,114187100423,114187139307,114187155871,114187356010,114187429298,114187486541,114187840307,114187852322,114187883107,114187907479,114187991038,114188248874,114188257296,114188659570,114188673665,114189233630,114194221748,114194227161,114194229166,114194241694,114194246298,114194650812'
	,@TransIdSolds		VARCHAR(MAX)	= '' -- just for BetTrade's subticket (transid of bettype 901)  
	,@UserName			VARCHAR(30) = 'starixIT'
	,@UserId			INT = 10278938 -- custid of Admin
	,@IP				VARCHAR(15) ='125.227.140.97'
	,@Reason			NVARCHAR(500) = 'Abnormal bet'
	,@ReasonSC			NVARCHAR(500) = N'非正常投注'
	,@IsAbnormalBet		BIT = 1

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
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(@IsAbnormalBet,'void',main.ExtraInfo,tmpmain.sporttype,main.bettype) 
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
 



