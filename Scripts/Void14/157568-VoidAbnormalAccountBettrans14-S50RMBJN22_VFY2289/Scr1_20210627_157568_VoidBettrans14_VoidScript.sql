/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date: 20210627
	Task: Support to void tickets in bettrans14 - [Redmine: #157568]
	DB: DBTXN/bodb02
	
*/ 
USE bodb02
GO
DECLARE @TransIds			VARCHAR(MAX) = '112337005710,112337025396,112337050730,112337113931,112337126751,112337135587,112337150141,112337179614,112337190685,112337203341,112337220632,112337233034,112337244675,112337300209,112337310011,112337316860,112337324978,112337340315,112337349872,112337357498,112337365284,112337429074,112337535625,112337605153,112337621151,112337633728,112337652694,112337703487,112337711229,112337769436,112337787414,112337804999,112337815485,112337838102,112337854713,112338044564,112338053836,112338055300,112338066444,112338072867,112338088621,112338095968,112338112401,112338119086,112338144426,112338175106,112338195912,112338224112,112338227783,112338259713,112338261853,112338313470,112338323085,112338333090,112338339202,112338354993,112338367386,112338370878,112338374784,112338380518,112338406029,112338435948,112338475219,112338535751,112338537490,112338564034,112338569305,112338589807,112338734641,112338780284,112338803192,112338826918,112338831730,112338842998,112338843548,112338855002,112338855730,112338874256,112338874600,112338899893,112338901405,112338915916,112338917919,112338927048,112338938936,112338960384,112338989577,112339008466,112339020151,112339033684,112339047674,112339076570,112339206104,112339215019,112339227287,112339235916,112339249861,112339268478,112339277937,112339281955,112339317709,112339322287,112339336301,112339355159,112339365656,112339366930,112339375151,112339384712,112339384877,112339395462,112339409193,112339438699,112339452308,112339510637,112339522491,112339537769,112339551592,112339561550,112339582941,112339597746,112339604638,112339633210,112339685555,112339772246,112339792937,112339814016,112339815021,112339833911,112339849689,112339880459,112339938834,112339953757,112339992150,112340006490,112340026781,112340056453,112340076568,112340112278,112340147049,112340173340,112340197872,112340222896,112340295209,112340309589,112340335386,112340401524,112340412213,112340423246,112340449982,112340471568,112340483127,112340492988,112340519602,112340529181,112340539384,112340551095,112340563308,112340575107,112340588058,112340609015,112340639431,112340649673,112340661752,112340671669,112340948347,112340982935,112341011346,112341011704,112341024854,112341035330,112341045076,112341066264,112341089116,112341099580,112341120057,112341130711,112341160237,112341170977,112341181153,112341190333,112341200654,112341209545,112341223487,112341240987,112341250646,112341259069,112341267064,112341275395,112341285383,112341293714,112341300835,112341317123,112341325621,112341365234,112341373433,112341382139,112341396434,112341407347,112341415478,112341425433,112341437219,112341478650,112341487549,112341495995,112341544327,112341549521,112341551520,112341560191,112341566019,112341568380,112341574705,112341576963,112341589432,112341596851,112341630827,112341659541,112341666377,112341674890,112341682519,112341683458,112341689923,112341690609,112341697025,112341703233,112341709559,112341715977,112341721958,112341727178,112341731448,112341737580,112341744213,112341750715,112341757172,112341764766,112341800252,112341810983,112341821906,112341835385,112341858858,112341870148,112341878348,112341884831,112341889899,112341893449,112341900440,112341904481,112341907057,112341916774,112341917189,112341925897,112341939258,112341948359,112341948780,112341968387,112341977349,112341977843,112341984600,112341985732,112341990020,112341992180,112341996919,112342006075,112342038040,112342050290,112342053985,112342059388,112342064528,112342064784,112342070234,112342086166,112342092892,112342097675,112342115555,112342146127,112342158941,112342178307,112342201425,112342206564,112342217012,112342223896,112342244560,112342250297,112342256554,112342257134,112342264423,112342278227,112342278289,112342282565,112342286701,112342290655,112342297353,112342301897,112342308637,112342313016,112342320504,112342324854,112342329381,112342333538,112342339251,112342343847,112342354235,112342365948,112342372876,112342378796,112342383086,112342392915,112342403699,112342405278,112342414879,112342427321,112342447312,112342454030,112342461908,112342467597,112342471575,112342474054,112342478285,112342480724,112342481469,112342485601,112342488265,112342491825,112342492311,112342539886,112342559261,112342586791,112342592274,112342599411,112342601445,112342603514,112342604875,112342608643,112342610981,112342620060,112342622887,112342630677,112342640366,112342664345,112342668653,112342673644,112342747755,112342796734,112342821152,112342830448,112342837939,112342862519,112342953911,112342973171,112343011044,112343023447,112343023771,112343052231,112343052561,112343068857,112343069302,112343145039,112343145551,112343209377,112343258125,112343331932,112343342244,112343347761,112343362969,112343373858,112343399378,112343408317,112343408333,112343418564,112343427367,112343427692,112343431849,112343452103,112343690410,112343690612,112343811355,112343812234,112343934631,112344013540,112344028824,112344043299,112344045984,112344055809,112344056392,112344068887,112344140697,112344161776,112344178991,112344200915,112344201484,112344214969,112344219022,112344225740,112344264174,112344264531,112344290013,112344292110,112344325392,112344443015,112344499584,112344741822,112344901073,112345008935'
	,@TransIdSolds		VARCHAR(MAX)	= '' -- just for BetTrade's subticket (transid of bettype 901)  
	,@UserName			VARCHAR(30) = 'starixIT'
	,@UserId			INT = 10278938 -- custid of Admin
	,@IP				VARCHAR(15) ='125.227.140.97'
	,@Reason			NVARCHAR(500) = 'Soccer - Abnormal bet'
	,@ReasonSC			NVARCHAR(500) = N'足球  - 非正常投注'
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
 



