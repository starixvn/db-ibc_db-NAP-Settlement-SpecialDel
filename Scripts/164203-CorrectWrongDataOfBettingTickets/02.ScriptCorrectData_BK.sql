/*<info serverAlias="DBARC-bodb_Archive" isFunction="0"></info>*/

/*
	Created: 20211103@Tina
    Task: Correct wrong data of customers & betting tickets [RedmineID: #164203]
    DB: DBARC-bodb_Archive
    Revisions:

*/

/*
56713984  2  MYGAMECVRMB201 -> 56713996  2  MYGAMECVRMB203
56948071  2  dfbetCVRMB201 -> 56948082  2  dfbetCVRMB203
*/

---------------DATA PREPARATION-------------------------
CREATE TABLE #Customer (CustID INT, CurrentUserName VARCHAR(30), Currentrecommend INT, CorrectUserName VARCHAR(30), CorrectRecommend INT)
CREATE TABLE #bettransbk_Adjust (transid BIGINT, CorrectRecommend INT)
CREATE TABLE #bettrans_Batch (transid BIGINT, CorrectRecommend INT)


INSERT INTO #Customer (CustID,CurrentRecommend,CorrectRecommend,CurrentUserName,CorrectUserName)
SELECT custid, 
       recommend, 
       56713996 AS new_recommend, 
       username, 
       REPLACE(username, 'MYGAMECVRMB201', 'MYGAMECVRMB203') AS New_username
FROM bodb02.dbo.custinfo ci WITH (NOLOCK)
WHERE recommend = 56713984
      AND username LIKE 'MYGAMECVRMB%'
      AND username <> 'MYGAMECVRMB201'
      AND username <> 'MYGAMECVRMB201ClearBal'
      AND username <> 'MYGAMECVRMB201CashOut'
UNION ALL
SELECT custid, 
       recommend, 
       56948082 AS new_recommend, 
       username, 
       REPLACE(username, 'dfbetCVRMB201', 'dfbetCVRMB203') AS New_username
FROM bodb02.dbo.custinfo ci WITH (NOLOCK)
WHERE recommend = 56948071
      AND username LIKE 'dfbetCVRMB%'
      AND username <> 'dfbetCVRMB201'
      AND username <> 'dfbetCVRMB201ClearBal'
      AND username <> 'dfbetCVRMB201CashOut';


--Update Username of MYGAMECVRMB201001 
UPDATE t
SET t.CorrectUserName = 'MYGAMECVRMB203xxx' 
FROM #Customer t
WHERE t.CurrentUserName = 'MYGAMECVRMB201001'


INSERT INTO #bettransbk_Adjust(transid, CorrectRecommend)
SELECT b.transid, c.CorrectRecommend
FROM #Customer c
	INNER JOIN bettrans_bk b WITH (NOLOCK) ON b.custid = c.CustID

--------------START TO UPDATE BETTRANS_BK -------------------
DECLARE @debug_message VARCHAR(500)
SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)

WHILE (1 = 1)
BEGIN
  TRUNCATE TABLE #bettrans_Batch

  DELETE TOP (1000) r 
  OUTPUT DELETED.transid, DELETED.CorrectRecommend
  INTO #bettrans_Batch (transid, CorrectRecommend)    
  FROM #bettransbk_Adjust r 
  
  
  IF @@ROWCOUNT = 0
    BREAK
  
  SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)
  
  RAISERROR (@debug_message, 0, 1) WITH NOWAIT
  
  UPDATE b
    SET recommend = t.CorrectRecommend
  FROM bettrans_bk b WITH (ROWLOCK)
    INNER JOIN #bettrans_Batch t ON t.transid = b.transid

  WAITFOR DELAY '00:00:00.020'
END
