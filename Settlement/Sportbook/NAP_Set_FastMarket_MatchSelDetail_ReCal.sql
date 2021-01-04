 /*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail_ReCal]
(
	@MatchId INT
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20201211@Max: Support to Re-calculate Settled Tickets [Redmine: #145669]
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tblFMBettype TABLE (BetType SMALLINT PRIMARY KEY, ResourceId VARCHAR(20))
	DECLARE @tblResultDetail TABLE (
		ResourceId			VARCHAR(20)
		,BetType			SMALLINT
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
	)
	
	INSERT INTO @tblFMBettype(bettype, ResourceId)
	SELECT	BetType
			,CAST(BetType AS VARCHAR) + '__' AS ResourceId -- 22X__
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId = 9
	
	INSERT INTO @tblResultDetail (ResourceId, BetType, HomeValue, AwayValue)
	SELECT	r.ResourceId, t.BetType, r.HomeValue, r.AwayValue
	FROM	dbo.ResultDetail r WITH(NOLOCK)
		INNER JOIN (
			SELECT	BetType, ResourceId
			FROM	@tblFMBettype t
			UNION ALL
			SELECT 221, '221CNT__'
			UNION ALL
			SELECT 0, '221WB__'
		) t
			ON r.ResourceId LIKE t.ResourceId
	WHERE	matchid = @matchid			
	
	UPDATE d
		SET HomeValue = CASE WHEN ISNULL(HomeValue,'') = '' THEN REPLICATE('0', 50) ELSE HomeValue END
		, AwayValue = CASE WHEN ISNULL(AwayValue,'') = '' THEN REPLICATE('0', 50) ELSE AwayValue END
	FROM @tblResultDetail d
	WHERE bettype = 228 AND (ISNULL(HomeValue,'') = '' OR ISNULL(AwayValue,'') = '')
	
	-- Always shows 228
	IF NOT EXISTS (SELECT TOP (1) 1 FROM @tblResultDetail WHERE ResourceId IN ('22800'))
	BEGIN
		INSERT INTO @tblResultDetail (ResourceId, BetType,  HomeValue, AwayValue)
		SELECT '22800', 228, REPLICATE('0', 50),REPLICATE('0', 50)
	END
	
	IF NOT EXISTS (SELECT TOP (1) 1 FROM @tblResultDetail WHERE ResourceId IN ('22801'))
	BEGIN
		INSERT INTO @tblResultDetail (ResourceId, BetType,  HomeValue, AwayValue)
		SELECT '22801', 228, REPLICATE('0', 50),REPLICATE('0', 50)
	END
	
	-- result detail of each bettype
	;WITH cteBetOption AS (
		SELECT	bettype
				, MAX(CASE WHEN ResourceId % 100 = 0 THEN HomeValue END) AS ResultStatus1st -- 22X00 
				, MAX(CASE WHEN ResourceId % 100 = 1 THEN HomeValue END) AS BetOption1st -- 22X01
				, MAX(CASE WHEN ResourceId % 100 = 0 THEN AwayValue END) AS ResultStatus2nd -- 22X00 
				, MAX(CASE WHEN ResourceId % 100 = 1 THEN AwayValue END) AS BetOption2nd -- 22X01
		FROM	@tblResultDetail
		WHERE	ResourceId LIKE CAST(BetType AS VARCHAR) + '__'
		GROUP BY bettype
		
	), cteResultStatus AS (
		SELECT CASE WHEN ResultStatus1st IS NULL THEN REPLICATE('0', 50) ELSE ResultStatus1st END AS ResultStatus1st
			, CASE WHEN BetOption1st IS NULL  THEN REPLICATE(CHAR(0), 50) ELSE BetOption1st END AS BetOption1st
			, CASE WHEN ResultStatus2nd IS NULL  THEN REPLICATE('0', 50) ELSE ResultStatus2nd END AS ResultStatus2nd
			, CASE WHEN BetOption2nd IS NULL THEN REPLICATE(CHAR(0), 50) ELSE BetOption2nd END AS BetOption2nd
			, BetType
		FROM	cteBetOption t
	)
	SELECT	CAST(t.BetType AS SMALLINT) AS BetType
			, CAST(rs.Position AS TINYINT) AS Position
			, CAST(rs.Result AS TINYINT) AS Result
			,rs.ResultStatus
	FROM	cteResultStatus t 
	CROSS APPLY (
		SELECT	f.pos AS Position, f.bitmap AS Result, ff.ResultStatus AS ResultStatus
		FROM	dbo.f_Set_GetBytes(BetOption1st) f
			INNER JOIN dbo.f_Set_GetChars(ResultStatus1st) ff 
				ON	f.pos = ff.pos
		WHERE	f.pos < 45 AND t.BetType <> 228

		UNION ALL
		
		SELECT	f.pos + 45 AS Position, f.bitmap AS Result, ff.ResultStatus AS ResultStatus
		FROM	dbo.f_Set_GetBytes(BetOption2nd) f
			INNER JOIN dbo.f_Set_GetChars(ResultStatus2nd) ff 
				ON	f.pos = ff.pos
		WHERE	f.pos < 45 AND t.BetType <> 228
		
		UNION ALL
		
		SELECT	f.pos AS Position, f.ResultStatus AS Result, ff.ResultStatus AS ResultStatus
		FROM	dbo.f_Set_GetChars(BetOption1st) f
			INNER JOIN dbo.f_Set_GetChars(ResultStatus1st) ff 
				ON	f.pos = ff.pos
		WHERE	f.pos < 46 AND t.BetType = 228

		UNION ALL
		
		SELECT	f.pos + 46 AS Position, f.ResultStatus AS Result, ff.ResultStatus AS ResultStatus
		FROM	dbo.f_Set_GetChars(BetOption2nd) f
			INNER JOIN dbo.f_Set_GetChars(ResultStatus2nd) ff 
				ON	f.pos = ff.pos
		WHERE	f.pos < 45 AND t.BetType = 228
		
	) rs
	WHERE	1 = CASE 
					WHEN t.bettype IN (222,224,227) AND rs.Position > 85 THEN 0
					ELSE 1
				END
END
GO
