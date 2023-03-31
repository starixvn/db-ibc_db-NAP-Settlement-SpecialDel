/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Creator: TW Team
	Date: 20230330
	DB: DBCTG/bodb02

	Revisions:
		- 20230330@Tina: TW team scripts to detect for the issue- Wrong PT, Comm Setting, SMA winloss for tickets  [Redmine:#186125]

*/

--- Credit sport

--Single-SportBetTypeReference_Setting
select  B.transid, b.transdate, m.sporttype, b.bettype, m.matchid,
		cs.spositiontaking,
        cs.mpositiontaking,
        cs.apositiontaking,
		csd.playerdiscount,
		csd.sdiscount,
		csd.discount,
		csd.adiscount,
        --ISNULL((SELECT SUM(ISNULL(ept.ExtraPT,0)) FROM Acc_GroupExtraPTSetting ept with(nolock) WHERE ept.ProductId = 1 and ept.sporttype = 0 and ept.subProduct = '' and ept.superId = b.srecommend AND b.transDate BETWEEN FromDate AND ToDate ),0) AS epositiontaking			 ,
        cs.spositiontaking + cs.mpositiontaking + cs.apositiontaking as Tpositiontaking
--into #credit_single_1
from bettrans b with (nolock)
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99
    inner join Sport_Bettype_Reference_setting sb with (nolock) on sb.bettype=b.bettype and sb.Sporttype=m.sporttype and sb.isLicensee= 0 and sb.islive = b.liveIndicator and sb.site ='all'
    inner join dbcust.custdb.dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=sb.SporttypeRefPT and sb.BettypeRefPT=cs.bettype
	inner join dbcust.custdb.dbo.custsetting csd with (nolock) on csd.custid=b.custid and csd.sporttype=sb.SporttypeRefComm and sb.BetTypeRefComm=csd.bettype
where currency not in (20,72)
  and b.srecommend not in (select custid from dbcust.custdb.dbo.dep_custsuper with (nolock))
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
select  B.transid, b.transdate, m.sporttype, b.bettype, m.matchid,
		cs.spositiontaking,
        cs.mpositiontaking,
        cs.apositiontaking,
		cs.playerdiscount,
		cs.sdiscount,
		cs.discount,
		cs.adiscount,
        --ISNULL((SELECT SUM(ISNULL(ept.ExtraPT,0)) FROM Acc_GroupExtraPTSetting ept with(nolock) WHERE ept.ProductId = 1 and ept.sporttype = 0 and ept.subProduct = '' and ept.superId = b.srecommend AND b.transDate BETWEEN FromDate AND ToDate ),0) AS epositiontaking			 ,
        cs.spositiontaking + cs.mpositiontaking + cs.apositiontaking as Tpositiontaking
--into #credit_single_2
from bettrans b with (nolock)
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99
    inner join Sport_Bettype_Reference sb with (nolock) on sb.bettype=b.bettype and sb.Sporttype=m.sporttype and sb.isLicensee= 0
    inner join dbcust.custdb.dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=sb.SporttypeRef and sb.BettypeRef=cs.bettype    
where currency not in (20,72)
  and b.srecommend not in (select custid from dbcust.custdb.dbo.dep_custsuper with (nolock))
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
select  B.transid, b.transdate, m.sporttype, b.bettype, m.matchid,
		cs.slivepositiontaking as spositiontaking,
        cs.mlivepositiontaking as mpositiontaking,
        cs.alivepositiontaking as apositiontaking,
		cs.playerdiscount,
		cs.sdiscount,
		cs.discount,
		cs.adiscount,
		--ISNULL((SELECT SUM(ISNULL(ept.ExtraPT,0)) FROM dbo.Acc_GroupExtraPTSetting ept with(nolock) WHERE ept.ProductId = 1 and ept.sporttype = 0 and ept.subProduct = '' and ept.superId = b.srecommend AND b.transDate BETWEEN FromDate AND ToDate ),0) AS epositiontaking			,
        cs.slivepositiontaking + cs.mlivepositiontaking + cs.alivepositiontaking as Tpositiontaking
--into #credit_single_3
from bettrans b with (nolock)
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99
    inner join dbcust.custdb.dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=m.sporttype and cs.bettype = b.bettype
where currency not in (20,72)
  and b.liveIndicator = 1
  and m.sporttype =1
  and b.bettype in (1,3,7,8)
  and b.srecommend not in (select custid from dbcust.custdb.dbo.dep_custsuper with (nolock))
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
select  B.transid, b.transdate, m.sporttype, b.bettype, m.matchid,
		cs.spositiontaking,
        cs.mpositiontaking,
        cs.apositiontaking,
		cs.playerdiscount,
		cs.sdiscount,
		cs.discount,
		cs.adiscount,
		--ISNULL((SELECT SUM(ISNULL(ept.ExtraPT,0)) FROM dbo.Acc_GroupExtraPTSetting ept with(nolock) WHERE ept.ProductId = 1 and ept.sporttype = 0 and ept.subProduct = '' and ept.superId = b.srecommend AND b.transDate BETWEEN FromDate AND ToDate ),0) AS epositiontaking			,
        cs.spositiontaking + cs.mpositiontaking + cs.apositiontaking as Tpositiontaking
--into #credit_single_4
from bettrans b with (nolock)
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99
    inner join dbcust.custdb.dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=m.sporttype and cs.bettype = b.bettype
where currency not in (20,72)
  and (b.liveIndicator = 0 or (b.liveIndicator =  1 and b.bettype not in (1,3,7,8)))
  and b.srecommend not in (select custid from dbcust.custdb.dbo.dep_custsuper with (nolock))
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

-- parlay
select B.transid, b.transdate, b.bettype, 
       ISNULL(cs.playerdiscount, 0) AS playerdiscount,
       ISNULL(cs.discount, 0) AS discount,
       ISNULL(cs.adiscount, 0) AS adiscount,
       ISNULL(cs.sdiscount, 0) AS sdiscount,
       cs.spositiontaking,
       cs.mpositiontaking,
       cs.apositiontaking,
       cs.spositiontaking + cs.mpositiontaking + cs.apositiontaking as Tpositiontaking
--into #credit_parlay
from bettrans b with (nolock)
	inner join dbcust.custdb.dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.bettype=9 and cs.sporttype= b.oddsid
where currency not in (20,72) and matchid=29
  and b.srecommend not in (select custid from dbcust.custdb.dbo.dep_custsuper with (nolock))
  and (b.spositiontaking<>cs.spositiontaking
   or b.mpositiontaking<>cs.mpositiontaking
   or  b.apositiontaking<>cs.apositiontaking
   or b.playerdiscount <> cs.playerdiscount
   or  b.sdiscount<>cs.sdiscount
   or  b.discount<>cs.discount
   or  b.adiscount<>cs.adiscount
    )
	and b.transdate >= '2023-03-30 04:00' and b.transdate <= '2023-03-30 04:20'
order by b.transdate
-- (23 rows affected)

-- Parlay BetTransM
select
    bm.transid, bm.transdate, bm.bettype, bm.matchid,
    ISNULL(cs.playerdiscount, 0) AS playerdiscount,
    ISNULL(cs.discount, 0) AS discount,
    ISNULL(cs.adiscount, 0) AS adiscount,
    ISNULL(cs.sdiscount, 0) AS sdiscount,
    cs.spositiontaking,
    cs.mpositiontaking,
    cs.apositiontaking
--into #credit_parlaym
from bettrans b with (nolock)
	inner join bettransm bm with(nolock) on b.refno = bm.refno
    inner join dbcust.custdb.dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.bettype=9 and cs.sporttype= b.oddsid
where b.currency not in (20,72) and b.matchid=29
  and b.srecommend not in (select custid from dbcust.custdb.dbo.dep_custsuper with (nolock))
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

select bt.transid, bt.custid, bt.bettype, m.matchid,m.sporttype, bt.liveindicator,
	pt.alivepositiontaking,
	pt.mlivepositiontaking,
	pt.slivepositiontaking,
	pt.alivepositiontaking+	pt.mlivepositiontaking+	pt.slivepositiontaking as tpositiontaking,
	comm.playerdiscount,
	comm.discount,
	comm.adiscount,
	comm.sdiscount
--into #credit_ng
from bettrans bt with (nolock)
	inner join dbcust.custdb.dbo.site S with(nolock) on bt.BetSiteID = S.siteid 
	inner join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (161,164)
	inner join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and m.sporttype = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and isLive=bt.liveindicator
	inner join dbcust.custdb.dbo.CustSetting3rd comm with (nolock) on comm.custid = bt.custid and comm.bettype = sbr.BetTypeRefComm and comm.sporttype = sbr.SportTypeRefComm
	inner join dbcust.custdb.dbo.CustSetting3rd PT with (nolock) on PT.custid = bt.custid and PT.bettype = sbr.BetTypeRefPT and PT.sporttype = sbr.SportTypeRefPT
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
select * from (						
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
--into #credit_vs
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

/*
select b.* into Mondb.dbo.Temp0331_credit_single_1  from bettrans b with(Nolock)   	join #credit_single_1	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_single_2  from bettrans b with(Nolock)   	join #credit_single_2	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_single_3  from bettrans b with(Nolock) 	join #credit_single_3	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_single_4  from bettrans b with(Nolock)  	join #credit_single_4	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_parlay	from bettrans b with(Nolock)  	join #credit_parlay	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_parlaym	from bettransm b with(Nolock) 	join #credit_parlaym	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_ng		from bettrans b with(Nolock) 	join #credit_ng		T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_vs		from bettrans b with(Nolock) 	join #credit_vs		T on b.transid = T.Transid
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
from #credit_single_1	tmp
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
from #credit_single_2	tmp
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
from #credit_single_3	tmp
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
from #credit_single_4	tmp
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
from #credit_parlay	tmp
where bettrans.transid = tmp.transid

update bettransm with (rowlock,updlock)
set playerdiscount = tmp.playerdiscount,
	discount = tmp.discount,
	adiscount = tmp.adiscount,
	sdiscount = tmp.sdiscount,
	apositiontaking = tmp.apositiontaking,
	mpositiontaking = tmp.mpositiontaking,
	spositiontaking = tmp.spositiontaking
from #credit_parlaym	tmp
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
drop table #credit_single_1
drop table #credit_single_2
drop table #credit_single_3
drop table #credit_single_4
drop table #credit_parlay
drop table #credit_parlaym
drop table #credit_ng
drop table #credit_vs
*/
