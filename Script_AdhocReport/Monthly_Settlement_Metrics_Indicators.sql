/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0" isNested="0"></info>*/
create table #temp (ID int identity (1,1), eventdate smalldatetime,matchid INT, totalticket INT, totalticketFT INT )																																																		
create table #result (matchid INT, islicensee BIT, totalticket INT, totalticketFT INT, settlementtime_min datetime, settlementtime_max datetime, starttime_queue datetime,ExecTime_queue datetime, duration_queue INT )																									
	
insert into #temp (eventdate, matchid, totalticket, totalticketFT)																									
values ('20230501',66282519,136690,115175),
('20230502',66281336,124552,99321),
('20230502',66281337,119110,88136),
('20230502',66282515,199667,162703),
('20230502',66887890,104293,90278),
('20230502',66887891,123188,92947),
('20230503',66281335,146133,114585),
('20230503',66281341,157450,122153),
('20230503',66364489,120137,94064),
('20230503',66364496,149295,115175),
('20230504',66281339,169020,127539),
('20230504',66281340,189511,151770),
('20230504',66364491,202207,172030),
('20230506',66281350,110994,88343),
('20230506',66281351,124192,102139),
('20230506',66364492,118160,99171),
('20230506',66364494,131458,107097),
('20230506',66364495,222030,159490),
('20230506',66364500,191958,142410),
('20230506',66365321,116773,83111),
('20230506',66977027,120081,93927),
('20230506',66977033,110370,86825),
('20230507',66281342,125226,103620),
('20230507',66281345,129479,99617),
('20230507',66364493,279594,224363),
('20230507',66364501,201105,164078),
('20230507',66365320,116910,88652),
('20230507',66977025,126588,105315),
('20230508',66281346,142704,107096),
('20230508',66281348,232369,197067),
('20230508',66364490,123582,99354),
('20230508',66364499,213240,163807),
('20230508',66364502,243752,199420),
('20230508',67235064,103115,77726),
('20230509',66609608,355619,306372),
('20230510',66281343,103061,83518),
('20230510',66281344,142124,115801),
('20230510',66609609,263300,220493),
('20230511',66281347,148102,118388),
('20230511',66281349,259487,211083),
('20230511',66653003,127928,107884),
('20230511',66653004,101858,88862),
('20230512',67453616,105359,84483),
('20230512',67461147,114283,91762),
('20230513',66719433,126378,107464),
('20230513',66719437,259898,207152),
('20230513',66719439,114746,96748),
('20230513',66719440,153954,121283),
('20230513',66977614,135627,100031),
('20230513',66977617,102758,74962),
('20230513',67103348,138265,109723),
('20230513',67545230,134473,103353),
('20230513',67547384,257209,215137),
('20230514',66719436,279064,228508),
('20230514',66719438,241158,183931),
('20230514',66719441,113981,96289),
('20230514',66977291,107893,89736),
('20230515',66719432,170555,139321),
('20230515',67580065,110807,82041),
('20230515',67580066,191225,148541),
('20230516',67191957,209827,177779),
('20230516',67624198,204977,157915),
('20230516',67624228,335885,279137),
('20230517',67191772,408430,339361),
('20230518',67059244,174858,142793),
('20230520',67059307,172508,137142),
('20230520',67059308,210502,170868),
('20230520',67059312,213657,167547),
('20230520',67061735,251042,208732),
('20230520',67318044,103143,74381),
('20230520',67318267,109831,85371),
('20230521',67059311,160713,122889),
('20230521',67059313,189012,152669),
('20230521',67059314,261224,200586),
('20230521',67232190,106748,88827),
('20230521',67318039,108844,94103),
('20230521',67318270,160789,115384),
('20230522',67059315,159370,128732),
('20230522',67318041,125357,100608),
('20230524',67061734,131157,109628),
('20230525',67061843,176788,150124),
('20230527',67508630,217876,170209),
('20230527',67508631,112261,90147),
('20230527',67611121,119627,95393),
('20230527',67967277,100269,82962),
('20230528',67059319,104510,81242),
('20230528',67611123,105918,88392),
('20230528',67611125,114102,93206),
('20230531',67852150,181679,155576)

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
	insert into #result (matchid, IsLicensee,totalticketFT,totalTicket, settlementtime_MIN,settlementtime_max, starttime_queue
	, ExecTime_queue, duration_queue )																							
	select matchid, case when cs.IsLicensee = 1 THEN 1 ELSE 0 end, count(1) as totalticketFT,@totalTicket, min(settlementtime), max(settlementtime)																							
		,log_.starttime																						
		,log_.endtime																						
		,log_.duration																						
	from bettrans_bk bk (nolock)																							
		outer apply (select top 1 1 IsLicensee																						
				FROM bodb02.dbo.dep_custsuper cs with (nolock)																				
				WHERE bk.srecommend = cs.custid																				
				) AS cs																				
		cross apply (select TOP 1 starttime, exectime as endtime, duration																						
					from dblog.bodb_customerlog_archive.dbo.single_calculate_queue_bk with (nolock)																			
					where matchid = @matchid														
					and isnull(sitedbgroupid,0) = 0
					and action in ('cal', 'cal-ft')		
					order by starttime
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
																																																		
select t.MatchId
	,tmp.leaguename 'League Name'
	,tmp.hometeam 'Home Team'
	,tmp.awayteam 'Away Team'
	,t.totalticket 'Total Tickets'
	,t1.totalticketFT_Deposit + t2.totalticketFT_credit as 'Total Ticket FT'
	,t2.totalticketFT_credit as 'Total Ticket FT Credit'
	,t1.totalticketFT_Deposit as 'Total Ticket FT Licensee'
	,suspender.logdate as 'Time Suspender Confirm Result'		
	,t1.keyscore_Press 'Time Keyscore Press'
	,DATEDIFF(ms, suspender.logdate, t1.keyscore_Press) as 'Delay Time (ms) from Confirmed Result to Keyscore Press'
	,t2.duration_ms_credit
	,t1.duration_ms_deposit
	,t2.settlementtime_max_credit
	,ABS(t1.duration_ms_deposit - t2.duration_ms_credit) as 'Gap between Credit vs Lic'
from #temp t																									
	cross apply (
		select	starttime_queue as keyscore_Press, starttime_queue, dateadd(s,-1,settlementtime_max) as settlementtime_max_deposit																								
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

order by t2.keyscore_press																									
					

																								
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									
																									