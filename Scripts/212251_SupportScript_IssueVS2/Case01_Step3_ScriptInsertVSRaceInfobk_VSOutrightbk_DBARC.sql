/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*
	Created: 20241017@July 
	Task: Support script to handle the issue: tickets moved to 14 but event still be in active table for VS2 - [Redmine: #212251]
	DB: DBARC-bodb_Archive
*/
USE bodb_Archive
GO
DROP TABLE IF EXISTS #tmp_EventIDList ;

DECLARE @EventIDList VARCHAR(MAX) 
--Match have winlostdate '09/10','10/10' 
SET @EventIDList ='62109410,62109416,62109454,62109560,62109660,62109772,62114310,62114314,62114316,62114331,62114352,63468466,63468766,63468774,63468776,63468802,63468846,63468938,63468972,63469014,63469178,63469180,63469182,63469184,63469308,63469314,63469352,63473027,63474707,63474709,63474715,63474751,63474753,63474793,63474795,63474827,63474849,63474855'

CREATE TABLE #tmp_EventIDList (EventID INT);
INSERT INTO #tmp_EventIDList(EventID ) --38 matches
SELECT value AS EventID
FROM STRING_SPLIT(@EventIDList,',')
WHERE value <> ''

INSERT INTO dbo.VSRaceInfo_bk (
	[EventTime]
      ,[LeagueID]
      ,[PayOut]
      ,[EachWay]
      ,[CourseName]
      ,[TrackType]
      ,[Distance]
      ,[Racers]
      ,[ForeCastPayout]
      ,[TriCastPayout]
      ,[CreateDate]
      ,[Calculate]
      ,[SportType]
      ,[ChangeTime]
      ,[BetStatus]
      ,[EventStatus]
      ,[VendorMatchId]
	  ,[EventID]
)
SELECT [EventTime]
      ,[LeagueID]
      ,[PayOut]
      ,[EachWay]
      ,[CourseName]
      ,[TrackType]
      ,[Distance]
      ,[Racers]
      ,[ForeCastPayout]
      ,[TriCastPayout]
      ,[CreateDate]
      ,[Calculate]
      ,[SportType]
      ,[ChangeTime]
      ,[BetStatus]
      ,[EventStatus]
      ,[VendorMatchId]
      ,vs.EventID
FROM bodb02.dbo.VSRaceInfo vs WITH(NOLOCK) 
	INNER JOIN #tmp_EventIDList m ON vs.EventID = m.EventID

INSERT INTO dbo.VSOutright_bk (
		[Orid]
      ,[EventID]
      ,[RacerNum]
      ,[IsFavor]
      ,[EventDate]
      ,[KickoffTime]
      ,[RacerID]
      ,[HumanID]
      ,[WinOdds]
      ,[PlaceOdds]
      ,[Lane]
      ,[MaxBet]
      ,[Placing]
      ,[Creator]
      ,[EventStatus]
	  )
SELECT [Orid]
      ,vo.EventID
      ,[RacerNum]
      ,[IsFavor]
      ,[EventDate]
      ,[KickoffTime]
      ,[RacerID]
      ,[HumanID]
      ,[WinOdds]
      ,[PlaceOdds]
      ,[Lane]
      ,[MaxBet]
      ,[Placing]
      ,[Creator]
      ,[EventStatus]
FROM bodb02.dbo.VSOutright vo WITH(NOLOCK) 
	INNER JOIN #tmp_EventIDList m ON vo.EventID = m.EventID
