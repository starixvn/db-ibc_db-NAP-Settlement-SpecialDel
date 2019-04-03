/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_UnMarkedTickets_BetIds_Select]
	@TransIds				VARCHAR(MAX)	= NULL,
	@InvalidTransIds		VARCHAR(MAX)	= '' OUTPUT,
	@MovedTransIds			VARCHAR(MAX)	= '' OUTPUT,
	@MarkedTransIds			VARCHAR(MAX)	= '' OUTPUT
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		
	Explanation's Param:
*/
BEGIN
SET NOCOUNT ON
	CREATE TABLE #Tickets (
		GroupID				BIGINT,
		transid				BIGINT,
		custid				INT,
		username			VARCHAR(30),
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
		matchid				INT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		BonusID				INT,
		MainTransId			BIGINT,
		WinLost				MONEY,
		IsCashOutMemberTicket BIT DEFAULT 0,
		SportType			TINYINT,
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		IsNeutral			BIT,
		SettlementStatus	TINYINT,
		ShowTime			NVARCHAR(50),
		MatchCode			NVARCHAR(50)
	)

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,matchid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)
	CREATE INDEX IX_Data_RefCode ON #Tickets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT val 
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (maxrecursion 0)

	INSERT INTO #Tickets (
			GroupID
			,bettype
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
			,matchid
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
		)
		SELECT
			b.transid AS GroupId
			,b.bettype
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
			,b.matchid
			,(b.winlost - b.actual_stake) winlost
			,b.transdesc
			,b.betdaqid
			,b.username
			,b.recommend
			,b.ExtraInfo
			,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #transIdTemp temp ON b.transid = temp.transid
		WHERE	b.bettype < 19001
			AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
			AND b.bettype NOT BETWEEN 801 AND 806		-- MG
			AND b.bettype NOT IN (901, 902, 903, 904)	-- BT subticket
			AND b.bettype NOT IN (911, 912, 913, 914)	-- Cash-out subticket
			AND b.bettype NOT BETWEEN 1501 AND 1599		-- NOT IN Keno
			AND b.bettype NOT IN (10, 9, 29, 2799, 38, 500)			-- Outright, Mix Parlay, BetBuilder
			AND b.statusID IN (0, 1)
			AND b.betfrom <> 'p'

	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #Tickets WHERE refno IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #Tickets main
			 INNER JOIN #Tickets sub
					 ON main.RefCode = sub.RefCode	
						AND main.transid <> sub.transid					
						AND main.custid = sub.custid
						AND main.matchid = sub.matchid
						AND main.bettype = sub.bettype											
		WHERE main.WalletType = 1			
	  
		-- Insert more bonus or cash ticket in case only one ticket appears in #Tickets	
		INSERT INTO #tmpRefCodeSummary (RefCode, custid, matchid, bettype, transid)
		SELECT RefCode, custid, matchid, bettype, MAX(transid) AS transid
		FROM #Tickets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, matchid, bettype
		HAVING COUNT(*) = 1
		
		IF @@ROWCOUNT > 0
		BEGIN
			INSERT INTO #Tickets (
					GroupID
					,bettype
					,transid
					,betid
					,refno
					,hdp1
					,hdp2
					,odds
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
					,matchid
					,winlost
					,TransDesc
					,betdaqid
					,username
					,recommend
					,ExtraInfo
					,MainCashoutId
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
				)
				SELECT	
					b.refno AS GroupId
					,b.bettype
					,b.transid
					,isnull(b.BetID, 0) AS BetID
					,b.refno			
					,b.hdp1
					,b.hdp2
					,b.odds
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
					,b.matchid
					,(b.winlost - b.actual_stake) winlost
					,b.transdesc
					,b.betdaqid
					,b.username
					,b.recommend
					,b.ExtraInfo
					,CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid ELSE NULL END AS MainCashoutId
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,t.transid AS MainTransId	
			FROM #tmpRefCodeSummary t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)
						 ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.custid = t.custid
							AND b.matchid = t.matchid
							AND b.bettype = t.bettype
			WHERE b.statusID IN (0, 1)
		END
	END

	IF(EXISTS(SELECT TOP 1 1 FROM #Tickets WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
		FROM #Tickets d
			INNER JOIN dbo.match m WITH (NOLOCK) ON	d.matchid = m.matchid
	END

	-- delete marked tickets
	DELETE t FROM #Tickets t
	WHERE EXISTS (SELECT TOP 1 1 
				  FROM dbo.MarkedTransaction m WITH(NOLOCK) 
				  WHERE m.TransId = t.transid)

	-- delete cash-out member bet tickets
	DELETE t FROM #Tickets t
	WHERE EXISTS (SELECT TOP 1 1
				  FROM bettrans sub911 (NOLOCK)
				  WHERE sub911.bettype = 911 AND sub911.transid = t.refno)	

	--- Remove invalid sporttype	
	DELETE 
	FROM #Tickets
	WHERE (sporttype IS NULL OR bettype = 500 /*charge comm*/)

	-- get sub ticket of Cash-out (911) and cash-out member bet tickets
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
			,matchid
			,winlost
			,TransDesc
			,betdaqid
			,username
			,recommend
			,matchcode
			,homeid
			,awayid
			,leagueid
			,sporttype
			,IsNeutral
			,showtime
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
				,main.matchid
				,sub911.winlost - sub911.actual_stake
				,main.TransDesc
				,sub911.betdaqid
				,sub911.username
				,sub911.recommend
				,main.matchcode
				,main.homeid
				,main.awayid
				,main.leagueid
				,main.sporttype
				,main.IsNeutral
				,main.showtime
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
						AND sub911.matchid = main.matchid	
						AND sub911.custid = main.custid	
						AND main.betdaqid = 0
						AND charindex ('p25',main.extrainfo)> 0	
						AND sub911.bettype = 911			 
		WHERE sub911.statusID IN (0, 1) 

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
			,matchid
			,winlost
			,TransDesc
			,betdaqid
			,username
			,recommend
			,ExtraInfo
			,MainCashoutId
			,IsCashOutMemberTicket
			,homeid
			,awayid
			,leagueid
			,sporttype
			,IsNeutral
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
				,b.matchid
				,(b.winlost - b.actual_stake) winlost
				,b.transdesc
				,b.betdaqid
				,b.username
				,b.recommend
				,b.ExtraInfo
				,1 AS IsCashOutMemberTicket
				,sub911.MainCashoutId
				,sub911.homeid
				,sub911.awayid
				,sub911.leagueid
				,sub911.sporttype
				,sub911.IsNeutral
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
								AND b.matchid = sub911.matchid
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID IN (0, 1) 
						 ) AS b
		WHERE sub911.bettype = 911
	END

	-- Group Name By Licensee
	BEGIN
		DECLARE @MBCGroup_Name VARCHAR(50) = 'MBC Group'
			  , @789y_Name	   VARCHAR(50) = '789y'
			  , @y987_Name	   VARCHAR(50) = 'y987'
			  , @cn88_Name		VARCHAR(50) = 'CN88'
		CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
		CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)
		CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))

		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT	s.site AS LicenseeName,  s.site AS GroupName 
		FROM	DBCUST.CUSTDB.dbo.site s WITH(NOLOCK)
		WHERE	s.isLicensee = 1 AND s.isActive =1 AND s.siteID NOT IN (29,35)

		INSERT INTO #t_UIRepresentativeLicenseeGroupNames(GroupName)
		VALUES (@MBCGroup_Name), (@789y_Name), (@cn88_Name)

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
		b.IsCashOutMemberTicket,
		b.MainCashoutId,
		b.WalletType,			
		b.MainTransId,		
		b.RefCode,
		m.homeid,
		m.awayid,
		m.leagueid,
		m.IsNeutral,
		m.sporttype,
		m.SettlementStatus
	FROM #Tickets b
		INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
		INNER JOIN #t_LicenseeNames tl WITH (NOLOCK) ON tl.LicenseeName = c.site 
		LEFT JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
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

	-- invalid trans
	SELECT @InvalidTransIds = '', @MovedTransIds = '', @MarkedTransIds = ''
	;WITH t_invalid AS
	(
		SELECT	transid
				,ISNULL(bm.isMoved, CAST(0 AS BIT)) AS isMoved
				,ISNULL(m.isMarked, CAST(0 AS BIT)) AS isMarked
		FROM #transIdTemp temp
			OUTER APPLY (
				SELECT TOP 1 CAST(1 AS BIT) AS isMoved
				FROM dbo.bettrans14 WITH(NOLOCK) 
				WHERE transid = temp.transid
			) bm
			OUTER APPLY (
				SELECT TOP 1 CAST(1 AS BIT) AS isMarked
				FROM dbo.MarkedTransaction WITH(NOLOCK) 
				WHERE transid = temp.transid
			) m
		WHERE NOT EXISTS (SELECT 1 FROM #Tickets WHERE transid = temp.transid OR refno = temp.transid)
	)
	SELECT @InvalidTransIds = @InvalidTransIds + CASE WHEN isMoved = 0 AND isMarked = 0
							  THEN CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + CAST(transid AS VARCHAR(100))
							  ELSE '' END
		 , @MovedTransIds = @MovedTransIds + CASE WHEN isMoved = 1
							THEN CASE WHEN @MovedTransIds <> '' THEN ',' ELSE '' END + CAST(transid AS VARCHAR(100))
							ELSE '' END
		 , @MarkedTransIds = @MarkedTransIds + CASE WHEN isMarked = 1
							THEN CASE WHEN @MarkedTransIds <> '' THEN ',' ELSE '' END + CAST(transid AS VARCHAR(100))
							ELSE '' END
		FROM t_invalid

	DROP TABLE #Tickets
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #transIdTemp
	DROP TABLE #t_LicenseeNames
	DROP TABLE #t_UIRepresentativeLicenseeGroupNames

SET NOCOUNT OFF
END
GO
GO
