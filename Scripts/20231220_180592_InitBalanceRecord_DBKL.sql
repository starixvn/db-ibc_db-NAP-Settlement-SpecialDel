/*<info serverAlias="DBBAH-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231220@Louisa
	Task: Check and re-init balance record [Redmine: #180592]
	DB:DBBAH/bodb02

*/
USE bodb02
GO

DROP TABLE IF EXISTS #CustId_tmp
CREATE TABLE #CustId_tmp (custid INT PRIMARY KEY)

INSERT INTO #CustId_tmp (custid)
SELECT DISTINCT c.custid
FROM KL_drill_custlist c WITH(NOLOCK)

INSERT INTO BalanceRecord (custid, transid, bettype, actual_stake, winlost, playercomm, balancechanged, newbalance, actionDate, actionID, [action])
SELECT c.custid AS custid, 0, 0, 0, 0, 0, 0, bal.Balance AS balance,CURRENT_TIMESTAMP, 255, 'Balance : Re-Init'
FROM #CustId_tmp c WITH(NOLOCK)
CROSS APPLY (
			SELECT TOP 1 Balance 
			FROM DBTXN.bodb02.dbo.v_BalanceTable b WITH(NOLOCK) 
			WHERE b.custid = c.custid
			) AS bal
		




