USE bodb_CustomerLog
GO
/*
	DB: DBLOG/bodb_CustomerLog

*/
declare @fromdate datetime
		,@todate datetime

select @fromdate = ''
		,@todate = ''

select l.ActionNameEN
	, case 
		when u.ActionID in (100, 101, 109, 111)  then 'FT'
		when u.ActionID in (102, 110)  then 'HT'
		end AS scope
	,case 
		when u.actionid in (100,101, 102) then 'CAL'
		else 'REF'
		end as type
	, case 
		when u.actionid in (100, 101) then 101
		else u.actionid
		end as action
	, u.*
into #SettlementLog
from (select *
		from UserLog_Settle u with(nolock)
		where u.ActionId in (100, 101, 102, 109, 110, 111)
			and u.LogDate between @fromdate and @todate
		union all
		select *
		from bodb_customerlog_archive.dbo.UserLog_Settle u with (nolock)
		where u.ActionId in (100, 101, 102, 109, 110, 111)
			and u.LogDate between @fromdate and @todate
	) u
	INNER JOIN bodb_customerlog.dbo.LogAction L WITH(NOLOCK)
		ON u.ActionID = l.ActionID


select s.*
	,h.teamname as 'homename'
	,a.teamname as 'awayname'
	,m.kickofftime
into #SoccerResult
from #SettlementLog s
	inner join (select matchid, sporttype, kickofftime	 , leagueid		 , homeid, awayid
		from bodb02.dbo.match m with(nolock)
		union all
		select  matchid, sporttype, kickofftime	, leagueid	    , homeid, awayid
		from bodb02.dbo.match14 m14 with(nolock)
		union all
		select  matchid, sporttype, kickofftime	, leagueid	   , homeid, awayid
		from dbarc.bodb_archive.dbo.match_bk m with(nolock)
		)m
		on s.matchid = m.matchid
	inner join bodb02.dbo.League l with (nolock)
		on m.leagueid = l.leagueid
	inner join bodb02.dbo.Team h with (nolock)
		on m.homeid = h.teamid
	inner join bodb02.dbo.Team a with (nolock)
		on m.awayid = a.teamid
where l.isTest = 0
and m.sporttype = 1

select distinct matchid
into #matchid
from #SoccerResult r
where exists (
	select * 
	from #SoccerResult r2
	where	r.logid <> r2.LogID
			AND r.matchid = r2.matchid
			and r.scope = r2.scope
			and (
				(r.action = r2.action
					and (ISNULL(r.finalhomescore,0) <> ISNULL(r2.finalhomescore,0)
							or ISNULL(r.finalawayscore,0) <> ISNULL(r2.finalawayscore,0)
							or ISNULL(r.hthomescore,0) <> ISNULL(r2.hthomescore,0)
							or ISNULL(r.htawayscore,0) <> ISNULL(r2.htawayscore	,0)
							or (ISNULL(r.GoalRecord,0) <> ISNULL(r2.GoalRecord,0) and r.scope = 'FT')
							OR ( SUBSTRING(ISNULL(r.GoalRecord,0),1,CHARINDEX(';',ISNULL(r.GoalRecord,0))) <>  SUBSTRING(ISNULL(r2.GoalRecord,0),1,CHARINDEX(';',ISNULL(r2.GoalRecord,0))) and r.scope = 'HT')
						)
				)
				or r.type <> r2.type
			)
)

select MatchID, homename, awayname, kickofftime, ci.username, ActionNameEN, finalhomescore, finalawayscore, hthomescore, htawayscore, GoalRecord, LogDate
from #SoccerResult r
	inner join bodb02.dbo.custInfo ci with (nolock)
		on r.UserID = ci.custid
where matchid in (select MatchID from #matchid)
order by MatchID, LogDate


drop table #SettlementLog
drop table #SoccerResult
drop table #matchid

