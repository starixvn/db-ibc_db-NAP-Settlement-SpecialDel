/*
	Created: Helen
	Date: 20200826
	Task: Saba.club - Offer Freebet tickets for 789y market - https://nexdev.net/issues/137942
	DB: DBTRANS/bodb02
	
	Notes:
		  * Loss [50-99]: 1 spin
		  * Loss [100-499]: 2 spins
		  * Loss [500-799]: 3 spins
		  * Loss [800-999]: 4 spins
		  * Loss >= 1000: 5 spins
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
		, @winlostdate = '2020-09-19'
		
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
		,ROUND(SUM (winlost - actual_stake),0) NetWinLoss
	FROM bettrans b WITH (NOLOCK) 
		INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid 
		INNER  JOIN dbo.league l WITH (NOLOCK) ON m.leagueID = l.leagueID 
		INNER JOIN CustDB.dbo.Customer c (NOLOCK) ON b.recommend = c.custid AND c.site = '789y'
	WHERE m.sporttype IN (1,2,50) 
		AND eventstatus = 'completed'
		AND b.statusID IN (111,112,113)
		AND b.bettype < 19999
		AND b.bettype NOT IN (29)
		AND l.LeagueGroupID IN (42,74)
		AND l.isTest = 0
		AND b.currency <> 20
		AND b.winlostdate = @winlostdate
		AND 1 = CASE WHEN m.sporttype = 1 AND l.leaguegroupid in (42, 74) THEN 1
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
		,ROUND(SUM (winlost - actual_stake),0) NetWinLoss
	FROM dbo.bettrans14 b WITH (NOLOCK) 
		INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid 
		INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueID = l.leagueID 
		INNER JOIN CustDB.dbo.Customer c (NOLOCK) ON b.recommend = c.custid AND c.site = '789y'
	WHERE m.sporttype IN (1,2,50) 
		AND eventstatus = 'completed'
		AND b.statusID IN (111,112,113)
		AND b.bettype < 19999
		AND b.bettype NOT IN (29)
		AND l.LeagueGroupID IN (42,74)
		AND l.isTest = 0
		AND b.currency <> 20
		AND b.winlostdate = @winlostdate
		AND 1 = CASE WHEN m.sporttype = 1 AND l.leaguegroupid in (42, 74) THEN 1
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
			WHEN ABS(NetWinLoss) BETWEEN 50 AND 99 THEN 1
			WHEN ABS(NetWinLoss) BETWEEN 100 AND 499 THEN 2
			WHEN ABS(NetWinLoss) BETWEEN 500 AND 799 THEN 3
			WHEN ABS(NetWinLoss) BETWEEN 800 AND 999 THEN 4
			WHEN ABS(NetWinLoss) >= 1000 THEN 5
		END AS FreeSpinCount
		,GETDATE() CreatedDate
		,NULL SentDate
		,NULL ShowBannerEndDate
		,0 StatusId
		,srecommend,mrecommend,recommend
		,NetWinLoss
	FROM #temp_result 
	WHERE NetWinLoss < 0 AND ABS(NetWinLoss) >= 50
END

SELECT * FROM LuckyDraw3rd WITH (NOLOCK)
WHERE RoundID = @RoundID  AND Sporttype = @Sporttype

SELECT @RoundID AS RoundID
--DROP TABLE #temp_result

