USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Set_SettledErrorSel] @AdminId INT
	,@Top INT = 10
AS
/*	Creator: Kathy
	Date: 20140108
	Task: Get error message when settlement failed
	DB: DBTXN/BODB02
	Original: 

	History:
		- 20140404@Kathy: Get all notification messages for each group (Soccer, Other Sports)
		- 20170112@Kathy: Add AdminId 111 into Soccer Team [Redmine:#70302]
		
	Param's Explanation:
		@Top: 0 -- Get all
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @numberRow INT
	DECLARE @tblSoccerTeam TABLE (custid INT)
	DECLARE @tblOtherSportTeam TABLE (custid INT)
	
	DECLARE	@IsSoccer			BIT = 0
			,@IsOtherSport		BIT = 0
	
	DECLARE @tblTemp TABLE (
		AdminId INT
		,matchcode NVARCHAR(50)
		,homeid INT
		,awayid INT
		,Action VARCHAR(10)
		,Message VARCHAR(300)
		,starttime DATETIME
		,isRead BIT
		)
		
	INSERT INTO @tblSoccerTeam
	SELECT	14228954			-- Keyscore1	
	UNION ALL SELECT 14228977	-- Keyscore2		
	UNION ALL SELECT 8068543	-- TRACY			
	UNION ALL SELECT 384559		-- YONG 
	UNION ALL SELECT 12978541	-- pgmHarris 
	--UNION ALL SELECT 9503076	-- pgmJacob 
	UNION ALL SELECT 4338171	-- pgmKaka 
	UNION ALL SELECT 111		-- Auto Settlement


	INSERT INTO @tblOtherSportTeam
	SELECT 462523 -- IRENE		
	UNION ALL SELECT 1590728	-- OSAMMY	
	UNION ALL SELECT 622158		-- OSBONNIE		
	UNION ALL SELECT 626446		-- OSFIONA		
	UNION ALL SELECT 283830		-- OSJOHNSON1	
	UNION ALL SELECT 859948		-- OSMICKEY	
	UNION ALL SELECT 5234866	-- OSVENNY
	UNION ALL SELECT 12978541	-- pgmHarris 
	--UNION ALL SELECT 9503076	-- pgmJacob 
	UNION ALL SELECT 4338171	-- pgmKaka 

	
	IF EXISTS (SELECT TOP 1 1 FROM @tblSoccerTeam WHERE custid = @AdminId)
		SET @IsSoccer = 1
	ELSE IF EXISTS (SELECT TOP 1 1 FROM @tblOtherSportTeam WHERE custid = @AdminId)
		SET @IsOtherSport = 1
	
	INSERT INTO @tblTemp(AdminId, matchcode, homeid, awayid, Action, Message, starttime, isRead)	
	SELECT s.AdminId, m.matchcode, m.homeid, m.awayid, s.Action, s.Message, s.Starttime, s.IsRead
	FROM Settled_Message s WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = s.MatchId
	WHERE (
			(
				s.AdminId IN (SELECT custid FROM @tblSoccerTeam) 
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
		
	SET @numberRow = (SELECT COUNT(1) FROM @tblTemp)

	SELECT ISNULL(@numberRow, 0) AS NumberRow
	
	IF @Top = 0
	BEGIN
		SELECT *
		FROM	@tblTemp
		ORDER BY IsRead
			,CASE WHEN Action <> 'KEYIN-AUTO' THEN 0 ELSE 1 END
			,Starttime
			,CASE 
				WHEN AdminId = @AdminId THEN 0
				ELSE 1
			END
	END
	ELSE
	BEGIN
		SELECT  TOP (@Top) *
		FROM	@tblTemp
		ORDER BY IsRead
			,CASE WHEN Action <> 'KEYIN-AUTO' THEN 0 ELSE 1 END
			,Starttime
			,CASE 
				WHEN AdminId = @AdminId THEN 0
				ELSE 1
				END
	END

	UPDATE	dbo.Settled_Message WITH (UPDLOCK, ROWLOCK)
	SET		isRead = 1
	WHERE	(AdminId = @AdminId 
				OR (AdminId = 111 AND @IsSoccer = 1)
			)
			AND IsRead = 0
END



GO
GRANT EXECUTE ON [dbo].[NAP_Set_SettledErrorSel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Set_SettledErrorSel] TO [vnteam] AS [dbo]