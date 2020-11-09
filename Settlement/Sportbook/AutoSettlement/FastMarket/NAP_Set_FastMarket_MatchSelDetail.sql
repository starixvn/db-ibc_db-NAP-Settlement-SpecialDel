/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail] @MatchId INT
AS
/*
	Created: 20160427@Patrick
	Task: Fast market - Select match detail
	DB: DBTXN.BODB02
	Original:
	
	Revisions:
			- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]
			- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
			- 20200928@Helen: Implement New Bettype 288 Time Machine Over/Under [Redmine:#142001]
			- 20201106@Kathy: Add "Water Break" Concept to Fast Markets [Readmine:#143573]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tblFMBettype TABLE (BetType SMALLINT PRIMARY KEY, ResourceId VARCHAR(20))
	DECLARE @tblResultDetail TABLE (
		ResourceId			VARCHAR(20)
		,BetType			SMALLINT
		,SettlementStatusId TINYINT
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,OtherInfo			VARCHAR(50)
	)

	CREATE TABLE #tblBettrans (TransId BIGINT, BetType SMALLINT, hdp1 SMALLMONEY, statusId TINYINT, isMarked BIT DEFAULT(0))
	CREATE INDEX IX_tblBettrans_bettype ON #tblBettrans (BetType)
	
	INSERT INTO @tblFMBettype(bettype, ResourceId)
	SELECT	BetType
			,CAST(BetType AS VARCHAR) + '__' AS ResourceId -- 22X__
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId = 9
	
	INSERT INTO @tblResultDetail (ResourceId, BetType, SettlementStatusId, HomeValue, AwayValue, OtherInfo)
	SELECT	r.ResourceId, t.BetType, r.SettlementStatusId, r.HomeValue, r.AwayValue, r.OtherInfo
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

	-- Event Counter
	SELECT	CAST(f.Position AS TINYINT) AS Position
			,CAST(f.Result AS VARCHAR(8)) AS Result
	FROM	(
			SELECT	CASE 
						WHEN rCNT.ResourceId = '221CNT02' THEN 'Bit2' -- Goal
						WHEN rCNT.ResourceId = '221CNT03' THEN 'Bit3' -- Corner
						WHEN rCNT.ResourceId = '221CNT04' THEN 'Bit4' -- FreeKick
						WHEN rCNT.ResourceId = '221CNT05' THEN 'Bit5' -- GoalKick
						WHEN rCNT.ResourceId = '221CNT06' THEN 'Bit6' -- ThrowIn
						WHEN rCNT.ResourceId = '221CNT08' THEN 'Bit8' -- Penalty
					END AS EventCounter 
					,rCNT.Result
			FROM(
				SELECT	def.ResourceId
						,SUBSTRING(ISNULL(rCNT.HomeValue, REPLICATE(' ',45)),1,45) 
							+ SUBSTRING(ISNULL(rCNT.AwayValue, REPLICATE(' ',45)),1,45) AS Result
				FROM (VALUES ('221CNT02'), ('221CNT03'), ('221CNT04'), ('221CNT05'), ('221CNT06'), ('221CNT08')) AS def (ResourceId)
				OUTER APPLY (
					SELECT	ResourceId
							,HomeValue
							,AwayValue
					FROM	@tblResultDetail rCNT
					WHERE	rCNT.ResourceId = def.ResourceId 
				) rCNT
			)rCNT
		)AS rCNT
	PIVOT (
		MAX(rCNT.Result)
		FOR EventCounter IN (Bit1, Bit2, Bit3, Bit4, Bit5, Bit6, Bit7, Bit8)
	) AS pvt
	CROSS APPLY (
		SELECT	init.Position AS Position
				-- only show eventcounter if the inteval has been settled, if not --> set blank
				,(CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit8.ResultStatus AS VARCHAR(1)) ELSE ' ' END  -- Penalty
					+ ' ' -- Booking
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit6.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- ThrowIn
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit5.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- GoalKick
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit4.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- FreeKick
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit3.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- Corner
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit2.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- Goal
					+ ' ' -- None
				) AS Result				
		FROM(
			SELECT	init.pos AS Position
					,SUBSTRING(ISNULL(r00.HomeValue,REPLICATE(' ', 45)),1,45) 
						+ SUBSTRING(ISNULL(r00.AwayValue,REPLICATE(' ',45)),1,45) AS SettlementResult
			FROM	dbo.f_Set_GetChars(REPLICATE(' ',90)) init
				CROSS APPLY (
					SELECT	HomeValue
							,AwayValue
					FROM	@tblResultDetail r
					WHERE	r.ResourceId = '22100'
				)r00
		)init
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit2) f WHERE	init.Position = f.pos) bit2
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit3) f WHERE	init.Position = f.pos) bit3
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit4) f WHERE	init.Position = f.pos) bit4
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit5) f WHERE	init.Position = f.pos) bit5
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit6) f WHERE	init.Position = f.pos) bit6
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit8) f WHERE	init.Position = f.pos) bit8			
		OUTER APPLY (
			SELECT	f.ResultStatus AS SettlementStatus
			FROM	dbo.f_Set_GetChars(init.SettlementResult) f
			WHERE	init.Position = f.pos
		) r00
	)f

	-- Over/Under value of each situation 
	SELECT	OtherInfo AS HandicapValue
	FROM	@tblResultDetail
	WHERE	ResourceId = '22201'

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
			, CAST(rs.ResultStatus AS TINYINT) AS ResultStatus
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

	SELECT	9 AS GroupId
			,SUM(CASE WHEN statusId = 0 AND isMarked = 0 THEN 1 ELSE 0 END) AS betRunningCount
			,SUM(CASE WHEN statusId BETWEEN 111 AND 113 OR statusId = 103 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN statusId BETWEEN 0 AND 1 AND isMarked = 1 THEN 1 ELSE 0 END) AS betMarkedCount
	FROM	#tblBettrans

	-- Water break
	SELECT	r.ResourceId, r.HomeValue, r.AwayValue, r.OtherInfo
	FROM	@tblResultDetail r
	WHERE	r.ResourceId LIKE '221WB__'
END
GO
