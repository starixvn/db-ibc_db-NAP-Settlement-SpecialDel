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
--into #credit_ng
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
	--into #credit_vs		
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
			

-- betradar parlay					
select transid,bt.custid, bt.bettype, bt.matchid,bt.oddsid as sporttype,						
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
	--into #credit_vsparlay
from bettrans bt with (nolock)						
join DBCust.CustDB.dbo.Site s with (nolock) on s.siteid = bt.betsiteid
--join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (190,191,192,193,194,195,196,197)						
join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and bt.oddsid = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and isLive=bt.liveindicator						
left join DBCust.CustDB.dbo.CustSettingMode3rd csm with (nolock) on csm.CustId = bt.custId						
left join DBCust.CustDB.dbo.CustPTSetting3rd_member pt with (nolock) on pt.custid = bt.custid and pt.bettype = sbr.bettyperefpt and pt.sporttype = sbr.sporttyperefpt and pt.islive = sbr.islivePT						
left join DBCust.CustDB.dbo.CustPTGroupSetting3rd_Member gpt with (nolock) on gpt.agentid = bt.recommend and gpt.bettype = sbr.bettyperefpt and gpt.sporttype = sbr.sporttyperefpt and gpt.islive = sbr.islivePT				where  (1 = case when csm.isGrouped = 1 then						
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
				or bt.playerdiscount <> 0
				or bt.discount <> 0
				or bt.adiscount <> 0
				or bt.sdiscount <> 0	)	
and bt.transdate between '20230330 04:00' and '20230330 04:20'		
and bt.bettype = 2799				
and s.islicensee = 0

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
	--into #credit_vsparlaym
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




/*
select b.* into Mondb.dbo.Temp0331_credit_vsparlay	from bettrans b with(Nolock)  	join #credit_vsparlay	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_vsparlaym	from bettransm b with(Nolock) 	join #credit_vsparlaym	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_ng		from bettrans b with(Nolock) 	join #credit_ng			T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_vs		from bettrans b with(Nolock) 	join #credit_vs			T on b.transid = T.Transid
*/

/*

update bettrans with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount,
	apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking,
	tpositiontaking = tmp.tpositiontaking
from #credit_vsparlay	tmp
where bettrans.transid = tmp.transid

update bettransm with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount,
	apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking
from #credit_vsparlaym	tmp
where bettransm.transid = tmp.transid


update bettrans with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount,
	apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking,
	tpositiontaking = tmp.tpositiontaking
from #credit_ng	tmp
where bettrans.transid = tmp.transid

update bettrans with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount,
	apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking,
	tpositiontaking = tmp.tpositiontaking
from #credit_vs	tmp
where bettrans.transid = tmp.transid
*/
		

/*
drop table #credit_vsparlay
drop table #credit_vsparlaym
drop table #credit_ng
drop table #credit_vs
*/
