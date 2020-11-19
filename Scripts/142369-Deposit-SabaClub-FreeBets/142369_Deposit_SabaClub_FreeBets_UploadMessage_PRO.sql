/*<info serverAlias="DBMSG-bodb_Message" executers="" isFunction="0"></info>*/
/*
	Created: Max
	Date: 20201119
	Task: Deposit - Saba.Club - Free Bets [Redmine: #142369]
	DB: DBMSG-bodb_Message
*/
USE bodb_Message
GO

DECLARE @sporttype INT 
DECLARE @RoundID INT

CREATE TABLE #Member_tmp (CustId INT, Username VARCHAR(50), IsFinish BIT)
CREATE TABLE #SMA_tmp (CustId INT, Username VARCHAR(50), IsFinish BIT)

SELECT @sporttype = 150
	--, @RoundID = xxx

IF @RoundID IS NULL
BEGIN 
	SET @RoundID = (SELECT MAX(roundID) 
					FROM DBTXN.bodb02.dbo.LuckyDraw3rd WITH (NOLOCK) 
					WHERE sporttype = @Sporttype)
END						

CREATE TABLE #LuckyDraw3rd (CustID INT, srecommend INT, mrecommend INT, recommend INT)
INSERT INTO #LuckyDraw3rd (CustID,srecommend, mrecommend,recommend)
SELECT CustID,srecommend, mrecommend,recommend
FROM DBTXN.bodb02.dbo.LuckyDraw3rd WITH (NOLOCK)
WHERE RoundID = @RoundID AND SportType = @sporttype AND statusid = 0
 
INSERT INTO #Member_tmp (CustId, Username)
SELECT DISTINCT ld.CustID, c.username
FROM #LuckyDraw3rd ld WITH (NOLOCK)
	INNER JOIN bodb02.dbo.custinfo c WITH (NOLOCK) ON c.custid = ld.custid

INSERT INTO #SMA_tmp (CustId, Username)
SELECT DISTINCT ld.srecommend, c.username
FROM #LuckyDraw3rd ld WITH (NOLOCK)
	INNER JOIN bodb02.dbo.custinfo c WITH (NOLOCK) ON c.custid = ld.srecommend
UNION ALL
SELECT DISTINCT ld.mrecommend, c.username
FROM #LuckyDraw3rd ld WITH (NOLOCK)
	INNER JOIN bodb02.dbo.custinfo c WITH (NOLOCK) ON c.custid = ld.mrecommend
UNION ALL
SELECT DISTINCT ld.recommend, c.username
FROM #LuckyDraw3rd ld WITH (NOLOCK)
	INNER JOIN bodb02.dbo.custinfo c WITH (NOLOCK) ON c.custid = ld.recommend
	
-----------STARTINT FOR send message --------------		
DECLARE @MessageId int = NULL,
	@Content_en	nvarchar(4000) = NULL,
	@Content_ch	nvarchar(4000) = NULL,
	@Content_cs	nvarchar(4000) = NULL,
	@Content_jp	nvarchar(4000) = NULL,
	@Content_it	nvarchar(4000) = NULL,
	@Content_th	nvarchar(4000) = NULL,
	@Content_ko nvarchar(4000) = NULL,
	@Content_es nvarchar(4000) = NULL,
	@Content_vn nvarchar(4000) = NULL,
	@Content_id nvarchar(4000) = NULL,
	@MsgType int = 1,
	@IsSticky bit = 0,
	@Creator int = 0,
	@CreatorName nvarchar(50),
	@IsTest bit = 0,
	@MatchId int = 0,
	@IsBatch bit = 0

SELECT @Creator = 10278938, @CreatorName = 'starixIT'	

