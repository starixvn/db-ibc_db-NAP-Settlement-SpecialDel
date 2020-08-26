/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: Helen
	Date: 20200826
	Task: Saba.club - Offer Freebet tickets for 789y market - https://nexdev.net/issues/137942
	DB: DBTXN-bodb02
*/
USE bodb02
GO

DECLARE @sporttype INT 
DECLARE @RoundID INT, @ShowBannerEndDate DATETIME

SELECT @sporttype = 150, @RoundID = 1

SET @ShowBannerEndDate = CONVERT(VARCHAR(10), DATEADD(DD, 7, GETDATE()),102) + ' 23:59:59.000'

SELECT @ShowBannerEndDate

WHILE 1 = 1
BEGIN
	UPDATE TOP (2000) ld
		SET statusid = 1
			,sentdate = GETDATE()
			,ShowBannerEndDate = @ShowBannerEndDate
	FROM LuckyDraw3rd ld WITH (ROWLOCK)
	WHERE RoundID = @RoundID AND SportType = @sporttype AND statusid = 0

	IF @@ROWCOUNT = 0 BREAK
	
END
GO
