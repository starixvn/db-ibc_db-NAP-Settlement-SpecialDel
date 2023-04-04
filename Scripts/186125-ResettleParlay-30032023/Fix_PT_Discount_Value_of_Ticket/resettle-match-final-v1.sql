/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Creator: TW Team
	Date: 20230330
	DB: DBTXN/bodb02

	Revisions:
		- 20230330@Tina: TW team scripts to detect for the issue- Wrong PT, Comm Setting, SMA winloss for tickets  [Redmine:#186125]

*/	
--drop table #TEMP																				
--- Credit sport																				
--Single-SportBetTypeReference_Setting																				
select  m.matchid into #TEMP																				
from bettrans b with (nolock)																				
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99																			
inner join Sport_Bettype_Reference_setting sb with (nolock) on sb.bettype=b.bettype and sb.Sporttype=m.sporttype and sb.isLicensee= 0 and sb.islive = b.liveIndicator and sb.site ='all'																				
inner join dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=sb.SporttypeRefPT and sb.BettypeRefPT=cs.bettype																				
	inner join dbo.custsetting csd with (nolock) on csd.custid=b.custid and csd.sporttype=sb.SporttypeRefComm and sb.BetTypeRefComm=csd.bettype																			
where currency not in (20,72)																				
and b.srecommend not in (select custid from dep_custsuper with (nolock))																				
and (b.spositiontaking<>cs.spositiontaking																				
or b.mpositiontaking<>cs.mpositiontaking																				
or  b.apositiontaking<>cs.apositiontaking																				
or b.playerdiscount <> csd.playerdiscount																				
or  b.sdiscount<>csd.sdiscount																				
or  b.discount<>csd.discount																				
or  b.adiscount<>csd.adiscount																				
)																				
	and b.transdate >= '2023-03-30 04:00' and b.transdate <= '2023-03-30 04:20'																			
order by b.transdate																				
-- (121 rows affected)																				
																				
--Single-SportBetTypeReference																				
insert into #TEMP																				
select  m.matchid																				
from bettrans b with (nolock)																				
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99																			
inner join Sport_Bettype_Reference sb with (nolock) on sb.bettype=b.bettype and sb.Sporttype=m.sporttype and sb.isLicensee= 0																				
inner join custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=sb.SporttypeRef and sb.BettypeRef=cs.bettype																				
where currency not in (20,72)																				
and b.srecommend not in (select custid from dbo.dep_custsuper with (nolock))																				
and (b.spositiontaking<>cs.spositiontaking																				
or b.mpositiontaking<>cs.mpositiontaking																				
or  b.apositiontaking<>cs.apositiontaking																				
or b.playerdiscount <> cs.playerdiscount																				
or  b.sdiscount<>cs.sdiscount																				
or  b.discount<>cs.discount																				
or  b.adiscount<>cs.adiscount																				
)																				
	and b.transdate >= '2023-03-30 04:00' and b.transdate <= '2023-03-30 04:20'																			
	and b.bettype not in (10, 16, 20, 21, 22, 25, 29, 38, 143, 144, 154, 221, 222, 223, 224, 225, 226, 227, 228, 229,																			
376, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399,																				
400, 408, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 428, 429, 430, 431, 442, 445, 446, 447,																				
448,																				
449, 450,																				
451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 467, 468, 469, 470, 471, 472, 473,																				
474,																				
475, 476,																				
477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497,																				
501,																				
1301, 1311, 1324, 1332, 1333, 2799)																				
	and m.sporttype not in (2, 6, 9, 43, 45, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 161, 164,																			
175,																				
180, 181, 182, 183, 184, 185, 186, 190, 191, 192, 193, 194, 195, 196, 197)																				
order by b.transdate																				
-- (24 rows affected)																				
																				
--Single-WithOutReference live pt																				
insert into #TEMP																				
select  m.matchid																				
from bettrans b with (nolock)																				
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99																			
inner join dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=m.sporttype and cs.bettype = b.bettype																				
where currency not in (20,72)																				
and b.liveIndicator = 1																				
and m.sporttype =1																				
and b.bettype in (1,3,7,8)																				
and b.srecommend not in (select custid from dbo.dep_custsuper with (nolock))																				
and (b.spositiontaking<>cs.slivepositiontaking																				
or b.mpositiontaking<>cs.mlivepositiontaking																				
or  b.apositiontaking<>cs.alivepositiontaking																				
or b.playerdiscount <> cs.playerdiscount																				
or  b.sdiscount<>cs.sdiscount																				
or  b.discount<>cs.discount																				
or  b.adiscount<>cs.adiscount																				
)																				
	and b.transdate >= '2023-03-30 04:00' and b.transdate <= '2023-03-30 04:20'																			
	and b.bettype not in (10, 16, 20, 21, 22, 25, 29, 38, 143, 144, 154, 221, 222, 223, 224, 225, 226, 227, 228, 229,																			
376, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399,																				
400, 408, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 428, 429, 430, 431, 442, 445, 446, 447,																				
448,																				
449, 450,																				
451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 467, 468, 469, 470, 471, 472, 473,																				
474,																				
475, 476,																				
477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497,																				
501,																				
1301, 1311, 1324, 1332, 1333, 2799)																				
	and m.sporttype not in (2, 6, 9, 43, 45, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 161, 164,																			
175,																				
180, 181, 182, 183, 184, 185, 186, 190, 191, 192, 193, 194, 195, 196, 197)																				
order by b.transdate																				
																				
-- credit without reference deadball																				
insert into #TEMP																				
select  m.matchid																				
from bettrans b with (nolock)																				
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99																			
inner join dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=m.sporttype and cs.bettype = b.bettype																				
where currency not in (20,72)																				
and (b.liveIndicator = 0 or (b.liveIndicator =  1 and b.bettype not in (1,3,7,8)))																				
and b.srecommend not in (select custid from dbo.dep_custsuper with (nolock))																				
and (b.spositiontaking<>cs.spositiontaking																				
or b.mpositiontaking<>cs.mpositiontaking																				
or  b.apositiontaking<>cs.apositiontaking																				
or b.playerdiscount <> cs.playerdiscount																				
or  b.sdiscount<>cs.sdiscount																				
or  b.discount<>cs.discount																				
or  b.adiscount<>cs.adiscount																				
)																				
	and b.transdate >= '2023-03-30 04:00' and b.transdate <= '2023-03-30 04:20'																			
	and b.bettype not in (10, 16, 20, 21, 22, 25, 29, 38, 143, 144, 154, 221, 222, 223, 224, 225, 226, 227, 228, 229,																			
376, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399,																				
400, 408, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 428, 429, 430, 431, 442, 445, 446, 447,																				
448,																				
449, 450,																				
451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 467, 468, 469, 470, 471, 472, 473,																				
474,																				
475, 476,																				
477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497,																				
501,																				
1301, 1311, 1324, 1332, 1333, 2799)																				
	and m.sporttype not in (2, 6, 9, 43, 45, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 161, 164,																			
175,																				
180, 181, 182, 183, 184, 185, 186, 190, 191, 192, 193, 194, 195, 196, 197)																				
order by b.transdate																				
-- (171 rows affected)																				
																				
																				
-- Parlay BetTransM																				
insert into #TEMP																				
select bm.matchid																				
from bettrans b with (nolock)																				
	inner join bettransm bm with(nolock) on b.refno = bm.refno																			
inner join dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.bettype=9 and cs.sporttype= b.oddsid																				
where b.currency not in (20,72) and b.matchid=29																				
and b.srecommend not in (select custid from dbo.dep_custsuper with (nolock))																				
and (bm.spositiontaking<>cs.spositiontaking																				
or bm.mpositiontaking<>cs.mpositiontaking																				
or  bm.apositiontaking<>cs.apositiontaking																				
or bm.playerdiscount <> cs.playerdiscount																				
or  bm.sdiscount<>cs.sdiscount																				
or  bm.discount<>cs.discount																				
or  bm.adiscount<>cs.adiscount																				
)																				
	and b.transdate >= '2023-03-30 04:00' and b.transdate <= '2023-03-30 04:20'																			
order by b.transdate																				
																				
--- Credit number game																				
																				
insert into #TEMP																				
select  m.matchid																				
from bettrans bt with (nolock)																				
	inner join site S with(nolock) on bt.BetSiteID = S.siteid																			
	inner join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (161,164)																			
	inner join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and m.sporttype = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and isLive=bt.liveindicator																			
	inner join CustSetting3rd comm with (nolock) on comm.custid = bt.custid and comm.bettype = sbr.BetTypeRefComm and comm.sporttype = sbr.SportTypeRefComm																			
	inner join CustSetting3rd PT with (nolock) on PT.custid = bt.custid and PT.bettype = sbr.BetTypeRefPT and PT.sporttype = sbr.SportTypeRefPT																			
where  (comm.playerdiscount <> bt.playerdiscount																				
		or comm.discount <> bt.discount																		
		or comm.adiscount <> bt.adiscount																		
		or comm.sdiscount <>  bt.sdiscount																		
		or pt.alivepositiontaking <> bt.apositiontaking																		
		or pt.mlivepositiontaking <> bt.mpositiontaking																		
		or pt.slivepositiontaking <> bt.spositiontaking																		
		)																		
and bt.transdate >= '2023-03-30 04:00' and bt.transdate <= '2023-03-30 04:20'																				
and bt.winlostdate = '2023-03-30'																				
and S.isLicensee =0 and bt.liveindicator=1																				
																				
																				
--- credit virtual sport																				
insert into #TEMP																				
select  matchid from (																				
select transid,bt.custid, bt.bettype, m.matchid,m.sporttype,																				
	case when csm.isgrouped =1 then ISNULL(gpt.agentpt,0) /100 else ISNULL(pt.agentpt,0) /100 end as apositiontaking,																			
	case when csm.isgrouped =1 then ISNULL(gpt.masterpt,0) /100 else ISNULL(pt.masterpt,0) /100 end as mpositiontaking,																			
	case when csm.isgrouped =1 then ISNULL(gpt.superpt,0) /100 else ISNULL(pt.superpt,0) /100 end as spositiontaking,																			
	case when csm.isgrouped =1 then ISNULL(gpt.agentpt,0) + ISNULL(gpt.masterpt,0) + ISNULL(gpt.superpt,0)																			
		else (ISNULL(pt.agentpt,0) + ISNULL(pt.masterpt,0) + ISNULL(pt.superpt,0))/100 end																		
			as tpositiontaking,																	
	comm.playerdiscount,																			
	comm.discount,																			
	comm.adiscount,																			
	comm.sdiscount,																			
	bt.apositiontaking as APT,																			
	bt.mpositiontaking as MPT,																			
	bt.spositiontaking as SPT,																			
	bt.playerdiscount as PPT,																			
	bt.discount as DS,																			
	bt.adiscount as ADS,																			
	bt.sdiscount as SDS																			
from bettrans bt with (nolock)																				
join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (180,186,190,191,192,193,194,195,196,197)																				
join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and m.sporttype = sbr.SportType and isLicensee = 0 and site = 'all' and isLive=bt.liveindicator																				
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
)A where tpositiontaking <>0																				
																				
---------------------------------------------																				
insert into #TEMP																				
SELECT bt.matchid																				
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
insert into #TEMP																				
SELECT bt.matchid																				
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
insert into #TEMP																				
SELECT bt.matchid																				
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
																				
insert into #TEMP																				
SELECT bt.matchid																				
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
																				
----4------																				
																				
																				
insert into #TEMP																				
select  m.matchid																				
FROM bettrans bt  with (nolock)																				
join match m with (nolock) on bt.matchid = m.matchid																				
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid																				
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=1																				
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=1																				
where 1 = case when dcm.isGroupedComm = 1 then																				
				case when	gdcom.playerdiscount <> bt.playerdiscount or															
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
and bt.bettype in (1, 2, 3, 7, 8, 11, 12, 13, 17, 18, 25, 27, 28, 121, 122, 123, 128, 153, 155, 156, 157, 178, 183, 184, 185,																				
189, 190, 191, 194, 197, 198, 203, 204, 205, 206, 207, 208, 209, 219, 220, 228, 229, 381, 382, 383, 386,																				
387, 388, 389, 390, 393, 394, 400, 401, 402, 403, 404, 411, 428, 453, 461, 462, 463, 464, 470, 471, 472,																				
477, 478, 482, 483, 484, 485, 488, 489, 490, 491, 492, 497, 609, 610, 611, 615, 616, 701, 702, 704, 705,																				
706, 708, 709, 710, 801, 803, 804, 805, 806, 1318, 3902, 3904, 3905, 3906, 3907, 3908, 7901, 9002, 9003,																				
9005, 9008, 9009, 9012, 9013, 9018, 9019, 9024, 9025, 9028, 9029, 9034, 9035, 9040, 9041, 9046, 9047, 9052,																				
9053, 9058, 9059, 9060, 9061, 9070, 9071, 9074, 9076, 9077, 9078, 9079, 9080, 9081, 9082, 9083, 9084, 9085,																				
9086, 9089, 9090, 9091, 9092, 9093, 9094, 9095, 9096, 9097, 9098, 9099, 9100, 9116, 9117, 9118, 9119, 9120,																				
9121, 9123, 9126, 9127, 9128, 9129, 9131, 9134, 9136, 9137, 9139, 9140, 9402, 9403, 9404, 9405, 9406, 9407,																				
9408, 9409, 9410, 9411, 9412, 9413, 9414, 9415, 9416, 9417, 9418, 9419, 9420, 9421, 9422, 9423, 9424, 9425,																				
9426, 9427, 9428, 9429, 9430, 9431, 9432, 9433, 9445, 9446, 9447, 9448, 9449, 9450, 9451, 9452, 9453, 9454,																				
9455, 9456, 9457, 9458, 9459, 9460, 9461, 9462, 9463, 9464, 9465, 9466, 9467, 9468, 9469, 9470, 9471, 9472,																				
9473, 9474, 9475, 9476, 9477, 9478, 9479, 9480, 9481, 9482, 9483, 9496, 9497, 9498, 9499, 9500, 9501, 9502,																				
9503, 9504, 9505, 9506, 9507, 9508, 9509, 9510, 9511, 9512, 9513, 9514, 9515, 9516, 9517, 9518, 9519, 9520,																				
9521, 9522, 9523, 9524, 9525, 9526, 9527, 9528, 9529, 9530, 9531, 9532, 9533, 9534, 9535, 9536, 9537, 9604,																				
9605, 9607, 9608, 9609, 9610, 9611, 9612, 9613, 9614, 9616, 9617, 9618, 9619, 9620, 9621, 9622, 9623, 9676,																				
9677, 9678, 9679, 9680, 9681, 9682, 9683, 9684, 9685, 9686, 9687, 9688, 9689, 9690, 9691, 9692, 9693, 9694,																				
9695, 9696, 9697, 9698, 9699, 9702, 9703, 9704, 9705, 9708, 9709, 9730, 9731, 9732, 9733, 9734, 9735, 9736,																				
9737, 9738, 9739)																				
and m.sporttype <= 99																				
																				
insert into #TEMP																				
select  m.matchid																				
FROM bettrans bt  with (nolock)																				
join match m with (nolock) on bt.matchid = m.matchid																				
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid																				
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=4																				
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=4																				
where 1 = case when dcm.isGroupedComm = 1 then																				
				case when	gdcom.playerdiscount <> bt.playerdiscount or															
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
and bt.bettype in (4, 6, 10, 14, 16, 22, 24, 26, 30, 38, 126, 127, 133, 134, 135, 140, 141, 142, 143, 144, 145, 146, 147, 148,																				
149, 150, 151, 152, 159, 160, 161, 162, 163, 164, 165, 166, 168, 169, 170, 171, 172, 173, 174, 175, 179,																				
180, 181, 182, 186, 187, 188, 192, 193, 195, 196, 199, 200, 201, 202, 210, 211, 212, 213, 214, 215, 216,																				
217, 221, 222, 223, 224, 225, 226, 227, 376, 384, 391, 392, 395, 396, 397, 398, 399, 405, 406, 407, 408,																				
409, 410, 412, 413, 414, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 429, 431, 442, 445, 446,																				
447, 448, 449, 450, 451, 452, 454, 455, 456, 457, 460, 467, 468, 469, 473, 474, 475, 476, 479, 481, 486,																				
487, 493, 494, 495, 496, 601, 602, 608, 614, 618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628, 629,																				
631, 632, 633, 634, 635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646, 703, 711, 1302, 1317, 9088)																				
and m.sporttype <= 99																				
																				
insert into #TEMP																				
select  m.matchid																				
FROM bettrans bt  with (nolock)																				
join match m with (nolock) on bt.matchid = m.matchid																				
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid																				
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=5																				
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=5																				
where 1 = case when dcm.isGroupedComm = 1 then																				
				case when	gdcom.playerdiscount <> bt.playerdiscount or															
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
and bt.bettype in (5, 15, 20, 21, 154, 167, 176, 177, 385, 430, 458, 459, 501, 502, 603, 604, 605, 606, 607, 612, 613, 617,																				
630, 707, 712, 713, 714, 1301, 1311, 1324, 1332, 1333, 3901, 3903, 3909, 3912, 3914, 3916, 3918, 9001, 9006,																				
9007,																				
9011, 9015, 9016, 9017, 9021, 9022, 9023, 9027, 9031, 9032, 9033, 9037, 9038, 9039, 9043, 9044, 9045, 9049,																				
9050, 9051, 9055, 9056, 9057, 9062, 9063, 9064, 9068, 9072, 9073, 9075, 9087, 9101, 9102, 9103, 9104, 9105,																				
9106, 9107, 9108, 9109, 9110, 9111, 9112, 9113, 9114, 9115, 9122, 9124, 9125, 9130, 9132, 9133, 9135, 9138,																				
9141, 9142, 9400, 9401, 9434, 9435, 9436, 9437, 9438, 9439, 9440, 9441, 9442, 9443, 9444, 9615, 9624, 9625,																				
9626, 9627, 9628, 9629, 9630, 9631, 9632, 9633, 9634, 9635, 9662, 9663, 9664, 9665, 9666, 9667, 9710, 9711)																				
and m.sporttype <= 99																				
																				
insert into #TEMP																				
select  m.matchid																				
FROM bettrans bt  with (nolock)																				
join match m with (nolock) on bt.matchid = m.matchid																				
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid																				
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=9																				
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=9																				
where 1 = case when dcm.isGroupedComm = 1 then																				
				case when	gdcom.playerdiscount <> bt.playerdiscount or															
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
and bt.bettype in (29, 3900, 3910, 3911, 3913, 3915, 3917, 9484, 9485, 9486, 9487, 9488, 9489, 9490, 9491, 9492, 9493, 9494,																				
9495,																				
9636, 9637, 9638, 9639, 9640, 9641, 9650, 9651, 9652, 9653, 9654, 9655, 9656, 9657, 9658, 9659, 9660, 9661,																				
9668, 9669, 9670, 9671, 9672, 9673, 9674, 9675)																				
and m.sporttype <= 99																				
																				
insert into #TEMP																				
select  m.matchid																				
FROM bettrans bt  with (nolock)																				
join match m with (nolock) on bt.matchid = m.matchid																				
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid																				
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =161 and dcom.bettype=81																				
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =161 and gdcom.bettype=81																				
where 1 = case when dcm.isGroupedComm = 1 then																				
				case when	gdcom.playerdiscount <> bt.playerdiscount or															
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
																				
insert into #TEMP																				
select  m.matchid																				
FROM bettrans bt  with (nolock)																				
join match m with (nolock) on bt.matchid = m.matchid																				
join Sport_Bettype_Reference_Setting sbr with (nolock) on sbr.sporttype = m.sporttype and sbr.bettype = bt.bettype and sbr.islicensee = 1 and sbr.islive = bt.liveindicator and sbr.site = 'all'																				
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid																				
left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =sbr.sporttyperefcomm and dcom.bettype=sbr.bettyperefcomm																				
left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =sbr.sporttyperefcomm and gdcom.bettype=sbr.bettyperefcomm																				
where 1 = case when dcm.isGroupedComm = 1 then																				
				case when	gdcom.playerdiscount <> bt.playerdiscount or															
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
																				
																				
insert into #TEMP																				
select  bm.matchid																				
from bettrans bt with (nolock)																				
	inner join bettransm bm with(nolock) on bt.refno = bm.refno																			
join DBCust.CustDB.dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid																				
	left join DBCust.CustDB.dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=9																			
	left join DBCust.CustDB.dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=9																			
where bt.matchid=29																				
and 1 = case when dcm.isGroupedComm = 1 then																				
				case when	gdcom.playerdiscount <> bm.playerdiscount or															
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
order by bt.transdate																				
																				
																				
																				
																				
																				
select distinct matchid from #Temp																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				
																				