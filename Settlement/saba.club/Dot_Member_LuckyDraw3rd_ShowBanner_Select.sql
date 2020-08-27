/*<info serverAlias="DBTXN-bodb02" executers="dot_intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Member_LuckyDraw3rd_ShowBanner_Select]
	@CustID INT
	,@IsShowBanner BIT = 0 OUTPUT
	,@ShowBannerEndDate DATETIME = NULL OUTPUT
	,@RoundID INT = NULL OUTPUT
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
	
	SET @RoundID = (SELECT MAX(RoundID) 	
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE custid = @CustID AND statusid = 1
					)
					
	IF @RoundID IS NULL
	BEGIN
		SELECT @IsShowBanner = 0
			, @ShowBannerEndDate = NULL	
			, @RoundID = NULL
		RETURN
	END	
	
	SET @ShowBannerEndDate_tmp  = (SELECT TOP (1) ShowBannerEndDate 	
									FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
									WHERE custid = @CustID AND statusid = 1 AND RoundID = @RoundID
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
