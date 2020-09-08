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
		
SET @RoundID = ISNULL((SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype
					),1) 

CREATE TABLE #testAccount (username VARCHAR(30),FreeSpinCount INT )			
INSERT INTO #testAccount (username,FreeSpinCount)
VALUES 
('twpgmenid.lin',10),
('twpgmsteveliao',10),
('twpgmyikhunchiu01',10),
('twpgmyikhunchiu02',10),
('twpgmjessica.chen',10),
('twpgmbert.chang',10),
('twpgmleolee',10),
('twpgmkennychiang01',10),
('twpgmeric.hsu',10),
('twpgmnabifan',10),
('twpgmandrewlan',10),
('twpgmjaye.chen',10),
('twpgmtroychen',10),
('twpgmrita.chang2',10),
('twpgmqa02c',10),
('twpgmqa02d',10)

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


