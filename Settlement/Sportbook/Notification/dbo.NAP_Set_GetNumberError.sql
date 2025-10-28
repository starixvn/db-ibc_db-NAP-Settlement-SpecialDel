/*<info serverAlias="DBSIG-bodb02,DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_GetNumberError] 
	@AdminId INT
	,@NumberError INT = 0 OUTPUT
AS
/*	Creator: Kathy
	Date: 20140108
	Task: Get number error
	DB: DBTXN/BODB02
	Original: 

	Revisions:
		- 20140404@Kathy: Count notification messages for each group (Soccer, Other Sports)
							Send email in case calculation got notify
		- 20170112@Kathy: Add AdminId 111 into Soccer Team [Redmine:#70302]		
		- 20190418@Kathy: - Do not send email when mark/unmark ticket [Redmine:#106823]
						  -	Add starix56 to view notification
		- 20191210@Helen: Hotfix GetNumberOfNotifications failed when message length is over 300 characters - [Redmine:#125246]						  
		- 20200120@Sol:	Settlement with Ticket Exclusion for Other Sports - Added AdminId = 111 to Other sport - [Redmine:#126963]
		- 20200720@Kathy: Extend datatype for table Settled_Message.Action [Redmine:#135846]
		- 20251027@Louisa: Enhance Betbuilder-send message when has effected ticket [Redmine:#237039]
							
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tblSoccerTeam TABLE (custid INT)
	DECLARE @tblOtherSportTeam TABLE (custid INT)
	
	DECLARE @tblBetbuilder TABLE (
		matchid INT
		,marketid INT
		,matchcode NVARCHAR(50)
		,homeid INT
		,awayid INT
		,sporttype SMALLINT
		,IP VARCHAR(15)
		,starttime DATETIME
		,Action VARCHAR(20)
		,Message VARCHAR(MAX)
		,IsSent BIT
		)

	DECLARE	@IsSoccer			BIT = 0
			,@IsOtherSport		BIT = 0
			,@IsCentral			BIT

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO @tblSoccerTeam (custid)
	SELECT	14228954			-- Keyscore1	
	UNION ALL SELECT 14228977	-- Keyscore2		
	UNION ALL SELECT 8068543	-- TRACY			
	UNION ALL SELECT 384559		-- YONG 
	UNION ALL SELECT 12978541	-- pgmHarris
	UNION ALL SELECT 4338171	-- pgmKaka  	
	UNION ALL SELECT 20442488	-- starix56 
	UNION ALL SELECT 111		-- Auto Settlement

	INSERT INTO @tblOtherSportTeam (custid)
	SELECT 462523 -- IRENE		
	UNION ALL SELECT 1590728	-- OSAMMY	
	UNION ALL SELECT 622158		-- OSBONNIE		
	UNION ALL SELECT 626446		-- OSFIONA		
	UNION ALL SELECT 283830		-- OSJOHNSON1	
	UNION ALL SELECT 859948		-- OSMICKEY	
	UNION ALL SELECT 5234866	-- OSVENNY
	UNION ALL SELECT 12978541	-- pgmHarris 
	UNION ALL SELECT 4338171	-- pgmKaka 
	UNION ALL SELECT 20442488	-- starix56  
	UNION ALL SELECT 111		-- Auto Settlement

	IF EXISTS (SELECT TOP 1 1 FROM @tblSoccerTeam WHERE custid = @AdminId)
			SET @IsSoccer = 1
	IF EXISTS (SELECT TOP 1 1 FROM @tblOtherSportTeam WHERE custid = @AdminId)
		SET @IsOtherSport = 1
			
	DECLARE @tblTemp TABLE (
		matchid INT
		,matchcode NVARCHAR(50)
		,homeid INT
		,awayid INT
		,sporttype SMALLINT
		,IP VARCHAR(15)
		,starttime DATETIME
		,Action VARCHAR(20)
		,Message VARCHAR(MAX)
		,IsSent BIT
		)
	
	INSERT INTO @tblTemp (matchid, matchcode, homeid, awayid, sporttype, IP, starttime, Action, Message, IsSent)
	SELECT	m.matchid, m.matchcode, m.homeid, m.awayid, m.sporttype
			,s.IP, s.Starttime, s.Action, s.Message
			,CASE WHEN s.Action IN ('MARK', 'UNMARK', 'VOID') THEN 1 ELSE s.IsSent END
	FROM	dbo.Settled_Message s WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) 
			ON	m.matchid = s.MatchId
			WHERE IsRead = 0 
				AND (
						(s.AdminId IN (SELECT custid FROM @tblSoccerTeam) 
						AND @IsSoccer = 1
						AND m.sporttype = 1
						) 
					OR (
							s.AdminId IN (SELECT custid FROM @tblOtherSportTeam) 
							AND @IsOtherSport = 1
							AND m.sporttype <> 1
						) 
					OR (s.AdminId = @AdminId)
				)
				AND Message IS NOT NULL
 
	DELETE tbl 
	OUTPUT deleted.matchid
			,SUBSTRING(
					deleted.Message,
					CHARINDEX('MarketId:', deleted.Message) + LEN('MarketId:'),                   
					CHARINDEX(',', deleted.Message) - (CHARINDEX('MarketId:', deleted.Message) + LEN('MarketId:'))  
				) AS MarketId
			,deleted.matchcode, deleted.homeid, deleted.awayid, deleted.sporttype, deleted.IP, deleted.starttime, deleted.Action, deleted.Message, deleted.IsSent
	INTO @tblBetbuilder  (matchid, marketid, matchcode, homeid, awayid, sporttype, IP, starttime, Action, Message, IsSent)
	FROM @tblTemp tbl
	WHERE tbl.sporttype IN (1,2)
		AND tbl.Action = 'KEYIN-AUTO'
		AND tbl.Message LIKE 'MarketId%'
 
	DELETE tbl
	FROM @tblBetbuilder tbl
	WHERE NOT EXISTS (SELECT TOP 1 b.Transid 
						FROM bettrans b WITH(NOLOCK) 
						WHERE b.matchid = tbl.matchid 
							AND b.BetCheck = tbl.marketid
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							AND b.bettype = 38)


	SET @NumberError = (SELECT COUNT(1) FROM @tblTemp)
	
	IF @NumberError = 0
		SET @NumberError = (SELECT COUNT(1) FROM @tblBetbuilder)

	-- send email in case calculation got issues
	SELECT matchid, matchcode, homeid, awayid, sporttype, IP, starttime, Action, Message
	FROM	@tblTemp
	WHERE	IsSent = 0
	UNION
	SELECT matchid, matchcode, homeid, awayid, sporttype, IP, starttime, Action, Message
	FROM @tblBetbuilder
	WHERE	IsSent = 0
/*
	UPDATE	s
	SET		s.IsSent = 1
	FROM	dbo.Settled_Message s 
		INNER JOIN @tblTemp t
			ON	s.MatchId = t.MatchId
				AND s.Action = t.Action
				AND s.Message = t.Message
	WHERE	t.IsSent = 0
	*/			
END
GO