USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Admin_3rdCalculate_s151_Reject_Admin]    Script Date: 08/07/2015 14:57:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Admin_3rdCalculate_s151_Reject_Admin    Script Date: 3/1/2013 4:00:56 AM ******/
/****** Object:  Stored Procedure dbo.Admin_3rdCalculate_s151_Reject_Admin    Script Date: 2/22/2013 5:35:49 PM ******/
ALTER PROCEDURE [dbo].[Admin_3rdCalculate_s151_Reject_Admin]
	@LeagueID int,
	@raceNumber tinyint,
    @EventDate smalldatetime
AS
/*
Created by:[]
Date:
Task: Reject HR bets
DB: DBTXN/BODB02
Revisions:
   - 20101007@Henry: Change column transid from INT to BIGINT
   - 20120430@AllenWu: Apply new credit balance procedure
   - 20120717@Cooper: add try catch 
   - 20130121@Elodie: Change link server DB02 to DBPRO
   - 20150807@Kathy: Using new balance table (BalCreditOthersPending) [Redmine:#40125]
*/
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY 
	-- get outright.orid
	DECLARE @Horse TABLE (orid int)
	INSERT INTO @Horse (orid)
	SELECT orid FROM DBPRO.bodb02.dbo.outright with (nolock)
	WHERE
		eventdate = @eventdate 
		AND LeagueID = @LeagueID 
		AND groupmatch = CAST(@raceNumber as varchar(20))
		AND oddsstatus = 'closed'

-------------------------------------------------------------
---        CAPTURE value BALANCE before settlement        ---
---------------------------VVVV------------------------------
CREATE TABLE #BalanceBefore (custid int PRIMARY KEY, balance money)
Declare @TotalAccount int, @TotalAccount_BalanceUpdate int
 
        INSERT INTO #BalanceBefore
        SELECT custid,sum( winlost-actual_stake+playercomm)
        FROM dbo.bettrans with (rowlock)
        WHERE matchid in (select orid from @Horse)
        AND bettrans.bettype IN (31, 32, 33) 
        and statusID =1	-- waiting
		Group by custid
 
	select @TotalAccount = count(distinct custid) from #BalanceBefore

	declare @tbltransid as table (transid bigint)

	-- reject ticket
	UPDATE dbo.bettrans with (ROWLOCK, UPDLOCK)
	SET
		[status] = N'reject',
		statusID = 101,
		winlost = actual_stake,
		awinlost = 0, mwinlost = 0, swinlost = 0,
		playercomm = 0, comm = 0, acomm = 0, scomm = 0,
		ruben = 1,
		transdesc = 'system reject waiting bet ' + transdesc
	output deleted.transid into @tbltransid
	FROM @Horse h	
    WHERE 
		bettrans.matchid = h.orid
        AND bettrans.bettype IN (31, 32, 33)
		--AND bettrans.[status] = N'waiting'
		AND bettrans.[statusID] = 1
	
	UPDATE dbo.bettransm with (ROWLOCK, UPDLOCK)
	SET
		[status] = N'reject',
		statusID = 101,
		winlost = stake,
		awinlost = 0, mwinlost = 0, swinlost = 0,
		playercomm = 0, comm = 0, acomm = 0, scomm = 0,
		ruben = 1	
	FROM @Horse h	
    WHERE 
		bettransm.matchid = h.orid
        AND bettransm.bettype IN (31, 32)
		AND bettransm.refno in (select transid from @tbltransid)

-------------------------------------------------------------
---         CAPTURE value BALANCE after settlement        ---
---------------------------VVVV------------------------------
CREATE TABLE #BalanceAfter (custid int PRIMARY KEY, balance money)
 
        INSERT INTO #BalanceAfter
        SELECT  custid,sum( winlost-actual_stake+playercomm)
        FROM dbo.bettrans with (rowlock)
        WHERE matchid in (select orid from @Horse)
        AND bettrans.bettype IN (31, 32, 33) 
        and statusID =101 -- reject
		Group by custid

       
-------------------------------------------------------------
---                   compare BALANCE                     ---
---------------------------VVVV------------------------------
CREATE TABLE #Balance (custid int not null, balance money, Increased bit not null)
ALTER TABLE #Balance add constraint pk_C2 primary key (custid, Increased);

DECLARE @tblCreditPending TVP_BalanceList

CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
 
INSERT INTO #Balance
SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
FROM #BalanceBefore b
        INNER JOIN #BalanceAfter a ON b.custid = a.custid
WHERE b.balance <> a.balance


select @TotalAccount_BalanceUpdate = count(distinct custid) from #Balance
 
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

DECLARE @LogData nvarchar(200)
SELECT @LogData = '3rd_Result Bal:' + CAST(IsNull(@TotalAccount_BalanceUpdate,0) as varchar(20)) + 
	'/' + CAST(IsNull(@TotalAccount,0) as varchar(20))
EXEC dbo.WriteLog_UserLog 151, @LogData

	-- LOG reject ticket
	IF EXISTS(SELECT transid FROM @tbltransid)
	BEGIN
		INSERT INTO dbo.userlog (userid,doing)
		SELECT 151, '3rd_Result transid:' + CAST(transid as varchar(20)) + ' Success:0 FailedMsg: system reject waiting bet'
		FROM @tbltransid
	END

END TRY
BEGIN CATCH 
			SET @LogData = 'Admin_3rdCalculate_s151_Reject_Admin_ErrorNumber:' + cast ( ERROR_NUMBER() as varchar(10) )
			+'.ErrorSeverity:' + cast ( ERROR_SEVERITY() as varchar(10))
			+'.ErrorState:' + cast ( ERROR_STATE() as varchar(10) )
			+'.ErrorProcedure:' + isnull(ERROR_PROCEDURE(),'')
			+'.ErrorLine:' + cast ( ERROR_LINE() as varchar(10) )
			+'.ErrorMessage:' +ERROR_MESSAGE() 
			EXEC dbo.WriteLog_UserLog 151, @LogData
END CATCH

END

GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Reject_Admin] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Reject_Admin] TO [Dot_3rdparty] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Reject_Admin] TO [Dot_Admin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Admin_3rdCalculate_s151_Reject_Admin] TO [vnteam] AS [dbo]