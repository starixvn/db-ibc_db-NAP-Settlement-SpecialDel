/*<info serverAlias="DBTP-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
declare @today date = getdate()

select matchid, eventdate, ChildMatchType
into #tmpmatchid
from match with(nolock)
where eventdate < @today
and sporttype = 8
and EventStatus = 'completed'

select eventdate, count(1) cnt
into #tmpevent
from #tmpmatchid
group by eventdate
order by eventdate

select distinct(isnull(refresourceid, ResourceID)) as resourceId, SettleType
into #tmpresource
from SettlementSpecialBettypeProfile with(nolock)
where sporttype = 8

insert into #tmpresource (resourceId, SettleType) values ('EI','MNL')

select *
from #tmpevent

-- main resource
select m.eventdate, pi.SourceName, count(distinct m.matchid) cnt, cast(count(distinct m.matchid) as money) / e.cnt * 100
from ProviderExternalResultDetailOS p with(nolock)
	inner join #tmpmatchid m 
		on p.matchid = m.matchid
	inner join ProviderInfo pi
		on pi.SourceId = p.SourceId
	inner join #tmpevent e
		on e.eventdate = m.eventdate
where exists (select top 1 1 from #tmpresource r where r.resourceId = p.ResourceId and r.SettleType = 'MNL')
and p.SourceId <> 1001
group by  m.eventdate, pi.SourceName, e.cnt
order by m.eventdate, SourceName

-- early resource
select m.eventdate, pi.SourceName, count(distinct m.matchid) cnt, cast(count(distinct m.matchid) as money)/ e.cnt  * 100
from ProviderExternalResultDetailOS p with(nolock)
	inner join #tmpmatchid m 
		on p.matchid = m.matchid
	inner join ProviderInfo pi
		on pi.SourceId = p.SourceId
	inner join #tmpevent e
		on e.eventdate = m.eventdate
where exists (select top 1 1 from #tmpresource r where r.resourceId = p.ResourceId and r.SettleType = 'EAR')
and p.SourceId <> 1001
group by  m.eventdate, pi.SourceName, e.cnt
order by m.eventdate, SourceName

-- main resource
select final.eventdate, final.SourceName, final.totalresult, final.correct
	,case
		when final.nodata = final.totalresult then 0
		else cast(final.correct as money)/(final.totalresult - final.nodata) * 100
		end as correct_per
	,final.wrong
	,case
		when final.nodata = final.totalresult then 0
		else cast(final.wrong as money)/(final.totalresult - final.nodata) * 100
		end as wrong_per
	,final.nodata
	,case
		when final.nodata = final.totalresult then 0
		else cast(final.nodata as money)/(final.totalresult) * 100
		end as nodata_per
from (
select tmp.eventdate, tmp.SourceName, count(1) as totalresult
	, SUM(tmp.correct) correct
	, SUM(tmp.wrong) wrong
	, SUM(tmp.nodata) nodata
	, SUM(tmp.WrongNullOrEmpty) WrongNullOrEmpty
from (
select e.eventdate, m.matchid, r.ResourceID, pi.SourceName
	,r.HomeValue, r.AwayValue
	, case when p.MatchId is null then 1 else 0 end as nodata
	, case 
		when p.MatchId is null then 0 -- nodata
		when (isnull(p.HomeValue,0)  <> isnull(r.HomeValue,0) or isnull(p.AwayValue,0) <> isnull(r.AwayValue,0)) then 1 -- wrong
		else 0 end as wrong
	, case 
		when p.MatchId is null then 0 -- nodata
		when isnull(p.HomeValue,0)  = isnull(r.HomeValue,0) and isnull(p.AwayValue,0) = isnull(r.AwayValue,0) then 1 
		else 0 end as correct 
	, case 
		when p.MatchId is null then 0 -- nodata
		when p.HomeValue <> r.HomeValue and (p.HomeValue is null or p.HomeValue = '' or p.HomeValue = '0' or r.HomeValue is null or r.HomeValue = '' or r.HomeValue = '0') then 1 
		else 0 end WrongNullOrEmpty
	
from #tmpmatchid m
	inner join ResultDetailOS r with(nolock)
		on m.matchid = r.MatchID
	inner join #tmpevent e
		on m.eventdate = e.eventdate
	cross apply (
		select pi.SourceId, pi.SourceName
		from ProviderInfo pi with(nolock) 
			cross apply (
				select *
				from ProviderGameTypeMapping where sporttype = 8 and isActive =1 and SourceId < 1000
			) p	
		where pi.SourceId = p.SourceId
	) pi
	outer apply (
		select *
		from (
		select ROW_NUMBER() over (partition by p.sourceid, p.matchid, p.resourceid order by createdate desc) as rn, p.matchid, p.SourceId, p.ResourceId, ISNULL(p.HomeValue,0) HomeValue, ISNULL(p.AwayValue,0) AwayValue, p.CreateDate
		from ProviderExternalResultDetailOS p with(nolock)
		where p.MatchId = r.matchid and p.ResourceId = r.ResourceID and p.SourceId = pi.SourceId
		) t1
		where rn = 1
	) p
where  exists (select top 1 1 from #tmpresource tr where tr.resourceId = r.ResourceId and tr.SettleType = 'mnl')
and r.SettlementStatusID = 4
) tmp
group by eventdate, SourceName
) final
order by eventdate, SourceName


-- early resource
select final.eventdate, final.SourceName, final.totalresult, final.correct
	,case
		when final.nodata = final.totalresult then 0
		else cast(final.correct as money)/(final.totalresult - final.nodata) * 100
		end as correct_per
	,final.wrong
	,case
		when final.nodata = final.totalresult then 0
		else cast(final.wrong as money)/(final.totalresult - final.nodata) * 100
		end as wrong_per
	,final.nodata
	,case
		when final.nodata = final.totalresult then 0
		else cast(final.nodata as money)/(final.totalresult) * 100
		end as nodata_per
from (
select tmp.eventdate, tmp.SourceName, count(1) as totalresult
	, SUM(tmp.correct) correct
	, SUM(tmp.wrong) wrong
	, SUM(tmp.nodata) nodata
	, SUM(tmp.WrongNullOrEmpty) WrongNullOrEmpty
from (
select e.eventdate, m.matchid, r.ResourceID, pi.SourceName
	,r.HomeValue, r.AwayValue
	, case when p.MatchId is null then 1 else 0 end as nodata
	, case 
		when p.MatchId is null then 0 -- nodata
		when (isnull(p.HomeValue,0)  <> isnull(r.HomeValue,0) or isnull(p.AwayValue,0) <> isnull(r.AwayValue,0)) then 1 -- wrong
		else 0 end as wrong
	, case 
		when p.MatchId is null then 0 -- nodata
		when isnull(p.HomeValue,0)  = isnull(r.HomeValue,0) and isnull(p.AwayValue,0) = isnull(r.AwayValue,0) then 1 
		else 0 end as correct 
	, case 
		when p.MatchId is null then 0 -- nodata
		when p.HomeValue <> r.HomeValue and (p.HomeValue is null or p.HomeValue = '' or p.HomeValue = '0' or r.HomeValue is null or r.HomeValue = '' or r.HomeValue = '0') then 1 
		else 0 end WrongNullOrEmpty
	
from #tmpmatchid m
	inner join ResultDetailOS r with(nolock)
		on m.matchid = r.MatchID
	inner join #tmpevent e
		on m.eventdate = e.eventdate
	cross apply (
		select pi.SourceId, pi.SourceName
		from ProviderInfo pi with(nolock) 
			cross apply (
				select *
				from ProviderGameTypeMapping where sporttype = 8 and isActive =1 and SourceId < 1000
			) p	
		where pi.SourceId = p.SourceId
	) pi
	outer apply (
		select *
		from (
		select ROW_NUMBER() over (partition by p.sourceid, p.matchid, p.resourceid order by createdate desc) as rn, p.matchid, p.SourceId, p.ResourceId, ISNULL(p.HomeValue,0) HomeValue, ISNULL(p.AwayValue,0) AwayValue, p.CreateDate
		from ProviderExternalResultDetailOS p with(nolock)
		where p.MatchId = r.matchid and p.ResourceId = r.ResourceID and p.SourceId = pi.SourceId
		) t1
		where rn = 1
	) p
where  exists (select top 1 1 from #tmpresource tr where tr.resourceId = r.ResourceId and tr.SettleType = 'ear')
and r.SettlementStatusID = 4
) tmp
group by eventdate, SourceName
) final
order by eventdate, SourceName

