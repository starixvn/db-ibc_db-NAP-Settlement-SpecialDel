------- compare parlay: matchid 29 sitedb with dbtrans

--run on SiteDB

use bodb02
go

;with cte as
(	select  winlostdate
			,recommend
			, CHECKSUM_AGG(CHECKSUM( [status],[statusid] )) AS TotalCheckSumAgg
	from bettrans b with (nolock)
	where matchid = 29 
	and b.statusID not in (0,1) 
	and winlostdate in ('2024-03-06','2024-03-07') 
	group by winlostdate,recommend
) 
,ctg as
(	select  winlostdate
		,recommend
		, CHECKSUM_AGG(CHECKSUM(  [status],[statusid]  )) AS TotalCheckSumAgg
	from dbctg.bodb02.dbo.bettrans b with (nolock)
	where matchid = 29 and b.statusID not in (0,1) 
	and  winlostdate in ('2024-03-06','2024-03-07') 
	and SiteDBGroupID = 2
	group by winlostdate,recommend
)
select top 10 t1.*, t2.*
from cte t1
	inner join ctg t2 
		ON t1.recommend = t2.recommend and t1.winlostdate = t2.winlostdate
where t1.TotalCheckSumAgg <> t2.TotalCheckSumAgg

select t1.transid, t1.status, t2.status, t1.matchid
from bettrans t1 with (nolock)
	--inner join bettransm bm with (nolock) on t1.refno = bm.refno
	inner join dbctg.bodb02.dbo.bettrans t2 with (nolock) ON  t1.transid = t2.transid
where t1.winlostdate  = xxx
	and t1.recommend = xxx
	and t1.statusID <> t2.statusID 
	--and t1.transid in (xxxx)