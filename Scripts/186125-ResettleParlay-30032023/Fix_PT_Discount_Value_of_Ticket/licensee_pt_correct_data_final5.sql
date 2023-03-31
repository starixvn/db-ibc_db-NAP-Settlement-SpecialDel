SELECT bt.transid,bt.transdate,bt.matchid,m.sporttype,
case when dcm.isGroupedPT = 1 then gdpt.agentpt / 100 else dpt.agentpt / 100 end as apositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.masterpt / 100  else dpt.masterpt / 100 end as mpositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.superpt / 100 else dpt.superpt / 100 end as spositiontaking,
case when dcm.isGroupedPT = 1 then  gdpt.agentpt / 100 + gdpt.masterpt / 100 + gdpt.superpt / 100 
		else dpt.agentpt / 100 + dpt.masterpt / 100 + dpt.superpt / 100 end as tpositiontaking
--into #lic_pt_sports		
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =1 and dpt.bettype=1 and dpt.islive = 0
left join DBCust.CustDB.dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =1 and gdpt.bettype=1 and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype <= 99

--number game
SELECT bt.transid,bt.transdate,bt.matchid,m.sporttype,
case when dcm.isGroupedPT = 1 then gdpt.agentpt / 100 else dpt.agentpt / 100 end as apositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.masterpt / 100  else dpt.masterpt / 100 end as mpositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.superpt / 100 else dpt.superpt / 100 end as spositiontaking,
case when dcm.isGroupedPT = 1 then  gdpt.agentpt / 100 + gdpt.masterpt / 100 + gdpt.superpt / 100 
		else dpt.agentpt / 100 + dpt.masterpt / 100 + dpt.superpt / 100 end as tpositiontaking
--into #lic_pt_ng
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =161 and dpt.bettype=81 and dpt.islive = 0
left join DBCust.CustDB.dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =161 and gdpt.bettype=81 and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in (161,164)

-- betradar & inspire
SELECT bt.transid,bt.transdate,bt.matchid,m.sporttype,
case when dcm.isGroupedPT = 1 then gdpt.agentpt / 100 else dpt.agentpt / 100 end as apositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.masterpt / 100  else dpt.masterpt / 100 end as mpositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.superpt / 100 else dpt.superpt / 100 end as spositiontaking,
case when dcm.isGroupedPT = 1 then  gdpt.agentpt / 100 + gdpt.masterpt / 100 + gdpt.superpt / 100 
		else dpt.agentpt / 100 + dpt.masterpt / 100 + dpt.superpt / 100 end as tpositiontaking
--into #lic_pt_vs
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join Sport_Bettype_Reference_Setting sbr with (nolock) on sbr.sporttype = m.sporttype and sbr.bettype = bt.bettype and sbr.islicensee = 1 and sbr.islive = bt.liveindicator and sbr.site = 'all'
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =sbr.sporttyperefpt and dpt.bettype=sbr.bettyperefpt and dpt.islive = 0
left join DBCust.CustDB.dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =sbr.sporttyperefpt and gdpt.bettype=sbr.bettyperefpt and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in (180,186,190,191,192,193,194,195,196,197) 

--parlay
SELECT bt.transid,bt.transdate,bt.matchid,0 as sporttype,
case when dcm.isGroupedPT = 1 then gdpt.agentpt / 100 else dpt.agentpt / 100 end as apositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.masterpt / 100  else dpt.masterpt / 100 end as mpositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.superpt / 100 else dpt.superpt / 100 end as spositiontaking,
case when dcm.isGroupedPT = 1 then  gdpt.agentpt / 100 + gdpt.masterpt / 100 + gdpt.superpt / 100 
		else dpt.agentpt / 100 + dpt.masterpt / 100 + dpt.superpt / 100 end as tpositiontaking
--into #lic_pt_parlay
FROM bettrans bt  with (nolock)
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =1 and dpt.bettype=1 and dpt.islive = 0
left join DBCust.CustDB.dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =1 and gdpt.bettype=1 and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.matchid = 29

SELECT bm.transid, bm.transdate, bm.bettype, bm.matchid,
case when dcm.isGroupedPT = 1 then gdpt.agentpt / 100 else dpt.agentpt / 100 end as apositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.masterpt / 100  else dpt.masterpt / 100 end as mpositiontaking,
case when dcm.isGroupedPT = 1 then gdpt.superpt / 100 else dpt.superpt / 100 end as spositiontaking
--into #lic_pt_parlaym	
FROM bettrans bt  with (nolock)
join bettransm bm with (nolock) on bt.refno = bm.refno
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =1 and dpt.bettype=1 and dpt.islive = 0
left join DBCust.CustDB.dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =1 and gdpt.bettype=1 and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bm.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bm.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bm.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bm.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bm.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bm.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.matchid = 29


-------------------------------
-- backup data
-------------------------------
select b.*
into MONDB.dbo.Temp0331_lic_pt_sports
from bettrans b with (nolock)
	inner join #lic_pt_sports t on b.transid=t.transid

select b.*
into MONDB.dbo.Temp0331_lic_pt_ng
from bettrans b with (nolock)
	inner join #lic_pt_ng t on b.transid=t.transid

select b.*
into MONDB.dbo.Temp0331_lic_pt_vs
from bettrans b with (nolock)
	inner join #lic_pt_vs t on b.transid=t.transid

select b.*
into MONDB.dbo.Temp0331_lic_pt_parlay
from bettrans b with (nolock)
	inner join #lic_pt_parlay t on b.transid=t.transid

select b.*
into MONDB.dbo.Temp0331_lic_pt_parlaym
from bettransm b with (nolock)
	inner join #lic_pt_parlaym t on b.transid=t.transid

/*
update bettrans with (rowlock,updlock)
set apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking,
	tpositiontaking = tmp.tpositiontaking
	--RepUpdateTime = sysdatetime()	
from #lic_pt_sports	tmp
where bettrans.transid = tmp.transid

update bettrans with (rowlock,updlock)
set apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking,
	tpositiontaking = tmp.tpositiontaking
	--RepUpdateTime = sysdatetime()
from #lic_pt_ng	tmp
where bettrans.transid = tmp.transid

update bettrans with (rowlock,updlock)
set apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking,
	tpositiontaking = tmp.tpositiontaking
	--RepUpdateTime = sysdatetime()
from #lic_pt_vs	tmp
where bettrans.transid = tmp.transid

update bettrans with (rowlock,updlock)
set apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking,
	tpositiontaking = tmp.tpositiontaking
	--RepUpdateTime = sysdatetime()
from #lic_pt_parlay	tmp
where bettrans.transid = tmp.transid

update bettransm with (rowlock,updlock)
set apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking
	--RepUpdateTime = sysdatetime()	
from #lic_pt_parlaym tmp
where bettransm.transid = tmp.transid
*/

/*
drop table #lic_pt_sports
drop table #lic_pt_parlay
drop table #lic_pt_parlaym
drop table #lic_pt_ng
drop table #lic_pt_vs

*/