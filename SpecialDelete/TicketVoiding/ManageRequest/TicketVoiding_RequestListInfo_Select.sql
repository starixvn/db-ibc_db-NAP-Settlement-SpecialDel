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

	Param's explanation:
	
	Sample execution:
	EXEC TicketVoiding_RequestListInfo_Select @FromDate = '2021-03-01', @ToDate = '2021-03-28'
	
	+ Note: With ticket get main parlay(bettrans) only check on CENTRAL	
*/
BEGIN 
    SET NOCOUNT ON 

    DECLARE @tmpResult TABLE (requestid INT) 

	DECLARE @FromDate_tmp DATETIME, @ToDate_tmp DATETIME

	SELECT @FromDate_tmp = @FromDate, @ToDate_tmp = @ToDate

    IF EXISTS (SELECT TOP 1 1 
               FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
               WHERE  matchid IN ( 9, 29, 2799, 10449 )) 
      BEGIN 
			--BETTRANS
            INSERT INTO @tmpResult (requestid) 
            SELECT s.requestid
            FROM   dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON s.transid = b.transid 
            WHERE  s.matchid IN ( 9, 29, 2799, 10449 ) AND b.winlostdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
            GROUP  BY s.requestid
            
			--BETTRANS14
            INSERT INTO @tmpResult (requestid) 
            SELECT s.requestid 
            FROM   dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
					INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) ON s.transid = b14.transid 
            WHERE  s.matchid IN ( 9, 29, 2799, 10449 ) 
                    AND b14.winlostdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
            GROUP  BY s.requestid
      END 
	
	 IF EXISTS (SELECT TOP 1 rd.requestid, o.eventdate 
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
               WHERE  o.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp ) 
      BEGIN 
          INSERT INTO @tmpResult (requestid) 
          SELECT rd.requestid
          FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				 INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.requestid = r.RequestId
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
          GROUP  BY rd.requestid, r.IssueTypeId
      END 
	
    INSERT INTO @tmpResult (requestid) 
    SELECT rd.requestid
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK) ON rd.matchid = m.matchid 
	WHERE m.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 						
    GROUP  BY rd.requestid
	UNION ALL
	SELECT rd.requestid
    FROM   dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN dbo.match14 m14 WITH(NOLOCK) ON rd.matchid = m14.matchid 
	WHERE m14.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 					
    GROUP  BY rd.requestid
    
	SELECT DISTINCT requestid
	FROM @tmpResult
END