------- Message for SMA ----------------
IF EXISTS (SELECT TOP (1) 1 FROM #SMA_tmp )
BEGIN
	SET @Content_en = N'Dear Valued Customers, We will be giving away free spins in the Lucky Wheel program to eligible members who meet the win/loss criteria of SABA Virtual Sport’s products. Prize winners will receive free bets on Saba.club. 100% of the win/loss amount from those free bets will be on the company. Best Regards.'
	SET @Content_vn = N'Kính gửi quý khách hàng, Chúng tôi sẽ tiến hành tặng các lượt quay trong chương trình Vòng Quay May Mắn cho các member thỏa mãn tiêu chí thắng thua trên các sản phẩm Thể Thao Ảo SABA. Giải thưởng từ các lượt quay này là các lượt chơi miễn phí (Free Bets) trên Saba.club. Toàn bộ 100% thắng/thua từ các cược này sẽ do công ty chịu. Trân trọng.'
	--Msg
	INSERT dbo.Msg (Content_vn,Content_en,Content_ch, Content_it, Content_cs, Content_jp, Content_th,
					Content_ko, Content_es, Content_id,
					MsgType, IsSticky, Creator, CreatorName, MatchId,
					LastUpdator, LastUpdateName, CreateTime, LastUpdateTime, PostTime, IsTest,
					IsBatch) 
	VALUES(@Content_vn,@Content_en, @Content_en, @Content_en, @Content_en, @Content_en,@Content_en, 
  			@Content_en, @Content_en, @Content_id,
			@MsgType, @IsSticky, @Creator, @CreatorName, @MatchId,
			@Creator, @CreatorName, GETDATE(), GETDATE(), GETDATE(), @IsTest,
			@IsBatch);

	SELECT @MessageId = @@IDENTITY

	--dbo.MsgTarget
	INSERT dbo.MsgTarget(MessageId, TargetId, TargetName, isRead ,PostTime)
	SELECT @MessageId, CustId, Username, 0, GETDATE()
	FROM #SMA_tmp
	
END

------- Message for members ----------------
IF EXISTS (SELECT TOP (1) 1 FROM #Member_tmp )
BEGIN
	SET @Content_en = N'Dear Valued Customers, Congratulations on receiving free spins in Saba.club’s Lucky Wheel program for satisfying the win/loss criteria of SABA Virtual Sport’s products. Prize winners will receive free bets on Saba.club. 100% of the win/loss amount from those free bets will be on the company. Best Regards.'
	SET @Content_vn = N'Kính gửi quý khách hàng, Chúc mừng bạn đã nhận được các lượt quay trong chương trình Vòng Quay May Mắn của Saba.club vì đã thỏa mãn tiêu chí thắng thua trên các sản phẩm Thể Thao Ảo SABA. Giải thưởng từ các lượt quay này là các lượt chơi miễn phí (Free Bets) trên Saba.club. Toàn bộ 100% thắng/thua từ các cược này sẽ do công ty chịu. Trân trọng.'
	--Msg
	INSERT dbo.Msg (Content_vn, Content_en,Content_ch, Content_it, Content_cs, Content_jp, Content_th,
					Content_ko, Content_es, Content_id,
					MsgType, IsSticky, Creator, CreatorName, MatchId,
					LastUpdator, LastUpdateName, CreateTime, LastUpdateTime, PostTime, IsTest,
					IsBatch) 
	VALUES(@Content_vn,@Content_en, @Content_en, @Content_en, @Content_en, @Content_en,@Content_en
			,@Content_en, @Content_en, @Content_id,
			@MsgType, @IsSticky, @Creator, @CreatorName, @MatchId,
			@Creator, @CreatorName, GETDATE(), GETDATE(), GETDATE(), @IsTest,
			@IsBatch);

	SELECT @MessageId = @@IDENTITY

	--dbo.MsgTarget
	INSERT dbo.MsgTarget(MessageId, TargetId, TargetName, isRead ,PostTime)
	SELECT @MessageId, CustId, Username, 0, GETDATE()
	FROM #Member_tmp
	
END
/*-- for checking data
SELECT * FROM #SMA_tmp
SELECT * FROM #Member_tmp

SELECT TOP 10 m.* 
FROM MsgTarget ms (nolock) 
	inner join Msg m (nolock) on ms.MessageId = m.MessageId
WHERE TargetId = xxx -- custid of sma
ORDER BY PostTime desc

SELECT TOP 10 m.* 
FROM MsgTarget ms (nolock) 
	INNER JOIN Msg m (nolock) on ms.MessageId = m.MessageId
WHERE TargetId = xxx -- custid id of member
ORDER BY PostTime desc
*/
DROP TABLE #Member_tmp
DROP TABLE #SMA_tmp
DROP TABLE #LuckyDraw3rd
