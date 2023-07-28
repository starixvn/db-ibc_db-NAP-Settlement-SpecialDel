/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

USE bodb_CustomerLog
GO
SELECT --a.ActionNameEN AS Function_SDName ,ActionID,l.*
DISTINCT a.ActionNameEN AS Function_SDName , l.matchid
FROM dbo.TicketVoiding_Log l WITH(NOLOCK) 
	INNER JOIN dbo.LogAction a WITH(NOLOCK)  ON l.LogActionId = a.ActionID
WHERE LogActionid IN (90512,90513,90514,90515,90516,90517,90518)
	AND (
		MatchID IN (69666733)
		OR 
		LogData LIKE '%137052032753205253%'
	)




/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/
USE bodb_archive 
GO

DECLARE @matchid INT = 70132399 --70244942
, @winlostdate SMALLDATETIME = '2023-07-12 0:00:00'

SELECT 'bettrans' AS tbl, b.matchid,b.transid, b.sitedbgroupid
FROM bodb02.dbo.bettrans b (NOLOCK) 
INNER JOIN bodb02.dbo.zzzbettrans z WITH(NOLOCK) ON b.transid = z.transid AND b.matchid = z.matchid AND z.VoidingHistoryId IS NULL
WHERE b.matchid = @matchid AND @winlostdate = @winlostdate
and statusid = 102
UNION ALL
SELECT 'bettrans14' AS tbl,b.matchid,b.transid, b.sitedbgroupid
FROM bodb02.dbo.bettrans14 b (NOLOCK) 
INNER JOIN bodb02.dbo.zzzbettrans z WITH(NOLOCK) ON b.transid = z.transid AND b.matchid = z.matchid AND z.VoidingHistoryId IS NULL
WHERE b.matchid = @matchid AND @winlostdate = @winlostdate
and statusid = 102

UNION ALL
SELECT 'bettrans_bk' AS tbl, b.matchid,b.transid, NULL AS sitedbgroupid
FROM dbo.bettrans_bk b (NOLOCK) 
INNER JOIN dbo.zzzbettrans_bk z WITH(NOLOCK) ON b.transid = z.transid AND b.matchid = z.matchid AND z.VoidingHistoryId IS NULL
WHERE b.matchid = @matchid AND @winlostdate = @winlostdate
and statusid = 102
