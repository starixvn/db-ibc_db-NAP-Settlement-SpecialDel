--- Credit number game

select bt.transid, bt.custid, bt.bettype, m.matchid,m.sporttype, bt.liveindicator,
	pt.alivepositiontaking,
	pt.mlivepositiontaking,
	pt.slivepositiontaking,
	pt.alivepositiontaking+	pt.mlivepositiontaking+	pt.slivepositiontaking as tpositiontaking,
	isnull(comm.playerdiscount,0) as playerdiscount,					
	isnull(comm.discount,0) as discount,					
	isnull(comm.adiscount,0) as adiscount,					
	isnull(comm.sdiscount,0) as sdiscount
into #credit_ng
from bettrans bt with (nolock)
	inner join dbcust.custdb.dbo.site S with(nolock) on bt.BetSiteID = S.siteid 
	inner join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (161,164)
	inner join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and m.sporttype = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and isLive=bt.liveindicator
	left join dbcust.custdb.dbo.CustSetting3rd comm with (nolock) on comm.custid = bt.custid and comm.bettype = sbr.BetTypeRefComm and comm.sporttype = sbr.SportTypeRefComm
	left join dbcust.custdb.dbo.CustSetting3rd PT with (nolock) on PT.custid = bt.custid and PT.bettype = sbr.BetTypeRefPT and PT.sporttype = sbr.SportTypeRefPT
where  (isnull(comm.playerdiscount,0) <> bt.playerdiscount
		or isnull(comm.discount,0) <> bt.discount
		or isnull(comm.adiscount,0) <> bt.adiscount
		or isnull(comm.sdiscount,0) <>  bt.sdiscount
		or pt.alivepositiontaking <> bt.apositiontaking 
		or pt.mlivepositiontaking <> bt.mpositiontaking 
		or pt.slivepositiontaking <> bt.spositiontaking 
		)		
and bt.transdate >= '2023-03-30 04:00' and bt.transdate <= '2023-03-30 04:20'
and S.isLicensee =0 and bt.liveindicator=1


--- credit virtual sport
select transid,bt.custid, bt.bettype, m.matchid,m.sporttype,						
	case when csm.isgrouped =1 then ISNULL(gpt.agentpt,0) /100 else ISNULL(pt.agentpt,0) /100 end as apositiontaking,					
	case when csm.isgrouped =1 then ISNULL(gpt.masterpt,0) /100 else ISNULL(pt.masterpt,0) /100 end as mpositiontaking,					
	case when csm.isgrouped =1 then ISNULL(gpt.superpt,0) /100 else ISNULL(pt.superpt,0) /100 end as spositiontaking,					
	case when csm.isgrouped =1 then (ISNULL(gpt.agentpt,0) + ISNULL(gpt.masterpt,0) + ISNULL(gpt.superpt,0)) /100				
								else (ISNULL(pt.agentpt,0) + ISNULL(pt.masterpt,0) + ISNULL(pt.superpt,0))/100 end				
			as tpositiontaking,			
	isnull(comm.playerdiscount,0) as playerdiscount,					
	isnull(comm.discount,0) as discount,					
	isnull(comm.adiscount,0) as adiscount,					
	isnull(comm.sdiscount,0) as sdiscount,					
	bt.apositiontaking as APT,					
	bt.mpositiontaking as MPT,					
	bt.spositiontaking as SPT,					
	bt.playerdiscount as PPT,					
	bt.discount as DS,					
	bt.adiscount as ADS,					
	bt.sdiscount as SDS		
	into #credit_vs		
from bettrans bt with (nolock)						
inner join dbcust.custdb.dbo.site S with(nolock) on bt.BetSiteID = S.siteid 
join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (180,186,190,191,192,193,194,195,196,197)						
join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and m.sporttype = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and sbr.isLive=bt.liveindicator						
left join DBCust.CustDB.dbo.CustSettingMode3rd csm with (nolock) on csm.CustId = bt.custId						
left join DBCust.CustDB.dbo.CustPTSetting3rd_member pt with (nolock) on pt.custid = bt.custid and pt.bettype = sbr.bettyperefpt and pt.sporttype = sbr.sporttyperefpt and pt.islive = sbr.islivePT						
left join DBCust.CustDB.dbo.CustPTGroupSetting3rd_Member gpt with (nolock) on gpt.agentid = bt.recommend and gpt.bettype = sbr.bettyperefpt and gpt.sporttype = sbr.sporttyperefpt and gpt.islive = sbr.islivePT						
left join DBCust.CustDB.dbo.CustSetting3rd comm with (nolock) on comm.custid = bt.custid and comm.bettype = sbr.BetTypeRefComm and comm.sporttype = sbr.SportTypeRefComm						
where ( 1 = case when csm.isGrouped = 1 then						
				case when bt.apositiontaking <> ISNULL(gpt.agentpt,0) /100 or		
				bt.mpositiontaking <> ISNULL(gpt.masterpt,0) /100 or		
						bt.spositiontaking <> ISNULL(gpt.superpt,0) /100 then 1
				else 0 end		
				else		
				case when bt.apositiontaking <> ISNULL(pt.agentpt,0) /100 or		
				bt.mpositiontaking <> ISNULL(pt.masterpt,0) /100 or		
						bt.spositiontaking <> ISNULL(pt.superpt,0) /100 then 1
				else 0 end		
				end		
or (	isnull(comm.playerdiscount,0) <> bt.playerdiscount					
		or isnull(comm.discount,0) <> bt.discount				
		or isnull(comm.adiscount,0) <> bt.adiscount				
		or isnull(comm.sdiscount,0) <>  bt.sdiscount)	)			
