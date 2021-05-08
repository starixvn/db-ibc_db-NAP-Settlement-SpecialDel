/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20210508@Helen
	Task: https://nexdev.net/issues/154762 - Wrong ticket status displayed on bet list for voided Abnormal Bet tickets
	DB: DBTXN-bodb02
*/
USE bodb02
GO

CREATE TABLE #Result(transid BIGINT, bettype SMALLINT,sporttype TINYINT,isFinished BIT )
CREATE TABLE #tmp_batch(transid BIGINT, bettype SMALLINT,sporttype TINYINT, )

INSERT INTO #Result (transid, bettype, sporttype)
SELECT b.transid, b.bettype, m.sporttype
FROM bettrans b WITH (NOLOCK)
	INNER JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
	INNER JOIN zzzbettrans z WITH (NOLOCK) ON b.transid = z.transid --and z.VoidingHistoryId is not NULL
	INNER JOIN TicketVoiding_VoidedTransaction v WITH (NOLOCK) ON b.transid = v.TransId
WHERE b.currency <> 20
	AND b.ExtraInfo NOT LIKE '%ab="1"%'
	AND v.IssueTypeID in (11,15,13)
	AND b.statusID = 102
	AND betdaqid = -1
	
DECLARE @debug_message VARCHAR(500)
SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)

WHILE (1 = 1)
BEGIN
	
	UPDATE TOP (2000) r
		SET isFinished = 1	
	OUTPUT DELETED.transid,DELETED.bettype,DELETED.sporttype
	INTO #tmp_batch (transid,bettype,sporttype)		
	FROM #Result r 
	WHERE Isfinished IS NULL
	
	IF @@ROWCOUNT = 0
		BREAK
		
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
	
	UPDATE b
		SET ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'VOID',b.ExtraInfo,t.sporttype,t.bettype)
	FROM bettrans b WITH (ROWLOCK)
		INNER JOIN #tmp_batch t ON t.transid = b.transid
	WHERE b.statusID = 102
	
	TRUNCATE TABLE #tmp_batch
		
END

DROP TABLE #Result