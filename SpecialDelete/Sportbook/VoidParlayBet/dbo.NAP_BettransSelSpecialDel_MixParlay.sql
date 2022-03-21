/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelSpecialDel_MixParlay]
	  @MatchID			INT
	, @BetType			SMALLINT 		= 0
	, @Type				SMALLINT 		= 0
	, @LiveHomeScore	SMALLINT 		= NULL
	, @LiveAwayScore	SMALLINT 		= NULL
	, @FromTransdate	DATETIME 		= NULL
	, @ToTransdate		DATETIME 		= NULL
	, @BetTypes			XML				= NULL
	, @Language			NVARCHAR(2)		= 'E'
AS  
/*  
	Created by:  Kathy
	Date:   
	Task: Get transaction of mix parlay bet in bettrans  
	DB: DBTXN.BODB02  
	Original:   
   
	Revisions:   
		- 20140102@Kathy: - Add username2 column [Redmine:#10270]
						  - Show settled ticket 
		- 20140411@Kathy: Separate tickets of Bet Fair, OneExchange 3rd parties [Redmine:#10128]
						  - Add 2 new bettypes 1H Total Goal and 1H First Goal/ Last Goal (126, 127) [Redmine:#14749]
		- 20140701@Kathy: Apply BetRadar - change @BetTypes to varchar(1000) [Redmine:#18219]						  
		- 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]		
		- 20140806@Kathy: Support new 11 bettypes [Redmine:#19955]
		- 20140929@Kathy: - Offer new bettypes from Sportting Solutions and new IBC bettypes [Redmine:#23129]
						  - Add moneyline in filter
		- 20141104@Kathy: Change size of username2 to nvarchar(50)
		- 20141125@Kathy: Add betcheck column [Redmine:#26489]
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20151302@Kathy: add modds column 
		- 20150712@Kathy: - Apply 28 Live Bettypes(PH) [Redmine: #48110]
						  - Database - Change datatype [Redmine: #48660]
		- 20150119@Kathy: Changes for phase 1.2 of PH All in One: bettype 4,30,413,414,405 [Redmine:#50932]	  					  
		- 20160112@Patrick: Support Cricket [Redmine: #50688]
		- 20160401@Bobby: #55354 - Update changes for new message structure
		- 20160421@Kathy: Add bettrans.betcheck, hdp1, hdp2 columns to support Combo Parlay [Redmine:#55272]
		- 20160722@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
		- 20160909@Kent: Add logic for bettype 425, 426, 429 - PH AIO [Redmine:#62880]
		- 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
		- 20170216@Kent: Modify logic of time range filter and Union result tables [Redmine:#71037]
		- 20170220@Kent: Add logic of new bettypes in BAIO [Redmine:#71536]
		- 20170224@Kent: Tuning Performance for High CPU [Redmine:#71536]
		- 20170515@Kent: Fix parsing error for param @BetTypes [Redmine:#76576]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20180514@Alan: Return column IsNeutral for neutral match [Redmine: #94308]
		- 20180821@Alan: Incorporate ESports 2.0 [99448]
		- 20190531@Raymond.Le: PH AIO 4 - change filter advanced mode for bettype 479, 481 [112884]
		- 20200723@Zane: Basketball AIO Phase 2 - Change filter advanced mode [137189]
		- 20200925@Charles: HotFix - advance mode can not search all for 226-227 (fast market)[142312]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210303@July: Enhance data type advance mode [Redmine: #150075]
		- 20210426@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20220301@July: Integrate Cricket AIO Phase 2 [Redmine:#168080]

	Param's Explanation:
			@Type:	  0	Dead
					  1	Live
					  2	All

			@BetType: 0	All
					  9	MixParlay
					  29	System parlay

			@BetTypes : 
			'<BetTypes>
				<BetType Id="1" 
						 BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
						 Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
						 Game="01"				-- Default : "All" ; Format : 0X 
						 BetOption="4-4,5-5"	-- Default : "All" ; Format : hdp2-betteam,...					 
						 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ;
						 ValueHdp1="1,2,3"		-- Default : "All" ; Format : 1,2,3,4,... ; 
						 ValueHdp2="1"			-- Default : "All" ; Format : Single Number
						 Goal="2"				-- Default : "All" ; Format : Single Number
						 OddsId ="10006450"		-- Default : "All" ; Format : Single Number
						 Transdesc = '100001'	-- Default : "All" ; Format : Single Number (PlayerId - [Team].[TeamID])
				/>
			 <BetTypes/>'

*/  
BEGIN   
	SET NOCOUNT ON  

	DECLARE @ValueDefault SMALLMONEY = 9999.00

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT,		 				
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		[Value]			SMALLMONEY,
		ValueHdp1		SMALLMONEY,
		ValueHdp2		SMALLMONEY,
		Goal			BIGINT,
		OddsId			INT,
		Transdesc		NVARCHAR(1000)
	)
	
	CREATE TABLE #Bettypes_Parlay (BetType SMALLINT)

	CREATE TABLE #ParlayDelete (
		transid					BIGINT 
        ,ChoiceTransID			BIGINT 
        ,Refno					BIGINT  
        ,UserName				VARCHAR(30)		
        ,CustId					INT  
        ,TransDate				DATETIME  
        ,Creator				VARCHAR(30)
        ,Stake					MONEY  
        ,WinLost				MONEY 
        ,Odds					MONEY 
        ,OddsType				TINYINT  
		,BetType				SMALLINT
        ,Status					NVARCHAR(10)
		,ChoiceStatus			NVARCHAR(10)
        ,spositiontaking		SMALLMONEY  
        ,mpositiontaking		SMALLMONEY  
        ,apositiontaking		SMALLMONEY  
        ,Currency				TINYINT
        ,CurrencyName			VARCHAR(30) 
        ,mrecommend				INT     
		,recommend				INT     
        ,IsDeposit				BIT  
        ,ChoiceBetType			INT  
        ,ChoiceHomeID			INT 
        ,ChoiceAwayID			INT 
        ,ChoiceHdp1				SMALLMONEY
        ,ChoiceHdp2				SMALLMONEY
        ,hdp1					SMALLMONEY
        ,hdp2					SMALLMONEY
        ,ChoiceOdds				MONEY
        ,ChoiceBetTeam			NVARCHAR(20)
		,BetTeam				NVARCHAR(20)
        ,ChoiceLiveHomeScore	SMALLINT
        ,ChoiceLiveAwayScore	SMALLINT
        ,ChoiceLiveIndicator	BIT
        ,ChoiceLeagueId			INT
        ,ChoiceSportType 		SMALLINT
        ,ChoiceIsNeutral 		BIT  
        ,ChoiceMatchId			INT  
        ,ChoiceMatchCode		NVARCHAR(50)  
        ,ChoiceBetCheck			NVARCHAR(50)
        ,betcheck				NVARCHAR(50)
        ,modds					MONEY
        ,transdesc				NVARCHAR(1000)
		,ExtraInfo				VARCHAR(1000)
		,ActualStake			MONEY
        ,OddsId					INT
	   )
                  
	CREATE TABLE #Ref (--id INT identity(1,1) primary key clustered   
      refno				BIGINT   
      ,transid			BIGINT        
      ,Bettype			INT  
      ,hdp1 			SMALLMONEY  
      ,hdp2 			SMALLMONEY  
      ,odds 			MONEY  
      ,betteam			NVARCHAR(20)  
      ,livehomescore 	SMALLINT  
      ,liveawayscore 	SMALLINT  
      ,liveindicator 	BIT        
      ,org_betteam		NVARCHAR(10)       
      ,statusID			INT
	  ,status			VARCHAR(10) 
	  ,betcheck			NVARCHAR(50)
	  ,transdesc		NVARCHAR(1000)
	  ,OddsId			INT
	 ) 

    -- Parse xml @BetTypes
	;WITH CTE_ParsedBettypes_1 AS
	(	
		SELECT t.c.value('@Id','SMALLINT') AS Id
			 , t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			 , t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
			 , t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
			 , t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			 , t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			 , t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1			 ; single-choice + multi-choice
			 , t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2	-- check columns : hdp2	 		 ; single-choice
			 , t.c.value('@Goal','VARCHAR(20)') AS Goal				-- check columns : betID		 ; single-choice
			 , t.c.value('@OddsId','VARCHAR(20)') AS OddsId			-- check columns : OddsId		 ; single-choice
			 , t.c.value('@Transdesc','NVARCHAR(1000)') AS Transdesc	-- check columns : Transdesc	 ; single-choice
		FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	),
	CTE_ParsedBettypes AS
	(
		SELECT cte.Id
			 , bt.val AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , CAST(CASE
						WHEN v.val = 'ALL' THEN @ValueDefault
						ELSE v.val
					END AS SMALLMONEY) AS [Value]	
			, CAST(CASE
						WHEN vhdp1.val = 'ALL' THEN @ValueDefault 
						ELSE vhdp1.val
					END AS SMALLMONEY) AS ValueHdp1

			, CAST(CASE
						WHEN cte.ValueHdp2 = 'ALL' THEN @ValueDefault 
						ELSE cte.ValueHdp2
					END AS SMALLMONEY) AS ValueHdp2

			 , CAST(CASE 
						WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal
					END AS BIGINT) AS Goal
			, CAST(CASE 
						WHEN cte.OddsId = 'ALL' THEN NULL 
						ELSE cte.OddsId
					END AS INT) AS OddsId
			, cte.Transdesc
		FROM CTE_ParsedBettypes_1 cte
			 CROSS APPLY dbo.strSplit(cte.betteam, ',') bt
			 CROSS APPLY dbo.strSplit(cte.[Value], ',') v
			 CROSS APPLY dbo.strSplit(cte.ValueHdp1, ',') vhdp1
	)	 
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, [Value], Goal, ValueHdp1, ValueHdp2, OddsId, Transdesc)
	SELECT cte.Id
		 , CASE
				WHEN cte.Id = 30 AND cte.BetTeam = '4:0up' THEN '4:0' -- replace row [bettype 30 - betteam '4:0up'] by [bettype 30 - betteam '4:0'] 
				WHEN cte.Id = 30 AND cte.BetTeam = '0:4up' THEN '0:4' -- replace row [bettype 30 - betteam '0:4up'] by [bettype 30 - betteam '0:4']
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4&Over' THEN 'G4' -- replace row [bettype 179 - betteam 'G4&Over'] by [bettype 179 - betteam 'G4'] 
				ELSE cte.BetTeam
		   END AS BetTeam
		 , cte.[Set]
		 , cte.Game
		 , cte.[Value]
		 , cte.Goal
		 , cte.ValueHdp1
		 , cte.ValueHdp2
		 , cte.OddsId
		 , cte.Transdesc
	FROM CTE_ParsedBettypes cte	
	WHERE CASE
				WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
				ELSE 1
		  END = 1
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))
	
	IF @BetType = 0
		INSERT INTO #Bettypes_Parlay(BetType)
		VALUES (9), (29)
	ELSE
		INSERT INTO #Bettypes_Parlay(BetType)
		VALUES (@BetType) 
   
	INSERT INTO #Ref (refno, transid, Bettype, hdp1, hdp2, odds, betteam, 
				livehomescore, liveawayscore, liveindicator, org_betteam, statusID, status, betcheck, transdesc, OddsId)  
	SELECT b.refno  
	  ,b.transid  
	  ,b.Bettype     
	  ,b.hdp1  
	  ,CASE WHEN b.bettype = 646 THEN ABS(b.hdp2) ELSE b.hdp2 END AS hdp2 --646: Match Handicap & Total
	  ,b.odds  
	  ,b.betteam  
	  ,b.livehomescore  
	  ,b.liveawayscore  
	  ,b.liveindicator  
	  ,b.betteam    
	  ,b.statusID  
	  ,b.status
	  ,b.betcheck
	  ,b.transdesc
	  ,b.OddsId
	 FROM dbo.bettransm AS b WITH(NOLOCK)		  
	 WHERE	matchid=@MatchID    
			AND CASE WHEN @Type = 2 THEN @Type ELSE b.liveindicator END = @Type
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @Type = 1 THEN @LiveHomeScore ELSE livehomescore END
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @Type = 1 THEN @LiveAwayScore ELSE liveawayscore END
			AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL THEN @FromTransdate ELSE b.transdate END 
								AND	CASE WHEN @ToTransdate IS NOT NULL THEN @ToTransdate ELSE b.transdate END 
		    AND b.statusID NOT IN (101, 102)  -- reject, void
		    AND b.betfrom <> 'p'
		    AND EXISTS (SELECT TOP 1 1
						FROM #tblBetType s
						WHERE b.bettype = s.Id)
	OPTION (maxrecursion 0)		    

	CREATE CLUSTERED INDEX cl_Ref_refno ON #Ref(refno)  
	CREATE NONCLUSTERED INDEX nl_Ref_StatusID ON #Ref(StatusID)  
	CREATE NONCLUSTERED INDEX nl_Ref_bettype_betteam ON #Ref(bettype,org_betteam)	
					 

	/*
		filter for Betteam		

		filter for [Set] (+ [Quarter])
		[Set] : 8xx; 1324 : 8xxyy
		[Quarter] : 80X; 613 : 80XYY
		
		filter for Game : Only handle for bettype 1324
		 
		filter for [Value]
		 
		filter for Goal

		filter for ValueHdp1: for bettype 479, 481

		filter for ValueHdp2

		filter for OddsId (Cricket AIO P2)
	*/			
	BEGIN
	DELETE s
	FROM #Ref s		 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.BetTeam = 'ALL' THEN 1									
								ELSE CASE 
										WHEN s.org_betteam = tp.BetTeam THEN 1
										ELSE 0
									 END 
							END = 1)		
				
	DELETE s
	FROM #Ref s	 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.[Set] = 'ALL' THEN 1							
								ELSE CASE 						  
										WHEN s.betcheck LIKE tp.[Set] + '%' THEN 1
										ELSE 0
									 END
							END = 1) 
					
	DELETE s
	FROM #Ref s	 	
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.Game = 'ALL' THEN 1
								WHEN (tp.Game LIKE '>%' AND RIGHT(s.betcheck, 2) > RIGHT(tp.Game, 2))
									 OR (RIGHT(s.betcheck, 2) = tp.Game)
										THEN 1
								ELSE 0
							END = 1)
					 
	DELETE s
	FROM #Ref s		 		
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.[Value] = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp1 + s.hdp2 = tp.[Value] THEN 1
										ELSE 0
									 END
							END = 1)		  
					
	DELETE s
	FROM #Ref s		 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.Goal = 100 THEN 1
								WHEN ISNULL(s.betcheck, 0) = tp.Goal THEN 1			
								ELSE 0
							END = 1)

	DELETE s
	FROM  #Ref s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND (tp.ValueHdp1 = 9999 OR s.hdp1 = tp.ValueHdp1 )) 

	DELETE s
	FROM  #Ref s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND (tp.ValueHdp2 = 9999 OR s.hdp2 = tp.ValueHdp2 )) 

	/*Apply for bettypes Cricket 2.0 [168080]*/
	DELETE s
	FROM  #Ref s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND (tp.OddsId IS NULL OR s.OddsId = tp.OddsId )) 
	
	DELETE s
	FROM  #Ref s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND  (tp.Transdesc = 'ALL' OR s.transdesc = tp.Transdesc))
	
	END

	INSERT INTO #ParlayDelete  
	SELECT   
	b.transid,  
	r.transid AS ChoiceTransID,  
	r.refno,  
	b.username,	
	b.custid,  
	b.transdate,     
	cr.username as Creator,   
	b.stake, --as StakePositiontaking,  
	b.winlost-b.actual_stake AS WinLost,  
	b.odds,     
	b.OddsType,
	b.bettype,   
	b.status,  
	r.status,
	b.spositiontaking,  
	b.mpositiontaking,  
	b.apositiontaking,      
	b.currency,   
	b.CurrencyName,  
	b.mrecommend,     
	b.recommend,
	CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit
	,r.bettype AS ChoiceBetType  
	,m.homeid  
	,m.awayid  
	,r.hdp1 AS ChoiceHandicap1  
	,r.hdp2 AS ChoiceHandicap2  
   ,b.hdp1
   ,b.hdp2
	,r.odds AS ChoiceOdds  
	,r.betteam  
	,b.betteam
	,r.livehomescore  
	,r.liveawayscore  
	,r.liveindicator  
	,m.leagueid  
	,m.sporttype  
	,m.isNeutral  
	,m.matchID  
	,m.matchCode  
   ,r.betcheck AS ChoiceBetCheck
   ,b.betcheck
	,b.modds
	,r.transdesc
	,b.ExtraInfo
	,b.actual_stake AS ActualStake
	,r.OddsId
	FROM #Bettypes_Parlay t
	INNER JOIN dbo.bettrans AS b with (NOLOCK) ON t.BetType = b.matchid
	INNER JOIN #Ref AS r WITH(NOLOCK) ON b.refno=r.refno
	INNER JOIN dbo.match AS m WITH(NOLOCK) ON m.matchid=@MatchID  
	INNER JOIN custDB.dbo.customer AS cr with (NOLOCK) ON cr.custid = b.creator	
	
	SELECT   T.transid				AS TransId 
			,T.ChoiceTransID		AS SubTransId 
			,T.Refno				AS RefNo 
			,T.UserName				AS UserName  			
			,T.TransDate			AS TransDate 
			,T.Creator				AS Creator 
			,T.Stake				AS Stake 
			,T.WinLost				AS WinLost 
			,T.Odds					AS Odds 			
			,T.BetType				AS BetType 
			,T.Status				AS Status 
			,T.ChoiceStatus			AS SubStatus  			
			,T.CurrencyName			AS CurrencyCode 			
			,T.ChoiceBetType		AS SubBetType 
			,T.ChoiceHomeID			AS SubHomeId  
			,T.ChoiceAwayID			AS SubAwayId    
			,T.ChoiceHdp1			AS SubHdp1 
			,T.ChoiceHdp2			AS SubHdp2 
			,T.hdp1					AS Hdp1 
			,T.hdp2					AS Hdp2 
			,T.ChoiceOdds			AS SubOdds 
			,T.ChoiceBetTeam		AS SubBetTeam 
			,T.BetTeam				AS BetTeam 
			,T.ChoiceLiveHomeScore	AS SubLiveHomeScore  
			,T.ChoiceLiveAwayScore	AS SubLiveAwayScore  
			,T.ChoiceLiveIndicator	AS SubLiveIndicator 
			,T.ChoiceLeagueId		AS SubLeagueId 
			,T.ChoiceSportType 		AS SubSportType 	
			,T.ChoiceIsNeutral		AS IsNeutral		
			,T.ChoiceBetCheck		AS SubBetCheck 
			,T.betcheck				AS BetCheck 
			,T.modds				AS MasterOdds 
			,T.transdesc			AS TransDesc 
			,T.[Group]				AS GroupName
			,T.ExtraInfo
			,T.ActualStake
			,T.OddsId				AS SubOddsId
	FROM
	(	
		--0. For Credit bets  
		SELECT *, [Group]='Credit'   
		FROM #ParlayDelete
		WHERE IsDeposit = 0  
		AND custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
		AND username <> '12EU'  
		AND mrecommend NOT IN (105181, 118473, 105183)  
		AND recommend NOT IN (11196380, 13423967) -- Foobet, 1E
		AND custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102		
		UNION ALL
		--1. For Deposit bets  
		SELECT * ,[Group]='Deposit'  
		FROM #ParlayDelete   
		WHERE IsDeposit = 1  
		AND custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
		AND username <> '12EU'  
		AND mrecommend NOT IN (105181, 118473, 105183) 
		AND recommend NOT IN (11196380, 13423967) -- Foobet, 1E
		AND custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102		 
		UNION ALL
		-- 2: For Betfair 
		SELECT *, [Group] = 'BetFair'
		FROM #ParlayDelete
		WHERE custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102
	) AS T
	ORDER BY CASE
				WHEN T.[Group]='Credit' THEN 0
				WHEN T.[Group]='Deposit' THEN 1
				WHEN T.[Group]='BetFair' THEN 2
				ELSE 3
			 END ASC
		   , T.IsDeposit DESC, T.transid  


	DROP TABLE #ParlayDelete  
	DROP TABLE #Ref  
	DROP TABLE #tblBettype
	DROP TABLE #Bettypes_Parlay	 
	 
	SET NOCOUNT OFF  
END