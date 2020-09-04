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
	
	-- Account test
	SIT: 8/9
	UAT: 10/9
	PRO: 20/9
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
VALUES ('SUPERTESTKSaba02',10),('SUPERTESTKSaba03',10),('SUPERTESTKSaba07',10),('SUPERTESTKSaba08',10),('supertestsaba10',5),('supertestsaba11',5),('supertestsaba12',5),('supertestsaba13',5),('supertestsaba14',5),('supertestsaba15',5),('supertestsaba16',5),('supertestsaba17',5),('supertestsaba19',5),('supertestsaba20',5),('supertestsaba21',10),('supertestsaba22',10),('supertestsaba23',10),('supertestsaba24',10),('supertestsaba25',10),('supertestsaba26',10),('supertestsaba27',10),('supertestsaba28',10),('supertestsaba29',10),('supertestsaba30',10),('supertestsaba31',20),('supertestsaba32',20),('supertestsaba33',20),('supertestsaba34',20),('supertestsaba35',20),('supertestsaba36',20),('supertestsaba37',20),('supertestsaba38',20),('supertestsaba39',20),('supertestsaba40',20),('supertestsaba41',30),('supertestsaba42',30),('supertestsaba43',30),('supertestsaba44',30),('supertestsaba45',30),('supertestsaba46',30),('supertestsaba47',30),('supertestsaba48',30),('supertestsaba49',30),('supertestsaba50',30),('supertestsaba51',30),('supertestsaba52',30),('supertestsaba53',30),('supertestsaba54',30),('supertestsaba55',30),('supertestsaba56',30),('supertestsaba57',30),('supertestsaba58',30),('supertestsaba59',30),('supertestsaba60',30),('supertestsaba61',30),('supertestsaba62',30),('supertestsaba63',30),('supertestsaba64',30),('supertestsaba65',30),('supertestsaba66',30),('supertestsaba67',30),('supertestsaba68',30),('supertestsaba69',30),('membertestSaba01',5),('membertestSaba02',5),('membertestSaba03',5),('membertestSaba04',10),('membertestSaba05',10),('membertestSaba06',10),('MembertestSaba0301',20),('MembertestSaba0302',20),('MembertestSaba0303',20),('MembertestSaba0304',20)

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


