/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_UnMarkedTickets_MatchId_Select]
	@MatchId			INT,
	@FromTransId		BIGINT			= 0,
	@ToTransId			BIGINT			= 0,
	
	@Duration			XML				= NULL,
	
	@LiveIndicator		INT				= 0,
	@LiveHomeScore		SMALLINT 		= NULL,
    @LiveAwayScore		SMALLINT 		= NULL,
	@CurrencyIDs		VARCHAR(MAX)	= NULL,
	@LicenseeNames		VARCHAR(MAX)	= NULL,
	@BetTypes			XML				= NULL
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		
	Explanation's Param:
		- @LiveIndicator:
		 + 0: Dead
		 + 1: Live
		 + 2: All

		- @BetTypes: 
		'<BetTypes>
			<BetType Id="1" 
					 BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
					 Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
					 Game="01"				-- Default : "All" ; Format : 0X 
					 BetOption="4-4,5-5"	-- Default : "All" ; Format : hdp2-betteam,...					 
					 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ; Additional handled field : TimeInterval
					 Goal="2"				-- Default : "All" ; Format : Single Number
			/>
		 <BetTypes/>'

		  - @Duration:
		  '<TransDates><TransDate From="2019-03-04 04:11:33.240" To="2019-03-26 04:11:33.240" /></TransDates>'
	    
