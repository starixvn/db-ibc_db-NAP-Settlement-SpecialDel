/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Max
	Date: 20201119
	Task: Deposit - Saba.Club - Free Bets [Redmine: #142369]
	DB: DBTRANS/bodb02
	
	Notes:
		  * Loss [500-1000]: 2 spins  (500 <= Loss < 1000)
		  * Loss [1000-5000]: 4 spins  (1000 <= Loss < 5000)
		  * Loss [5000-8000]: 6 spins  (5000 <= Loss < 8000)
		  * Loss [8000-10,000]: 8 spins  (8000 <= Loss < 10,000)
		  * Loss > 10,000: 10 spins  (10,000 <= Loss < ∞)
		  + Saba Soccer : sporttype = 1 and [league].leaguegroupid in (42, 74)
		  + Saba Basketball: sporttype = 2 and [league].leaguegroupid in (42)
		  + Saba Cricket: sporttype = 50 and [league].leaguegroupid in (42)

*/
USE bodb02
GO

DECLARE @RoundID INT 
		, @Sporttype TINYINT 
		, @winlostdate DATETIME 
		, @IsTicket14 BIT = 0

-- Input param value here
SELECT  @Sporttype = 150
		, @winlostdate = '2021-03-06'
		
CREATE TABLE #temp_result (CustID INT, srecommend INT, mrecommend INT,recommend INT, NetWinLoss MONEY)
		
SET @RoundID = 1 + ISNULL((SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype
					),0) 
				
IF EXISTS (SELECT TOP 1 1 FROM dbo.match14 WITH (NOLOCK) WHERE eventdate = @winlostdate)
	SET @IsTicket14 = 1	

SELECT @IsTicket14 AS IsTicket14

IF @IsTicket14 = 0
BEGIN
	INSERT INTO #temp_result (CustID, srecommend, mrecommend, recommend, NetWinLoss)
	SELECT b.custid
		,b.srecommend,b.mrecommend,b.recommend
		,SUM (winlost - actual_stake) NetWinLoss
	FROM bettrans b WITH (NOLOCK) 
		INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid 
		INNER  JOIN dbo.league l WITH (NOLOCK) ON m.leagueID = l.leagueID 
		INNER JOIN CustDB.dbo.Customer c (NOLOCK) ON b.recommend = c.custid AND c.site IN ('11Bet','12Bet','Fabet','Five88','Lucky88','One88','zbet','Sunwin','Debet','Red88','Zowin','SV88','Nbet','OXbet','Sky88','Mansion88')
		INNER JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK) ON s.custid = b.srecommend
	WHERE m.sporttype IN (1,2,50) 
		AND eventstatus = 'completed'
		AND b.statusID IN (111,112,113)
		AND b.bettype < 19999
		AND b.bettype NOT IN (29)
		AND l.LeagueGroupID IN (42,74,108)
		AND l.isTest = 0
		AND b.currency = 51
		AND b.winlostdate = @winlostdate
		AND 1 = CASE WHEN m.sporttype = 1 AND l.leaguegroupid in (42, 74, 108) THEN 1
					 WHEN m.sporttype = 2 AND l.leaguegroupid = 42 THEN 1
					 WHEN m.sporttype = 50 AND l.leaguegroupid = 42 THEN 1
					 ELSE 0
				END	 
	GROUP BY b.custid,b.srecommend,b.mrecommend,b.recommend				
					 
END
ELSE
BEGIN
	INSERT INTO #temp_result (CustID, srecommend, mrecommend, recommend, NetWinLoss)
	SELECT b.custid
		,b.srecommend,b.mrecommend,b.recommend
		,SUM (winlost - actual_stake) NetWinLoss
	FROM dbo.bettrans14 b WITH (NOLOCK) 
		INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid 
		INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueID = l.leagueID 
		INNER JOIN CustDB.dbo.Customer c (NOLOCK) ON b.recommend = c.custid AND c.site IN ('11Bet','12Bet','Fabet','Five88','Lucky88','One88','zbet','Sunwin','Debet','Red88','Zowin','SV88','Nbet','OXbet','Sky88','Mansion88')
		INNER JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK) ON s.custid = b.srecommend
	WHERE m.sporttype IN (1,2,50) 
		AND eventstatus = 'completed'
		AND b.statusID IN (111,112,113)
		AND b.bettype < 19999
		AND b.bettype NOT IN (29)
		AND l.LeagueGroupID IN (42,74,108)
		AND l.isTest = 0
		AND b.currency = 51
		AND b.winlostdate = @winlostdate
		AND 1 = CASE WHEN m.sporttype = 1 AND l.leaguegroupid in (42, 74, 108) THEN 1
					 WHEN m.sporttype = 2 AND l.leaguegroupid = 42 THEN 1
					 WHEN m.sporttype = 50 AND l.leaguegroupid = 42 THEN 1
					 ELSE 0
				END	 
	GROUP BY b.custid,b.srecommend,b.mrecommend,b.recommend				
END

IF EXISTS (SELECT TOP (1) 1 FROM #temp_result WHERE NetWinLoss < 0 )
BEGIN				
	INSERT INTO LuckyDraw3rd (Sporttype, RoundID, CustID, FreeSpinCount, CreatedDate, SentDate, ShowBannerEndDate, StatusId, srecommend, mrecommend, recommend, NetWinLoss)
	SELECT @Sporttype Sporttype
		, @RoundID AS RoundID
		,custid
		,CASE 
			WHEN ABS(NetWinLoss) >= 500 AND ABS(NetWinLoss) < 1000 THEN 2
			WHEN ABS(NetWinLoss) >= 1000 AND ABS(NetWinLoss) < 5000 THEN 4
			WHEN ABS(NetWinLoss) >= 5000 AND ABS(NetWinLoss) < 8000 THEN 6
			WHEN ABS(NetWinLoss) >= 8000 AND ABS(NetWinLoss) < 10000 THEN 8
			WHEN ABS(NetWinLoss) >= 10000 THEN 10
		END AS FreeSpinCount
		,GETDATE() CreatedDate
		,NULL SentDate
		,NULL ShowBannerEndDate
		,0 StatusId
		,srecommend,mrecommend,recommend
		,NetWinLoss
	FROM #temp_result 
	WHERE NetWinLoss < 0 AND ABS(NetWinLoss) >= 500
END

SELECT * FROM LuckyDraw3rd WITH (NOLOCK)
WHERE RoundID = @RoundID  AND Sporttype = @Sporttype

SELECT @RoundID AS RoundID
--DROP TABLE #temp_result

