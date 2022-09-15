ALTER PROCEDURE dbo.NAP_RollbackCricketList @CricketIds VARCHAR(MAX)
	, @Action VARCHAR(50)
	, @AdminId INT
	, @Reason VARCHAR(512) = ''
AS
/*  
	Created by: 20160114@Patrick
	Task: Rollback cricket list
	DB: DBTXN/bodb02   
	Revisions:  
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's Explanation:

	*/
BEGIN
	SET NOCOUNT ON
	IF ISNULL(@CricketIds , '') = ''
		RETURN

	CREATE TABLE #TmpCricketIds (TransId BIGINT, MatchId INT)

	INSERT INTO #TmpCricketIds(TransId, MatchId)
	SELECT CAST(value AS BIGINT), b.matchid
	FROM STRING_SPLIT(@CricketIds, ',') f
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON CAST(f.val AS BIGINT) = b.transid
		--INNER JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid
	WHERE b.bettype = 501
		AND b.statusID NOT IN (101, 102)
		--AND m.eventstatus = 'running'
		AND NOT EXISTS (SELECT 1 FROM CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) WHERE b.srecommend = s.custid)

	DECLARE @RowId INT, @MatchId INT, @TransIds VARCHAR(MAX), @StartTime DATETIME
	DECLARE @TmpData TABLE(RowId INT IDENTITY(1,1), MatchId INT, TransIds VARCHAR(MAX))

	--List out ticket which has been terminated when updating
	INSERT INTO @TmpData(MatchId, TransIds)
	SELECT MatchId, STUFF((SELECT ',' + CAST(TransId AS VARCHAR(50))
							FROM #TmpCricketIds tt WITH(NOLOCK) WHERE t.MatchId = tt.MatchId
							FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
	FROM #TmpCricketIds t
	WHERE MatchId IS NOT NULL
	GROUP BY MatchId

	SELECT @RowId = 1, @StartTime = GETDATE()
	WHILE EXISTS (SELECT TOP 1 1 FROM @TmpData WHERE RowId = @RowId)
	BEGIN
		SELECT @MatchId = MatchId, @TransIds = TransIds
		FROM @TmpData WHERE RowId = @RowId
		SET @RowId = @RowId + 1

		--insert data to API log
		EXEC dbo.NAP_Admin_SettlementService_Ins @ServiceType = 1
			, @MatchId = NULL
			, @TransIds = @TransIds
			, @Action = @Action
			, @ServiceStatus = 0 --wating
			, @AdminId = @AdminId
			, @StartTime = @StartTime
			, @EndTime = NULL
			, @Reason = @Reason
	END

	DROP TABLE #TmpCricketIds

END
GO