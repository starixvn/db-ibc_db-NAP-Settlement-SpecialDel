/*
	Created: Helen
	Date: 20200826
	Task: Saba.club - Offer Freebet tickets for 789y market - https://nexdev.net/issues/137942
	DB: DBTRANS/bodb02
	
	-- FOR sample execution, permission: dot_intg 
*/
DECLARE @CustID INT
	,@IsShowBanner BIT = 0 
	,@ShowBannerEndDate DATETIME = NULL
	
EXEC dbo.NAP_Set_LuckyDraw3rd_Select @CustID = @CustID,@IsShowBanner= @IsShowBanner OUT, @ShowBannerEndDate = @ShowBannerEndDate OUT

SELECT  @IsShowBanner AS IsShowBanner, @ShowBannerEndDate AS ShowBannerEndDate