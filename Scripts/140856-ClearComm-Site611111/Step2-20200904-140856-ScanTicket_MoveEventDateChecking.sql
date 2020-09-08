/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: Helen
	Date 20200317
	Task: Remove Sportsbook Comm from 611111 Site - [Redmine:140856]
	DB: DBTXN/bodb02
	
*/
USE bodb02
GO
--- define temporary tables 
DECLARE @winlostdate DATETIME 

SET @winlostdate = '2020-09-13 00:00:00'

CREATE TABLE #tmp_recommend (custid INT)
-------------------------- DATA PREPARATION  ------------------------
------ GET list of recommend to utilize index IX_recommend on bettrans

INSERT INTO #tmp_recommend (custid)
SELECT custid
FROM CUSTDB.dbo.customer WITH(NOLOCK)
WHERE roleid = 2
	AND currency IN (2,5,13)	--	RM,HK$,RMB
	AND site IN ('611111')
	
------------ get result------------
-- bettrans
SELECT b.transid, b.Matchid, 1, 0
FROM #tmp_recommend r
	INNER JOIN bettrans b WITH (NOLOCK) ON r.custid = b.recommend
	INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid 
WHERE m.sporttype <= 99 AND eventstatus <> 'completed'
	AND b.statusID IN (0,1,102)
	AND b.playerdiscount + b.discount + b.adiscount + b.sdiscount  > 0
	AND b.bettype < 19999
	AND b.bettype NOT IN (29,10)
	AND b.winlostdate = @winlostdate
	AND b.currency <> 20
	
UNION ALL
-- outright
SELECT b.transid, b.Matchid, 1, 0
FROM #tmp_recommend r
	INNER JOIN bettrans b WITH (NOLOCK) ON r.custid = b.recommend
WHERE  b.statusID IN (0,1,102)
	AND b.playerdiscount + b.discount + b.adiscount + b.sdiscount  > 0
	AND b.bettype = 10 -- outright
	AND b.winlostdate = @winlostdate
	AND b.currency <> 20
UNION ALL
-- translog
SELECT b.translogid, b.eventID,  0, 1
FROM #tmp_recommend r
	INNER JOIN translog b WITH (NOLOCK) ON r.custid = b.recommend
WHERE b.gameID BETWEEN 801 AND 806
	AND b.statusID IN (0,1,102)
	AND b.playerdiscount + b.discount + b.adiscount + b.sdiscount  > 0
	AND b.winlostdate = @winlostdate
	AND b.currency <> 20
	
	