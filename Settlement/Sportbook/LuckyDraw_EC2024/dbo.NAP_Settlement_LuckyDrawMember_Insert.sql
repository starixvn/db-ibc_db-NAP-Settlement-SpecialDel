/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_LuckyDrawMember_Insert]
	 @MatchId			INT
	,@ListTransIDs		VARCHAR(MAX)
	,@PoolAmount		DECIMAL(12,4)
	,@TotalWinner		INT
	,@IsTest			BIT = 0
AS
/*
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]

	Param's Explanation:  	   
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE  @handle			INT
			,@TotalCust			INT = 0
			,@VerificationCode	VARCHAR(50)
			,@finalhomescore	INT
			,@finalawayscore	INT
			,@crrDateGMT8		DATETIME

	DECLARE @Winner TABLE(CustId INT, VerificationCode VARCHAR(50))

	CREATE TABLE #TransInfo (transId BIGINT,CustId INT,Rank1 INT,Rank2 INT)
	
	EXEC sp_xml_preparedocument @handle OUTPUT, @ListTransIDs
	INSERT INTO #TransInfo(TransID, CustId,Rank1,Rank2)
	SELECT tbl.TransID, tbl.CustId,tbl.Rank1, DENSE_RANK() OVER(PARTITION BY tbl.CustId ORDER BY tbl.Rank1)
	FROM (SELECT tt.t AS TransID, tt.c AS CustId,ROW_NUMBER() OVER(ORDER BY NEWID()) AS Rank1
		  FROM OPENXML(@handle,'root/r',1) WITH(t   BIGINT
											   ,c   INT
										   ) tt
	) AS tbl
	EXEC sp_xml_removedocument @handle 

	SELECT	 @finalhomescore = finalhomescore
			,@finalawayscore = finalawayscore
	FROM match WITH(NOLOCK)
	WHERE matchid = @MatchId

	SELECT @TotalCust = COUNT(DISTINCT CustId)
	FROM #TransInfo

	SET @crrDateGMT8 = DATEADD(HOUR,12,GETDATE())

	IF (@TotalWinner >= @TotalCust)
	BEGIN
		INSERT INTO @Winner(CustId)
		SELECT	DISTINCT 
				CustId
		FROM #TransInfo

		SET @TotalWinner = @TotalCust
	END
	ELSE
	BEGIN
		INSERT TOP (@TotalWinner) INTO  @Winner(CustId)
		SELECT	TOP (@TotalWinner) CustId
		FROM #TransInfo
		WHERE Rank2 = 1
		ORDER BY Rank1 ASC
	END

	WHILE (1 = 1)
	BEGIN
		SET @VerificationCode = dbo.f_GenerateLuckyDraw_VerificationCode(RAND(),RAND(),NEWID(),NEWID(),NEWID())

		IF EXISTS (SELECT 1 FROM LuckyDrawList WITH(NOLOCK) WHERE VerificationCode = @VerificationCode AND TypeID = 1)
		BEGIN
			CONTINUE 
		END

		UPDATE TOP (1) @Winner
		SET VerificationCode = @VerificationCode
		WHERE  VerificationCode IS NULL

		IF @@ROWCOUNT = 0
		BEGIN
			BREAK
		END
	END

	INSERT INTO LuckyDrawList(matchid,custid,DisplayName,TypeID,VerificationCode,StatusID,Payout,Currency,CreatedDate,LastModifiedDate,IsNotify,ExpiredDate,IsLicensee,PoolPrize,finalhomescore,finalawayscore, IsTest)
	SELECT @MatchId
		  ,l.custid
		  ,[dbo].[f_EncodeLuckyDraw_UserName](c.username) AS DisplayName
		  ,1 AS TypeID
		  ,l.VerificationCode
		  ,0 AS StatusID
		  ,ROUND(@PoolAmount/@TotalWinner,0) AS Payout
		  ,'RM' AS Currency
		  ,GETDATE() AS CreatedDate
		  ,GETDATE() AS LastModifiedDate
		  ,0 AS IsNotify
		  ,CASE WHEN c.Site = 'IBCIndo' THEN DATEADD(DAY, 14, @crrDateGMT8)
				ELSE DATEADD(DAY, 7, @crrDateGMT8)
			END AS ExpiredDate
		  ,0 AS IsLicensee -- Credit
		  ,@PoolAmount
		  ,@finalhomescore 
		  ,@finalawayscore
		  ,@IsTest
	FROM @Winner AS l
		INNER JOIN CustDB.dbo.Customer AS c WITH(NOLOCK) ON l.CustId = c.custid
END