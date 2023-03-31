
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

/*
select b.* into Mondb.dbo.Temp0331_credit_single_1  from bettrans b with(Nolock)   	join #credit_single_1	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_single_2  from bettrans b with(Nolock)   	join #credit_single_2	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_single_3  from bettrans b with(Nolock) 	join #credit_single_3	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_single_4  from bettrans b with(Nolock)  	join #credit_single_4	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_parlay	from bettrans b with(Nolock)  	join #credit_parlay	T on b.transid = T.Transid
select b.* into Mondb.dbo.Temp0331_credit_parlaym	from bettransm b with(Nolock) 	join #credit_parlaym	T on b.transid = T.Transid
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
*/
		

/*
drop table #credit_single_1
drop table #credit_single_2
drop table #credit_single_3
drop table #credit_single_4
drop table #credit_parlay
drop table #credit_parlaym
*/
