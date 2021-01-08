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

	Convert from GMT + 8 -> GMT -4
	SELECT DATEADD (HH, -12, '2021-01-13 13:00:00.000') -> 2021-01-13 01:00:00.000
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

SELECT RoundID,CustID, FreeSpinCount, CONVERT(VARCHAR(10),'2021-01-13',101) + ' 01:00:00.000' ShowBannerEndDate 
FROM dbo.LuckyDraw3rd WITH (NOLOCK)
WHERE Sporttype = @Sporttype AND RoundID = @RoundID


