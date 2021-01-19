/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Max
	Date: 20201215
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

SET @RoundID = 1 + ISNULL((SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype
					),0) 

CREATE TABLE #testAccount (username VARCHAR(30),FreeSpinCount INT )			
INSERT INTO #testAccount (username,FreeSpinCount)
VALUES ('Athena000UUS011904379',50),
('Athena000UUS011904380',50),
('Athena000UUS011904381',50),
('Athena000UUS011904382',50),
('Athena000UUS011904383',50),
('Athena000UUS011904384',50),
('Athena000UUS011904385',50),
('Athena000UUS011904386',50),
('Athena000UUS011904387',50),
('Athena000UUS011904388',50),
('Athena000UUS011904389',50),
('Athena000UUS011904390',50),
('Athena000UUS011904391',50),
('Athena000UUS011904392',50),
('Athena000UUS011904393',50),
('Athena000UUS011904394',50),
('Athena000UUS011904395',50),
('Athena000UUS011904396',50),
('Athena000UUS011904397',50),
('Athena000UUS011904398',50),
('Athena000UUS011904399',2),
('Athena000UUS011904400',4),
('Athena000UUS011904401',6),
('Athena000UUS011904402',8),
('Athena000UUS011904403',10),
('Athena000UUS011904404',0),
('Athena000UUS011904405',30),
('Athena000UUS011904406',30),
('Athena000UUS011904407',30),
('Athena000UUS011904408',30),
('Athena000UUS011904517',30),
('Athena000UUS011904518',20),
('Athena000UUS011904519',20),
('Athena000UUS011904520',20),
('Athena000UUS011904521',50),
('Athena000UUS011904369',20),
('Athena000UUS011904254',20),
('Athena000UUS011904260',50),
('Athena000UUS011904261',50),
('Athena000UUS011904268',50)

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


