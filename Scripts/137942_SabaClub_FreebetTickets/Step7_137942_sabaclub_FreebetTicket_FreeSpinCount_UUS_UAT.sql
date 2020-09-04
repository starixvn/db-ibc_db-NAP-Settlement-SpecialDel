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
		, @winlostdate = '2020-09-10'
		
CREATE TABLE #temp_result (CustID INT, srecommend INT, mrecommend INT,recommend INT, NetWinLoss MONEY)

DELETE FROM dbo.LuckyDraw3rd

/*		
SET @RoundID = 1 + ISNULL((SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype
					),0) 
*/				

CREATE TABLE #testAccount (username VARCHAR(30),FreeSpinCount INT )			
INSERT INTO #testAccount (username,FreeSpinCount)
VALUES ('viettest789UAT',10),('kiwitest789',10),('IT01Test789',5),('IT02Test789',5),('IT03Test789',5),('IT04Test789',5),('IT05Test789',5),('IT06Test789',5),('IT07Test789',5),('IT09Test789',5),('IT08Test790',5),('IT10Test789',5),('IT11Test789',10),('IT12Test789',10),('IT13Test789',10),('IT14Test789',10),('IT15Test789',10),('IT16Test789',10),('IT17Test789',10),('IT19Test789',10),('IT20Test789',10),('IT21Test789',10),('IT22Test789',20),('IT23Test789',20),('IT24Test789',20),('IT25Test789',20),('IT27Test789',20),('IT28Test789',20),('IT29Test789',20),('IT30Test789',20),('IT31Test789',20),('IT32Test789',20),('IT33Test789',30),('IT34Test789',30),('IT35Test789',30),('IT36Test789',30),('IT37Test789',30),('IT38Test789',30),('IT39Test789',30),('IT40Test789',30),('IT41Test789',30),('IT42Test789',30),('IT43Test789',30),('IT44Test789',30),('IT45Test789',30),('IT46Test789',30),('IT47Test789',30),('IT48Test789',30),('IT49Test789',30),('IT50Test789',30),('IT51Test789',30),('IT52Test789',30),('IT53Test789',30),('IT54Test789',30),('IT55Test789',30),('IT56Test789',30),('IT57Test789',30),('IT58Test789',30),('IT59Test789',30),('IT60Test789',30),('IT61Test789',30),('SUPERTESTTE10010000E',5),('SUPERTESTTE10010000F',5),('SUPERTESTTE10010000G',5),('SUPERTESTTE10010000H',10),('SUPERTESTTE10010100J',10),('SUPERTESTTE10010100I',10),('SUPERTESTTE10010000L',20),('SUPERTESTTE10010000M',20),('SUPERTESTTE10010000N',20),('SUPERTESTTE10010000O',20)

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

SELECT @RoundID AS RoundID
--DROP TABLE #temp_result

