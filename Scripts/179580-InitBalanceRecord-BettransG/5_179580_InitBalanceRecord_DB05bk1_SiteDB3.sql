/*<info serverAlias="DBBAH-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230830@louisa
	Task: Check and re-init balance record - bettransG [Redmine: #179580]
	DB:DBBAH/bodb02
	
*/

---ONLY run in DB05BK1/bodb02

USE bodb02
GO

--------------DECLARE temporary tables ------------------
CREATE TABLE #temp_MemberInput(
	ID INT IDENTITY (1,1) PRIMARY KEY,
	custid INT
)

CREATE TABLE #tempMember (custid INT PRIMARY KEY)

--------------GET members needs to process ------------------

INSERT INTO #temp_MemberInput (custid)
SELECT DISTINCT c.custid
FROM bodb02.dbo.Customer c WITH(NOLOCK)
WHERE c.custid IN (XXXXX) --Input list cust here

SELECT count(1) AS [custid_Count_diff] FROM #temp_MemberInput 

-- Check data [dbo].[BalanceTrigger_ProcessData] on DB05/DB05BK1 until it's no data
SELECT TOP 1 1
FROM BalanceTrigger_ProcessData b WITH (NOLOCK)
	INNER JOIN #temp_MemberInput m ON b.custid = m.custid

------ info for deployer 
DECLARE @debug_message VARCHAR(MAX) = ''

--------------LOOP BY batch 500 of customers ------------------
DECLARE @rid_loop INT, @rowCount int  =0, @batch int = 500, @loop_cnt int = 1
DECLARE @StartRow INT = 1
		, @StopRow INT 
		, @retrycnt INT = 0 
		, @isSuccess BIT = 0
DECLARE  @ExecuteSQL NVARCHAR(MAX) = ''
		, @query NVARCHAR(MAX) = ''
		, @ExecuteSQL_balance NVARCHAR(MAX) = ''
		, @query_balance NVARCHAR(MAX) = ''
		, @SiteDBAlias VARCHAR(200) = ''
		, @CustidList VARCHAR(MAX) = ''

DECLARE @CustidBalanceList VARCHAR(MAX) = ''
DECLARE @xml XML = NULL

SET @rid_loop = ((SELECT MAX(ID) FROM #temp_MemberInput)/@batch) + 1
SET @StopRow = @batch

-- SET param to insert balance in db05
SELECT  @query_balance = N'', @SiteDBAlias = 'DB05'		
SELECT	@query_balance = @query_balance + N'EXEC SiteDB_BalanceRecord_InsertBalanceRecord_tmp @CustidBalanceList'
SELECT	@ExecuteSQL_balance = N'EXECUTE '+ @SiteDBAlias +'.bodb02.dbo.sp_executesql @query_balance, N''@CustidBalanceList VARCHAR(MAX)'',@CustidBalanceList'

WHILE (@loop_cnt <= @rid_loop)
BEGIN
	
	TRUNCATE TABLE #tempMember

	SET @debug_message = CONCAT(CONVERT(VARCHAR(50), GETDATE(), 121), ', processing for round:',  @loop_cnt, '/', @rid_loop)
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT

	-- process by recommend, 2000 customers per batch
	INSERT INTO #tempMember(custid)
	SELECT custid
	FROM #temp_MemberInput 
	WHERE ID BETWEEN @StartRow AND @StopRow

	IF @@ROWCOUNT = 0
		BREAK

	SET @CustidList = ''
	SET @CustidList = STUFF((SELECT ',' + CONVERT(VARCHAR(20), custid)
				 FROM #tempMember 
				 FOR XML PATH ('')
					),1,1,'')	
					
	--- step 2 insert balance record to re-init
	SELECT @CustidBalanceList = (SELECT  m.custid AS '@c'
										,bal.Balance AS '@b'
								FROM #tempMember m
									CROSS APPLY (
												SELECT TOP 1 Balance 
												FROM DBSIG03.bodb02.dbo.v_BalanceTable b WITH(NOLOCK) -- v_BalanceTable: this is a view, get data from 8 balance tables
												WHERE b.custid = m.custid) AS bal
								FOR XML PATH('r'), ROOT('root')
								)
	SET @xml = CONVERT(XML, @CustidBalanceList)
	-- insert db05bk1 first
	INSERT INTO BalanceRecord (custid, transid, bettype, actual_stake, winlost, playercomm, balancechanged, newbalance, actionDate, actionID, [action])
	SELECT	t.c.value('@c','int') AS custid, 0, 0, 0, 0, 0, 0, t.c.value('@b','MONEY') AS balance,CURRENT_TIMESTAMP, 255, 'Balance : Re-Init'
	FROM @xml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@xml = NULL))	

	-- insert db05
	EXECUTE	sys.sp_executesql @ExecuteSQL_balance, N'@query_balance NVARCHAR(MAX), @CustidBalanceList VARCHAR(MAX)', @query_balance, @CustidBalanceList

	WAITFOR DELAY '00:00:00.020' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @batch

	SELECT  @loop_cnt += 1

END

--SELECT @rowCount

DROP TABLE #temp_MemberInput
DROP TABLE #tempMember



