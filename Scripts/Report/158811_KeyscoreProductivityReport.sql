/*

	Created by: 20210723@Louisa
	Task: Keyscore Productivity Report [Redmine:#158811]
*/
use bodb02
go


declare @FROMDate datetime = '2021-06-01'
		,@toDate datetime = GETDATE()
-------------------------------------------------


IF OBJECT_ID ('tempdb..#MatchInfo' ) IS NOT NULL	DROP TABLE #MatchInfo
IF OBJECT_ID ('tempdb..#ResultInfo' ) IS NOT NULL	DROP TABLE #ResultInfo
IF OBJECT_ID ('tempdb..#MatchId' ) IS NOT NULL		DROP TABLE #MatchId

IF OBJECT_ID ('tempdb..#PV' ) IS NOT NULL	DROP TABLE #PV


CREATE TABLE #ResultInfo 
	( MatchId INT, ResourceId VARCHAR(20), LastModifyBy INT, StatusId SMALLINT	, IsAuto BIT DEFAULT(0) )

CREATE TABLE #MatchId (matchid INT)

CREATE TABLE #MatchInfo 
	(matchid INT, eventdate VARCHAR(10), sporttype TINYINT, SportName NVARCHAR(100)
	 , HomeName NVARCHAR(200), AwayName  NVARCHAR(200)
	 ,leagueid INT, leaguename  NVARCHAR(1000), LeagueGroupID SMALLINT, LeagueGroupName NVARCHAR(400)
	)

CREATE TABLE #PV (matchid INT, UserId INT, cnt_Manual_Calculate INT, cnt_Auto_Calculate INT, cnt_Refund INT)
------------------------------------------------------------------------------------------------------------------

	INSERT INTO #ResultInfo ( MatchId ,  ResourceId ,  LastModifyBy, StatusId, IsAuto )
	--PinGoal, Basketball, Tennis 
	SELECT
	r.MatchId, r.ResourceId, r.LastModifyBy
	,CASE WHEN  r.SettlementStatusID IN (4,5,6) THEN 1 --'calculated'
		  WHEN  r.SettlementStatusID IN (1,2,3,7) THEN 2 --- 'Refunded'
		  ELSE 0
	END AS StatusId
	, CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) OR r.ResultStatusID = 2 THEN 1 ELSE 0 END as IsAuto
	FROM dbo.ResultDetail r WITH(NOLOCK)
	WHERE ( r.CreateDate BETWEEN @FROMDate AND @toDate OR LastModifyDate BETWEEN @FROMDate AND @toDate )
		AND r.ResultStatusID  IN ( 2, 5 )	---settle manually AND Auto
		AND r.SettlementStatusID > 0			
		AND ResourceId not in ('OT', '02')
		AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine

--E-Sports
	UNION ALL
	SELECT
	r.MatchId, r.ResourceId, r.LastModifyBy
	,CASE WHEN  r.SettlementStatusID IN (4,5,6) THEN 1 --'calculated'
		  WHEN  r.SettlementStatusID IN (1,2,3,7) THEN 2 --- 'Refunded'
		  ELSE 0
	END AS StatusId
	, CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) OR r.ResultStatusID = 2 THEN 1 ELSE 0 END as IsAuto
	FROM dbo.ResultDetailES r WITH(NOLOCK)
	WHERE ( r.CreateDate BETWEEN @FROMDate AND @toDate OR LastModifyDate BETWEEN @FROMDate AND @toDate )
		AND r.ResultStatusID  IN ( 2, 5 )	---settle manually AND Auto
		AND r.SettlementStatusID > 0			
	
--Badminton, BeachVolleyBall, Cricket
	UNION ALL
	SELECT 
	r.MatchId, r.ResourceId, r.LastModifyBy
	,CASE WHEN  r.SettlementStatusID IN (4,5,6) THEN 1 --'calculated'
		  WHEN  r.SettlementStatusID IN (1,2,3,7) THEN 2 --- 'Refunded'
		  ELSE 0
	END AS StatusId
	, CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) OR r.ResultStatusID = 2 THEN 1 ELSE 0 END as IsAuto
	FROM dbo.ResultDetailOS r WITH(NOLOCK)
	WHERE ( r.CreateDate BETWEEN @FROMDate AND @toDate OR LastModifyDate BETWEEN @FROMDate AND @toDate )
		AND r.ResultStatusID  IN ( 2, 5 )	---settle manually AND Auto
		AND r.SettlementStatusID > 0			

	INSERT INTO #MatchId (matchid) SELECT DISTINCT matchid FROM #ResultInfo

	INSERT INTO #MatchInfo 
		(matchid , eventdate, sporttype , sportName
		 , HomeName, AwayName 
		 ,leagueid , leaguename , LeagueGroupID, LeagueGroupName
		)
	SELECT
	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
	,m.sporttype, s.SportName
	,home.teamname AS HomeName, away.teamname AS AwayName
	,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN #MatchId tmp ON tmp.matchid = m.matchid
		INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
		INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
		INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
		INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
	WHERE 1 =  CASE WHEN m.ParentID is not NULL AND   ISNULL(m.ChildMatchType,'')  = 100 THEN 0 ---exclude hedge match, child match Cricket
				  ELSE 1 END
		--AND l.isTest = 0 --exclude test match


	INSERT INTO #PV (matchid, UserId, cnt_Manual_Calculate, cnt_Auto_Calculate, cnt_Refund)
	SELECT pv.matchid, pv.LastModifyBy, pv.[MC],pv.[AC], pv.[R] FROM 
	(
		SELECT 
		r.MatchId
		,r.LastModifyBy
		,r.ResourceId
		,CASE r.StatusId 
			WHEN 1 THEN  CASE WHEN r.IsAuto = 0 THEN 'MC' ELSE 'AC' END
			WHEN 2 THEN 'R'
			END AS SettlementStatus
		FROM #ResultInfo  r
	) r
	PIVOT (
			COUNT(r.ResourceId) FOR  r.SettlementStatus IN ( [MC],[AC],[R]) 
		  ) pv

	SELECT m.* 
	,ISNULL(c.username,'') AS UserName
	,pv.cnt_Manual_Calculate, pv.cnt_Auto_Calculate, pv.cnt_Refund
	FROM  #MatchInfo m
		INNER JOIN #PV pv ON m.matchid = pv.matchid
		LEFT JOIN dbo.CustInfo c ON pv.UserId = c.custid
	ORDER BY m.sporttype, m.eventdate, matchid


	----Detail Info
	--SELECT m.* 
	--,ISNULL(c.username,'') AS UserName
	--,r.ResourceId
	--, CASE r.StatusId WHEN 1 THEN 'Calculated'
	--				  WHEN 2 THEN 'Refunded'
	--				  ELSE '' END AS SettlementStatus
	--, r.IsAuto
	--FROM  #MatchInfo m
	--	INNER JOIN #ResultInfo r ON m.matchid = r.matchid
	--	INNER JOIN dbo.CustInfo c ON r.LastModifyBy = c.custid
	--order by m.sporttype, m.eventdate, m.matchid  

