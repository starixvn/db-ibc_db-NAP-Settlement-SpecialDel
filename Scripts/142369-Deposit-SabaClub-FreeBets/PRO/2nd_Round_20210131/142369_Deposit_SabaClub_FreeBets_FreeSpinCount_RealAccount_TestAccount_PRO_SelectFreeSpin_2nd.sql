a/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Max
	Date: 20201119
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
	
	Sample: CONVERT(VARCHAR(10),'01/13/2021',101) + ' 01:00:00'
*/
USE bodb02
GO
DECLARE @sporttype INT 
DECLARE @RoundID INT

SELECT @sporttype = 150
	--, @RoundID = XXX
	
IF @RoundID IS NULL
BEGIN 
	SET @RoundID = (SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype)
END	

SELECT RoundID,d.CustID, d.FreeSpinCount
	, CONVERT(VARCHAR(10), DATEADD(DD, 7, '01/31/2021'),101) + ' 23:59:59' AS ShowBannerEndDate 
FROM dbo.LuckyDraw3rd d WITH (NOLOCK)
	INNER JOIN CUSTDB.dbo.customer c WITH (NOLOCK) ON d.CustID = c.custid
WHERE Sporttype = @sporttype AND RoundID = @RoundID
		
