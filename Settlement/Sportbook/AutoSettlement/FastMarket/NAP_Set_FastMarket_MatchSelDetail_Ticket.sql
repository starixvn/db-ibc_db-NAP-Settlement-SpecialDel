/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail_Ticket] 
	@MatchId	INT
	,@Resources  VARCHAR(MAX) = ''
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
	
	DECLARE @handle INT, @xmlData XML
	
	SET @xmlData = CAST( @Resources AS XML )

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
	
	EXEC sp_xml_preparedocument @handle OUTPUT, @Resources
	INSERT INTO @tblResultDetail (ResourceId, HomeValue, AwayValue, BetType)
	SELECT r, h, a, b
	FROM OPENXML(@handle,'root/r',1) WITH(r   VARCHAR(20)
										 ,h   SMALLMONEY
										 ,a   TINYINT
										 ,b   INT
									) tbl
	EXEC sp_xml_removedocument @handle

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
		SELECT CASE WHEN ResultStatus1st IS NULL AND TicketCount > 0 THEN REPLICATE('0', 50) ELSE ResultStatus1st END AS ResultStatus1st
			, CASE WHEN BetOption1st IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOption1st END AS BetOption1st
			, CASE WHEN ResultStatus2nd IS NULL AND TicketCount > 0 THEN REPLICATE('0', 50) ELSE ResultStatus2nd END AS ResultStatus2nd
			, CASE WHEN BetOption2nd IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOption2nd END AS BetOption2nd

			, CASE WHEN BetOptionHome1st IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOptionHome1st END AS BetOptionHome1st
			, CASE WHEN BetOptionHome2nd IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOptionHome2nd END AS BetOptionHome2nd
			, CASE WHEN BetOptionAway1st IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOptionAway1st END AS BetOptionAway1st
			, CASE WHEN BetOptionAway2nd IS NULL AND TicketCount > 0 THEN REPLICATE(CHAR(0), 50) ELSE BetOptionAway2nd END AS BetOptionAway2nd

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
	LEFT JOIN betstatus b 
		ON	t.bettype = b.bettype 
			AND rs.Position = CASE 
								WHEN b.BetType NOT IN (228, 229) THEN b.Position 
								ELSE CASE 
										WHEN rs.Position <= 44 THEN b.Position
										WHEN rs.Position > 45 THEN b.Position + 1 -- for bettype 228, the position 45 is HT injury, 2nd starts at postion 46
										ELSE -1 -- injury time
									END
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

END
GO
