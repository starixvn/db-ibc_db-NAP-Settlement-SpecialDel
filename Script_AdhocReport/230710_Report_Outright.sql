/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" isFunction="0"></info>*/

/*  Created by: 20250617@Louisa
    Task: Get report about action on outright event [Redmine:#230710]
    DB: DBLOG/bodb_CustomerLog
    
    Revisions: 
		- 20250617@Louisa: create [Redmine:#230710]
*/

use bodb_CustomerLog
GO

DECLARE @fromDate DATETIME = '2025-01-01'
		,@toDate  DATETIME = '2025-06-17 23:59:59'
			
		,@MovebetDate SMALLDATETIME
		,@BUDate SMALLDATETIME

SELECT @MovebetDate = CONVERT(SMALLDATETIME, VValue)
FROM bodb02.dbo.SystemSettings
WHERE VName = 'MovebetDate'

-- BU
SELECT @BUDate = CONVERT(SMALLDATETIME, VValue)
FROM DBACC.bodb02.dbo.MBUSettings with(nolock)
WHERE VName like 'BalanceUpDate'

DROP TABLE IF EXISTS #tmp_matchOutright 
DROP TABLE IF EXISTS #tmp_Return

CREATE TABLE #tmp_matchOutright (sporttype TINYINT,  SportName NVARCHAR(100),Leagueid INT,LeagueCode VARCHAR(20),LeagueName NVARCHAR(1000), MatchID INT, EventDate DATETIME, ActionID INT, SettlementAction VARCHAR(10))
CREATE INDEX IX_Matchid_EventDate ON #tmp_matchOutright (MatchID,EventDate)

CREATE TABLE #tmp_Return (sporttype TINYINT,  SportName NVARCHAR(100),Leagueid INT,LeagueCode VARCHAR(20),LeagueName NVARCHAR(1000), MatchID INT, EventDate DATETIME, HomeID INT, AwayID INT, ActionID INT, SettlementAction VARCHAR(10))

INSERT INTO #tmp_matchOutright (sporttype, SportName,Leagueid,LeagueCode,LeagueName, MatchID, EventDate, ActionID, SettlementAction)
SELECT  s.sporttype   
		,s.SportName  
		,lo.Leagueid
		,l.LeagueCode
		,l.leaguename
		,lo.MatchID  
		,lo.EventDate
		,lo.ActionID
		,CASE WHEN lo.ActionID = 136 THEN 'CAL'
			  WHEN lo.ActionID = 138 THEN  'REFUND' 
			  WHEN lo.ActionID = 81039 THEN 'HIDE'
			  WHEN lo.ActionID = 140 THEN  'UNDO'
		END AS [SettlementAction]
FROM UserLog_SettleOutright lo  WITH(NOLOCK)
	INNER JOIN bodb02.dbo.league l WITH(NOLOCK) ON lo.leagueid = l.leagueid
	INNER JOIN bodb02.dbo.sports s WITH(NOLOCK) ON l.sporttype =s.SportType
WHERE lo.ActionID IN (136, 138,81039, 140)
	AND lo.LogDate >= @FromDate
	AND l.isTest = 0
-----------------------------
IF @toDate > @MovebetDate
BEGIN
  INSERT INTO #tmp_Return (sporttype, SportName,Leagueid,LeagueCode,LeagueName, MatchID, EventDate, HomeID, AwayID, ActionID, SettlementAction)
  SELECT  tmp.sporttype   
          ,tmp.SportName  
          ,tmp.Leagueid
          ,tmp.LeagueCode
          ,tmp.leaguename
          ,tmp.MatchID
          ,tmp.EventDate
          ,m.homeid
          ,m.awayid
          ,tmp.ActionID
          ,tmp.SettlementAction
  FROM #tmp_matchOutright tmp  WITH(NOLOCK)
      INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON tmp.MatchID = m.matchid
  WHERE tmp.EventDate > @MovebetDate
    AND   tmp.EventDate <= @todate
END

IF @fromDate <= @MovebetDate 
BEGIN
	INSERT INTO #tmp_Return (sporttype, SportName,Leagueid,LeagueCode,LeagueName, MatchID, EventDate, HomeID, AwayID, ActionID, SettlementAction)
	SELECT  tmp.sporttype   
			,tmp.SportName  
			,tmp.Leagueid
			,tmp.LeagueCode
			,tmp.leaguename
			,tmp.MatchID
			,tmp.EventDate
			,m.homeid
			,m.awayid
			,tmp.ActionID
			,tmp.SettlementAction
	FROM #tmp_matchOutright tmp  WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON tmp.MatchID = m.matchid
	WHERE tmp.EventDate between @BUDate AND @MovebetDate
END

IF @fromDate < @BUDate
BEGIN
	INSERT INTO #tmp_Return (sporttype, SportName,Leagueid,LeagueCode,LeagueName, MatchID, EventDate, HomeID, AwayID, ActionID, SettlementAction)
	SELECT  tmp.sporttype   
			,tmp.SportName  
			,tmp.Leagueid
			,tmp.LeagueCode
			,tmp.leaguename
			,tmp.MatchID
			,tmp.EventDate
			,m.homeid
			,m.awayid
			,tmp.ActionID
			,tmp.SettlementAction
	FROM #tmp_matchOutright tmp  WITH(NOLOCK)
		INNER JOIN DBACC.bodb_Archive.dbo.match_bk m WITH(NOLOCK) ON tmp.MatchID = m.matchid
	WHERE tmp.EventDate < @BUDate
		AND m.EventDate < @BUDate
END
------------------------


SELECT r.sporttype, r.SportName,r.Leagueid,r.LeagueCode,r.LeagueName, r.MatchID, r.EventDate, h.teamname AS HomeTeamName, a.teamname AS AwayTeamName ,ActionID,	SettlementAction
FROM #tmp_Return r
INNER JOIN bodb02.dbo.team h WITH(NOLOCK) ON  r.HomeID =h.teamid
INNER JOIN bodb02.dbo.team a WITH(NOLOCK) ON  r.AwayID =a.teamid
ORDER BY r.sporttype, r.Leagueid, r.MatchID