and bt.transdate between '20230330 04:00' and '20230330 04:20'	
and s.IsLicensee = 0			


-- betradar parlaym					
select bm.transid,bm.custid, bm.bettype, bm.matchid,bt.oddsid as sporttype,						
	case when csm.isgrouped =1 then ISNULL(gpt.agentpt,0) /100 else ISNULL(pt.agentpt,0) /100 end as apositiontaking,					
	case when csm.isgrouped =1 then ISNULL(gpt.masterpt,0) /100 else ISNULL(pt.masterpt,0) /100 end as mpositiontaking,					
	case when csm.isgrouped =1 then ISNULL(gpt.superpt,0) /100 else ISNULL(pt.superpt,0) /100 end as spositiontaking,					
	case when csm.isgrouped =1 then (ISNULL(gpt.agentpt,0) + ISNULL(gpt.masterpt,0) + ISNULL(gpt.superpt,0)	)/100				
		else (ISNULL(pt.agentpt,0) + ISNULL(pt.masterpt,0) + ISNULL(pt.superpt,0))/100 end				
			as tpositiontaking,
	0 as playerdiscount,
	0 as discount,
	0 as adiscount,
	0 as sdiscount
	into #credit_vsparlaym
from bettrans bt with (nolock)		
join bettransm bm with (nolock) on bt.refno = bm.refno				
join DBCust.CustDB.dbo.Site s with (nolock) on s.siteid = bt.betsiteid
join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and bt.oddsid = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and isLive=bt.liveindicator						
left join DBCust.CustDB.dbo.CustSettingMode3rd csm with (nolock) on csm.CustId = bt.custId						
left join DBCust.CustDB.dbo.CustPTSetting3rd_member pt with (nolock) on pt.custid = bt.custid and pt.bettype = sbr.bettyperefpt and pt.sporttype = sbr.sporttyperefpt and pt.islive = sbr.islivePT						
left join DBCust.CustDB.dbo.CustPTGroupSetting3rd_Member gpt with (nolock) on gpt.agentid = bt.recommend and gpt.bettype = sbr.bettyperefpt and gpt.sporttype = sbr.sporttyperefpt and gpt.islive = sbr.islivePT				where  (1 = case when csm.isGrouped = 1 then						
				case when bm.apositiontaking <> ISNULL(gpt.agentpt,0) /100 or		
						  bm.mpositiontaking <> ISNULL(gpt.masterpt,0) /100 or		
						  bm.spositiontaking <> ISNULL(gpt.superpt,0) /100 then 1
				else 0 end		
				else		
				case when bm.apositiontaking <> ISNULL(pt.agentpt,0) /100 or		
						  bm.mpositiontaking <> ISNULL(pt.masterpt,0) /100 or		
						  bm.spositiontaking <> ISNULL(pt.superpt,0) /100 then 1
				else 0 end		
				end		
				or bm.playerdiscount <> 0
				or bm.discount <> 0
				or bm.adiscount <> 0
				or bm.sdiscount <> 0	)	
and bt.transdate between '20230330 04:00' and '20230330 04:20'		
and bt.bettype = 2799				
and s.islicensee = 0


--number game
SELECT bt.transid,bt.transdate,bt.matchid,m.sporttype,
case when dcm.isGroupedComm = 1 then gdcom.playerdiscount else dcom.playerdiscount end as playerdiscount,
case when dcm.isGroupedComm = 1 then gdcom.agentdiscount else dcom.agentdiscount end as discount,
case when dcm.isGroupedComm = 1 then gdcom.masterdiscount else dcom.masterdiscount end as adiscount,
case when dcm.isGroupedComm = 1 then gdcom.superdiscount else dcom.superdiscount end as sdiscount
into #lic_comm_ng
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
into #lic_comm_vs
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


