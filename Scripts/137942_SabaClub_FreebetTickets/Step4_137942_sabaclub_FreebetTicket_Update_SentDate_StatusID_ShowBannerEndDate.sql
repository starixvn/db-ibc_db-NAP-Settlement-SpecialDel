/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Helen
	Date: 20200826
	Task: Saba.club - Offer Freebet tickets for 789y market - https://nexdev.net/issues/137942
	DB: DBTXN-bodb02
*/
USE bodb02
GO

DECLARE @sporttype INT 
DECLARE @RoundID INT, @ShowBannerEndDate DATETIME, @ShowBannerEndDate_UUS DATETIME 

SELECT @sporttype = 150, @RoundID = XXX

SET @ShowBannerEndDate = CONVERT(VARCHAR(10), DATEADD(DD, 6, GETDATE()),101) + ' 23:59:59.000'
SET @ShowBannerEndDate_UUS = CONVERT(VARCHAR(10), DATEADD(DD, 1, '2020-09-20'),101) + ' 23:59:59.000'
SELECT @ShowBannerEndDate

WHILE 1 = 1
BEGIN
	UPDATE TOP (2000) ld
		SET statusid = 1
			,sentdate = GETDATE()
			,ShowBannerEndDate = CASE WHEN c.currency = 20 THEN @ShowBannerEndDate_UUS ELSE @ShowBannerEndDate END  
	FROM LuckyDraw3rd ld WITH (ROWLOCK)
		INNER JOIN CUSTDB.dbo.customer c WITH (NOLOCK) ON ld.custid = c.custid
	WHERE RoundID = @RoundID AND SportType = @sporttype AND statusid = 0

	IF @@ROWCOUNT = 0 BREAK
	
END
GO


