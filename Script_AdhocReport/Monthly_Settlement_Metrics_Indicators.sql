/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0" isNested="0"></info>*/
create table #temp (ID int identity (1,1), eventdate smalldatetime,matchid INT, totalticket INT, totalticketFT INT )																																																		
create table #result (matchid INT, islicensee BIT, totalticket INT, totalticketFT INT, settlementtime_min datetime, settlementtime_max datetime, starttime_queue datetime,ExecTime_queue datetime, duration_queue INT )																									
	
insert into #temp (eventdate, matchid, totalticket, totalticketFT)																									
--values ('1/1/2023',60766765,333375,272109)	-- must be input match info


------ info for deployer																									
DECLARE @StartRow INT																									
		, @StopRow INT																							
		, @MaxRow INT  -- Keep the total row of your data																							
		, @Threshold INT  -- the number of each batch																							
		, @winlostdate smalldatetime																							
		, @matchid INT																							
		, @totalTicket INT			
		
DECLARE @debug_message VARCHAR(500)	

SET @MaxRow = (SELECT MAX(ID) FROM #temp)																									
SET @Threshold = 1																									
																									
IF @Threshold >= @MaxRow																									
	SET @Threshold = @MaxRow																								
																									
-- SET for first batch																									
SELECT @StartRow = 1, @StopRow = @Threshold																									
																									
WHILE (@MaxRow IS NOT NULL)																									
BEGIN																																										
	PRINT @StartRow																							
	PRINT @StopRow																							
																									
	-- YOUR CODE PROCESS FOR DATA FROM @StartRow & @StopRow																							
	SELECT @winlostdate = eventdate, @matchid = matchid	, @totalTicket = totalticket																						
	FROM #temp R																							
	WHERE ID BETWEEN @StartRow AND @StopRow																							
																									
	--, starttime_queue datetime,Endtime_queue datetime, duration_queue INT																							
	insert into #result (matchid, IsLicensee,totalticketFT,totalTicket, settlementtime_MIN,settlementtime_max, starttime_queue, ExecTime_queue, duration_queue )																							
	select matchid, case when cs.IsLicensee = 1 THEN 1 ELSE 0 end, count(1) as totalticketFT,@totalTicket, min(settlementtime), max(settlementtime)																							
		,log_.starttime																						
		,log_.endtime																						
		,log_.duration																						
	from bettrans_bk bk (nolock)																							
		outer apply (select top 1 1 IsLicensee																						
				FROM bodb02.dbo.dep_custsuper cs with (nolock)																				
				WHERE bk.srecommend = cs.custid																				
				) AS cs																				
		cross apply (select starttime, exectime as endtime, duration																						
					from dblog.bodb_customerlog_archive.dbo.single_calculate_queue_bk with (nolock)																			
					where matchid = @matchid																			
					and action in ('cal', 'cal-ft')																				
					) as log_																			
																									
	where	winlostdate = @winlostdate 
			and matchid = @matchid																							
			and bk.bettype in (1,2,3,4,5,6,13,16,17,18,20,24,25,26,27,28,121,122,123,124,128,130,131,132,133,134,137,139,140,141,142,144,145,146,147,148,149,150,152,157,159,161,162,163,166,170,171,172,177,178,183,184,185,186,187,189,190,301,302,401,461,402,462,405,406,407,408,409,413,415,416,417,418,419,420,421,422,423,425,428,429,430,431,432,433,434,435,436,437,438,439,440,441,442,443,444,445,446,447,501,601,602,603,604,605,607,618,619,620,624,625,626,634,632,635,636,637,638,639,640,641,642,643,644,645,646,14,194,195,196,197,198,199,206,208,9088,448,449,450,451,452,454,458,460,22,465,470,472,473,475,477,482,483,486,488,490,491,493,495,496,497,467,468,469,701,702,703,704,705,706,400,399,398,397,396,394,392,389,388,9538,9539,9604,9605)																							
	group by matchid
		,case when cs.IsLicensee = 1 THEN 1 ELSE 0 end																							
		,log_.starttime																							
		,log_.endtime																						
		,log_.duration																						
																									
																									
	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)																							
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT																							
																									
																									
	IF @StopRow = @MaxRow BREAK																							
																									
	WAITFOR DELAY '00:00:00.100' --optional																							
																									
	SET @StartRow = @StopRow + 1																							
	SET @StopRow = @StopRow + @Threshold
	
	IF @StopRow >= @MaxRow																							
		SET @StopRow = @MaxRow																						
																									
END																									
																																																		
select matchid, totalticket, totalticketFT, suspender.logdate as confirmedResult																									
, t1.*																									
,t2.*																									
from #temp t																									
	cross apply (
		select	starttime_queue as keyscore_Press_credit, starttime_queue, dateadd(s,-1,settlementtime_max) as settlementtime_max_deposit																								
				, datediff (ms,starttime_queue,dateadd(s,-1,settlementtime_max)) as duration_ms_deposit																					
				, t1.totalticketFT as totalticketFT_Deposit																					
		from	#Result t1																						
		where	t1.matchid = t.matchid 
				and t1.islicensee = 1																						
	)as T1																																												
	cross apply (
		select	starttime_queue as keyscore_Press, settlementtime_max as settlementtime_max_credit																						
				, datediff (ms,starttime_queue,settlementtime_max) as duration_ms_credit																					
				, t2.totalticketFT as totalticketFT_credit																					
		from	#Result t2																						
		where	t2.matchid = t.matchid 
				and t2.islicensee = 0																						
	)as T2																						
	outer apply (
		SELECT	top 1 ROW_NUMBER() OVER(PARTITION BY u.matchid, actionid ORDER BY logdate ) AS rn																						
				,ROW_NUMBER() OVER(PARTITION BY u.matchid, actionid ORDER BY logdate DESC ) AS rnDESC																					
				,u.logdate																																										
		FROM	dbwh.bodb_Account.dbo.UserLog_P_SuspenderConfirm u with(nolock)																																													
		where	actionid = 2 
				and t.matchid=u.matchid																									
	) as suspender																																														
order by t2.keyscore_press																									
					


-- get info league name, team name
create table #tempMatchId (id int identity(1,1),matchid INT)
insert into #tempMatchId (matchid)
values xxx

select	t.matchid, tmp.* 
from	#temp t
	cross apply (
		select l.leaguename, h.teamname hometeam, a.teamname awayteam, m.matchid
		from (
			select	matchid, leagueid, homeid, awayid 
			from	match_bk m with(nolock)
			where	matchid = t.matchid
			union 
			select	matchid, leagueid, homeid, awayid 
			from	bodb02.dbo.match14 with (nolock)
			where	matchid = t.matchid
			union 
			select	matchid, leagueid, homeid, awayid 
			from	bodb02.dbo.match with (nolock)
			where	matchid = t.matchid
	) m
inner join bodb02.dbo.league l with(nolock)
	on	m.leagueid = l.leagueid
inner join bodb02.dbo.team h with(nolock)
    on	h.teamid = m.homeid
inner join bodb02.dbo.team a with(nolock)
    on	a.teamid = m.awayid
)as tmp
order by t.id
																								
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									