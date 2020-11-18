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
VALUES ('SIT_test_INH_001',2),
('SIT_test_INH_002',4),
('SIT_test_INH_003',6),
('SIT_test_INH_004',8),
('SIT_test_INH_005',10),
('SIT_test_INH_006',0),
('VNTestSabaClub01',50),
('VNTestSabaClub02',50),
('VNTestSabaClub03',50),
('VNTestSabaClub04',50),
('VNTestSabaClub05',50),
('VNTestSabaClub06',50),
('VNTestSabaClub07',50),
('VNTestSabaClub08',50),
('VNTestSabaClub09',50),
('VNTestSabaClub10',50),
('VNTestSabaClub11',50),
('VNTestSabaClub12',50),
('VNTestSabaClub13',50),
('VNTestSabaClub14',50),
('VNTestSabaClub15',50),
('VNTestSabaClub16',50),
('VNTestSabaClub17',50),
('VNTestSabaClub18',50),
('VNTestSabaClub19',50),
('VNTestSabaClub20',50),
('SIT_test_INH_001',50),
('SIT_test_INH_002',30),
('SIT_test_INH_003',30),
('SIT_test_INH_004',30),
('SIT_test_INH_005',30),
('SIT_test_INH_006',30),
('SIT_test_INH_007',30),
('SIT_test_INH_008',30),
('SIT_test_INH_009',30),
('SIT_test_INH_010',30),
('SIT_test_INH_011',30),
('SIT_test_INH_012',20),
('SIT_test_INH_013',20),
('SIT_test_INH_014',20),
('SIT_test_INH_015',20),
('SIT_test_INH_016',20),
('SIT_test_INH_017',20),
('SIT_test_INH_018',20),
('SIT_test_INH_019',20),
('SIT_test_INH_020',20),
('QCTest29Sep16',50),
('QCTest29Sep17',20),
('QCTest29Sep18',20),
('QCTest29Sep19',50),
('QCTest29Sep20',50)

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


