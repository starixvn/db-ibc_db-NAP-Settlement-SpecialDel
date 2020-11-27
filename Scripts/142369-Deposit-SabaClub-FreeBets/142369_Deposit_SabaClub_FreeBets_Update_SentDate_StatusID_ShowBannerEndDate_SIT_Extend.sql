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

DECLARE @sporttype INT 
DECLARE @RoundID INT, @ShowBannerEndDate DATETIME, @ShowBannerEndDate_UUS DATETIME 

SELECT @sporttype = 150
	--, @RoundID = XXX
IF @RoundID IS NULL
BEGIN 
	SET @RoundID = (SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype)
END		
	
SET @ShowBannerEndDate = CONVERT(VARCHAR(10),'2020-12-01',101) + ' 04:00:00.000'
SELECT @ShowBannerEndDate

WHILE 1 = 1
BEGIN
	UPDATE TOP (2000) ld
		SET statusid = 1
			,sentdate = GETDATE()
			,ShowBannerEndDate = @ShowBannerEndDate
	FROM LuckyDraw3rd ld WITH (ROWLOCK)
		INNER JOIN CUSTDB.dbo.customer c WITH (NOLOCK) ON ld.custid = c.custid
	WHERE RoundID = @RoundID AND SportType = @sporttype AND statusid = 0

	IF @@ROWCOUNT = 0 BREAK
	
END
GO


