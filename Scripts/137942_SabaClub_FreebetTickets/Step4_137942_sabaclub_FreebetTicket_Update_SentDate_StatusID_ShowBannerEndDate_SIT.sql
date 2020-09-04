/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Helen
	Date: 20200826
	Task: Saba.club - Offer Freebet tickets for 789y market - https://nexdev.net/issues/137942
	DB: DBTXN-bodb02
	
	-- Account test
	SIT: 8/9
	UAT: 10/9
	PRO: 20/9
	
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
	
SET @ShowBannerEndDate = CONVERT(VARCHAR(10), DATEADD(DD, 1, '2020-09-08'),101) + ' 23:59:59.000'
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


