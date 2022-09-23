/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail_Ticket] 
	@MatchId	INT = 55099707
AS
/*
	 Created by: 20220719@Louisa
     Task: Scale Out BetTrans [Redmine:#175251]
     DB: DBTXN/BODB02 
	
	Revisions:
		- 20220719@Louisa: Initial- Get ResourceId and Count ticket Status [Redmine:#175251]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @IsCentral BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	DECLARE @tblFMBettype	TABLE (BetType SMALLINT PRIMARY KEY)
	DECLARE @tblResultDetail TABLE (ResourceId	VARCHAR(20)	,BetType SMALLINT )

	CREATE TABLE #tblBettrans (TransId BIGINT, BetType SMALLINT, hdp1 SMALLMONEY, statusId TINYINT, isMarked BIT DEFAULT(0))
	CREATE INDEX IX_tblBettrans_bettype ON #tblBettrans (BetType)
	
	INSERT INTO @tblFMBettype(bettype)
	SELECT	BetType
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId = 9	
 
	INSERT INTO #tblBettrans(TransId, bettype, hdp1, statusId)
	SELECT	b.transid, bettype, hdp1, statusID
	FROM	dbo.bettrans b WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			AND EXISTS(SELECT TOP 1 1 FROM @tblFMBettype WHERE bettype = b.bettype)
	
	UPDATE b 
		SET isMarked = 1
	FROM	#tblBettrans b
		INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
			ON b.TransId = mt.TransId
	
	SELECT	9 AS GroupId
	,SUM(CASE WHEN statusId = 0 AND isMarked = 0 THEN 1 ELSE 0 END) AS betRunningCount
	,SUM(CASE WHEN statusId BETWEEN 111 AND 113 OR statusId = 103 THEN 1 ELSE 0 END) AS betSettledCount
	,SUM(CASE WHEN statusId BETWEEN 0 AND 1 AND isMarked = 1 THEN 1 ELSE 0 END) AS betMarkedCount
	FROM	#tblBettrans

	;WITH cte_FMResources ( bettype, ResourceID ) AS 
	(
		SELECT 221			 , '22100'	
		UNION ALL SELECT 222 , '22200'
		UNION ALL SELECT 223 , '22300'
		UNION ALL SELECT 224 , '22400'
		UNION ALL SELECT 225 , '22500'
		UNION ALL SELECT 226 , '22600'
		UNION ALL SELECT 227 , '22700'
		UNION ALL SELECT 221 , '22101'	
		UNION ALL SELECT 222 , '22201'
		UNION ALL SELECT 223 , '22301'
		UNION ALL SELECT 224 , '22401'
		UNION ALL SELECT 225 , '22501'
		UNION ALL SELECT 226 , '22601'
		UNION ALL SELECT 227 , '22701'
		UNION ALL SELECT 228 , '22800'
		UNION ALL SELECT 228 , '22801'
		UNION ALL SELECT 229 , '22900'
		UNION ALL SELECT 229 , '22901'
		UNION ALL SELECT 229 , '22901H'
		UNION ALL SELECT 229 , '22901A'
	)

	INSERT INTO @tblResultDetail ( ResourceId, BetType )
	SELECT c.ResourceId, b.BetType 
	FROM cte_FMResources c  
		CROSS APPLY (	SELECT TOP 1 bettype FROM #tblBettrans b WHERE b.bettype = c.bettype ) b

	;WITH cteBetOption AS (
		SELECT	bettype
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '00' THEN REPLICATE('0', 50) END) AS ResultStatus1st -- 22X00 
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01' THEN REPLICATE(CHAR(0), 50) END) AS BetOption1st -- 22X01
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '00' THEN REPLICATE('0', 50) END) AS ResultStatus2nd -- 22X00 
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01' THEN REPLICATE(CHAR(0), 50) END) AS BetOption2nd -- 22X01
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01H' THEN REPLICATE(CHAR(0), 50)END) AS BetOptionHome1st -- 22901H
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01H' THEN REPLICATE(CHAR(0), 50)END) AS BetOptionHome2nd -- 22901H
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01A' THEN REPLICATE(CHAR(0), 50)END) AS BetOptionAway1st -- 22901A
				, MAX(CASE WHEN ResourceId LIKE CAST(bettype AS VARCHAR) + '01A' THEN REPLICATE(CHAR(0), 50)END) AS BetOptionAway2nd -- 22901A

		FROM	@tblResultDetail
		WHERE	ResourceId LIKE CAST(BetType AS VARCHAR) + '0[0-1]%' 
		GROUP BY bettype		
	)
	-- result detail of each bettype
	,betstatus AS (
		SELECT	bettype
				, hdp1 AS Position
				, SUM(CASE WHEN StatusID IN (101, 102) THEN 0 ELSE 1 END) AS TicketCount
				, MAX(CASE WHEN StatusID = 0 AND isMarked = 0 THEN 1 ELSE 0 END) AS TicketRunning
				, MAX(CASE WHEN statusId BETWEEN 0 AND 1 AND isMarked = 1 THEN 1 ELSE 0 END) AS TicketMarked
		FROM	#tblBettrans
		GROUP BY bettype, hdp1
	)
	 
		SELECT b.bettype, rs.Position , s.TicketCount, s.TicketRunning, s.TicketMarked
		FROM cteBetOption b 
			CROSS APPLY (
						SELECT	f.pos AS Position, f.bitmap AS Result, ff.ResultStatus AS ResultStatus
						FROM	dbo.f_Set_GetBytes(BetOption1st) f
							INNER JOIN dbo.f_Set_GetChars(ResultStatus1st) ff 
								ON	f.pos = ff.pos
						WHERE	f.pos < 45 AND b.BetType NOT IN (228, 229)

						UNION ALL
		
						SELECT	f.pos + 45 AS Position, f.bitmap AS Result, ff.ResultStatus AS ResultStatus
						FROM	dbo.f_Set_GetBytes(BetOption2nd) f
							INNER JOIN dbo.f_Set_GetChars(ResultStatus2nd) ff 
								ON	f.pos = ff.pos
						WHERE	f.pos < 45 AND b.BetType NOT IN (228, 229)
		
						UNION ALL
		
						SELECT	f.pos AS Position, f.ResultStatus AS Result, ff.ResultStatus AS ResultStatus
						FROM	dbo.f_Set_GetChars(BetOption1st) f
							INNER JOIN dbo.f_Set_GetChars(ResultStatus1st) ff 
								ON	f.pos = ff.pos
						WHERE	f.pos < 46 AND b.BetType = 228

						UNION ALL

						SELECT	f.pos + 46 AS Position, f.ResultStatus AS Result, ff.ResultStatus AS ResultStatus
						FROM	dbo.f_Set_GetChars(BetOption2nd) f
							INNER JOIN dbo.f_Set_GetChars(ResultStatus2nd) ff 
								ON	f.pos = ff.pos
						WHERE	f.pos < 45 AND b.BetType = 228

						UNION ALL

						SELECT	f.Position, f.Result, f.ResultStatus
						FROM (
							SELECT	fh.pos AS Position, (fh.ResultStatus + fa.ResultStatus * 10) AS Result, ff.ResultStatus AS ResultStatus
							FROM	dbo.f_Set_GetChars(BetOptionHome1st) fh
								INNER JOIN dbo.f_Set_GetChars(BetOptionAway1st) fa
									on fh.pos = fa.pos
								INNER JOIN dbo.f_Set_GetChars(ResultStatus1st) ff 
									ON	fh.pos = ff.pos
							WHERE	fh.pos < 46 AND b.BetType  = 229
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
							WHERE	fh.pos < 45 AND b.BetType = 229
						)f

				) rs
		LEFT JOIN betstatus s 
			ON	s.bettype = b.bettype 
				AND rs.Position = CASE 
									WHEN b.BetType NOT IN (228, 229) THEN s.Position 
									ELSE CASE 
											WHEN rs.Position <= 44 THEN s.Position
											WHEN rs.Position > 45 THEN s.Position + 1 -- for bettype 228, the position 45 is HT injury, 2nd starts at postion 46
											ELSE -1 -- injury time
										END
								END

		WHERE	1 = CASE 
					WHEN b.bettype IN (222,224,227) AND rs.Position > 85 THEN 0
					ELSE 1
				END

	DROP TABLE #tblBettrans
END
GO
