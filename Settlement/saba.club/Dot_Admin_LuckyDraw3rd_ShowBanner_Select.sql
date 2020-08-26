/*<info serverAlias="DBTXN-bodb02" executers="dot_intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_LuckyDraw3rd_Select]
	@CustID INT
	,@IsShowBanner BIT = 0 OUTPUT
	,@ShowBannerEndDate DATETIME = NULL OUTPUT
AS
/*
	Creator: 20200826@Helen
	Task: Show banner for Freebet tickets for 789y
	DB: DBTXN/bodb02
	
	Revisions:
		- 20200826@Helen: Saba.club - Offer Freebet tickets for 789y market [Redmine:#137942]
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ShowBannerEndDate_tmp DATETIME
	
	SET @ShowBannerEndDate_tmp  = (SELECT MAX(ShowBannerEndDate) 	
									FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
									WHERE custid = @CustID
									)
	IF 	@ShowBannerEndDate_tmp > GETDATE()
	BEGIN
		SELECT @IsShowBanner = 1
			, @ShowBannerEndDate = @ShowBannerEndDate_tmp						
	END	
	ELSE 
	BEGIN
		SELECT @IsShowBanner = 0
			, @ShowBannerEndDate = NULL												
	END
	
END
GO
