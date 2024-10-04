/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestListInfo_Select] 
(
	@FromDate   DATETIME
	,@ToDate	DATETIME
)
AS
/*	Created by: 20210112@Zane
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBCTG/bodb02
	
	Revisions: 		
		- 20210112@Zane: Create new SP [Redmine:#145719]
        - 20210201@Zane: Modify archive process for abnormal Account [Redmine:#149776]
        - 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20230224@July: Change config DBTXN -> DBCTG [Redmine: #180625]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240319@July: [TVS] SP tuning for EC2024 [Redmine: #200840]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]

	Param's explanation:
	
	Sample execution:
	EXEC TicketVoiding_RequestListInfo_Select @FromDate = '2021-03-01', @ToDate = '2021-03-28'
	
	+ Note: With ticket get main parlay(bettrans) only check on CENTRAL	
*/
BEGIN 
    SET NOCOUNT ON 

    DECLARE @tmpResult TABLE (RequestID INT, Eventdate DATETIME)

	DECLARE @FromDate_tmp	DATETIME
		  , @ToDate_tmp		DATETIME
		  , @RequestInfo	VARBINARY(MAX) = NULL
	
	SELECT @FromDate_tmp = @FromDate, @ToDate_tmp = @ToDate

    IF EXISTS (SELECT TOP 1 1 
               FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
               WHERE  matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))) 
    BEGIN 
		--BETTRANS
        INSERT INTO @tmpResult (RequestID, Eventdate) 
        SELECT s.requestid, MIN(b.winlostdate)
        FROM   dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON s.transid = b.transid
        WHERE  s.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) 
				AND b.winlostdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
        GROUP  BY s.requestid
            
		--BETTRANS14
        INSERT INTO @tmpResult (RequestID, Eventdate) 
        SELECT s.requestid, MIN(b14.winlostdate)
        FROM   dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
				INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) ON s.transid = b14.transid 
        WHERE  s.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) 
                AND b14.winlostdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
        GROUP  BY s.requestid
    END 
	
    INSERT INTO @tmpResult (RequestID, Eventdate) 
    SELECT rd.requestid, MIN(o.eventdate)
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
            CROSS APPLY (
					SELECT o.orid, o.eventdate
					FROM	dbo.outright o WITH(NOLOCK)
					WHERE rd.MatchId = o.orid
					UNION
					SELECT	o14.orid, o14.eventdate
					FROM	dbo.outright14 o14 WITH(NOLOCK)
					WHERE rd.MatchId = o14.orid
		)o 
    WHERE  o.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
    GROUP  BY rd.requestid
	
    INSERT INTO @tmpResult (RequestID, Eventdate) 
    SELECT rd.requestid, MIN(m.eventdate)
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK) ON rd.matchid = m.matchid 
	WHERE m.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 						
    GROUP  BY rd.requestid
	UNION ALL
	SELECT rd.requestid, MIN(m14.eventdate)
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.match14 m14 WITH(NOLOCK) ON rd.matchid = m14.matchid 
	WHERE m14.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 					
    GROUP  BY rd.requestid

	INSERT INTO @tmpResult (RequestID, Eventdate) 
    SELECT rd.requestid, MIN(m.eventdate)
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.Match3rd m WITH(NOLOCK) ON rd.matchid = m.Match3rdId 
	WHERE m.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 						
    GROUP  BY rd.requestid
	UNION ALL
	SELECT rd.requestid, MIN(m14.eventdate)
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.Match3rd14 m14 WITH(NOLOCK) ON rd.matchid = m14.Match3rdId 
	WHERE m14.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 					
    GROUP  BY rd.requestid

	INSERT INTO @tmpResult (RequestID, Eventdate) 
    SELECT rd.requestid, MIN(o.eventdate)
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.VSRaceInfo m WITH(NOLOCK) ON rd.matchid = m.EventID 
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON m.EventID = o.EventID
	WHERE o.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 						
    GROUP  BY rd.requestid
	UNION ALL
	SELECT rd.requestid, MIN(o.eventdate)
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.VSRaceInfo14 m WITH(NOLOCK) ON rd.matchid = m.EventID 
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON m.EventID = o.EventID
	WHERE o.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 					
    GROUP  BY rd.requestid
    
	SET @RequestInfo = COMPRESS((
		SELECT DISTINCT RequestId AS 'req'
			  ,MIN(Eventdate) AS 'e'
		FROM @tmpResult
		GROUP BY RequestID
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfo, 1) AS RequestInfo
END
