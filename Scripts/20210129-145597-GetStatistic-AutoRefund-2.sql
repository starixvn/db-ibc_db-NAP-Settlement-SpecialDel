																				  /*
	DB: DBACC.bodb02
	Task: get statistics of auto refund match function [Redmine:#145597]
*/
use bodb02
GO
-- failed match
select distinct a.matchid
into #tmpmatchid
from dbpro.bodb02.dbo.AutoRefundResult a with(nolock)
	inner join (
		select matchid 
		from dbo.match m with(nolock)
		union all
		select matchid 
		from dbo.match14 m with(nolock)
	)m
		on a.matchid = m.matchid
where typeid = 1
and statusid = 3

-- total ticket of those matches
select t.matchid, count(b.matchid)	 cnt
into #tmpMatchTicket
from #tmpmatchid t
	left join (
		select matchid
		from bettrans b	with(nolock)
		union all
		select matchid
		from bettrans14 b14 with(nolock)
	)b
on t.matchid = b.matchid
group by t.matchid
		
select count(1) as total_match_active_14
	,sum(case when cnt =0 then 1 else 0 end) as total_noticket 
from (											 
	   select matchid, cnt
	   from #tmpMatchTicket
) t

-- get match info of 'no ticket' matches
select m.*
from #tmpmatchid t
	inner join #tmpMatchTicket mt
		on t.MatchId = mt.MatchId
	cross apply (
		select matchid, eventstatus	, eventdate, leagueid, betstatus
		from match m with(nolock)
		where m.matchid =  t.MatchId
		union
		select matchid, eventstatus	, eventdate, leagueid, betstatus
		from match14 m14 with(nolock)
		where m14.matchid =  t.MatchId
)m
where mt.cnt = 0	

drop table #tmpmatchid
drop table #tmpMatchTicket

