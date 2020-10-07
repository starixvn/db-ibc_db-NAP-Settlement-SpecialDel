/*<info serverAlias="DBBAH-balancerecord" executers="" viewers="" isFunction="0"></info>*/
ALTER TRIGGER [dbo].[TG_BalanceTrigger_ProcessData_20180630]
   ON  [dbo].[BalanceTrigger_ProcessData]
   AFTER DELETE
AS 
/*
	Created: 
	DB: DBBAH.bodb02
	Task: 
	Revision:
		- 20200922@Kathy: Add column matchid, statusid, SettlementType, smawinlost, smacomm [Redmine:#138552]
*/
BEGIN

	Declare @minrid bigint, @maxrid bigint
	Declare @mindelay datetime, @maxdelay datetime
	Declare @custid_count int, @archive_rowcount int

	SELECT 
		@minrid = MIN(RowID), @maxrid = MAX(RowID),
		@maxdelay = MIN(ActionDate), @mindelay = MAX(ActionDate)
	FROM deleted --with (nolock)

	-- list of custid
	CREATE TABLE #custids (custid INT PRIMARY KEY)
	INSERT INTO  #custids SELECT DISTINCT custid FROM deleted 
	SET @custid_count = @@ROWCOUNT

	CREATE TABLE #PreCurrentBAL (custid INT PRIMARY KEY, NewBalance MONEY)
	-- prepare data to get lastest balance
	;WITH ListBAL AS (
		SELECT B.custid, NewBalance, RN = ROW_NUMBER() OVER (PARTITION BY B.custid ORDER BY RowID DESC) 
		FROM dbo.BalanceRecord B WITH (NOLOCK)
			INNER JOIN #custids C WITH (NOLOCK) ON B.custid = C.custid
		)
	INSERT INTO #PreCurrentBAL
	SELECT custid, NewBalance FROM ListBAL WHERE RN = 1
	OPTION (MAXDOP 4)

	CREATE TABLE #RawData (RowID BIGINT, custid INT, BalanceChanged MONEY)
		CREATE INDEX IX_RawData ON #RawData (custid, RowID)
	-- CurrentBAL = lastest balance
	;WITH CurrentBAL AS (
		SELECT c.custid, Balance = CASE WHEN ISNULL(p.custid, -1) = -1 THEN 0 ELSE p.NewBalance END
		FROM #custids c WITH (NOLOCK)
			LEFT JOIN #PreCurrentBAL p WITH (NOLOCK) ON c.custid = p.custid
		)
	-- prepare data to calculate Running Balance
	INSERT INTO #RawData
	SELECT RowID, custid, BalanceChanged FROM deleted
	UNION ALL
	SELECT 0, custid, Balance FROM CurrentBAL
	OPTION (MAXDOP 4)

	DROP TABLE #PreCurrentBAL

	-- since, these account gonna have new row already
	-- so, we can just archive all existing row now
		DELETE B WITH (ROWLOCK)
		OUTPUT
			DELETED.RowID, DELETED.custid, DELETED.transid, DELETED.bettype,
			DELETED.actual_stake, DELETED.winlost, DELETED.playercomm,
			DELETED.BalanceChanged, DELETED.NewBalance,
			DELETED.ActionDate, DELETED.ActionID, DELETED.[Action],
			DELETED.BTBalance,
			DELETED.matchid, DELETED.StatusId, DELETED.SettlementType,
			DELETED.swinlost, DELETED.mwinlost, DELETED.awinlost, DELETED.scomm, DELETED.acomm, DELETED.comm
		INTO BalanceRecord.dbo.BalanceRecord_bk (
			RowID, custid, transid, bettype, 
			actual_stake, winlost, playercomm,
			BalanceChanged, NewBalance, 
			ActionDate, ActionID, [Action],
			BTBalance,
			MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm
			)
		FROM dbo.BalanceRecord B WITH (INDEX=IX_custid)
			INNER JOIN #custids C WITH (PAGLOCK) ON B.custid = C.custid
		OPTION (MAXDOP 4)

		SET @archive_rowcount = @@ROWCOUNT
	
	DROP TABLE #custids


	;WITH
	-- Running Balance
	NewBalance AS (
		SELECT 
		NBcustid = t1.custid,
		NBRowID  = t1.RowID,
		NBBalance = SUM(t2.BalanceChanged)
		FROM #RawDATA t1 with (nolock)
			INNER JOIN #RawDATA t2 with (nolock) ON t1.custid = t2.custid AND t1.RowID >= t2.RowID
		GROUP BY t1.custid, t1.RowID
		--ORDER BY t1.custid, t1.RowID
	)

	-- Join Running Balance when insert into BalanceRecord
	INSERT INTO dbo.BalanceRecord (custid, transid, bettype, actual_stake, winlost, playercomm, balancechanged, newbalance, actiondate, actionid, [action], btbalance, MatchId, StatusId, SettlementType,
	swinlost, mwinlost, awinlost, scomm, acomm, comm)
	SELECT custid, transid, bettype, actual_stake, winlost, playercomm, balanceChanged, NBBalance, ActionDate, ActionID, [Action], BTBalance, MatchId, StatusId, SettlementType,
		swinlost, T.mwinlost, T.awinlost, T.scomm, T.acomm, T.comm
	FROM deleted T
		INNER JOIN NewBalance N ON T.RowID = N.NBRowID
	ORDER BY
		T.RowID
	OPTION (MAXDOP 4)

	-- BEGIN: Ploutos - Integration
	IF OBJECT_ID('Plo_BetTicket_Process', 'U') IS NOT NULL 
	BEGIN
		INSERT INTO [dbo].[Plo_BetTicket_Process]
			([custid]
			,[transid]
			,[bettype]
			,[ActionDate]
			,[ActionID]
			,[Action])
		SELECT [custid]
			,[transid]
			,[bettype]
			,[ActionDate]
			,[ActionID]
			,[Action]
		FROM deleted T
		WHERE [ActionID] IN (30,31)
	END
	
	-- END: Ploutos - Integration
	
	PRINT '*** ' + CAST(@custid_count AS VARCHAR(20)) + ' custids, archive ' + CAST(@archive_rowcount AS VARCHAR(50)) + ' rows' 
	+ ' ** insert ' + CAST(@@ROWCOUNT as varchar(20)) + ' rows **'
	+ ' Delay ' 
	+ CAST(DATEDIFF(ms, @maxdelay, CURRENT_TIMESTAMP) as varchar(20)) + ' / '
	+ CAST(DATEDIFF(ms, @mindelay, CURRENT_TIMESTAMP) as varchar(20)) + ' ms *** '

	DROP TABLE #RawData

END

