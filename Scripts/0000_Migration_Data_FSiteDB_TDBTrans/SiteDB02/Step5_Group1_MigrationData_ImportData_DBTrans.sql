/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - DBTRANS
    DB: DBCTG-bodb02

	 Revisions:
		- 20221107@Victoria: INSERT from the copy all data of the following tables [Redmineid:#180033] 
							 BalCreditCasino,BalCreditOthers,BalCreditSports,BalCreditTransfer,BalDebitCasino,BalDebitOthers,BalDebitSports,
							 BalDebitTransfer,BalNetPosition
*/

USE bodb02
GO
------------------------------------------------
------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
		--, @batch INT = 2000

--BalCreditCasino
CREATE TABLE #Bal_tmp (custid INT,Balance MONEY)
CREATE TABLE #Bal_tmp_insert (custid INT,Balance MONEY, rid INT IDENTITY (1,1) PRIMARY KEY)
CREATE TABLE #Bal_tmp_update (custid INT,Balance MONEY, rid INT IDENTITY (1,1) PRIMARY KEY)

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalCreditCasino_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalCreditCasino] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalCreditCasino] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalCreditCasino] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	--1. BalCreditCasino
	INSERT INTO [dbo].[BalCreditCasino] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

---------2. BalCreditOthers 
TRUNCATE TABLE #Bal_tmp
TRUNCATE TABLE #Bal_tmp_update
TRUNCATE TABLE #Bal_tmp_insert

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalCreditOthers_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalCreditOthers] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalCreditOthers] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalCreditOthers] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalCreditOthers] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

------------3. BalCreditSports
TRUNCATE TABLE #Bal_tmp
TRUNCATE TABLE #Bal_tmp_update
TRUNCATE TABLE #Bal_tmp_insert

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalCreditSports_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalCreditSports] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalCreditSports] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalCreditSports] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalCreditSports] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

----------4. BalCreditTransfer
TRUNCATE TABLE #Bal_tmp
TRUNCATE TABLE #Bal_tmp_update
TRUNCATE TABLE #Bal_tmp_insert

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalCreditTransfer_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalCreditTransfer] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalCreditTransfer] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalCreditTransfer] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalCreditTransfer] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
----------------5. BalDebitCasino
TRUNCATE TABLE #Bal_tmp
TRUNCATE TABLE #Bal_tmp_update
TRUNCATE TABLE #Bal_tmp_insert

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalDebitCasino_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalDebitCasino] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalDebitCasino] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalDebitCasino] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalDebitCasino] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

-----------6.BalDebitOthers
TRUNCATE TABLE #Bal_tmp
TRUNCATE TABLE #Bal_tmp_update
TRUNCATE TABLE #Bal_tmp_insert

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalDebitOthers_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalDebitOthers] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalDebitOthers] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalDebitOthers] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalDebitOthers] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--------7.BalDebitSports
TRUNCATE TABLE #Bal_tmp
TRUNCATE TABLE #Bal_tmp_update
TRUNCATE TABLE #Bal_tmp_insert

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalDebitSports_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalDebitSports] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalDebitSports] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalDebitSports] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalDebitSports] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

----- 8.BalDebitTransfer
TRUNCATE TABLE #Bal_tmp
TRUNCATE TABLE #Bal_tmp_update
TRUNCATE TABLE #Bal_tmp_insert

INSERT INTO #Bal_tmp (custid, Balance)
SELECT custid, Balance
FROM DBSIG02.SiteDB02tmp.dbo.BalDebitTransfer_Copy WITH (NOLOCK)

INSERT INTO #Bal_tmp_update (custid,Balance)
SELECT b.custid, b.Balance 
FROM #Bal_tmp b
	INNER JOIN [dbo].[BalDebitTransfer] main WITH (NOLOCK) ON b.custid = main.custid

INSERT INTO #Bal_tmp_insert (custid,Balance)
SELECT b.custid, b.Balance
FROM #Bal_tmp b
	LEFT JOIN [dbo].[BalDebitTransfer] main WITH (NOLOCK) ON b.custid = main.custid
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_update)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	UPDATE main
		SET [Balance] = bal.[Balance]
	FROM [dbo].[BalDebitTransfer] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #Bal_tmp_update bal ON bal.custid = main.custid
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #Bal_tmp_insert)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalDebitTransfer] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM #Bal_tmp_insert bal WITH (NOLOCK)
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
---------- 9.BalNetPosition

CREATE TABLE #BalNetPosition(
	[CustID] [int] NOT NULL,
	[MatchID] [int] NOT NULL,
	[Bettype] [smallint] NOT NULL,
	[Credit] [money] NOT NULL,
	[Debit] [money] NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL
 )

CREATE TABLE #BalNetPosition_insert ([CustID] [int],[MatchID] [int],[Bettype] [smallint], rid INT IDENTITY (1,1) PRIMARY KEY)
CREATE TABLE #BalNetPosition_update ([CustID] [int],[MatchID] [int],[Bettype] [smallint],[Credit] [money],[Debit] [money],[CreatedDate] [datetime],[ModifiedDate] [datetime], rid INT IDENTITY (1,1) PRIMARY KEY)

INSERT INTO #BalNetPosition ([CustID], [MatchID], [Bettype], [Credit], [Debit], [CreatedDate], [ModifiedDate])
SELECT [CustID], [MatchID], [Bettype], [Credit], [Debit], [CreatedDate], [ModifiedDate]
FROM DBSIG02.SiteDB02tmp.dbo.BalNetPosition_Copy WITH (NOLOCK)

INSERT INTO #BalNetPosition_update ([CustID], [MatchID], [Bettype], [Debit], [Credit], [CreatedDate], [ModifiedDate])
SELECT b.[CustID], b.[MatchID], b.[Bettype], b.[Debit],b.[Credit],b.[CreatedDate],b.[ModifiedDate]
FROM #BalNetPosition b
	INNER JOIN [dbo].[BalNetPosition] main WITH (NOLOCK) ON b.custid = main.custid 
				AND b.MatchID = main.MatchID 
				AND b.Bettype = main.Bettype

INSERT INTO #BalNetPosition_insert ([CustID], [MatchID], [Bettype])
SELECT b.[CustID], b.[MatchID], b.[Bettype]
FROM #BalNetPosition b
	LEFT JOIN [dbo].[BalNetPosition] main WITH (NOLOCK) ON b.custid = main.custid 
				AND b.MatchID = main.MatchID 
				AND b.Bettype = main.Bettype
WHERE main.custid IS NULL

-- START to update first
SET @MaxRow = (SELECT MAX(rid) FROM #BalNetPosition_update)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	UPDATE main
		SET [Debit]=bal.[Debit],[Credit]=bal.[Credit],[CreatedDate]=bal.[CreatedDate],[ModifiedDate]=bal.[ModifiedDate]
	FROM [dbo].[BalNetPosition] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #BalNetPosition_update bal ON bal.custid = main.custid AND bal.MatchID = main.MatchID AND bal.Bettype = main.Bettype
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #BalNetPosition_insert)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[BalNetPosition] ([CustID], [MatchID], [Bettype], [Debit], [Credit], [CreatedDate], [ModifiedDate])
	SELECT bal.[CustID], bal.[MatchID], bal.[Bettype], main.[Debit], main.[Credit], main.[CreatedDate], main.[ModifiedDate]
	FROM #BalNetPosition_insert bal
		INNER JOIN #BalNetPosition main ON bal.custid = main.custid AND bal.MatchID = main.MatchID AND bal.Bettype = main.Bettype
	WHERE bal.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
