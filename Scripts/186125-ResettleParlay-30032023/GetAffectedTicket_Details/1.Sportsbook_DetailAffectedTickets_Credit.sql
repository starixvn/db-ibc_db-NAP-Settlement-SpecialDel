/*	
	Creator: Tina
	Date: 20230330
	DB: DBDWCSS/bodb02_20230329
	[Redmine:#186125]

*/
--- Credit sportsbook
CREATE TABLE #result (transid BIGINT)
--Single-SportBetTypeReference_Setting

INSERT INTO #result (transid)
select B.transid
from bettrans b with (nolock)
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99
    inner join Sport_Bettype_Reference_setting sb with (nolock) on sb.bettype=b.bettype and sb.Sporttype=m.sporttype and sb.isLicensee= 0 and sb.islive = b.liveIndicator and sb.site ='all'
    inner join dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=sb.SporttypeRefPT and sb.BettypeRefPT=cs.bettype
	inner join dbo.custsetting csd with (nolock) on csd.custid=b.custid and csd.sporttype=sb.SporttypeRefComm and sb.BetTypeRefComm=csd.bettype
where currency not in (20,72)
  and b.srecommend not in (select custid from dbo.dep_custsuper with (nolock))
  and (b.spositiontaking<>cs.spositiontaking
   or b.mpositiontaking<>cs.mpositiontaking
   or  b.apositiontaking<>cs.apositiontaking
   or b.playerdiscount <> csd.playerdiscount
   or  b.sdiscount<>csd.sdiscount
   or  b.discount<>csd.discount
   or  b.adiscount<>csd.adiscount
    )
	and b.transdate >= '2023-03-30 04:00' and b.transdate <= '2023-03-30 04:20'

--Single-SportBetTypeReference
INSERT INTO #result (transid)
select  B.transid
from bettrans b with (nolock)
	inner join match m with (nolock) on m.matchid=b.matchid and m.sporttype<99
    inner join Sport_Bettype_Reference sb with (nolock) on sb.bettype=b.bettype and sb.Sporttype=m.sporttype and sb.isLicensee= 0
    inner join dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.sporttype=sb.SporttypeRef and sb.BettypeRef=cs.bettype    
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


--Single-WithOutReference live pt
INSERT INTO #result (transid)
select  B.transid
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

-- credit without reference deadball
INSERT INTO #result (transid)
select  B.transid
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

-- parlay
INSERT INTO #result (transid)
select B.transid
from bettrans b with (nolock)
	inner join dbo.custsetting cs with (nolock) on cs.custid=b.custid and cs.bettype=9 and cs.sporttype= b.oddsid
where currency not in (20,72) and matchid=29
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

--- Credit number game
INSERT INTO #result (transid)
select bt.transid
from bettrans bt with (nolock)
	inner join dbo.site S with(nolock) on bt.BetSiteID = S.siteid 
	inner join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (161,164)
	inner join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and m.sporttype = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and isLive=bt.liveindicator
	left join dbo.CustSetting3rd comm with (nolock) on comm.custid = bt.custid and comm.bettype = sbr.BetTypeRefComm and comm.sporttype = sbr.SportTypeRefComm
	left join dbo.CustSetting3rd PT with (nolock) on PT.custid = bt.custid and PT.bettype = sbr.BetTypeRefPT and PT.sporttype = sbr.SportTypeRefPT
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
INSERT INTO #result (transid)
select transid
from bettrans bt with (nolock)						
inner join dbo.site S with(nolock) on bt.BetSiteID = S.siteid 
join match m with (nolock) on bt.matchid = m.matchid and m.sporttype in (180,186,190,191,192,193,194,195,196,197)						
join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and m.sporttype = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and sbr.isLive=bt.liveindicator						
left join dbo.CustSettingMode3rd csm with (nolock) on csm.CustId = bt.custId						
left join dbo.CustPTSetting3rd_member pt with (nolock) on pt.custid = bt.custid and pt.bettype = sbr.bettyperefpt and pt.sporttype = sbr.sporttyperefpt and pt.islive = sbr.islivePT						
left join dbo.CustPTGroupSetting3rd_Member gpt with (nolock) on gpt.agentid = bt.recommend and gpt.bettype = sbr.bettyperefpt and gpt.sporttype = sbr.sporttyperefpt and gpt.islive = sbr.islivePT						
left join dbo.CustSetting3rd comm with (nolock) on comm.custid = bt.custid and comm.bettype = sbr.BetTypeRefComm and comm.sporttype = sbr.SportTypeRefComm						
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
INSERT INTO #result (transid)
select transid
from bettrans bt with (nolock)						
join dbo.Site s with (nolock) on s.siteid = bt.betsiteid				
join Sport_Bettype_Reference_Setting sbr with (nolock) on bt.bettype = sbr.BetType and bt.oddsid = sbr.SportType and sbr.isLicensee = 0 and sbr.site = 'all' and isLive=bt.liveindicator						
left join dbo.CustSettingMode3rd csm with (nolock) on csm.CustId = bt.custId						
left join dbo.CustPTSetting3rd_member pt with (nolock) on pt.custid = bt.custid and pt.bettype = sbr.bettyperefpt and pt.sporttype = sbr.sporttyperefpt and pt.islive = sbr.islivePT						
left join dbo.CustPTGroupSetting3rd_Member gpt with (nolock) on gpt.agentid = bt.recommend and gpt.bettype = sbr.bettyperefpt and gpt.sporttype = sbr.sporttyperefpt and gpt.islive = sbr.islivePT				where  (1 = case when csm.isGrouped = 1 then						
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

SELECT DISTINCT c.transid,tmp_old.*, tmp_new.*
FROM #result c
	cross apply (select TOP 1 custid, username, matchid, bettype, sitedbgroupid,srecommend, mrecommend, recommend
					--status
					,status AS status_old
					--winlost ammout
					,WinLost AS WinLost_old,aWinLost AS aWinLost_old,mWinLost AS mWinLost_old,sWinLost AS sWinLost_old 
					-- commission amount
					,PlayerComm AS PlayerComm_old,Comm AS Comm_old,aComm AS aComm_old,sComm AS sComm_old
					--PT setting value
					,apositiontaking AS apositiontaking_old,mpositiontaking AS mpositiontaking_old,spositiontaking AS spositiontaking_old
					--comm setting value
					,playerdiscount AS playerdiscount_old,discount AS discount_old,adiscount AS adiscount_old,sdiscount AS sdiscount_old
				from bettrans b with (nolock)
				where b.transid = c.transid) AS tmp_old
	cross apply (select TOP 1
					--status
					status AS status_new
					--winlost ammout
					,WinLost AS WinLost_new,aWinLost AS aWinLost_new,mWinLost AS mWinLost_new,sWinLost AS sWinLost_new 
					-- commission amount
					,PlayerComm AS PlayerComm_new,Comm AS Comm_new,aComm AS aComm_new,sComm AS sComm_new
					--PT setting value
					,apositiontaking AS apositiontaking_new,mpositiontaking AS mpositiontaking_new,spositiontaking AS spositiontaking_new
					--comm setting value
					,playerdiscount AS playerdiscount_new,discount AS discount_new,adiscount AS adiscount_new,sdiscount AS sdiscount_new
				from [dbtranskbt].bodb02.dbo.bettrans b with (nolock)
				where b.transid = c.transid) AS tmp_new


/*
drop table #result
*/