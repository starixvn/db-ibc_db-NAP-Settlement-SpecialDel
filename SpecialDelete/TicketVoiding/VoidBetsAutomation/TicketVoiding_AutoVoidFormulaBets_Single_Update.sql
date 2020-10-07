/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidFormulaBets_Single_Update]
(	
	@TransIds			VARCHAR(MAX)
	,@UserName			VARCHAR(30) = NULL
	,@UserId			INT = 0 -- custid of Admin
	,@IP				VARCHAR(15) = ''
	,@IsAbnormalBet		BIT = 1
	,@InvalidTransIds	VARCHAR(MAX)	= ''	OUTPUT -- invalid trans of BTrade
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
		
	Param's explanation:	
		
*/      
BEGIN
	SET NOCOUNT ON	
	
	DECLARE	 @isExistMatch				BIT = 0
			,@isExistMG					BIT = 0
			,@isExistFM					BIT = 0
			--,@isExistParlay				BIT = 0
			--,@IsExistParlayVSBetradar 	BIT = 0
			--,@IsExistVSBetradar 		BIT = 0
			--,@isExistOutright			BIT = 0
			--,@isExistNG					BIT = 0
			,@isExistCashOut			BIT = 0
			,@isExistCricket			BIT = 0
			--,@isExistLC					BIT = 0
			--,@isExistVS					BIT = 0
			,@IsExistBB					BIT = 0
			
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))					
	
	SELECT @InvalidTransIds		= '' 
		, @ErrCode				= 0
		, @ErrMsg				= ''
	
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange
		
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	
	-- Cash-out transaction
	CREATE TABLE #CashOutTransActive (		
		transId				BIGINT PRIMARY KEY,
		matchid				INT,
		bettype				SMALLINT,
		sporttype			SMALLINT,
		OriginalBetType		SMALLINT,
		MainCashoutId		BIGINT,
		matchcode			NVARCHAR(50),
		homeid				INT,
		awayid				INT,
		leagueid			INT,
		isNeutral			BIT,
		showtime			NVARCHAR(50),
		MainTransId			BIGINT,
		refno				BIGINT
	) -- store 911,912,913
	
	DECLARE @tblCustCashOut912 TABLE (custid INT, matchid INT) --store Cash-Out's custid
	
	-- FOR bettrade selling
	CREATE TABLE #CustIdList(custid INT PRIMARY KEY)
	CREATE TABLE #CustList(custid INT PRIMARY KEY,Balance MONEY)
		
	CREATE TABLE #BetDelete_AutoVoidFormula (
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
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)

	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds,',')	
		OPTION (maxrecursion 0)	
		
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
		,CASE
			WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
					THEN b.transid
			ELSE NULL
		 END AS MainCashoutId
		,b.awinlost
		,CAST(0 AS BIT) AS IsBetTrade
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
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransIds t
			ON b.transid = t.transid
	WHERE b.bettype < 19001
		AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND b.bettype NOT BETWEEN 801 AND 806-- MG
		--AND b.bettype NOT IN (901, 902, 903, 904) -- BT subticket
		AND b.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
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
			,MainCashoutId
			,awinlost
			,IsBetTrade
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
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
						THEN b.transid
				ELSE NULL
			 END AS MainCashoutId
			,b.awinlost
			,CASE WHEN b.betdaqid = 0 AND b.extrainfo is null THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsBetTrade
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
	
	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid)
	SELECT transid
	FROM #BetDelete_AutoVoidFormula	
	WHERE betdaqid = 0 
	  AND charindex ('p25',extrainfo)> 0
	
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
		  , @Action = 'Void'
		  , @IsReleased = 0
	
	DELETE bd
	FROM #BetDelete_AutoVoidFormula bd
		 INNER JOIN #tblCashOutProcess rp
				 ON bd.TransId = rp.transid							
					AND rp.IsAvailable = 0	
	
	-- return invalid transId	
	SELECT @InvalidTransIds = @InvalidTransIds + CAST(T.transid AS VARCHAR(20)) + ','
	FROM (
			SELECT transid
			FROM #tblCashOutProcess
			WHERE IsAvailable = 0
		 ) AS T
		
	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete_AutoVoidFormula)
	BEGIN
		IF @InvalidTransIds = ''
 			SELECT	@ErrCode = 99
 					,@ErrMsg = 'No ticket found.' 						
		
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1 				
		
		RETURN
	END
	SELECT 	 @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId <> 1 THEN 1 ELSE 0 END)
			,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			--,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			--,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			--,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			--,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
			--,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistCashOut			= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			--,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
			--,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
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
					AND f.GroupId <> 1
					AND Bettype NOT IN (1231,1232,1233)
				THEN 1 --SB,NG,LC
			WHEN Bettype = 10 THEN 2	-- Outright
			WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
			WHEN f.GroupId = 1 THEN 6 -- FM
			WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
			WHEN Bettype = 38 THEN 5 -- Bet Builder
			ELSE 0
		END AS KeyID
	FROM #BetDelete_AutoVoidFormula b
		OUTER APPLY (
					SELECT GroupId
					FROM f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	EXEC dbo.NAP_Admin_CheckingProcess
		--@isExistParlay 				= @isExistParlay
		--  @isExistOutright 			= @isExistOutright
		  @isExistMG				= @isExistMG
		, @isExistFM				= @isExistFM
		, @isExistMatch				= @isExistMatch
		--, @isExistNG				= @isExistNG
		--, @isExistVS				= @isExistVS
		, @isExistBB				= @isExistBB
		--, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1
		
		RETURN
	END
	
	-- INSERT  Cash-out sub tickets
	IF (@isExistCashOut = 1)
	BEGIN
		-- insert 911
		INSERT INTO #BetDelete_AutoVoidFormula (
				GroupTransId	
				,transid			
				,matchid		
				,Bettype
				,OriginalBetType		
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
				,homeid
				,awayid
				,matchcode
				,eventdate
				,leagueid
				,isNeutral
				,showtime
				,sporttype
				,ExtraInfo	
				,MainCashoutId	
				,awinlost
				,IsHideComm	
				,IsBetTrade
				,modds
				,CurrencyName	
				,WalletType
				,RefCode
				,BonusID
				,MainTransId		
		)
		OUTPUT inserted.transid
			 , inserted.bettype
			 , inserted.matchid
			 , inserted.sporttype
			 , inserted.OriginalBetType
			 , inserted.MainCashoutId
			 , inserted.matchcode
			 , inserted.homeid
			 , inserted.awayid
			 , inserted.leagueid
			 , inserted.isNeutral
			 , inserted.showtime
			 , inserted.MainTransId
			 , inserted.refno
				INTO #CashOutTransActive(transid
									   , bettype
									   , matchid
									   , sporttype
									   , OriginalBetType
									   , MainCashoutId
									   , matchcode
									   , homeid
									   , awayid
									   , leagueid
									   , isNeutral
									   , showtime
									   , MainTransId
									   , refno)
		SELECT	tmpmain.transid
				,sub.transid
				,tmpmain.matchid
				,sub.Bettype
				,tmpmain.Bettype AS OriginalBetType
				,tmpmain.Bettype AS betid
				,sub.stake
				,tmpmain.odds
				,tmpmain.oddsspread
				,sub.refno
				,tmpmain.betfrom
				,sub.statusID
				,sub.betdaqid
				,tmpmain.winlostdate
				,'Cash out' AS status
				,tmpmain.oddstype
				,sub.transdate
				,tmpmain.betteam
				,tmpmain.betcheck
				,tmpmain.hdp1
				,tmpmain.hdp2
				,tmpmain.livehomescore
				,tmpmain.liveawayscore
				,tmpmain.liveindicator
				,sub.winlost - sub.actual_stake
				,sub.playercomm
				,tmpmain.currency
				,tmpmain.transdesc
				,sub.custid
				,sub.creator
				,sub.recommend
				,sub.mrecommend
				,sub.srecommend
				,tmpmain.homeid
				,tmpmain.awayid
				,tmpmain.matchcode
				,tmpmain.eventdate
				,tmpmain.leagueid
				,tmpmain.IsNeutral
				,tmpmain.showtime
				,tmpmain.sporttype
				,sub.ExtraInfo
				,tmpmain.transid AS MainCashoutId
				,sub.awinlost
				,1 AS IsHideComm
				,CAST(0 AS BIT) AS IsBetTrade
				,tmpmain.modds
				,sub.CurrencyName
				,sub.WalletType
				,sub.RefCode
				,sub.BonusID
				,tmpmain.transid AS MainTransId
		FROM dbo.bettrans sub WITH(NOLOCK)
			 INNER JOIN #BetDelete_AutoVoidFormula tmpmain
					 ON	sub.refno = tmpmain.transid
						AND sub.matchid = tmpmain.matchid	
						AND sub.custid = tmpmain.custid						
						AND tmpmain.betdaqid = 0
						AND charindex ('p25',tmpmain.extrainfo)> 0			
						AND sub.bettype = 911								
		WHERE sub.statusID NOT IN (102, 101) -- VOID, REJECT
		
		-- insert cash-out member bet tickets
		INSERT INTO #BetDelete_AutoVoidFormula(
				GroupTransId	
				,transid			
				,matchid		
				,Bettype
				,OriginalBetType		
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
				,oddsid
				,ExtraInfo
				,MainCashoutId
				,IsCashOutMemberTicket
				,awinlost
				,matchcode
				,homeid
				,awayid
				,leagueid
				,sporttype
				,IsNeutral
				,showtime
				,IsHideComm
				,IsBetTrade
				,modds
				,CurrencyName
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
				,sub911.OriginalBetType
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
				,b.winlostdate
				,b.oddsid
				,b.ExtraInfo
				,sub911.MainCashoutId
				,1 AS IsCashOutMemberTicket
				,b.awinlost
				,sub911.matchcode
				,sub911.homeid
				,sub911.awayid
				,sub911.leagueid
				,sub911.sporttype
				,sub911.IsNeutral
				,sub911.showtime
				,1 AS IsHideComm
				,CAST(0 AS BIT) AS IsBetTrade
				,b.modds
				,b.CurrencyName
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,sub911.MainTransId
		FROM #BetDelete_AutoVoidFormula sub911
			 CROSS APPLY (
							  SELECT b.transid
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
									,b.winlost
									,b.actual_stake
									,b.playercomm
									,b.currency
									,b.transdesc
									,b.custid
									,b.creator
									,b.recommend
									,b.mrecommend
									,b.srecommend				
									,b.oddsid
									,b.ExtraInfo
									,b.awinlost
									,b.modds
									,b.CurrencyName
									,b.WalletType
									,b.RefCode
									,b.BonusID
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID NOT IN (102, 101) -- VOID, REJECT
						 ) AS b
		WHERE sub911.bettype = 911		 
		
		--Insert multiple cash-out transaction (912,913)
		INSERT INTO #CashOutTransActive(bettype, transId, matchid, sporttype
									  , MainTransId, refno)
		SELECT sub_912_913.bettype, sub_912_913.transId, sub_912_913.matchid, m.sporttype
			 , sub911.MainTransId
			 , sub_912_913.refno										
		FROM #CashOutTransActive sub911
			INNER JOIN dbo.bettrans sub_912_913 WITH(NOLOCK)					
					ON sub911.transId = sub_912_913.refno						
					   AND sub911.matchid = sub_912_913.matchid					   					
					   AND sub_912_913.bettype IN (912,913)
					   AND sub_912_913.statusID NOT IN (102, 101) -- VOID, REJECT
			INNER JOIN match m (NOLOCK)
					ON sub_912_913.matchid = m.matchid															
			
		--insert custCashOut912	
		INSERT INTO @tblCustCashOut912( custid, matchid )
		SELECT DISTINCT custid, matchid
		FROM #BetDelete_AutoVoidFormula
		WHERE IsCashOutMemberTicket = 1									
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
	FROM dbo.bettrans AS main WITH (NOLOCK)
		INNER JOIN #tblMatch tm 
		ON main.matchid = tm.matchid
		INNER JOIN #BetDelete_AutoVoidFormula AS tmpmain WITH (NOLOCK) 
		ON	main.transid = tmpmain.transid 
		AND main.matchid = tmpmain.matchid		
	WHERE main.bettype NOT IN (901, 902, 903)
	  AND main.bettype NOT IN (911, 912, 913)
	
	--1.3. Backup Cash-out's sub-tickets (911,912,913)
	IF (@isExistCashOut = 1)
	BEGIN
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
		SELECT sub.transid
			,sub.custid
			,CURRENT_TIMESTAMP
			,sub.oddsid
			,sub.hdp1
			,sub.hdp2
			,sub.odds
			,sub.stake
			,sub.STATUS
			,sub.winlost
			,sub.livehomescore
			,sub.liveawayscore
			,sub.liveindicator
			,sub.betteam
			,sub.creator
			,sub.refno
			,sub.winlostdate
			,sub.betfrom
			,@session AS betcheck
			,sub.checktime
			,sub.matchid
			,sub.bettype
		FROM dbo.bettrans AS sub WITH (NOLOCK)
			INNER JOIN #CashOutTransActive bt
			ON sub.matchid 		= bt.matchid			
				AND sub.bettype	= bt.bettype			
				AND sub.transId = bt.transId		
	END
	
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
		-- normal, main bettrade, main cash-out, cash-out member bet ticket
		SELECT tmpmain.custid
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
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
		
		-- sub cash-out (911,912,913)
		SELECT sub.custid
			 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype, sub.matchid, bt.sporttype
		FROM dbo.bettrans sub WITH (NOLOCK)
			INNER JOIN #CashOutTransActive bt 
				ON sub.matchid = bt.matchid
					AND sub.bettype = bt.bettype
					AND sub.transId = bt.transId															
		WHERE @isExistCashOut = 1
					
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
					
				
		UNION ALL
		
		-- cash-out summary 914
		SELECT	sub914.custid
			  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype, sub914.matchid, 1 AS sporttype
		FROM	bettrans sub914 WITH (NOLOCK)
			INNER JOIN @tblCustCashOut912 temp
			ON sub914.custid = temp.custid
				AND sub914.matchid = temp.matchid									
		WHERE sub914.bettype = 914
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
		-- 2.1. Update bettrans	for normal, main bettrade, main cash-out, cash-out member bet ticket
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
			,ExtraInfo = CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN main.ExtraInfo
				ELSE dbo.f_SD_SetExtraInfoAbnormalBet(@IsAbnormalBet,'void',main.ExtraInfo,tmpmain.sporttype,main.bettype) END
		FROM dbo.bettrans AS main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #tblMatch tm ON main.matchid = tm.matchid
			INNER JOIN #BetDelete_AutoVoidFormula AS tmpmain ON	main.transid = tmpmain.transid AND main.matchid = tmpmain.matchid			
		WHERE tmpmain.Bettype NOT BETWEEN 901 AND 903
		  AND tmpmain.Bettype NOT BETWEEN 911 AND 913
		
		-- 2.2 - void MetricGaming
		IF (@isExistMG = 1)
		BEGIN
			UPDATE main
				SET betid = ISNULL(main.BetID, rs.ResultID)
					,actual_stake = tl.actual_stake
					,winlost = tl.actual_stake
					,ruben = 1
					--,statuswinlost = 6
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
		
		-- 2.3 void BetTrade and cash-cout vs subtickets	
		IF (@isExistCashOut = 1)
		BEGIN		
			-- update status for sub cash-out ticket (911,912,913)
			IF (@isExistCashOut = 1)
				UPDATE sub
				SET winlost = sub.actual_stake
					,ruben = 1
					--,statuswinlost = 6
					,creator = @UserID
					,mwinlost = 0
					,swinlost = 0
					,awinlost = 0
					,playercomm = 0
					,comm = 0
					,acomm = 0
					,scomm = 0
					,statusID = 102
					,status = 'VOID'
				FROM dbo.bettrans AS sub WITH (ROWLOCK, UPDLOCK)
					INNER JOIN #CashOutTransActive bt
					ON sub.matchid 		= bt.matchid			
						AND sub.bettype	= bt.bettype			
						AND sub.transId = bt.transId
			
			--Pre-CAL 914
			IF (@isExistCashOut = 1)
			BEGIN
				BEGIN TRY
					DECLARE @TempDataBT1 TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
					INSERT INTO @TempDataBT1(MatchId, CustIds)
					SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
											FROM @tblCustCashOut912 tt 
											where tt.MatchId = t.MatchId
											FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
					FROM @tblCustCashOut912 t
					GROUP BY MatchId
					
					DECLARE @RowIdBT1 INT, @MatchIdTmpBT1 INT, @CustIdsBT1 VARCHAR(MAX)
					SELECT @RowIdBT1 = 1
					WHILE EXISTS (SELECT TOP 1 1 FROM @TempDataBT1 WHERE RowId = @RowIdBT1)
					BEGIN
						SELECT @MatchIdTmpBT1 = MatchId
							, @CustIdsBT1 = CustIds
						FROM @TempDataBT1 t 
						WHERE RowId = @RowIdBT1
						
						EXEC dbo.NAP_Admin_Calculate_914 
							@MatchId 	= @MatchIdTmpBT1
							, @Action 	= 'VOID'
							, @CustIds 	= @CustIdsBT1
							
						SET @RowIdBT1 = @RowIdBT1 + 1
					END
					
				END TRY 
				BEGIN CATCH
					SELECT	@ErrCode = 904
						,@ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
				END CATCH
			END
			
			-- STEP 3 : Update BetTrade selling information
				
			INSERT INTO #CustIdList(custid)
			SELECT DISTINCT custid FROM #BetDelete_AutoVoidFormula
			
			INSERT INTO #CustList(custid, Balance)
			SELECT T.custid, SUM(T.Balance)
			FROM
			(
				SELECT	b.custid, b.winlost - b.actual_stake + b.playercomm AS Balance				
				FROM	dbo.bettrans b WITH(NOLOCK)
					LEFT JOIN dbo.translog tl WITH(NOLOCK)
						ON	b.refno = tl.translogid
							AND b.matchid = tl.eventID				
				WHERE	b.custid IN (SELECT custid FROM #CustIdList)
						AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))									
				UNION ALL 
				SELECT	tl.custid, 0 - tl.actual_stake + 0 AS Balance 
				FROM	dbo.translog tl WITH(NOLOCK)
				WHERE	tl.custid IN (SELECT custid FROM #CustIdList)
						AND tl.statusID IN (0, 1)				
				UNION ALL
				SELECT	custid, winlost - actual_stake + playercomm AS Balance
				FROM	dbo.bettransRnG WITH(NOLOCK)
				WHERE	custid IN (SELECT custid FROM #CustIdList)
						AND IsSum=0				
				UNION ALL
				SELECT	custid, winlost - actual_stake + playercomm AS Balance
				FROM	dbo.bettransLC WITH(NOLOCK)
				WHERE	custid IN (SELECT custid FROM #CustIdList) 
						AND IsSum=0	
				UNION ALL
				SELECT bal.CustId, (Credit - Debit) AS Balance
				FROM dbo.BalNetPosition bal WITH(NOLOCK)
					INNER JOIN #BetDelete_AutoVoidFormula d 
							 ON bal.CustId = d.CustId 
								AND bal.MatchId = d.matchid 
								AND bal.Bettype = d.bettype	
				UNION ALL
				SELECT DISTINCT c.CustId, c.Credit AS Balance
				FROM DBCUST.custDB.dbo.custInfo c WITH(NOLOCK)						
					 INNER JOIN #CustIdList d 
							 ON c.CustId = d.CustId
			) T
			GROUP BY T.custid
			
			;WITH CTE_Source AS
			(
				SELECT	bts.TradeID AS TradeID
						,bts.TicketID AS [TicketID]					
						,'SB void ticket due to ' AS [Remark]
						,tmpsub.awinlost AS [BTBuyBack]
						,0 AS [BTComission]
						,tcust.Balance AS [AfterBalance]
						,'SB' AS [Owner]
						,1 AS [Cancelled]
						,GETDATE() AS [ChangeDate]
						,GETDATE() AS [CreateDate]
				FROM #BetDelete_AutoVoidFormula tmpsub						 											 
					 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
							 ON bts.TicketID = tmpsub.refno -- bettrade + cash-out
								AND CASE																				 
										WHEN tmpsub.bettype = 911 -- cash-out													 
												THEN CASE
														WHEN bts.SoldTicketID = tmpsub.transid THEN 1
														ELSE 0
													 END																							
										ELSE 1
									END = 1	
					 INNER JOIN #CustList tcust
							 ON tmpsub.custid = tcust.custid						 							
				WHERE tmpsub.BetType IN (901,911)			  
			)
			MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
			USING (SELECT * FROM CTE_Source) AS [Source]
			ON [Target].TradeID = [Source].TradeID
			WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
										,[BTBuyBack] = [Source].[BTBuyBack]
										,[BTComission] = [Source].[BTComission]
										,[AfterBalance] = [Source].[AfterBalance]
										,[Owner] = [Source].[Owner]
										,[Cancelled] = [Source].[Cancelled]
										,[ChangeDate] = [Source].[ChangeDate]										
			WHEN NOT MATCHED THEN INSERT(TradeID
										,[TicketID]										
										,[Remark]
										,[BTBuyBack]
										,[BTComission]
										,[AfterBalance]
										,[Owner]
										,[Cancelled]
										,[ChangeDate]
										,[CreateDate])
								  VALUES([Source].TradeID
										,[Source].[TicketID]										
										,[Source].[Remark]
										,[Source].[BTBuyBack]
										,[Source].[BTComission]
										,[Source].[AfterBalance]
										,[Source].[Owner]
										,[Source].[Cancelled]
										,[Source].[ChangeDate]
										,[Source].[CreateDate]); 
				
			
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
			-- normal, main bettrade, main cash-out, cash-out member bet ticket
			SELECT tmpmain.custid
				 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
				 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
				 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
			FROM dbo.bettrans main WITH (NOLOCK)
				INNER JOIN #BetDelete_AutoVoidFormula tmpmain
					ON	main.transid = tmpmain.transid
						AND main.transid = tmpmain.grouptransid
						AND main.matchid = tmpmain.matchid
						
			UNION ALL
			
			-- sub cash-out (911,912,913)		
			SELECT sub.custid
				 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype, sub.matchid,bt.sporttype
			FROM dbo.bettrans sub WITH (NOLOCK)
				INNER JOIN #CashOutTransActive bt 
					ON sub.matchid = bt.matchid
						AND sub.bettype = bt.bettype
						AND sub.transId = bt.transId																
			WHERE @isExistCashOut = 1
			
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
						
			UNION ALL
			
			-- cash-out summary 914
			SELECT	sub914.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype, sub914.matchid, 1 AS sporttype  
			FROM	bettrans sub914 WITH (NOLOCK)
				INNER JOIN @tblCustCashOut912 temp
				ON sub914.custid = temp.custid
					AND sub914.matchid = temp.matchid									
			WHERE sub914.bettype = 914
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
		-- normal, main bettrade, main cash-out, cash-out member bet ticket
		SELECT tmpmain.custid
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
			 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete_AutoVoidFormula tmpmain
				ON	main.transid = tmpmain.transid
					AND main.transid = tmpmain.grouptransid
					AND main.matchid = tmpmain.matchid
					
		UNION ALL
		
		-- sub cash-out (911,912,913)		
		SELECT sub.custid
			 , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			 , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype, sub.matchid,bt.sporttype
		FROM dbo.bettrans sub WITH (NOLOCK)
			INNER JOIN #CashOutTransActive bt 
				ON sub.matchid = bt.matchid
					AND sub.bettype = bt.bettype
					AND sub.transId = bt.transId																
		WHERE @isExistCashOut = 1
		
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
					
		UNION ALL
		
		-- cash-out summary 914
		SELECT	sub914.custid
			  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
			  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
			  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype, sub914.matchid, 1 AS sporttype  
		FROM	bettrans sub914 WITH (NOLOCK)
			INNER JOIN @tblCustCashOut912 temp
			ON sub914.custid = temp.custid
				AND sub914.matchid = temp.matchid									
		WHERE sub914.bettype = 914
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
		--@isExistParlay 				= @isExistParlay
		--, @isExistOutright 			= @isExistOutright
		 @isExistMG				= @isExistMG
		, @isExistFM				= @isExistFM
		, @isExistMatch				= @isExistMatch
		--, @isExistNG				= @isExistNG
		--, @isExistVS				= @isExistVS
		, @isExistBB				= @isExistBB
		--, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
		, @IsReleased				= 1
		
	-------> releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess
			@Mode = 'Original'
		  , @Action = 'Void' 
		  , @IsReleased = 1		

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
	DROP TABLE #CashOutTransActive
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tblCashOutProcess
	DROP TABLE #CustIdList
	DROP TABLE #CustList
END
GO


