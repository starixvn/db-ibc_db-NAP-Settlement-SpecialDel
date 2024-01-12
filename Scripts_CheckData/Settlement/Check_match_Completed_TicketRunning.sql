/*

	Louisa: check match completed but exists running tickets
	DBTXN/bodb02

*/

--- NUMBER GAME
	select top 300 m.matchid, m.sporttype, m.eventdate, m.eventstatus, m.eventdate 
			, b.transid, b.SiteDBGroupID, b.transdate, b.settlementtime , b.bettype 
			,b.liveindicator
			,b.livehomescore + b.liveawayscore + CASE WHEN b.bettype = 87 THEN 2 ELSE 1 END AS Ball
	from bodb02.dbo.match m with(nolock)
		inner join bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
		cross apply (	select b.transid, b.transdate, b.liveindicator, b.bettype, b.livehomescore ,b.liveawayscore, b.settlementtime, b.SiteDBGroupID
						from bodb02.dbo.bettrans b with(nolock)
						where m.matchid = b.matchid
						and bettype between 85 and 91 
						and b.statusid = 0
					) b
	where m.sporttype = 161 --NG
		and l.isTest = 0
		and m.eventstatus = 'completed'
		--and m.eventdate = '2023-09-27'
		and m.kickofftime between '2023-09-27 02:29:04' and '2023-09-27 02:40:04'
	order by matchid, settlementtime

	--compare bettrans.transdate with logtime settlement (if late bet, user do not be allowed re-cal)
	select top 300 l.LogId, l.matchid, l.LogDate, l.UserID,  l.ActionID, l.Remark, l.BroadcastSessionId, la.ActionNameEN, la.SPName
	from dblog.bodb_customerlog.dbo.userLog_Settle l with(nolock)
		inner join dblog.bodb_customerlog.dbo.LogAction la with(nolock) on l.ActionId = la.ActionId
	where l.matchid = 73558009

---- PINGOAL
	select m.matchid, m.sporttype, m.eventstatus , m.eventdate 
	from bodb02.dbo.match m with(nolock)
	inner join bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
	cross apply (select top 1 transid from bodb02.dbo.bettrans b with(nolock) where b.matchid = m.matchid and b.statusid = 0) b
	where l.LeagueGroupID in (113,151 ,122) 
		AND m.sporttype IN ( 1,2,43)  	  
		and l.isTest = 0
		--and m.kickofftime between '2023-09-27 02:29:04' and '2023-09-27 02:40:04'
		and m.eventstatus = 'completed'
		and m.eventdate =  '2023-09-27'
		AND 1 = CASE WHEN m.sporttype = 1 AND l.LeagueGroupID = 113 THEN 1
                     WHEN m.sporttype = 2 AND l.LeagueGroupID = 122 THEN 1
                     WHEN m.sporttype = 43 AND l.LeagueGroupID = 151 THEN 1
                 ELSE 0 
                 END

--- OUTRIGHT
	select m.matchid, m.sporttype, m.eventstatus, m.eventdate 
	from bodb02.dbo.match m with(nolock)
	inner join bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
	cross apply (select top 1 transid from bodb02.dbo.bettrans b with(nolock) where b.matchid = m.matchid and b.statusid = 0 and b.bettype = 10) b
	where  m.eventstatus = 'completed'
		  and l.isTest = 0
		  and m.eventdate =  '2023-09-27'

---- BITCOIN
	select m.matchid, m.sporttype, m.eventstatus, m.eventdate 
	from bodb02.dbo.match m with(nolock)
	inner join bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
	cross apply (select top 1 transid from bodb02.dbo.bettrans b with(nolock) where b.matchid = m.matchid and b.statusid = 0) b
	where   m.sporttype = 175
		  and l.isTest = 0
		  --and m.kickofftime between '2023-09-27 02:29:04' and '2023-09-27 02:40:04'
		  and m.eventstatus = 'completed'
		  and m.eventdate =  '2023-09-27'

---- OTHER PRODUCT BELONG TO BROADCAST API ( VS)
	select m.matchid, m.sporttype, m.eventstatus, m.eventdate 
	from bodb02.dbo.match m with(nolock)
	inner join bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
	cross apply (select top 1 transid from bodb02.dbo.bettrans b with(nolock) where b.matchid = m.matchid and b.statusid = 0) b
	where   m.sporttype IN ( 178, 193, 180, 192 )
		  and l.isTest = 0
		  --and m.kickofftime between '2023-09-27 02:29:04' and '2023-09-27 02:40:04'
		  and m.eventstatus = 'completed'
		  and m.eventdate =  '2023-09-27'

--- Betbuider
	select top 300 mk.MatchID, mk.MarketID 
		, b.transid, b.SiteDBGroupID, b.transdate, b.settlementtime , b.bettype 
	from DBPRO.bodb02.dbo.SMP_Market  mk WITH (NOLOCK)
			inner join bodb02.dbo.bettrans b WITH (NOLOCK) ON b.BetCheck = mk.MarketID
	where b.bettype = 38 and b.statusid = 0
		and mk.resultstatusId IN (2, 5)
		and mk.UpdateTime between '2023-09-27 02:29:04' and '2023-09-27 02:40:04'

---- sportbook
	select m.matchid, m.sporttype, m.eventstatus, m.eventdate , l.LeagueGroupID
	from bodb02.dbo.match m with(nolock)
	inner join bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
	cross apply (select top 1 transid from bodb02.dbo.bettrans b with(nolock) where b.matchid = m.matchid and b.statusid = 0) b
	where   m.sporttype < 99
		  and l.isTest = 0
		  --and m.kickofftime between '2023-09-27 02:29:04' and '2023-09-27 02:40:04'
		  and m.eventstatus = 'completed'
		  and m.eventdate =  '2023-09-27' 
----------------------------------------------------------------------------------------------------------------------------

---CHECK LOG SETTLEMENT

	select top 300 l.LogId, l.matchid, l.LogDate, l.UserID,  l.ActionID, l.Remark, l.BroadcastSessionId, la.ActionNameEN, la.SPName
	from dblog.bodb_customerlog.dbo.userLog_Settle l with(nolock)
		inner join dblog.bodb_customerlog.dbo.LogAction la with(nolock) on l.ActionId = la.ActionId
	where l.matchid = 73558009

----------------------------------------------------------------------------------------------------------------------------






