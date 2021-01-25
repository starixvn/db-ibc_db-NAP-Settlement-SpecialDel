/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Max
	Date: 20201118
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
VALUES ('Athena000UUS011903775',50),
('Athena000UUS011903776',50),
('Athena000UUS011903777',50),
('Athena000UUS011903779',50),
('Athena000UUS011903780',50),
('Athena000UUS011903778',50),
('Athena000UUS011903781',50),
('Athena000UUS011903782',50),
('Athena000UUS011903783',50),
('Athena000UUS011903784',50),
('Athena000UUS011903785',50),
('Athena000UUS011903786',50),
('Athena000UUS011903787',50),
('Athena000UUS011903788',50),
('Athena000UUS011903789',50),
('Athena000UUS011903790',50),
('Athena000UUS011903791',50),
('Athena000UUS011903792',50),
('Athena000UUS011903793',50),
('Athena000UUS011903794',50),
('Athena000INH01025',2),
('Athena000INH01024',4),
('Athena000INH01023',6),
('Athena000INH01022',8),
('Athena000INH01021',10),
('Athena000INH01020',0),
('Athena000INH01019',30),
('Athena000INH01018',30),
('Athena000INH01017',30),
('Athena000INH01016',30),
('Athena000INH01015',30),
('Athena000INH01014',20),
('Athena000INH01013',20),
('Athena000INH01012',20),
('Athena000UUS011903840',50),
('Athena000UUS011903839',20),
('Athena000UUS011903838',20),
('Athena000UUS011903837',50),
('Athena000UUS011903836',50)

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


