/*<info serverAlias="DBTXN-bodb02" executers="dot_intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Member_LuckyDraw3rd_ShowBanner_Select]
(
	@sporttype TINYINT = 150
	, @ErrCode	INT				= 0		OUTPUT	
	, @ErrMsg	VARCHAR(300)	= ''	OUTPUT
)
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
	DECLARE @RoundID INT
	
	SET @RoundID = (SELECT MAX(RoundID) 	
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE statusid = 1 AND Sporttype = @sporttype
					)
	
	SELECT RoundID, CustID, ShowBannerEndDate 	
	FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
	WHERE Sporttype = @sporttype AND statusid = 1 AND RoundID = @RoundID AND ShowBannerEndDate > GETDATE()
		
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	 @ErrCode = 100
				,@ErrMsg = 'No data found'
	END
		
END
GO
