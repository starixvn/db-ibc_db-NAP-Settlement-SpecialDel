USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Admin_3rdCalculate_s151_Refund_Admin]    Script Date: 08/07/2015 14:45:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Admin_3rdCalculate_s151_Refund_Admin    Script Date: 3/1/2013 4:00:55 AM ******/
/****** Object:  Stored Procedure dbo.Admin_3rdCalculate_s151_Refund_Admin    Script Date: 2/22/2013 5:35:49 PM ******/
ALTER PROCEDURE [dbo].[Admin_3rdCalculate_s151_Refund_Admin]
	@LeagueID int,
	@raceNumber int,
	@eventdate smalldatetime
AS
 -- 20100427@Henry: Update column StatusID of Bettrans,bettransm
 -- 20100521@Henry: Change to use StatusID instead of Status in WHERE statement
 -- 20120430@Victor: Apply new credit balance procedure
 -- 20130121@Elodie: Change link server DB02 to DBPRO
 -- 20150807@Kathy: Using new balance table (BalCreditOthersPending,BalDebitOthersPending) [Redmine:#40125]
 
BEGIN
	SET NOCOUNT ON;

	-- Get race no outright.orid
	DECLARE @Horse TABLE (orid int)
	INSERT INTO @Horse (orid)
	SELECT orid FROM DBPRO.bodb02.dbo.outright with (nolock)
	WHERE
		eventdate = @eventdate 
		AND LeagueID = @LeagueID 
		AND groupmatch = CAST(@raceNumber as varchar(20))
		AND oddsstatus IN ('running','suspend','closed')

-------------------------------------------------------------
---        CAPTURE value BALANCE before settlement        ---
---------------------------VVVV------------------------------
CREATE TABLE #BalanceBefore (custid int PRIMARY KEY, balance money)


        INSERT INTO #BalanceBefore
        SELECT custid, SUM(winlost-actual_stake+playercomm)
        FROM dbo.bettrans with (rowlock)
        WHERE matchid in (select orid from @Horse )
		and bettype IN (31, 32, 33) 
		and statusID NOT IN (101, 102)
        GROUP BY custid


	-- Refund ticket
	UPDATE dbo.bettrans with (ROWLOCK, UPDLOCK)
	SET
		[status] = 'Refund',
		statusID = 103,
		winlost=actual_stake,
		livehomescore=0, liveawayscore=0,
		awinlost=0, mwinlost=0, swinlost=0,
		playercomm=0, comm=0, acomm=0, scomm=0,
		ruben=1
	FROM @Horse h
    WHERE 
		bettrans.matchid = h.orid
        AND bettrans.bettype IN (31, 32, 33)
		--AND bettrans.[status] NOT IN (N'VOID', N'REJECT')
		AND bettrans.[statusID] NOT IN (101,102)

	--Refund for bettransm
	UPDATE dbo.bettransm with (ROWLOCK, UPDLOCK)
	SET
		[status] = 'Refund',
		statusID = 103,
		winlost=stake,
		livehomescore=0, liveawayscore=0,
		awinlost=0, mwinlost=0, swinlost=0,
		playercomm=0, comm=0, acomm=0, scomm=0,
		ruben=1
	FROM @Horse h
    WHERE 
		bettransm.matchid = h.orid
        AND bettransm.bettype IN (31, 32)
		--AND bettransm.[status] NOT IN (N'VOID', N'REJECT')
		AND bettransm.[statusID] NOT IN (101,102)


-------------------------------------------------------------
---         CAPTURE value BALANCE after settlement        ---
---------------------------VVVV------------------------------
CREATE TABLE #BalanceAfter (custid int PRIMARY KEY, balance money)

        INSERT INTO #BalanceAfter
        SELECT custid, SUM(winlost-actual_stake+playercomm)
        FROM dbo.bettrans with (rowlock)
        WHERE matchid in (select orid from @Horse )
		and bettype IN (31, 32, 33) 
		and statusID NOT IN (101, 102)
        GROUP BY custid
        
-------------------------------------------------------------
---                   compare BALANCE                     ---
---------------------------VVVV------------------------------
CREATE TABLE #Balance (custid int PRIMARY KEY, balance money, Increased bit)
CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

DECLARE @tblDebitPending TVP_BalanceList
DECLARE @tblCreditPending TVP_BalanceList

INSERT INTO #Balance
SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
FROM #BalanceBefore b
        INNER JOIN #BalanceAfter a ON b.custid = a.custid
WHERE b.balance <> a.balance


--INSERT INTO dbo.BalancePendingDebit (custid, balance)
--SELECT custid, ABS(balance)
--FROM #Balance
--WHERE Increased = 0

INSERT INTO @tblDebitPending (custID, balance)
SELECT	custid, ABS(balance)
FROM	#Balance
WHERE	Increased = 0

IF @@rowcount <> 0
	EXEC dbo.Dot_BalancePendingDebitIns 
		@BalancePending = @tblDebitPending
		,@Type			= 4 -- Others

--INSERT INTO dbo.BalancePendingCredit (custid, balance)
--SELECT custid, balance
--FROM #Balance
--WHERE Increased = 1     

INSERT INTO @tblCreditPending (custID, balance)
	SELECT	custid, balance
	FROM	#Balance
	WHERE	Increased = 1
	
IF @@rowcount <> 0
	EXEC dbo.Dot_BalancePendingCreditIns 
		@BalancePending = @tblCreditPending
		,@Type			= 4 -- Others
		
DROP TABLE #Balance
DROP TABLE #BalanceBefore
DROP TABLE #BalanceAfter

END

GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Refund_Admin] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Refund_Admin] TO [Dot_3rdparty] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Refund_Admin] TO [Dot_Admin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Admin_3rdCalculate_s151_Refund_Admin] TO [vnteam] AS [dbo]