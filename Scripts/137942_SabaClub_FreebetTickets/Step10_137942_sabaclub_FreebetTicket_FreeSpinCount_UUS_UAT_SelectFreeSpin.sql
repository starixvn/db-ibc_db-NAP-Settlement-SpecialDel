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
DECLARE @RoundID INT 
		, @Sporttype TINYINT 

SELECT  @Sporttype = 150		
		--,@RoundID = XXX
IF @RoundID IS NULL
BEGIN 
	SET @RoundID = (SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype)
END		

SELECT CustID, FreeSpinCount, CONVERT(VARCHAR(10), DATEADD(DD, 1, '2020-09-10'),101) + ' 23:59:59.000' ShowBannerEndDate 
FROM dbo.LuckyDraw3rd WITH (NOLOCK)
WHERE Sporttype = @Sporttype AND RoundID = @RoundID