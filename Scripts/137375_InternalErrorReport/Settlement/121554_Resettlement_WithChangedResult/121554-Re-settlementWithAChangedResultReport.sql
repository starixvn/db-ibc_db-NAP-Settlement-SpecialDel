declare @fromdate datetime
	,@todate datetime

select @fromdate = '20190801'
		,@todate = '20191010'

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
from UserLog_Settle u with(nolock)
	INNER JOIN bodb_customerlog.dbo.LogAction L WITH(NOLOCK)
		ON u.ActionID = l.ActionID
where u.ActionId in (100, 101, 102, 109, 110, 111)
and u.LogDate between @fromdate and @todate

select s.*
	,h.teamname as 'homename'
	,a.teamname as 'awayname'
	,m.kickofftime
into #SoccerResult
from #SettlementLog s
	inner join bodb02.dbo.match m with(nolock)
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
					and (r.finalhomescore <> r2.finalhomescore
							or r.finalawayscore <> r2.finalawayscore
							or r.hthomescore <> r2.hthomescore
							or r.htawayscore <> r2.htawayscore
							or r.GoalRecord <> r2.GoalRecord
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
order by LogID


drop table #SettlementLog
drop table #SoccerResult
drop table #matchid