-- Bet radar parlaym
select
    bm.transid, bm.transdate, bm.bettype,bm.matchid,
    case when dcm.isGroupedComm = 1 then gdcom.playerdiscount else dcom.playerdiscount end as playerdiscount,
	case when dcm.isGroupedComm = 1 then gdcom.agentdiscount else dcom.agentdiscount end as discount,
	case when dcm.isGroupedComm = 1 then gdcom.masterdiscount else dcom.masterdiscount end as adiscount,
	case when dcm.isGroupedComm = 1 then gdcom.superdiscount else dcom.superdiscount end as sdiscount
	into #lic_comm_vs_parlaym
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

--number game
SELECT bt.transid,bt.transdate,bt.matchid,m.sporttype,
case when dcm.isGroupedPT = 1 then ISNULL(gdpt.agentpt,0) / 100 else ISNULL(dpt.agentpt,0) / 100 end as apositiontaking,
case when dcm.isGroupedPT = 1 then ISNULL(gdpt.masterpt,0) / 100  else ISNULL(dpt.masterpt,0) / 100 end as mpositiontaking,
case when dcm.isGroupedPT = 1 then ISNULL(gdpt.superpt,0) / 100 else ISNULL(dpt.superpt,0) / 100 end as spositiontaking,
case when dcm.isGroupedPT = 1 then  (ISNULL(gdpt.agentpt,0) + ISNULL(gdpt.masterpt,0)  + ISNULL(gdpt.superpt,0) )/ 100 
		else (ISNULL(dpt.agentpt,0)  + ISNULL(dpt.masterpt,0) + ISNULL(dpt.superpt,0)) / 100 end as tpositiontaking
into #lic_pt_ng
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
case when dcm.isGroupedPT = 1 then ISNULL(gdpt.agentpt,0) 	/ 100 else ISNULL(dpt.agentpt,0) 	/ 100 end as apositiontaking,
case when dcm.isGroupedPT = 1 then ISNULL(gdpt.masterpt,0)	/ 100 else ISNULL(dpt.masterpt,0)	/ 100 end as mpositiontaking,
case when dcm.isGroupedPT = 1 then ISNULL(gdpt.superpt,0) 	/ 100 else ISNULL(dpt.superpt,0) 	/ 100 end as spositiontaking,
case when dcm.isGroupedPT = 1 then (  ISNULL(gdpt.agentpt,0) + ISNULL(gdpt.masterpt,0) + ISNULL(gdpt.superpt,0)) / 100 
								else( ISNULL(dpt.agentpt,0) + ISNULL(dpt.masterpt,0) + ISNULL(dpt.superpt,0) )/100 end as tpositiontaking
into #lic_pt_vs
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


-- betradar parlaym					
select bm.transid,bm.custid, bm.bettype, bm.matchid,bt.oddsid as sporttype,						
	case when dcm.isGroupedPT =1 then ISNULL(gdpt.agentpt,0) /100 else ISNULL(dpt.agentpt,0) /100 end as apositiontaking,					
	case when dcm.isGroupedPT =1 then ISNULL(gdpt.masterpt,0) /100 else ISNULL(dpt.masterpt,0) /100 end as mpositiontaking,					
	case when dcm.isGroupedPT =1 then ISNULL(gdpt.superpt,0) /100 else ISNULL(dpt.superpt,0) /100 end as spositiontaking
into #lic_pt_vsparlaym
from bettrans bt with (nolock)
join bettransm bm with (nolock) on bt.refno = bm.refno																
join Sport_Bettype_Reference_Setting sbr with (nolock) on sbr.sporttype = bt.oddsid and sbr.bettype = bt.bettype and sbr.islicensee = 1 and sbr.islive = bt.liveindicator and sbr.site = 'all'
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join DBCust.CustDB.dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =sbr.sporttyperefpt and dpt.bettype=sbr.bettyperefpt and dpt.islive = 0
left join DBCust.CustDB.dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =sbr.sporttyperefpt and gdpt.bettype=sbr.bettyperefpt and gdpt.islive = 0				
where  1 = case when dcm.isGroupedPT = 1 then						
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
and bt.bettype = 2799				
and bt.transdate between '20230330 04:00' and '20230330 04:20'		


select sporttype, matchid into #match_list from #credit_vsparlaym
insert into #match_list select sporttype, matchid from #credit_ng
insert into #match_list select sporttype, matchid from #credit_vs
insert into #match_list select sporttype, matchid from #lic_pt_ng
insert into #match_list select sporttype, matchid from #lic_pt_vs
insert into #match_list select sporttype, matchid from #lic_pt_vsparlaym
insert into #match_list select sporttype, matchid from #lic_comm_ng
insert into #match_list select sporttype, matchid from #lic_comm_vs
insert into #match_list select m.sporttype, t.matchid from #lic_comm_vs_parlaym t join match m with (nolock) on t.matchid = m.matchid

select distinct matchid, sporttype from #match_list

