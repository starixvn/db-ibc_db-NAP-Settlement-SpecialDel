/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*
    Created: 20240701@Max
	Task: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
	DB: DBARC-bodb_Archive
*/
USE bodb_Archive
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
SELECT DISTINCT matchid FROM dbo.TicketVoiding_RequestDetail_bk v WITH (NOLOCK) WHERE v.MatchId NOT IN (0,29,2799,10449)

insert into #Result (matchid, eventdate, sporttype)
select tmp.matchid, m.eventdate, m.sporttype
from @tmp_matchid tmp
inner join match_bk m with (nolock) on m.matchid = tmp.matchid
where not exists (select matchid from #Result where matchid = tmp.matchid) 

insert into #Result (matchid, eventdate, sporttype)
select tmp.matchid, m.eventdate, l.sporttype
from @tmp_matchid tmp
inner join outright_bk m with (nolock) on m.orid = tmp.matchid
inner join bodb02.dbo.League l with (nolock) on l.leagueid = m.leagueid
where not exists (select matchid from #Result where matchid = tmp.matchid) 

insert into #Result (matchid, eventdate, sporttype)
select tmp.matchid, m.eventdate, o.SportType
from @tmp_matchid tmp
inner join VSOutright_bk m with (nolock) on m.orid = tmp.matchid
inner join VSRaceInfo_bk o with (nolock) on m.EventID = o.EventID
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
		UPDATE rd SET rd.Eventdate = r.EventDate, rd.Sporttype = r.Sporttype
		FROM dbo.TicketVoiding_RequestDetail_bk rd WITH (ROWLOCK, UPDLOCK)
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
