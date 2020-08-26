/*<info serverAlias="DBMSG-bodb_Message" executers="" isFunction="0"></info>*/
/*
	Created: Helen
	Date: 20200826
	Task: Saba.club - Offer Freebet tickets for 789y market - https://nexdev.net/issues/137942
	DB: DBMSG-bodb_Message
*/
USE bodb_Message
GO

DECLARE @sporttype INT 
DECLARE @RoundID INT

CREATE TABLE #Member_tmp (CustId INT, Username VARCHAR(50), IsFinish BIT)
CREATE TABLE #SMA_tmp (CustId INT, Username VARCHAR(50), IsFinish BIT)

SELECT @sporttype = 150, @RoundID = 1

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
SELECT DISTINCT ld.CustID, c.username
FROM #LuckyDraw3rd ld WITH (NOLOCK)
	INNER JOIN bodb02.dbo.custinfo c WITH (NOLOCK) ON c.custid = ld.srecommend
UNION ALL
SELECT DISTINCT ld.CustID, c.username
FROM #LuckyDraw3rd ld WITH (NOLOCK)
	INNER JOIN bodb02.dbo.custinfo c WITH (NOLOCK) ON c.custid = ld.mrecommend
UNION ALL
SELECT DISTINCT ld.CustID, c.username
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

------- Message for members ----------------
IF EXISTS (SELECT TOP (1) 1 FROM #Master_tmp )
BEGIN
	SET @Content_en = 'Member - gogogogogogogogo'
	--Msg
	INSERT dbo.Msg (Content_ch, Content_it, Content_cs, Content_jp, Content_th,
							Content_en, Content_ko, Content_es, Content_vn, Content_id,
							MsgType, IsSticky, Creator, CreatorName, MatchId,
							LastUpdator, LastUpdateName, CreateTime, LastUpdateTime, PostTime, IsTest,
							IsBatch) 
	VALUES(@Content_ch, @Content_it, @Content_cs, @Content_jp, @Content_th, 
  			@Content_en, @Content_ko, @Content_es, @Content_vn, @Content_id,
			@MsgType, @IsSticky, @Creator, @CreatorName, @MatchId,
			@Creator, @CreatorName, GETDATE(), GETDATE(), GETDATE(), @IsTest,
			@IsBatch);

	SELECT @MessageId = @@IDENTITY

	--dbo.MsgTarget
	INSERT dbo.MsgTarget(MessageId, TargetId, TargetName, isRead ,PostTime)
	SELECT @MessageId, CustId, Username, 0, GETDATE()
	FROM #Member_tmp
	
END

------- Message for SMA ----------------
IF EXISTS (SELECT TOP (1) 1 FROM #Master_tmp )
BEGIN
	SET @Content_en = 'SMA - gogogogogogogogo'
	--Msg
	INSERT dbo.Msg (Content_ch, Content_it, Content_cs, Content_jp, Content_th,
							Content_en, Content_ko, Content_es, Content_vn, Content_id,
							MsgType, IsSticky, Creator, CreatorName, MatchId,
							LastUpdator, LastUpdateName, CreateTime, LastUpdateTime, PostTime, IsTest,
							IsBatch) 
	VALUES(@Content_ch, @Content_it, @Content_cs, @Content_jp, @Content_th, 
  			@Content_en, @Content_ko, @Content_es, @Content_vn, @Content_id,
			@MsgType, @IsSticky, @Creator, @CreatorName, @MatchId,
			@Creator, @CreatorName, GETDATE(), GETDATE(), GETDATE(), @IsTest,
			@IsBatch);

	SELECT @MessageId = @@IDENTITY

	--dbo.MsgTarget
	INSERT dbo.MsgTarget(MessageId, TargetId, TargetName, isRead ,PostTime)
	SELECT @MessageId, CustId, Username, 0, GETDATE()
	FROM #Member_tmp
	
END