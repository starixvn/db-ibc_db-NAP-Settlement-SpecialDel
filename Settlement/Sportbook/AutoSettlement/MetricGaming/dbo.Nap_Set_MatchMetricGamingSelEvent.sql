ALTER PROCEDURE [dbo].[Nap_Set_MatchMetricGamingSelEvent] 
	@matchid INT = 0
AS
	/*
		Created: Johnson
		Date: 2015-06-29
		Task: get list of events for a match
		DB: DBTXN/bodb02
		
		Revisions:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpEvent TABLE 
		(GameID INT,
		 BettypeTime VARCHAR(100),
		 Tickets INT,
		 statusID TINYINT			
		)
		
	
	INSERT INTO @tmpEvent(GameID,BettypeTime,Tickets,statusID)	
	SELECT gameID,
		SUBSTRING(transdesc,CHARINDEX('bettypetime',transdesc)+12,CHARINDEX(';time',transdesc)-CHARINDEX('bettypetime',transdesc)-12) as bettypeTime,
		COUNT(1) as Tickets,
		max(CASE WHEN status='running' then 1 ELSE 0 END) as statusid
	FROM translog WITH(NOLOCK)
	WHERE eventID = @matchid
		AND GameID IN (801,803,804,805,806)
	GROUP BY gameID, SUBSTRING(transdesc,CHARINDEX('bettypetime',transdesc)+12,CHARINDEX(';time',transdesc)-CHARINDEX('bettypetime',transdesc)-12)
	
	SELECT matchid, 
		leagueid,
		matchcode,
		kickofftime,
		eventdate,
		homeid,
		awayid,
		hthomescore AS HalfTimeHomeScore,
		htawayscore AS HalfTimeAwayScore,
		finalhomescore,
		finalawayscore
	FROM match WITH(NOLOCK)
	WHERE matchid = @matchid
	
	SELECT rs.ResultID,
		t.GameID,
		Custom1 as bettypeTime,
		t.Tickets,
		CASE WHEN t.statusID = 1 THEN 'Running' ELSE 'Calculated' END as TicketStatus,
		ResultStatusID,
		SettlementStatusID,
		GameResult,
		OtherInfo 
	FROM DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK)
		INNER JOIN @tmpEvent t ON t.GameID = rs.GameID AND t.BettypeTime = rs.Custom1
	WHERE matchid = @matchid
	ORDER BY t.GameID,bettypeTime,TicketStatus
		
END
GO
GRANT EXECUTE ON [dbo].[Nap_Set_MatchMetricGamingSelEvent] TO [bodbAdminNet]