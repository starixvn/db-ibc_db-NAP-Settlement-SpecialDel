--number game
SELECT bt.transid,bt.transdate,bt.matchid,m.sporttype,
case when dcm.isGroupedComm = 1 then gdcom.playerdiscount else dcom.playerdiscount end as playerdiscount,
case when dcm.isGroupedComm = 1 then gdcom.agentdiscount else dcom.agentdiscount end as discount,
case when dcm.isGroupedComm = 1 then gdcom.masterdiscount else dcom.masterdiscount end as adiscount,
case when dcm.isGroupedComm = 1 then gdcom.superdiscount else dcom.superdiscount end as sdiscount
--into #lic_comm_ng
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =161 and dcom.bettype=81 
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =161 and gdcom.bettype=81 
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in (161,164)
-- virtual sports
SELECT bt.transid,bt.transdate,bt.matchid,m.sporttype,
case when dcm.isGroupedComm = 1 then gdcom.playerdiscount else dcom.playerdiscount end as playerdiscount,
case when dcm.isGroupedComm = 1 then gdcom.agentdiscount else dcom.agentdiscount end as discount,
case when dcm.isGroupedComm = 1 then gdcom.masterdiscount else dcom.masterdiscount end as adiscount,
case when dcm.isGroupedComm = 1 then gdcom.superdiscount else dcom.superdiscount end as sdiscount
--into #lic_comm_vs
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join Sport_Bettype_Reference_Setting sbr with (nolock) on sbr.sporttype = m.sporttype and sbr.bettype = bt.bettype and sbr.islicensee = 1 and sbr.islive = bt.liveindicator and sbr.site = 'all'
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =sbr.sporttyperefcomm and dcom.bettype=sbr.bettyperefcomm
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =sbr.sporttyperefcomm and gdcom.bettype=sbr.bettyperefcomm 
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in  (180,186,190,191,192,193,194,195,196,197)

-- Bet radar parlay
SELECT bt.transid,bt.transdate,bt.matchid,0 as sporttype,
case when dcm.isGroupedComm = 1 then gdcom.playerdiscount else dcom.playerdiscount end as playerdiscount,
case when dcm.isGroupedComm = 1 then gdcom.agentdiscount else dcom.agentdiscount end as discount,
case when dcm.isGroupedComm = 1 then gdcom.masterdiscount else dcom.masterdiscount end as adiscount,
case when dcm.isGroupedComm = 1 then gdcom.superdiscount else dcom.superdiscount end as sdiscount
--into #lic_comm_vs_parlay
FROM bettrans bt  with (nolock)
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =190 and dcom.bettype=2701
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =190 and gdcom.bettype=2701
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.bettype = 2799

-- Bet radar parlaym
select
    bm.transid, bm.transdate, bm.bettype,bm.matchid,
    case when dcm.isGroupedComm = 1 then gdcom.playerdiscount else dcom.playerdiscount end as playerdiscount,
	case when dcm.isGroupedComm = 1 then gdcom.agentdiscount else dcom.agentdiscount end as discount,
	case when dcm.isGroupedComm = 1 then gdcom.masterdiscount else dcom.masterdiscount end as adiscount,
	case when dcm.isGroupedComm = 1 then gdcom.superdiscount else dcom.superdiscount end as sdiscount
	--into #lic_comm_vs_parlaym
from bettrans bt with (nolock)
	inner join bettransm bm with(nolock) on bt.refno = bm.refno
    join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
	left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =190 and dcom.bettype=2701
	left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =190 and gdcom.bettype=2701
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bm.playerdiscount or
						 	gdcom.agentdiscount <> bm.discount or
						 	gdcom.masterdiscount <> bm.adiscount or
						 	gdcom.superdiscount <>  bm.sdiscount then 1 
				else 0 end 
				else
				case when bm.playerdiscount <> dcom.playerdiscount or
				          bm.discount <> dcom.agentdiscount or
				          bm.adiscount <> dcom.masterdiscount or
						  bm.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
	and bt.transdate >= '2023-03-30 04:00' and bt.transdate <= '2023-03-30 04:20'
	and bt.bettype = 2799
order by bt.transdate


-------------------------------
-- backup data
-------------------------------
select b.*
into MONDB.dbo.Temp0331_lic_comm_ng
from bettrans b with (nolock)
	inner join #lic_comm_ng t on b.transid=t.transid

select b.*
into MONDB.dbo.Temp0331_lic_comm_vs
from bettrans b with (nolock)
	inner join #lic_comm_vs t on b.transid=t.transid
	
select b.*
into MONDB.dbo.Temp0331_lic_comm_parlay
from bettrans b with (nolock)
	inner join #lic_comm_vs_parlay t on b.transid=t.transid

select b.*
into MONDB.dbo.Temp0331_lic_comm_parlaym
from bettransm b with (nolock)
	inner join #lic_comm_vs_parlaym t on b.transid=t.transid
		

/*
update bettrans with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount
from #lic_comm_ng	tmp
where bettrans.transid = tmp.transid

update bettrans with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount
from #lic_comm_vs	tmp
where bettrans.transid = tmp.transid

update bettrans with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount
from #lic_comm_vs_parlay	tmp
where bettrans.transid = tmp.transid

update bettransm with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount
from #lic_comm_vs_parlaym	tmp
where bettransm.transid = tmp.transid

*/
/*
drop table #lic_comm_ng
drop table #lic_comm_vs
drop table #lic_comm_vs_parlay
drop table #lic_comm_vs_parlaym

*/

