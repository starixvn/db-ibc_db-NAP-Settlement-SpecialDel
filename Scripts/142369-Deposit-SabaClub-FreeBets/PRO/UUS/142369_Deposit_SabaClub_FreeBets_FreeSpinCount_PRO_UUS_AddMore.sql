/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Max
	Date: 20201224
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

DECLARE @RoundID INT = 1
		, @Sporttype TINYINT 
		, @winlostdate DATETIME 
		, @IsTicket14 BIT = 0

-- Input param value here
SELECT  @Sporttype = 150

SET @RoundID = ISNULL((SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype
					),0) 

CREATE TABLE #testAccount (username VARCHAR(30),FreeSpinCount INT )			
INSERT INTO #testAccount (username,FreeSpinCount)
VALUES ('11betINH01235836',20),
('FabetINH0141785',20),
('Lucky88INH01401231',20),
('AB88UUS01007',20)

INSERT INTO LuckyDraw3rd (Sporttype, RoundID, CustID, FreeSpinCount, CreatedDate, SentDate, ShowBannerEndDate, StatusId, srecommend, mrecommend, recommend, NetWinLoss)
SELECT @Sporttype Sporttype
	, @RoundID AS RoundID
	,custid
	,s.FreeSpinCount FreeSpinCount
	,GETDATE() CreatedDate
	,NULL SentDate
	,NULL ShowBannerEndDate
	,0 StatusId
	,c.srecommend,c.mrecommend,c.recommend
	,-1000000
FROM #testAccount s 
	INNER JOIN custdb.dbo.Customer c WITH (NOLOCK) ON s.username = c.username

SELECT * FROM LuckyDraw3rd WITH (NOLOCK)
WHERE RoundID = @RoundID  AND Sporttype = @Sporttype

SELECT @RoundID AS RoundID


