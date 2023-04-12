/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230207@Aries
	Task: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
	DB: DBTXN/bodb02
*/


USE bodb02
GO

-- Run DB TRANS/bodb02
IF OBJECT_ID(N'tempdb..#tmpMatchCompleted') IS NOT NULL DROP TABLE #tmpMatchCompleted
CREATE TABLE #tmpMatchCompleted (Matchid INT, Sporttype SMALLINT,  IsOnlyHTDone BIT)
IF OBJECT_ID(N'tempdb..#tmpResult') IS NOT NULL DROP TABLE #tmpResult
CREATE TABLE #tmpResult (Matchid INT, Sporttype SMALLINT,  IsOnlyHTDone BIT)

DECLARE	@tmpSportBettypeHT TABLE( Sporttype SMALLINT,Bettype INT)
DECLARE @FromDate DATE = DATEADD(DAY, -3, GETDATE())

-- Get list match completed and HT completed 
INSERT INTO #tmpMatchCompleted(Matchid,sporttype, IsOnlyHTDone)
SELECT m.matchid, m.Sporttype, rm.IsHTCal 
FROM match AS m WITH(NOLOCK)
    INNER JOIN match_remark AS rm WITH(NOLOCK) ON m.matchid = rm.matchid
WHERE m.sporttype IN (3,4,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,46,47,48,49,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,68,69,98,99)
    AND ( (m.eventstatus = 'completed' AND rm.multiple = 0 AND rm.refund = 0) 
           OR (rm.IsHTCal = 1 AND eventstatus != 'completed') 
        )
    AND m.eventdate >= @FromDate;

-- Get list match completed has parlay running
INSERT INTO #tmpResult(Matchid,Sporttype,IsOnlyHTDone)
SELECT m.Matchid,m.Sporttype,m.IsOnlyHTDone
FROM #tmpMatchCompleted AS m
WHERE EXISTS (SELECT 1 FROM bettransm AS b WITH(NOLOCK) WHERE b.matchid = m.Matchid AND b.statusID = 0)
    AND m.IsOnlyHTDone = 0;


-- Get list match HT completed has parlay running
IF EXISTS (SELECT 1 FROM #tmpMatchCompleted WHERE IsOnlyHTDone = 1)
BEGIN
    INSERT INTO @tmpSportBettypeHT(Sporttype,Bettype)
    SELECT Sporttype,Bettype
    FROM SettlementSpecialBettypeProfile WITH(NOLOCK) 
    WHERE  GroupType = 'HT'  
        AND  SportType IN (3,4,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,46,47,48,49,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,68,69,98,99)

    INSERT INTO #tmpResult(Matchid,Sporttype,IsOnlyHTDone)
    SELECT m.Matchid,m.Sporttype,m.IsOnlyHTDone
    FROM #tmpMatchCompleted AS m
    WHERE EXISTS (SELECT 1 
                  FROM bettransm AS b WITH(NOLOCK) 
                  WHERE b.matchid = m.Matchid 
                    AND b.statusID = 0
                    AND EXISTS (SELECT 1 FROM @tmpSportBettypeHT AS sb WHERE sb.Bettype = b.Bettype AND m.Sporttype = sb.Sporttype)
                   )
        AND m.IsOnlyHTDone = 1;
END
SELECT *
FROM #tmpResult