*/
BEGIN
SET NOCOUNT ON
	DECLARE @SportType TINYINT = NULL
	SELECT @SportType = SportType FROM dbo.match WITH(NOLOCK) WHERE MatchId = @MatchId
	IF @SportType <> 1 RETURN

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(250),
		[Value]			VARCHAR(500),
		Goal			VARCHAR(10)
	)

	CREATE TABLE #tblBetType_Detail
	(
		Id				SMALLINT,
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(50),
		[Value]			SMALLMONEY,	
		TimeInterval	SMALLMONEY,	
		Goal			BIGINT
	)
		
	-- Parse xml @BetTypes
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], Goal)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
			, t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
	FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))
			 
	INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], TimeInterval, Goal)
	SELECT cte.Id
		 , CASE
				WHEN cte.Id = 30 AND cte.BetTeam = '4:0up' THEN '4:0' -- replace row [bettype 30 - betteam '4:0up'] by [bettype 30 - betteam '4:0'] 
				WHEN cte.Id = 30 AND cte.BetTeam = '0:4up' THEN '0:4' -- replace row [bettype 30 - betteam '0:4up'] by [bettype 30 - betteam '0:4']
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4&Over' THEN 'G4' -- replace row [bettype 179 - betteam 'G4&Over'] by [bettype 179 - betteam 'G4'] 
				ELSE cte.BetTeam
		   END AS BetTeam
		 , cte.[Set]
		 , cte.Game
		 , cte.BetOption
		 , CAST(CASE WHEN cte.Id NOT BETWEEN 221 AND 227 THEN cte.[Value] ELSE 9999.00 END AS SMALLMONEY) AS [Value]
		 , CAST(CASE WHEN cte.Id BETWEEN 221 AND 227 THEN cte.[Value] ELSE 9999.00 END AS SMALLMONEY) AS TimeInterval
		 , cte.Goal
	FROM (
		SELECT cte.Id
			 , bt.val AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , bop.val AS BetOption
			 , CAST(CASE WHEN v.val = 'ALL' THEN 9999.00 ELSE v.val END AS SMALLMONEY) AS [Value]
			 , CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 ELSE cte.Goal END AS BIGINT) AS Goal
		FROM #tblBetType cte
			 CROSS APPLY dbo.strSplit(cte.betteam, ',') bt
			 CROSS APPLY dbo.strSplit(cte.BetOption, ',') bop
			 CROSS APPLY dbo.strSplit(cte.[Value], ',') v
	) cte	
	WHERE CASE WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
			WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
			ELSE 1 END = 1

	CREATE TABLE #Durations (FromTransDate DATETIME, ToTransDate DATETIME)
	-- Parse xml @Durations
	INSERT INTO #Durations(FromTransDate, ToTransDate)
	SELECT x.value('@From','DATETIME') AS FromTransDate
		, x.value('@To','DATETIME') AS ToTransDate
	FROM @Duration.nodes('TransDates/TransDate') XmlData(x)
	
	CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
	CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)
	
	CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))

	CREATE TABLE #t_exchanges(exchangeid INT, currency NVARCHAR(50))

	--> Parse @LicenseeNames
	INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
	SELECT ss.val AS LicenseeName, ss.val AS GroupName
	FROM dbo.f_SplitString(@LicenseeNames, ',') ss
	OPTION (maxrecursion 0)		

	DECLARE @MBCGroup_Name VARCHAR(50) = 'MBC Group'
		  , @789y_Name	   VARCHAR(50) = '789y'
		  , @y987_Name	   VARCHAR(50) = 'y987'
		  , @cn88_Name		VARCHAR(50) = 'CN88'

	-- Replace all UI representative groups (MBCGroup and 789y) by their real credit licensees
	DELETE FROM #t_LicenseeNames 
	OUTPUT DELETED.GroupName 
			INTO #t_UIRepresentativeLicenseeGroupNames(GroupName)
	WHERE LicenseeName IN (@MBCGroup_Name, @789y_Name, @cn88_Name)

	IF @@ROWCOUNT > 0
	BEGIN
		;WITH CTE_CreditSit AS
		(
			SELECT [site]
			FROM DBCUST.CUSTDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0 AND isActive = 1
		)
		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM #t_UIRepresentativeLicenseeGroupNames AS t
			 CROSS APPLY (
							SELECT cte.[site]
							FROM CTE_CreditSit cte
							WHERE CASE
								WHEN t.GroupName = @MBCGroup_Name AND cte.[site] NOT IN (@789y_Name, @y987_Name, @cn88_Name) THEN 1
								WHEN t.GroupName = @789y_Name AND cte.[site] IN (@789y_Name, @y987_Name) THEN 1
								WHEN t.GroupName = @cn88_Name AND cte.[site] IN (@cn88_Name) THEN 1 ELSE 0  
								END = 1
						 ) AS cte
	END
	
	--> Parse @CurrencyIDs
	INSERT INTO #t_exchanges(exchangeid, currency)
	SELECT e.exchangeid, e.currency
	FROM dbo.f_SplitString(@CurrencyIDs, ',') ss
		 INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK) ON CAST(ss.val AS INT) = e.exchangeid
	OPTION (maxrecursion 0)	

	CREATE TABLE #Tickets (
		GroupID				BIGINT,
		transid				BIGINT,
		custid				INT,
		UserName			VARCHAR(50),
		oddsspread 			MONEY,
		odds				MONEY, 
		OddsType			INT, 
		transdate			DATETIME,
		bettype				SMALLINT,
		OriginalBetType		SMALLINT,
		betteam				NVARCHAR(10),
		betcheck			NVARCHAR(50),
		hdp1				SMALLMONEY, 
		hdp2				SMALLMONEY,
		IsLiveIndicator		BIT,
		livehomescore 		SMALLINT, 
		liveawayscore 		SMALLINT,
		creator				INT,
		Stake				MONEY,
		CurrencyName		VARCHAR(10),
		IsDeposit			BIT DEFAULT (0),
		IsCricket			BIT DEFAULT (0),
		status				NVARCHAR(10), 
		srecommend			INT,
		mrecommend			INT, 
		recommend			INT, 
		SecAcceptFlag		BIT,
		betid				BIGINT,
		betdaqid			BIGINT,
		TransDesc			NVARCHAR(1000),
		refno				BIGINT,	
		ExtraInfo			VARCHAR(1000),
		MainCashoutId		BIGINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		BonusID				INT,
		MainTransId			BIGINT,
		WinLost				MONEY,
		IsCashOutMemberTicket BIT DEFAULT 0,
		
		FilterBettype		SMALLINT,
		FilterBetTeam		NVARCHAR(10), 
		FilterSet			VARCHAR(50),
		FilterGame			VARCHAR(50),
		FilterValue			SMALLMONEY,	
		FilterGoal			BIGINT,
		FilterBetOption		NVARCHAR(50),
		FilterTimeInterval	SMALLMONEY
	)

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)

	CREATE INDEX IX_Tickets_RefCode ON #Tickets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	-- Search By TransId
	IF @FromTransId > 0 
	BEGIN
		INSERT INTO #Tickets (
			GroupID
			,transid
			,custid	
			,odds
			,oddsspread	
			,OddsType
			,transdate
			,bettype
			,betteam
			,betcheck
			,hdp1
			,hdp2
			,IsLiveIndicator
			,livehomescore 
			,liveawayscore 
			,creator
			,UserName
			,Stake
			,CurrencyName
			,status
			,srecommend
			,mrecommend		
			,recommend
			,SecAcceptFlag
			,betid
			,betdaqid
			,TransDesc
			,refno
			,ExtraInfo
			,MainCashoutId
			,WalletType
			,RefCode
			,BonusID
			,WinLost
			,FilterBettype
			,FilterBetTeam
			,FilterSet
			,FilterGame	
			,FilterValue
			,FilterGoal
			,FilterBetOption
			,FilterTimeInterval
		)
		SELECT
			b.transid,
			b.transid,
			b.custid,
			b.odds,   
			b.oddsspread,
			b.OddsType,  
			b.transdate,
			b.bettype,
			b.betteam,
			b.betcheck,
			b.hdp1,
			b.hdp2,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.creator,
			b.Username,
			b.stake,
			b.CurrencyName, 
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
										   AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status END AS status,
			b.srecommend,
			b.mrecommend,
			b.recommend,
			ISNULL(SecAcceptFlag,0) SecAcceptFlag,
			b.betid,
			b.betdaqid,
			b.transdesc,
			b.refno,
			b.ExtraInfo,
			CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL
			END	AS MainCashoutId,
			b.WalletType,
			b.RefCode,
			b.BonusID,
			b.WinLost - b.actual_stake AS WinLost,
			b.bettype AS FilterBetType,
			b.betteam AS FilterBetTeam,
			b.betid AS FilterSet,
			RIGHT(b.betid, 2) AS FilterGame,
			b.hdp1 + b.hdp2 AS FilterValue,
			ISNULL(b.betid, 0) AS FilterGoal,
			CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
			b.hdp1 AS FilterTimeInterval
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = b.bettype		
			INNER JOIN #t_exchanges te WITH (NOLOCK) ON b.currency = te.exchangeid
			INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
		WHERE
			b.matchid = @MatchId 
			AND b.transid BETWEEN @FromTransId AND @ToTransId
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveIndicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END			
			AND b.statusID IN (0,1 ) -- running, waiting
			AND b.betfrom <> 'p'	
	END
	-- Search By TransDate
	ELSE
	BEGIN
		INSERT INTO #Tickets (
			GroupID
			,transid
			,custid	
			,odds
			,oddsspread	
			,OddsType
			,transdate
			,bettype
			,betteam
			,betcheck
			,hdp1
			,hdp2
			,IsLiveIndicator
			,livehomescore 
			,liveawayscore 
			,creator
			,UserName
			,Stake
			,CurrencyName
			,status
			,srecommend
			,mrecommend
			,recommend
			,SecAcceptFlag
			,betid
			,betdaqid
			,TransDesc
			,refno
			,ExtraInfo
			,MainCashoutId
			,WalletType
			,RefCode
			,BonusID
			,WinLost
			,FilterBettype
			,FilterBetTeam
			,FilterSet
			,FilterGame	
			,FilterValue
			,FilterGoal
			,FilterBetOption
			,FilterTimeInterval
		)
		SELECT
			b.transid,
			b.transid,
			b.custid,
			b.odds,   
			b.oddsspread,
			b.OddsType,  
			b.transdate,
			b.bettype,
			b.betteam,
			b.betcheck,
			b.hdp1,
			b.hdp2,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.creator,
			b.Username,
			b.stake,
			b.CurrencyName, 
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
										   AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status END AS status,
			b.srecommend,
			b.mrecommend,
			b.recommend,
			ISNULL(SecAcceptFlag,0) SecAcceptFlag,
			b.betid,
			b.betdaqid,
			b.transdesc,
			b.refno,
			b.ExtraInfo,
			CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL
			END	AS MainCashoutId,
			b.WalletType,
			b.RefCode,
			b.BonusID,
			b.WinLost - b.actual_stake AS WinLost,
			b.bettype AS FilterBetType,
			b.betteam AS FilterBetTeam,
			b.betid AS FilterSet,
			RIGHT(b.betid, 2) AS FilterGame,
			b.hdp1 + b.hdp2 AS FilterValue,
			ISNULL(b.betid, 0) AS FilterGoal,
			CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
			b.hdp1 AS FilterTimeInterval
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblBetType bt WITH (NOLOCK) ON bt.id = b.bettype
			INNER JOIN #Durations d WITH (NOLOCK) ON b.transdate BETWEEN d.FromTransDate AND d.ToTransDate 
			INNER JOIN #t_exchanges te WITH (NOLOCK) ON b.currency = te.exchangeid
			INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
		WHERE
			b.matchid = @MatchId 
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveIndicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
			AND b.statusID IN (0,1 ) -- running, waiting
			AND b.betfrom <> 'p'	
	END

	-- Filter Advanced Mode
	BEGIN
		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.BetTeam = 'All' OR b.FilterBetTeam = tp.BetTeam ))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%'  ))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.TimeInterval = 9999 OR b.FilterTimeInterval = tp.TimeInterval)) 
	END

	-- delete marked tickets
	DELETE t FROM #Tickets t
	WHERE EXISTS (SELECT TOP 1 1 
				  FROM dbo.MarkedTransaction m WITH(NOLOCK) 
				  WHERE m.TransId = t.transid)

	-- delete cash-out member bet tickets
	DELETE t
	FROM #Tickets t
	WHERE EXISTS (SELECT TOP 1 1
				  FROM bettrans sub911 (NOLOCK)
				  WHERE sub911.bettype = 911 AND sub911.transid = t.refno)

	-- update MainTransId	
	IF EXISTS (SELECT TOP 1 1 FROM #Tickets WHERE RefCode IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #Tickets main
			 INNER JOIN #Tickets sub
					 ON main.RefCode = sub.RefCode
						AND main.transid <> sub.transid	
						AND main.custid = sub.custid
						AND main.bettype = sub.bettype
		WHERE main.WalletType = 1
	  
		-- Insert more bonus or cash ticket in case only one ticket appears in #Tickets	
		INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, transid)
		SELECT	RefCode, custid, bettype, MAX(transid) AS transid
		FROM	#Tickets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype
		HAVING COUNT(*) = 1	
	
		IF @@ROWCOUNT > 0
		BEGIN		
			INSERT INTO #Tickets(
				GroupID
				,transid
				,custid
				,odds
				,oddsspread
				,OddsType
				,transdate
				,bettype
				,betteam
				,betcheck
				,hdp1
				,hdp2
				,IsLiveIndicator
				,livehomescore
				,liveawayscore
				,creator
				,UserName
				,Stake
				,CurrencyName
				,status
				,srecommend
				,mrecommend
				,recommend
				,SecAcceptFlag
				,betid
				,betdaqid
				,refno
				,ExtraInfo
				,MainCashoutId
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
				)
			SELECT  
				b.transid,
				b.transid,
				b.custid,
				b.odds, 
				b.oddsspread,
				b.OddsType,  
				b.transdate,
				b.bettype,
				b.betteam,
				betcheck,
				b.hdp1,
				b.hdp2,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.creator,
				b.Username,
				b.stake,
				b.CurrencyName,
				CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.status END AS status,
				b.srecommend,
				b.mrecommend,
				b.recommend,
				ISNULL(SecAcceptFlag,0) SecAcceptFlag,
				b.betid,
				b.betdaqid,
				b.refno,
				b.ExtraInfo,
				CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
					ELSE NULL END AS MainCashoutId,
				b.WalletType,
				b.RefCode,
				b.BonusID,
				t.transid AS MainTransId,
				b.WinLost - b.actual_stake AS WinLost
			FROM #tmpRefCodeSummary t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)
						 ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = @MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE b.statusID IN (0,1 ) -- running, waiting
		END 		
	END

	IF(EXISTS (SELECT TOP 1 1 
			   FROM #Tickets 
			   WHERE betdaqid = 0 AND charindex ('p25',extrainfo)> 0))
	BEGIN
		-- get sub ticket of Cash-out (911)	
		INSERT INTO #Tickets(
			GroupID
			,bettype
			,OriginalBetType
			,transid
			,betid
			,refno
			,hdp1
			,hdp2
			,odds
			,oddsspread
			,OddsType
			,STATUS	
			,stake
			,transdate
			,betteam
			,betcheck
			,IsLiveIndicator
			,custid
			,livehomescore
			,liveawayscore
			,winlost
			,TransDesc
			,betdaqid
			,username
			,recommend
			,ExtraInfo
			,MainCashoutId
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
		)
		SELECT  sub911.transid
				,sub911.bettype
				,main.bettype AS OriginalBetType
				,sub911.transid
				,main.bettype AS betid
				,sub911.refno
				,main.hdp1
				,main.hdp2
				,main.odds
				,main.oddsspread
				,main.OddsType
				,'Cash out'
				,sub911.stake
				,sub911.transdate
				,main.betteam
				,main.betcheck
				,main.IsLiveIndicator
				,sub911.custid
				,main.livehomescore
				,main.liveawayscore
				,sub911.winlost - sub911.actual_stake
				,main.TransDesc
				,sub911.betdaqid
				,sub911.username
				,sub911.recommend
				,sub911.ExtraInfo
				,main.transid AS MainCashoutId
				,sub911.CurrencyName
				,sub911.WalletType
				,sub911.RefCode
				,sub911.BonusID
				,main.transid AS MainTransId
		FROM #Tickets main
			 INNER JOIN dbo.bettrans sub911 WITH(NOLOCK)
					 ON main.transid = sub911.refno
						AND sub911.matchid = @matchId	
						AND sub911.custid = main.custid	
						AND main.betdaqid = 0
						AND charindex ('p25',main.extrainfo)> 0	
						AND sub911.bettype = 911			 

		-- get cash-out member bet tickets
		INSERT INTO #Tickets (
			GroupID	
			,bettype
			,OriginalBetType
			,transid
			,betid
			,refno
			,hdp1
			,hdp2
			,odds
			,oddsspread	
			,OddsType
			,STATUS
			,stake
			,transdate
			,betteam
			,betcheck
			,IsLiveIndicator
			,custid
			,livehomescore
			,liveawayscore
			,winlost
			,TransDesc
			,betdaqid
			,username
			,recommend
			,ExtraInfo
			,MainCashoutId
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
		)
		SELECT  sub911.transid AS GroupId
				,b.bettype
				,sub911.OriginalBetType
				,b.transid
				,isnull(b.BetID, 0) AS BetID
				,b.refno
				,b.hdp1
				,b.hdp2
				,b.odds
				,b.oddsspread
				,b.OddsType
				,CASE WHEN b.STATUS = 'running'
					AND IsNull(b.SecAcceptFlag, 0) = 1
					AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
				,b.stake
				,b.transdate
				,b.betteam
				,b.betcheck
				,b.liveindicator
				,b.custid
				,b.livehomescore
				,b.liveawayscore
				,(b.winlost - b.actual_stake) winlost
				,b.transdesc
				,b.betdaqid
				,b.username
				,b.recommend
				,b.ExtraInfo
				,sub911.MainCashoutId
				,b.CurrencyName
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,sub911.MainTransId
		FROM #Tickets sub911
			 CROSS APPLY (
							  SELECT b.*
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = @MatchId
								AND b.bettype = sub911.OriginalBetType
					   ) AS b
				LEFT JOIN CustDB.dbo.exchange te WITH(NOLOCK) ON b.currency = te.exchangeid
		WHERE sub911.bettype = 911
	END
	SELECT 
		b.Stake,
		b.BetCheck,
		b.BetId,
		b.BetTeam,
		b.BetType,
		b.OriginalBetType,
		b.CurrencyName,		
		b.Hdp1,
		b.Hdp2,
		b.IsLiveIndicator,
		b.LiveAwayScore,
		b.LiveHomeScore,
		b.Odds,
		b.oddsspread,
		CASE WHEN b.bettype = 501 AND T1.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket,
		b.OddsType,
		b.RefNo,
		b.Status,
		b.TransDate,
		b.TransDesc,
		b.TransId,
		b.UserName,
		b.WinLost,
		tl.GroupName,
		b.betdaqid,
		b.ExtraInfo,
		b.MainCashoutId,
		b.IsCashOutMemberTicket,
		b.WalletType,
		b.MainTransId,
		b.RefCode,
		m.homeid,
		m.awayid,
		m.leagueid,
		m.IsNeutral,
		m.sporttype,
		m.SettlementStatus,
		c.site AS LicenseeName,
		CASE WHEN tl.GroupName IN(@cn88_Name, @789y_Name, @MBCGroup_Name) THEN 0 ELSE 1 END AS IsDeposit
	FROM #Tickets b
		INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
		INNER JOIN #t_LicenseeNames tl WITH (NOLOCK) ON tl.LicenseeName = c.site 
		LEFT JOIN match m WITH (NOLOCK) ON m.matchid = @MatchId
		CROSS APPLY (SELECT CASE
						WHEN EXISTS (SELECT d.custid 
										FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) 
										WHERE d.custid = b.srecommend)
								THEN 1
						ELSE 0
					END AS IsDeposit) AS T1
	ORDER BY CASE
				WHEN tl.GroupName = @cn88_Name THEN 1
				WHEN tl.GroupName = @789y_Name THEN 2
				WHEN tl.GroupName = @MBCGroup_Name THEN 3
				ELSE 4
		     END ASC
		   , tl.GroupName ASC
		   , ISNULL(b.MainTransId, b.transid) ASC
		   , CASE WHEN b.BonusID IS NOT NULL
				THEN CASE WHEN b.MainTransId IS NULL THEN 1
				ELSE 2 END ELSE b.transid END

	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #Durations
	DROP TABLE #Tickets
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #t_exchanges
	DROP TABLE #t_LicenseeNames
	DROP TABLE #t_UIRepresentativeLicenseeGroupNames

SET NOCOUNT OFF
END
GO
GO
