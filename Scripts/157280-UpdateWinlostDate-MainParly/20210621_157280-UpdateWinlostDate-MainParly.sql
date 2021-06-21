/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20210621@Helen
	Task: Update winlostdate of main parlay tickets - https://nexdev.net/issues/157280
	DB: DBTXN/bodb02
*/
USE bodb02
go

CREATE TABLE #TransIds (RowId INT IDENTITY(1,1), TransId BIGINT)

DECLARE @Today_Winlostdate SMALLDATETIME
SET @Today_Winlostdate = '2021-06-21'

INSERT INTO #TransIds(TransId)
SELECT b.TransId
FROM dbo.bettrans b WITH(NOLOCK)
	INNER JOIN bettransm  bm (nolock) on b.refno = bm.refno and bm.matchid = 44304961
WHERE b.winlostdate = '2021-06-19'
	AND b.statusID = 0
	AND b.bettype IN (9,29)
	AND b.matchid IN (9,29)
	AND b.currency <> 20

UPDATE b
	SET winlostdate = @Today_Winlostdate
FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
	INNER JOIN #TransIds t ON t.transid = b.transid 

DROP TABLE #TransIds

GO

		