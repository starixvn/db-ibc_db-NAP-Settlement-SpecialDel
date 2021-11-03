/*<info serverAlias="DBTXN-bodb02" isFunction="0"></info>*/
/*
	Created: 20211103@Tina
    Task: Correct wrong data of customers & betting tickets [RedmineID: #164203]
    DB: DBTXN/bodb02
    Revisions:

*/

/*
56713984  2  MYGAMECVRMB201 -> 56713996  2  MYGAMECVRMB203
56948071  2  dfbetCVRMB201 -> 56948082  2  dfbetCVRMB203
*/

---------------DATA PREPARATION-------------------------
CREATE TABLE #Customer (CustID INT, CurrentUserName VARCHAR(30), Currentrecommend INT, CorrectUserName VARCHAR(30), CorrectRecommend INT)
CREATE TABLE #bettrans_Adjust (transid BIGINT, CorrectUserName VARCHAR(30), CorrectRecommend INT)
CREATE TABLE #bettrans14_Adjust (transid BIGINT, CorrectUserName VARCHAR(30), CorrectRecommend INT)
CREATE TABLE #bettrans_Batch (transid BIGINT, CorrectUserName VARCHAR(30), CorrectRecommend INT)


INSERT INTO #Customer (CustID, CurrentUserName, CurrentRecommend, CorrectUserName, CorrectRecommend)
-- MYGAMECV
SELECT 1 CustID, 'MYGAMECVRMB201' CurrentUserName, 56713984 CurrentRecommend, 'MYGAMECVRMB203' CorrectUserName, 56713996 CorrectRecommend
--dfbetCV
SELECT 2 CustID, 'dfbetCVRMB201' CurrentUserName, 56948071 CurrentRecommend, 'dfbetCVRMB203' CorrectUserName, 56948082 CorrectRecommend

--get data from bettrans
INSERT INTO #bettrans_Adjust(transid, CorrectUserName, CorrectRecommend)
SELECT b.transid, c.CorrectUserName, c.CorrectRecommend
FROM #Customer c
	INNER JOIN bettrans b WITH (NOLOCK) ON b.custid = c.CustID

--get data from bettrans14
INSERT INTO #bettrans14_Adjust(transid, CorrectUserName, CorrectRecommend)
SELECT b.transid, c.CorrectUserName, c.CorrectRecommend
FROM #Customer c
	INNER JOIN bettrans14 b WITH (NOLOCK) ON b.custid = c.CustID

DECLARE @debug_message VARCHAR(500)
SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)

--------------START TO UPDATE BETTRANS ------------------
WHILE (1 = 1)
BEGIN
  
  DELETE TOP (1000) r 
  OUTPUT DELETED.transid,DELETED.CorrectUserName,DELETED.CorrectRecommend
  INTO #bettrans_Batch (transid,CorrectUserName, CorrectRecommend)    
  FROM #bettrans_Adjust r 
  
  IF @@ROWCOUNT = 0
    BREAK
  
  SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)
  
  RAISERROR (@debug_message, 0, 1) WITH NOWAIT
  
  UPDATE b
    SET recommend = t.CorrectRecommend,
		Username = t.CorrectUserName
  FROM bettrans b WITH (ROWLOCK)
    INNER JOIN #bettrans_Batch t ON t.transid = b.transid
  
  TRUNCATE TABLE #bettrans_Batch
    
END

--------------START TO UPDATE BETTRANS14 -------------------
WHILE (1 = 1)
BEGIN
  TRUNCATE TABLE #bettrans_Batch

  DELETE TOP (1000) r 
  OUTPUT DELETED.transid,DELETED.CorrectUserName,DELETED.CorrectRecommend
  INTO #bettrans_Batch (transid,CorrectUserName, CorrectRecommend)    
  FROM #bettrans14_Adjust r 
  
  IF @@ROWCOUNT = 0
    BREAK
  
  SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)
  
  RAISERROR (@debug_message, 0, 1) WITH NOWAIT
  
  UPDATE b
    SET b.recommend = t.CorrectRecommend,
		b.Username = t.CorrectUserName
  FROM bettrans14 b WITH (ROWLOCK)
    INNER JOIN #bettrans_Batch t ON t.transid = b.transid
    
END