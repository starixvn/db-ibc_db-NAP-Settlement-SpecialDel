/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidFormulaBets_Single_Update]
(	
	@TransIds			VARCHAR(MAX)
	,@UserId			INT = 0 -- custid of Admin
	,@IP				VARCHAR(15) = ''
	,@IsAbnormalBet		BIT = 1
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(200) = '' OUTPUT
)
AS
/*	Created by: Helen
	Date 20200308
	Task:  Auto Void Settled Tickets of Formula Bet Feature [Redmine:#129971]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200308@Helen: Create new SP [Redmine:#129971]
		- 20200811@Charles: Exclude Saba Promotion - [Redmine: #139255]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's explanation:	
		
*/      
BEGIN
	SET NOCOUNT ON	
	
	DECLARE	 @isExistMatch				BIT = 0
			,@isExistMG					BIT = 0
			,@isExistFM					BIT = 0
			,@isExistCricket			BIT = 0
			,@IsExistBB					BIT = 0
			,@isExistFM2				BIT = 0
			,@RepUpdateTime				DATETIME2

	DECLARE @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))					
	
	SELECT @ErrCode	= 0, @ErrMsg = ''
	
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange
		
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	
	
	CREATE TABLE #BetDelete_AutoVoidFormula (
		GroupTransId	BIGINT -- parent Id (translog.traslogid | bettrans.transid)
		,transid		BIGINT PRIMARY KEY --bettrans.transid
		,matchid		INT
		,Bettype		SMALLINT
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
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,sporttype		SMALLINT
		,IsHideComm		BIT DEFAULT(0)
		,oddsid			INT
		,ExtraInfo		VARCHAR(1000)
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

	CREATE TABLE #tmpRefCodeSummary (
		RefCode		BIGINT
		,custid		INT
		,matchid	INT
		,bettype	SMALLINT
		,transid	BIGINT
	)

	CREATE INDEX IX_BetDelete_RefCode ON #BetDelete_AutoVoidFormula(RefCode)		
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	
	
	CREATE TABLE #tblMatch (matchid INT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@TransIds,',')	
		
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = 'Invalid TransIds.'										
		
		RETURN
	END CATCH		
	
	INSERT INTO #BetDelete_AutoVoidFormula(
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
		,eventdate
		,SiteId
		,CurrencyName			
		,IsMetricGaming
		,modds
	)
	-- MG tickets (running) in translog
	SELECT	tl.translogid AS groupTransId
			,tl.translogid AS transid
			,tl.eventID
			,tl.gameID
			,0 AS betid
			,tl.stake
			,tl.odds
			,0 AS oddsspread
			,tl.translogid AS refno
			,tl.betfrom
			,tl.statusID
			,-1 AS betdaqid -- normal ticket	
			,tl.winlostdate	
			,tl.status	
			,tl.custom1 AS oddstype
			,tl.transdate
			,NULL AS betteam
			,NULL AS betcheck
			,0 hdp1
			,0 hdp2
			,NULL livehomescore
			,NULL liveawayscore
			,0 liveindicator
			,-tl.actual_stake AS winlost
			,0 AS playercomm
			,tl.currency
			,tl.transdesc
			,tl.custid
			,tl.creator
			,tl.recommend
			,tl.mrecommend
			,tl.srecommend
			,tl.winlostdate	
			,tl.SiteId
			,tl.CurrencyName		
			,1 AS IsMetricGaming
			,NULL AS modds
	FROM	dbo.translog tl WITH(NOLOCK)
		INNER JOIN #tblTransIds t
			ON	tl.translogid = t.transid
	WHERE tl.gameID BETWEEN 801 AND 806
		AND tl.statusID = 0					
	
	/* Products & bettype
	-- SB/NG/LC/BT
	-- MG - settled ticket
	-- Parlay vs Outright ticket 
	*/
	INSERT INTO #BetDelete_AutoVoidFormula(
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
		,awinlost
		,SiteId
		,CurrencyName
		,IsMetricGaming
		,modds
		,WalletType
		,RefCode
		,BonusID
	)
	SELECT	
		b.refno AS groupTransId
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
		,-1 AS betdaqid
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
		,0 AS IsHideComm
		,b.winlostdate
		,b.oddsid
		,b.ExtraInfo
		,b.awinlost
		,tl.SiteId
		,b.CurrencyName
		,1 AS IsMetricGaming
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON b.custid 	= tl.custid
			AND b.refno 	= tl.translogid
			AND b.matchid 	= tl.eventid
		INNER JOIN #tblTransIds t
			ON tl.translogid = t.transid
	WHERE tl.gameID BETWEEN 801 AND 806 
		AND b.statusID NOT IN (0, 101, 102)
		
	UNION ALL
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
		,b.awinlost
		,NULL AS SiteId
		,b.CurrencyName
		,0 AS IsMetricGaming
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransIds t
			ON b.transid = t.transid
	WHERE b.bettype < 19001
		AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND b.bettype NOT BETWEEN 801 AND 806-- MG
		AND b.bettype NOT BETWEEN 1501 AND 1599	-- NOT IN Keno
		AND b.statusID NOT IN (101, 102)													
	
	-- Insert more bonus or cash ticket in case only one ticket appears in #BetDelete_AutoVoidFormula	
	INSERT INTO #tmpRefCodeSummary (RefCode, custid, matchid, bettype, transid)
	SELECT RefCode, custid, matchid, bettype, MAX(transid) as transid
	FROM #BetDelete_AutoVoidFormula
	WHERE RefCode IS NOT NULL	
	GROUP BY RefCode, custid, matchid, bettype
	HAVING COUNT(*) = 1	
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #BetDelete_AutoVoidFormula(
			GroupTransId	
			,transid			
			,matchid		
			,Bettype		
			,betid			
			,stake			
			,odds			
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
			,awinlost
			,SiteId
			,IsMetricGaming
			,modds		
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
		)
		SELECT	
			b.transid AS groupTransId
			,b.transid
			,b.matchid
			,b.bettype
			,b.betid
			,b.stake
			,b.odds
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
			,CASE WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1 ELSE 0 END AS IsHideComm
			,b.winlostdate
			,b.oddsid		
			,b.ExtraInfo
			,b.awinlost
			,NULL AS SiteId
			,0 AS IsMetricGaming
			,b.modds		
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,r.transid AS MainTransId
		FROM #tmpRefCodeSummary r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON b.RefCode = r.RefCode
						AND b.transid <> r.transid					
						AND b.custid = r.custid
						AND b.matchid = r.matchid
						AND b.bettype = r.bettype	
		WHERE b.statusID NOT IN (101,102 ) -- reject, void
	END
	
	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #BetDelete_AutoVoidFormula WHERE bettype NOT IN (9, 29, 2799)))
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
		FROM	#BetDelete_AutoVoidFormula b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		
		WHERE bettype NOT IN (9, 29, 2799)
			
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #BetDelete_AutoVoidFormula WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET homeid 		= o.teamid
			,awayid 	= 0
			,matchcode 	= o.matchcode
			,eventdate 	= o.eventdate
			,leagueid 	= l.leagueid
			,IsNeutral  = 0
			,showtime 	= '' 
			,sporttype	= l.sporttype
		FROM	#BetDelete_AutoVoidFormula b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
			
		WHERE bettype IN (10)
	END
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #BetDelete_AutoVoidFormula WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET homeid 		= o.RacerID
			,awayid 	= 0
			,matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
			,eventdate	= o.eventdate
			,leagueid 	= r.leagueid
			,IsNeutral  = 0
			,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
			,sporttype 	= r.sporttype
		
		FROM	#BetDelete_AutoVoidFormula b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END
	
	-- remove un-supported sports & bettype
	DELETE bd
	FROM #BetDelete_AutoVoidFormula bd
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	IF EXISTS(SELECT TOP 1 1 FROM #BetDelete_AutoVoidFormula WHERE Bettype BETWEEN 1101 AND 1199 AND StatusID BETWEEN 0 AND 1)  
	BEGIN  
		DELETE 
		FROM	#BetDelete_AutoVoidFormula 
		WHERE	Bettype BETWEEN 1101 AND 1199 AND StatusID BETWEEN 0 AND 1 -- Not allowed to settle the running Live CS bet   
	END  
	
	-- gather match Ids
	INSERT INTO #tblMatch (matchid)
	SELECT	matchid
	FROM	#BetDelete_AutoVoidFormula
	GROUP BY matchid
	
	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete_AutoVoidFormula)
	BEGIN
 		SELECT	@ErrCode = 99, @ErrMsg = 'No ticket found.' 						
		RETURN
	END
	SELECT 	 @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM	#BetDelete_AutoVoidFormula b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	--- CHECKING SETTLEMENT PROCESS IN PROGRESS OR NOT ?????  
	DECLARE @avaiableProcess BIT
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		, CASE 
			WHEN Bettype NOT IN (9, 29, 2799, 10, 38) 
					AND Bettype NOT BETWEEN 801 AND 899
					AND f.GroupId IS NULL
					AND Bettype NOT IN (1231,1232,1233)
				THEN 1 --SB,NG,LC
			WHEN Bettype = 10 THEN 2	-- Outright
			WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
			WHEN f.GroupId = 1 THEN 6 -- FM
			WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
			WHEN Bettype = 38 THEN 5 -- Bet Builder
			WHEN f.GroupId = 2 THEN 7 -- Fast market 228
			ELSE 0
		END AS KeyID
	FROM #BetDelete_AutoVoidFormula b
		OUTER APPLY (
					SELECT GroupId
					FROM f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMG				= @isExistMG
		, @isExistFM				= @isExistFM
		, @isExistMatch				= @isExistMatch
		, @isExistBB				= @isExistBB
		, @isExistFM2				= @isExistFM2
		, @spName					= @spName
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		RETURN
	END
	
	--Insert ticket of MGSL in translog: 801,803,804,805,806 
	--MetricGaming
	IF(@isExistMG = 1)
	BEGIN	
		 --Update new transid
		UPDATE	tmpmain
		SET	tmpmain.TransID 		= main.TransID
			,tmpmain.grouptransid 	= main.transid
			
		FROM #BetDelete_AutoVoidFormula tmpmain
			INNER JOIN dbo.bettrans main WITH(NOLOCK) 
				ON	main.custid = tmpmain.custid
					AND main.refno = tmpmain.refno 
					AND main.matchid = tmpmain.matchid
		WHERE tmpmain.Bettype BETWEEN 801 AND 806
		
	END	

	-- STEP 1 : BackUp bettrans
	-- 1.1  backup for normal ticket tickets
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
		,main.betcheck
		,main.checktime
		,main.matchid
		,main.bettype
	FROM dbo.bettrans AS main WITH (NOLOCK)
		INNER JOIN #tblMatch tm 
		ON main.matchid = tm.matchid
		INNER JOIN #BetDelete_AutoVoidFormula AS tmpmain WITH (NOLOCK) 
		ON	main.transid = tmpmain.transid 
		AND main.matchid = tmpmain.matchid		
	--capture balance before
	INSERT INTO @BeforeUpd (
		 matchid
		,custid
		,balanceType
		,BonusID
		,WalletType
		,balance
	)
	SELECT matchid
		 , custid
		 , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) AS balance
	FROM
	(
		-- normal ticket
		SELECT tmpmain.custid
			 , main.BonusID
			 , main.WalletType
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete_AutoVoidFormula tmpmain
				ON	main.transid = tmpmain.transid
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = tmpmain.matchid
		WHERE	
			1 = CASE 
				WHEN tmpmain.bettype BETWEEN 801 AND 806 AND tmpmain.statusID = 0 THEN 0 
				ELSE 1 
			END
					
		UNION ALL
		
		SELECT  tmpmain.custid
			  , 0 AS BonusID -- running metric gaming tickets always bet from cash wallet
			  , 2 AS WalletType -- running metric gaming tickets always bet from cash wallet
			  , 0 AS winlost, tl.actual_stake, 0 AS playercomm, tmpmain.Bettype, tmpmain.matchid,tmpmain.sporttype
		FROM	dbo.translog tl WITH(NOLOCK)
			INNER JOIN #BetDelete_AutoVoidFormula tmpmain
				ON	tl.translogid = tmpmain.refno					
		WHERE	tl.statusID = 0
				AND tmpmain.bettype BETWEEN 801 AND 806	
							
		UNION ALL
		
		-- Cricket charge comm
		SELECT b.custid
			 , 0 AS BonusID -- cricket tickets always bet from cash wallet
			 , 2 AS WalletType -- cricket tickets always bet from cash wallet
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype, b.matchid, 50 AS sporttype
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblMatch tm 
				ON b.matchid = tm.matchid
		WHERE b.bettype = 500
			AND EXISTS (
				SELECT TOP 1 1 
				FROM #BetDelete_AutoVoidFormula d 
				WHERE b.custid = d.custid
			)
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		     END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets
	
	-- STEP 2 : Update bettrans/translog
	BEGIN TRY
		-- 2.1. Update bettrans	for normal ticket
		SET @RepUpdateTime = SYSDATETIME()
		UPDATE main
		SET 
			winlost = main.actual_stake
			,ruben = 1
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
			,RepUpdateTime  = @RepUpdateTime
		FROM dbo.bettrans AS main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #tblMatch tm ON main.matchid = tm.matchid
			INNER JOIN #BetDelete_AutoVoidFormula AS tmpmain ON	main.transid = tmpmain.transid AND main.matchid = tmpmain.matchid			
		
		-- 2.2 - void MetricGaming
		IF (@isExistMG = 1)
		BEGIN
			SET @RepUpdateTime = SYSDATETIME()
			UPDATE main
				SET betid = ISNULL(main.BetID, rs.ResultID)
					,actual_stake = tl.actual_stake
					,winlost = tl.actual_stake
					,ruben = 1
					,creator = @UserID
					,awinlost = 0
					,mwinlost = 0
					,swinlost = 0
					,playercomm = 0
					,comm = 0
					,acomm = 0
					,scomm = 0
					,statusID = 102
					,status = 'VOID'
					,RepUpdateTime  = @RepUpdateTime
			FROM dbo.bettrans AS main WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #tblMatch tm 
					ON main.matchid = tm.matchid
				INNER JOIN #BetDelete_AutoVoidFormula AS tmpmain
					ON	main.transid = tmpmain.transid
					AND main.matchid = tmpmain.matchid
				INNER JOIN dbo.translog tl WITH(NOLOCK)
					ON	main.refno = tl.translogid
				OUTER APPLY (
					SELECT rs.ResultID 
					FROM DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK) 
					WHERE (
							(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, main.transdesc,0) <> 0)
							OR
							main.bettype = 806
						)
						AND rs.GameID = main.bettype	
						AND rs.VendorID = 5		
						AND rs.MatchID = main.matchid	
				) AS rs
			WHERE tmpmain.Bettype BETWEEN 801 AND 806
				
			-- 2.2. Update back to translog
			UPDATE tl
			SET
				tl.Status 		= 'VOID'
				,tl.StatusID 	= 102
				,tl.creator 	= @UserID
				,tl.custom3 	= ISNULL(tl.custom3, b.betid)
			FROM dbo.translog tl WITH(ROWLOCK,UPDLOCK)
				INNER JOIN #BetDelete_AutoVoidFormula main
				ON tl.translogid 	= main.refno
					AND tl.custid 	= main.custid
					AND tl.eventid 	= main.matchid
				INNER JOIN dbo.bettrans b (NOLOCK)
				ON b.transId 		= main.transId
				
			WHERE main.bettype BETWEEN 801 AND 806
		END		
		
		--re-calculate Cricket - charge comm
		IF(@isExistCricket = 1)
		BEGIN
			DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
			
			BEGIN TRY
				INSERT INTO @TempData(MatchId, CustIds)
				SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
										FROM #BetDelete_AutoVoidFormula tt where tt.MatchId = t.MatchId
										FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
				FROM #BetDelete_AutoVoidFormula t
				WHERE Bettype = 501
				GROUP BY MatchId

				IF EXISTS (SELECT TOP 1 1 FROM @TempData)
				BEGIN
					DECLARE @RowId INT, @MatchIdTmp INT, @CustIds VARCHAR(MAX)
					SELECT @RowId = 1
					WHILE EXISTS (SELECT TOP 1 1 FROM @TempData WHERE RowId = @RowId)
					BEGIN
						SELECT @MatchIdTmp = MatchId
							, @CustIds = CustIds
						FROM @TempData t WHERE RowId = @RowId
						SET @RowId = @RowId + 1
						
						EXEC dbo.NAP_Admin_Calculate_500 @MatchId	= @MatchIdTmp
							, @Action = 'VOID'
							, @CustIds = @CustIds
					END
				END
			END TRY 
			BEGIN CATCH
				SELECT	@ErrCode = 500
					,@ErrMsg = 'Called NAP_Admin_Calculate_500 with error.'
			END CATCH
		END
	END TRY
	BEGIN CATCH
		-- Capture Balance incase of failure
		INSERT INTO @AfterUpd (
			 matchid
			,custid
			,balanceType
			,BonusID
			,WalletType
			,balance
		)
		SELECT matchid	
			 , custid
			 , CASE 
					WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN tmp.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
			   END AS balanceType
			 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
			 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) balance
		FROM
		(
			-- normal ticket
			SELECT tmpmain.custid
				 , main.BonusID
				 , main.WalletType
				 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
			FROM dbo.bettrans main WITH (NOLOCK)
				INNER JOIN #BetDelete_AutoVoidFormula tmpmain
					ON	main.transid = tmpmain.transid
						AND main.transid = tmpmain.grouptransid
						AND main.matchid = tmpmain.matchid
			
			UNION ALL
			
			-- Cricket charge comm
			SELECT b.custid
				 , 0 AS BonusID -- cricket tickets always bet from cash wallet
				 , 2 AS WalletType -- cricket tickets always bet from cash wallet
				 , b.winlost, b.actual_stake, b.playercomm, b.bettype, b.matchid, 50 AS sporttype
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #tblMatch tm 
					ON b.matchid = tm.matchid
			WHERE b.bettype = 500
				AND EXISTS (
					SELECT TOP 1 1 
					FROM #BetDelete_AutoVoidFormula d 
					WHERE b.custid = d.custid
				)
		) tmp
		GROUP BY matchid
			   , CustID
			   , CASE 
					WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN tmp.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				 END
			   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
			   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets
		
		---INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			  @BalanceWalletBefore	= @BeforeUpd
			, @BalanceWalletAfter	= @AfterUpd
			, @ActionId				= 0	
		
		RETURN
		
	END CATCH
	--capture balance after
	INSERT INTO @AfterUpd (
			 matchid
			,custid
			,balanceType
			,BonusID
			,WalletType
			,balance
		)
	SELECT matchid	
		 , custid
		 , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		   END AS balanceType
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) balance
	FROM
	(
		-- normal ticket
		SELECT tmpmain.custid
			 , main.BonusID
			 , main.WalletType
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete_AutoVoidFormula tmpmain
				ON	main.transid = tmpmain.transid
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = tmpmain.matchid
		
		UNION ALL
		
		-- Cricket charge comm
		SELECT b.custid
			 , 0 AS BonusID -- cricket tickets always bet from cash wallet
			 , 2 AS WalletType -- cricket tickets always bet from cash wallet
			 , b.winlost, b.actual_stake, b.playercomm, b.bettype, b.matchid, 50 AS sporttype
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblMatch tm 
				ON b.matchid = tm.matchid
		WHERE b.bettype = 500
			AND EXISTS (
				SELECT TOP 1 1 
				FROM #BetDelete_AutoVoidFormula d 
				WHERE b.custid = d.custid
			)
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
			 END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets
	
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @BeforeUpd
		, @BalanceWalletAfter	= @AfterUpd
		, @ActionId				= 0
	
	------ releasing SD process
	--CleanUP:
	EXEC dbo.NAP_Admin_CheckingProcess
		 @isExistMG					= @isExistMG
		, @isExistFM				= @isExistFM
		, @isExistMatch				= @isExistMatch
		, @isExistBB				= @isExistBB
		, @isExistFM2				= @isExistFM2
		, @IsReleased				= 1
		
	-- Insert reason
	DECLARE @ReasonId INT = 0 
	INSERT INTO dbo.TicketVoiding_Reason (ReasonEnglish, ReasonChineseSimplified)
	SELECT 'Abnormal bet',N'由于非正常投注'
	
	SET @ReasonId = SCOPE_IDENTITY()
	
	-- Insert Void transaction
	INSERT INTO dbo.TicketVoiding_VoidedTransaction (
		TransId
		,MessageId
		,ReasonId
		,MatchId
		,IssueTypeId
		,SubIssueTypeId
		,CustID
		)
	SELECT CASE WHEN b.Bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END transid
		, 0 AS MessageId
		,@ReasonId
		,0
		,11
		,38
		,b.CustId
	FROM #BetDelete_AutoVoidFormula AS b
		
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblTransIds
	DROP TABLE #BetDelete_AutoVoidFormula
	DROP TABLE #tblMatch
	DROP TABLE #tmpRefCodeSummary
END
GO


