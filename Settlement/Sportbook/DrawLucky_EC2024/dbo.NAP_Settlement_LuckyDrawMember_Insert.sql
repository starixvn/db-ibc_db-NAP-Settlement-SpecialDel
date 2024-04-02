/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_LuckyDrawMember_Insert]
	 @MatchId			INT
	,@ListTransIDs		VARCHAR(MAX)
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
		    ,@NumberLucker		INT = 5
			,@TotalCust			INT = 0
			,@VerificationCode	VARCHAR(50)
			,@Count				INT = 1
			,@MaxCount		    INT

	DECLARE @Lucker TABLE(CustId INT, VerificationCode VARCHAR(50))

	CREATE TABLE #TransInfo (transId BIGINT,CustId INT,RankRandom INT)
	
	EXEC sp_xml_preparedocument @handle OUTPUT, @ListTransIDs
	INSERT INTO #TransInfo(TransID, CustId,RankRandom)
	SELECT t, c,ROW_NUMBER() OVER(ORDER BY NEWID()) AS r
	FROM OPENXML(@handle,'root/r',1) WITH(t   BIGINT
										 ,c   INT
									) tbl
	EXEC sp_xml_removedocument @handle 

	SELECT @TotalCust = COUNT(DISTINCT CustId)
	FROM #TransInfo

	IF (@NumberLucker >= @TotalCust)
	BEGIN
		INSERT INTO @Lucker(CustId)
		SELECT	DISTINCT 
				CustId
		FROM #TransInfo

		SET @NumberLucker = @TotalCust
	END
	ELSE
	BEGIN
		INSERT INTO @Lucker(CustId)
		SELECT	DISTINCT 
				TOP(@NumberLucker)  
				CustId
		FROM #TransInfo
		ORDER BY RankRandom ASC
	END

	SET @MaxCount = @NumberLucker*2
	WHILE @Count <= @MaxCount
	BEGIN
		SET @VerificationCode = dbo.f_GenerateLuckyDraw_VerificationCode(RAND(),RAND(),NEWID(),NEWID(),NEWID())

		IF EXISTS (SELECT 1 FROM LuckyDrawList WITH(NOLOCK) WHERE VerificationCode = @VerificationCode)
		BEGIN
			SET @Count = @Count + 1
			CONTINUE 
		END

		UPDATE TOP (1) @Lucker
		SET VerificationCode = @VerificationCode
		WHERE  VerificationCode IS NULL

		IF @@ROWCOUNT = 0
		BEGIN
			BREAK
		END

		SET @Count = @Count + 1
	END

	INSERT INTO LuckyDrawList(matchid,custid,TypeID,VerificationCode,StatusID,Payout,Currency,CreatedDate,LastModifiedDate,IsNotify)
	SELECT @MatchId
		  ,l.custid
		  ,1 AS TypeID
		  ,l.VerificationCode
		  ,0 AS StatusID
		  ,50000/@NumberLucker AS Payout
		  ,'US$' AS Currency
		  ,GETDATE() AS CreatedDate
		  ,GETDATE() AS LastModifiedDate
		  ,0 AS IsNotify
	FROM @Lucker AS l
		--CROSS APPLY(SELECT TOP 1 TotalPool
		--			FROM LuckyDrawPoolPrize AS ls 
		--			WHERE ls.MatchId = @MatchId
		--				AND ls.bettype = 413
		--			) AS s

END