 /*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail_ReCal]
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
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		
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
			SELECT 229, '22901H'
			UNION ALL
			SELECT 229, '22901A'
		) t
			ON r.ResourceId LIKE t.ResourceId
	WHERE	matchid = @matchid			
	
	UPDATE d
		SET HomeValue = CASE WHEN ISNULL(HomeValue,'') = '' THEN REPLICATE('0', 50) ELSE HomeValue END
		, AwayValue = CASE WHEN ISNULL(AwayValue,'') = '' THEN REPLICATE('0', 50) ELSE AwayValue END
	FROM @tblResultDetail d
	WHERE bettype IN (228, 229) AND (ISNULL(HomeValue,'') = '' OR ISNULL(AwayValue,'') = '')
	
	-- Always shows 228,229
	;WITH cteBetOption
	AS (
		SELECT  228 AS Bettype, CAST('22800' AS VARCHAR(50)) AS ResourceId
		UNION ALL
		SELECT  228 AS Bettype, CAST('22801' AS VARCHAR(50))
		UNION ALL
		SELECT  229 AS Bettype,  CAST('22900' AS VARCHAR(50))
		UNION ALL
		SELECT  229 AS Bettype, CAST('22901H' AS VARCHAR(50))
		UNION ALL
		SELECT  229 AS Bettype, CAST('22901A' AS VARCHAR(50))
	)
	INSERT INTO @tblResultDetail (ResourceId, BetType,  HomeValue, AwayValue)
	SELECT	c.ResourceId, c.Bettype, REPLICATE('0', 50) AS HomeValue, REPLICATE('0', 50) AS AwayValue
	FROM	cteBetOption c
		LEFT JOIN @tblResultDetail t
			ON c.ResourceId = t.ResourceId
	WHERE t.ResourceId IS NULL
	
	-- result detail of each bettype
	;WITH cteBetOption AS (
		SELECT	bettype
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '00' THEN HomeValue END) AS ResultStatus1st -- 22X00 
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01' THEN HomeValue END) AS BetOption1st -- 22X01
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '00' THEN AwayValue END) AS ResultStatus2nd -- 22X00 
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01' THEN AwayValue END) AS BetOption2nd -- 22X01

				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01H' THEN HomeValue END) AS BetOptionHome1st -- 22901H
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01H' THEN AwayValue END) AS BetOptionHome2nd -- 22901H
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01A' THEN HomeValue END) AS BetOptionAway1st -- 22901A
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01A' THEN AwayValue END) AS BetOptionAway2nd -- 22901A
		FROM	@tblResultDetail
		WHERE	ResourceId LIKE CAST(BetType AS VARCHAR) + '0[0-1]%' 
		GROUP BY bettype
		
	), cteResultStatus AS (
		SELECT CASE WHEN ResultStatus1st IS NULL THEN REPLICATE('0', 50) ELSE ResultStatus1st END AS ResultStatus1st
			, CASE WHEN BetOption1st IS NULL  THEN REPLICATE(CHAR(0), 50) ELSE BetOption1st END AS BetOption1st
			, CASE WHEN ResultStatus2nd IS NULL  THEN REPLICATE('0', 50) ELSE ResultStatus2nd END AS ResultStatus2nd
			, CASE WHEN BetOption2nd IS NULL THEN REPLICATE(CHAR(0), 50) ELSE BetOption2nd END AS BetOption2nd
			
			, CASE WHEN BetOptionHome1st IS NULL THEN REPLICATE(CHAR(0), 50) ELSE BetOptionHome1st END AS BetOptionHome1st
			, CASE WHEN BetOptionHome2nd IS NULL THEN REPLICATE(CHAR(0), 50) ELSE BetOptionHome2nd END AS BetOptionHome2nd
			, CASE WHEN BetOptionAway1st IS NULL THEN REPLICATE(CHAR(0), 50) ELSE BetOptionAway1st END AS BetOptionAway1st
			, CASE WHEN BetOptionAway2nd IS NULL THEN REPLICATE(CHAR(0), 50) ELSE BetOptionAway2nd END AS BetOptionAway2nd

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
		WHERE	f.pos < 45 AND t.BetType NOT IN (228, 229)

		UNION ALL
		
		SELECT	f.pos + 45 AS Position, f.bitmap AS Result, ff.ResultStatus AS ResultStatus
		FROM	dbo.f_Set_GetBytes(BetOption2nd) f
			INNER JOIN dbo.f_Set_GetChars(ResultStatus2nd) ff 
				ON	f.pos = ff.pos
		WHERE	f.pos < 45 AND t.BetType NOT IN (228, 229)
		
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

		UNION ALL

		SELECT	f.Position, f.Result, f.ResultStatus
		FROM (
			SELECT	fh.pos AS Position, (fh.ResultStatus + fa.ResultStatus * 10) AS Result, ff.ResultStatus AS ResultStatus
			FROM	dbo.f_Set_GetChars(BetOptionHome1st) fh
				INNER JOIN dbo.f_Set_GetChars(BetOptionAway1st) fa
					on fh.pos = fa.pos
				INNER JOIN dbo.f_Set_GetChars(ResultStatus1st) ff 
					ON	fh.pos = ff.pos
			WHERE	fh.pos < 46 AND t.BetType  = 229
		) f

		UNION ALL

		SELECT	f.Position, f.Result, f.ResultStatus
		FROM(
			SELECT	fh.pos + 46 AS Position, (fh.ResultStatus + fa.ResultStatus * 10) AS Result, ff.ResultStatus AS ResultStatus
			FROM	dbo.f_Set_GetChars(BetOptionHome2nd) fh
				INNER JOIN dbo.f_Set_GetChars(BetOptionAway2nd) fa
					ON fh.pos = fa.pos
				INNER JOIN dbo.f_Set_GetChars(ResultStatus2nd) ff 
					ON	fh.pos = ff.pos
			WHERE	fh.pos < 45 AND t.BetType = 229
		)f
		
	) rs
	WHERE	1 = CASE 
					WHEN t.bettype IN (222,224,227) AND rs.Position > 85 THEN 0
					ELSE 1
				END
END
GO
