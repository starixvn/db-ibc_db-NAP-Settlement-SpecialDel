/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
CREATE PROC Task_LuckyDraw3rd_Freebets_Update
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
	SET NOCOUNT ON
	DECLARE @sporttype INT 
	DECLARE @RoundID INT, @ShowBannerEndDate DATETIME
	
	DECLARE @currentDate DATETIME
	SET @currentDate = CONVERT(date, getdate())
	
	SELECT @sporttype = 150
	
	SET @RoundID = (SELECT MAX(roundID) 
					FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype AND statusID = 0)
	
	
	IF @RoundID IS NULL
	BEGIN
		SELECT 'Nothing to updated. Please check again.'
		RETURN
	END
	
	SET @ShowBannerEndDate = CONVERT(VARCHAR(10), DATEADD(DD, 6, @currentDate),101) + ' 23:59:59'
	SELECT @ShowBannerEndDate

	WHILE (1 = 1)
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
	
END