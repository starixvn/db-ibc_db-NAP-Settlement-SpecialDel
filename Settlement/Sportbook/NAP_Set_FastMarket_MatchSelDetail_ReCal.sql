 /*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail_ReCal]
(
	@MatchId INT
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBTXN/BODB02 
    
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

	CREATE TABLE #tblBettrans (TransId BIGINT, BetType SMALLINT, hdp1 SMALLMONEY, statusId TINYINT, isMarked BIT DEFAULT(0))
	CREATE INDEX IX_tblBettrans_bettype ON #tblBettrans (BetType)
	
	INSERT INTO @tblFMBettype(bettype, ResourceId)
	SELECT	BetType
			,CAST(BetType AS VARCHAR) + '__' AS ResourceId -- 22X__
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId = 9
	
	INSERT INTO @tblResultDetail (ResourceId, BetType, HomeValue, AwayValue)
	SELECT	r.ResourceId, t.BetType, r.HomeValue, r.AwayValue
	FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
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
	
	INSERT INTO #tblBettrans(TransId, bettype, hdp1, statusId)
	SELECT	b.transid, bettype, hdp1, statusID
	FROM	dbo.bettrans b WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND EXISTS(SELECT TOP 1 1 FROM @tblFMBettype WHERE bettype = b.bettype)
	
	UPDATE b 
		SET isMarked = 1
	FROM	#tblBettrans b
		INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
			ON b.TransId = mt.TransId

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
		SELECT CASE WHEN ResultStatus1st IS NULL AND TicketCount > 0 THEN REPLICATE('0', 50) ELSE ResultStatus1st END AS ResultStatus1st
			, CASE WHEN BetOption1st IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOption1st END AS BetOption1st
			, CASE WHEN ResultStatus2nd IS NULL AND TicketCount > 0 THEN REPLICATE('0', 50) ELSE ResultStatus2nd END AS ResultStatus2nd
			, CASE WHEN BetOption2nd IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOption2nd END AS BetOption2nd
			, ISNULL(t.BetType,tt.bettype) AS BetType
		FROM	cteBetOption t
			FULL OUTER JOIN (
				SELECT	b.bettype
						,SUM(CASE WHEN b.StatusID IN (101, 102) THEN 0 ELSE 1 END) AS TicketCount
				FROM	#tblBettrans b
				GROUP BY b.bettype
		)tt 
			ON	ISNULL(t.BetType,tt.bettype) = tt.bettype
	), betstatus AS (
		SELECT	bettype
				, hdp1 AS Position
				, SUM(CASE WHEN StatusID IN (101, 102) THEN 0 ELSE 1 END) AS TicketCount
				, MAX(CASE WHEN StatusID = 0 AND isMarked = 0 THEN 1 ELSE 0 END) AS TicketRunning
				, MAX(CASE WHEN statusId BETWEEN 0 AND 1 AND isMarked = 1 THEN 1 ELSE 0 END) AS TicketMarked
		FROM	#tblBettrans
		GROUP BY bettype, hdp1
	)
	SELECT	CAST(t.BetType AS SMALLINT) AS BetType
			, CAST(rs.Position AS TINYINT) AS Position
			, CAST(rs.Result AS TINYINT) AS Result
			, CASE 
				WHEN b.bettype IS NULL THEN 4 --N'No Ticket'
				ELSE CASE 
						WHEN TicketCount = 0 THEN 4 --N'No Ticket'
						WHEN b.TicketRunning > 0 THEN 2 -- N'Running'
						WHEN b.TicketMarked > 0 THEN 5 -- N'Marked'
						ELSE 3 --N'Calculated'
					 END  
			END AS TicketStatus
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
	LEFT JOIN betstatus b 
		ON	t.bettype = b.bettype 
			AND rs.Position = CASE 
								WHEN b.BetType <> 228 OR (b.BetType = 228 AND rs.Position <=44) THEN b.Position 
								ELSE b.Position + 1 -- for bettype 228, the position 45 is HT injury, 2nd starts at postion 46
							END
	WHERE	1 = CASE 
					WHEN t.bettype IN (222,224,227) AND rs.Position > 85 THEN 0
					ELSE 1
				END

	DROP TABLE #tblBettrans
END
GO
