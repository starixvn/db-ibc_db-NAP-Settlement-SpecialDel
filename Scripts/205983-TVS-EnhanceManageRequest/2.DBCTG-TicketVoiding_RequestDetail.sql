/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240701@Max
	Task: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
	DB: DBCTG-bodb02
*/
USE bodb02
GO

--should define primary key for the temporary tables
CREATE TABLE #Result(
	id [int] IDENTITY (1,1) PRIMARY KEY,
	matchid INT,
	EventDate DATETIME,
	Sporttype SMALLINT
)

DECLARE @tmp_MatchId AS TABLE (MatchId INT)
INSERT INTO @tmp_matchid (matchid)
SELECT DISTINCT matchid FROM dbo.TicketVoiding_RequestDetail v WITH (NOLOCK) WHERE v.MatchId NOT IN (0,29,2799,10449)

insert into #Result (matchid, eventdate, sporttype)
select tmp.matchid, m.eventdate, m.sporttype
from @tmp_matchid tmp
CROSS APPLY(
	SELECT m.eventdate, m.sporttype
	FROM match m with (nolock) 
	WHERE m.matchid = tmp.matchid

	UNION
	SELECT m.eventdate, m.sporttype
	FROM match14 m with (nolock) 
	WHERE m.matchid = tmp.matchid
)m
where not exists (select matchid from #Result where matchid = tmp.matchid) 

insert into #Result (matchid, eventdate, sporttype)
select tmp.matchid, m.eventdate, l.sporttype
from @tmp_matchid tmp
CROSS APPLY (
	SELECT m.eventdate, m.leagueid
	FROM outright m with (nolock) 
	WHERE m.orid = tmp.matchid
	
	UNION
	SELECT m.eventdate, m.leagueid
	FROM outright14 m with (nolock) 
	WHERE m.orid = tmp.matchid
)m
inner join bodb02.dbo.League l with (nolock) on l.leagueid = m.leagueid
where not exists (select matchid from #Result where matchid = tmp.matchid) 

insert into #Result (matchid, eventdate, sporttype)
select tmp.matchid, m.eventdate, m.SportType
from @tmp_matchid tmp
CROSS APPLY (
	SELECT m.EventDate, o.SportType
	FROM VSOutright m with (nolock) 
		inner join VSRaceInfo o with (nolock) on m.EventID = o.EventID
	WHERE m.orid = tmp.matchid
		
	UNION
	SELECT m.EventDate, o.SportType
	FROM VSOutright14 m with (nolock) 
		inner join VSRaceInfo14 o with (nolock) on m.EventID = o.EventID
	WHERE m.orid = tmp.matchid
)m
where not exists (select matchid from #Result where matchid = tmp.matchid) 

------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
		
DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(ID) FROM #Result)
SET @Threshold = 5000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		-- YOUR CODE PROCESS FOR DATA FROM @StartRow & @StopRow
		UPDATE rd SET rd.Sporttype = r.Sporttype
		FROM dbo.TicketVoiding_RequestDetail rd WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #Result r ON r.MatchId = rd.MatchId
		WHERE r.id BETWEEN @StartRow AND @StopRow

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.100' --optional

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

END

DROP TABLE #Result
