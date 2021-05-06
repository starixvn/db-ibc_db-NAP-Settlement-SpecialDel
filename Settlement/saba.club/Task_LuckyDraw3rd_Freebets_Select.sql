/*<info serverAlias="DBTXN-bodb02" executers="vnSAS" isFunction="0"></info>*/
ALTER PROC Task_LuckyDraw3rd_Freebets_Select 
(
	@sporttype INT = 150
	,@RoundID INT = NULL
	,@StatusId TINYINT = 0
)
AS
/*
	Created: Helen
	Date: 20210319
	Task: Deposit - Saba.Club - Free Bets [Redmine: #142369]
	DB: DBTRANS/bodb02
	
	Revisions:
		- 20210319@Helen: Deposit - Saba.Club - Free Bets [Redmine: #142369]
*/
BEGIN
	
	DECLARE @currentDate DATE
	SET @currentDate = GETDATE()

	IF @RoundID IS NULL
	BEGIN
		SET @RoundID = (SELECT MAX(roundID) 
						FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
						WHERE sporttype = @Sporttype AND StatusId = @StatusId)
	END
	
	IF @RoundID IS NOT NULL
	BEGIN
		SELECT RoundID,d.CustID, d.FreeSpinCount
			, CONVERT(VARCHAR(10), DATEADD(DD, 6, @currentDate),101) + ' 23:59:59' AS ShowBannerEndDate 
		FROM dbo.LuckyDraw3rd d WITH (NOLOCK)
		WHERE Sporttype = @sporttype AND RoundID = @RoundID AND StatusId = @StatusId
	END
	
END