/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231016@Aries  
	Task: Auto Send Announcement When Refund VS [Redmine:#195333]
	DB: DBTXN/bodb02
*/
 
--Check queue empty
SELECT   * 
FROM Single_Calculate_Queue_VS WITH(NOLOCK)
WHERE IsCalculating IN (0,1)

SELECT   * 
FROM Parlay_Calculate_Queue_VS WITH(NOLOCK)
WHERE IsCalculating IN (0,1)


-- Check data
DECLARE @FromDate	DATETIME = DATEADD(HOUR,-1,GETDATE())
	   ,@ToDate		DATETIME = DATEADD(HOUR,1,GETDATE())
SELECT @FromDate,@ToDate

SELECT top 10 m.kickofftime
FROM match AS m WITH(NOLOCK)
WHERE Sporttype IN (178,179,180,186,190,191,192,194,195,196,197,193)
    AND eventstatus = 'completed'
    AND m.kickofftime BETWEEN @FromDate AND @ToDate
    AND EXISTS (SELECT 1 
                FROM bettrans AS b WITH(NOLOCK) 
                WHERE b.matchid = m.matchid
                    AND b.statusID IN (0))

SELECT COUNT(1)
FROM match AS m WITH(NOLOCK)
WHERE Sporttype IN (190,191,192,194,195,196,197,193)
    AND eventstatus = 'completed'
    AND m.kickofftime BETWEEN @FromDate AND @ToDate
    AND EXISTS (SELECT 1 
                FROM bettransm AS b WITH(NOLOCK) 
                WHERE b.matchid = m.matchid
                    AND b.statusID IN (0))