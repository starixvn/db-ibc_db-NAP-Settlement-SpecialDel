/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: 20230721@Aries
	Task: Settlement Performance Report - Change The Way to Get Report Due to Scale Out 2 [Redmine:#191384]
	Server: DBLOG
	DB: DBARC/bodb_archive

	Revision:
		20230721@Aries: Created  [Redmine:#191384]

*/

IF OBJECT_ID(N'tempdb..#Match100k') IS NOT NULL DROP TABLE #Match100k
CREATE TABLE #Match100k(matchid INT,eventdate SMALLDATETIME, totalticket INT, totalticketFT INT, totalticketFT_Credit INT, totalticketFT_Licensee INT)																																																		

IF OBJECT_ID(N'tempdb..#ReportResult') IS NOT NULL DROP TABLE #ReportResult
CREATE TABLE #ReportResult(matchid INT, totalticket INT, totalticketFT INT,totalticketFT_Credit INT, totalticketFT_Licensee INT,startTimeMin DATETIME, startTime_Credit DATETIME, startTime_Licensee DATETIME,endtime_Credit DATETIME,  endtime_Licensee DATETIME, duration_ms_credit INT, duration_ms_deposit INT)																									

IF OBJECT_ID(N'tempdb..#SuspenderConfirm') IS NOT NULL DROP TABLE #SuspenderConfirm
CREATE TABLE #SuspenderConfirm(matchid INT,confirmDate DATETIME)																									


INSERT INTO #Match100k (eventdate, matchid, totalticket, totalticketFT,totalticketFT_Credit,totalticketFT_Licensee)																									
VALUES	xxx
								
																																														
INSERT INTO  #ReportResult (matchid,totalTicket,totalticketFT,totalticketFT_Credit,totalticketFT_Licensee,startTimeMin, startTime_Credit, startTime_Licensee,endtime_Credit,  endtime_Licensee,duration_ms_credit,duration_ms_deposit )																							
SELECT m.matchid	
	  ,m.totalTicket
	  ,m.totalticketFT
	  ,m.totalticketFT_Credit
	  ,m.totalticketFT_Licensee		
	  ,t.startTimeMin
	  ,t.startTime_Credit
	  ,t.endtime_Credit 
	  ,t.startTime_Licensee
	  ,t.endtime_Licensee
	  ,t.duration_Credit
	  ,t.duration_Licensee
	 
FROM #Match100k AS m (nolock)																																										
	CROSS APPLY (SELECT MIN(IIF(q.SiteDBGroupId IN (1,2),q.starttime,NULL)) AS startTime_Licensee
					   ,MAX(IIF(q.SiteDBGroupId IN (1,2),dateadd(ms,q.duration,q.exectime),NULL))  AS endtime_Licensee	
					   ,MIN(IIF(q.SiteDBGroupId IN (0,3),q.starttime,NULL)) AS startTime_Credit
					   ,MAX(IIF(q.SiteDBGroupId IN (0,3),dateadd(ms,q.duration,q.exectime),NULL))  AS endtime_Credit	
					   ,MIN(q.starttime) AS startTimeMin
					   ,MAX(IIF(q.sitedbgroupid in(1,2),q.duration,null)) as duration_Licensee
					   ,MAX(IIF(q.sitedbgroupid in(0,3),q.duration,null)) as duration_Credit

				 FROM dblog.bodb_customerlog_archive.dbo.single_calculate_queue_bk AS q WITH (NOLOCK)																			
				 WHERE q.matchid = m.matchId														
					AND q.action IN ('CAL', 'CAL-FT')		
				 GROUP BY q.matchid
	) AS t	
	
INSERT INTO #SuspenderConfirm(matchid,confirmDate)
SELECT m.matchid, l.logdate
FROM #Match100k AS m 
OUTER APPLY(SELECT TOP 1 u.logdate	 																																									
				FROM dbwh.bodb_Account.dbo.UserLog_P_SuspenderConfirm AS u																																											
				WHERE u.actionid = 2 
					AND m.matchid=u.matchid				
			) AS l																																										
									
					
SELECT r.MatchId
	  ,info.leaguename AS 'League Name'
	  ,info.hometeam  AS 'Home Team'
	  ,info.awayteam AS 'Away Team'
	  ,r.totalticket AS 'Total Tickets'
	  ,r.totalticketFT AS 'Total Ticket FT'
	  ,r.totalticketFT_Credit AS 'Total Ticket FT Credit'
	  ,r.totalticketFT_Licensee AS 'Total Ticket FT Licensee'
	  ,sp.confirmDate AS 'Time Suspender Confirm Result'		
	  ,r.startTimeMin AS 'Time Keyscore Press'
	  ,DATEDIFF(ms, sp.confirmDate, r.startTimeMin) AS 'Delay Time (ms) from Confirmed Result to Keyscore Press'
	  ,r.duration_ms_credit
	  ,r.duration_ms_deposit
	  ,ABS(r.duration_ms_deposit - r.duration_ms_credit) as 'Gap between Credit vs Lic'
FROM #ReportResult AS r 
	CROSS APPLY(SELECT l.leaguename, h.teamname hometeam, a.teamname awayteam, m.matchid
				FROM (SELECT mbk.matchid, mbk.leagueid, mbk.homeid, mbk.awayid 
					  FROM match_bk AS mbk WITH(NOLOCK)			
					  WHERE	mbk.matchid = r.matchid
					  UNION 
					  SELECT m14.matchid, m14.leagueid, m14.homeid, m14.awayid 
					  FROM bodb02.dbo.match14 AS m14 WITH(NOLOCK)			
					  WHERE	m14.matchid = r.matchid
					  UNION 
					  SELECT mm.matchid, mm.leagueid, mm.homeid, mm.awayid 
					  FROM	bodb02.dbo.match AS mm  WITH(NOLOCK)			
					  WHERE	mm.matchid = r.matchid
				) AS m
				INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN bodb02.dbo.team AS h WITH(NOLOCK) ON	h.teamid = m.homeid
				INNER JOIN bodb02.dbo.team AS a WITH(NOLOCK) ON	a.teamid = m.awayid
	) AS info
	LEFT JOIN #SuspenderConfirm AS sp ON  r.matchid= sp.matchid			
ORDER BY r.startTime_Credit																									
					
																						
																		