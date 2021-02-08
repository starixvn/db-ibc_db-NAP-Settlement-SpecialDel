/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestListInfo_Select] 
(
	@FromDate   DATETIME
	,@ToDate	DATETIME
)
AS
/*	Created by: Zane
	Date 20210112
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBTXN/bodb02
	
	Revisions: 		
		- 20210112@Zane: Create new SP [Redmine:#145719]
        - 20210201@Zane: Modify archive process for abnormal Account [Redmine:#149776]

	Param's explanation:
		
*/
BEGIN 
    SET NOCOUNT ON 

    DECLARE @tmpResult TABLE (requestid INT) 

    IF EXISTS (SELECT TOP 1 1 
               FROM   ticketvoiding_requestdetail rd WITH(NOLOCK) 
               WHERE  matchid IN ( 9, 29, 2799 )) 
      BEGIN 
			--BETTRANS
            INSERT INTO @tmpResult (requestid) 
            SELECT rd.requestid
            FROM   ticketvoiding_requestdetail rd WITH(NOLOCK)
					INNER JOIN dbo.ticketvoiding_request r WITH(NOLOCK) 
							ON rd.requestid = r.RequestId 
					INNER JOIN dbo.ticketvoiding_requestdetailticket_single s WITH(NOLOCK) 
							ON rd.requestid = s.requestid AND rd.MatchId = s.MatchId
					INNER JOIN dbo.bettrans b WITH(NOLOCK) 
							ON rd.matchid = b.matchid AND s.transid = b.transid 
            WHERE  rd.matchid IN ( 9, 29, 2799 ) 
                    AND b.winlostdate BETWEEN @FromDate AND @ToDate 
            GROUP  BY rd.requestid, r.IssueTypeId

			--BETTRANS14
            INSERT INTO @tmpResult (requestid) 
            SELECT rd.requestid 
            FROM   ticketvoiding_requestdetail rd WITH(NOLOCK)
					INNER JOIN dbo.ticketvoiding_request r WITH(NOLOCK) 
							ON rd.requestid = r.RequestId
					INNER JOIN dbo.ticketvoiding_requestdetailticket_single s WITH(NOLOCK) 
							ON rd.requestid = s.requestid AND rd.MatchId = s.MatchId
					INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) 
							ON rd.matchid = b14.matchid AND s.transid = b14.transid 
            WHERE  rd.matchid IN ( 9, 29, 2799 ) 
                    AND b14.winlostdate BETWEEN @FromDate AND @ToDate 
            GROUP  BY rd.requestid, r.IssueTypeId
      END 

    IF EXISTS (SELECT TOP 1 rd.requestid, o.eventdate 
               FROM   ticketvoiding_requestdetail rd WITH(NOLOCK) 
                      INNER JOIN (SELECT o.orid, o.eventdate 
                                  FROM   dbo.outright o WITH(NOLOCK) 
                                  UNION 
                                  SELECT o14.orid, o14.eventdate 
                                  FROM   dbo.outright14 o14 WITH(NOLOCK))o 
                              ON rd.matchid = o.orid 
               WHERE  o.eventdate BETWEEN @FromDate AND @ToDate) 
      BEGIN 
          INSERT INTO @tmpResult (requestid) 
          SELECT rd.requestid
          FROM   ticketvoiding_requestdetail rd WITH(NOLOCK)
				 INNER JOIN dbo.ticketvoiding_request r WITH(NOLOCK) 
								ON rd.requestid = r.RequestId
                 INNER JOIN (SELECT o.orid, o.eventdate 
                             FROM   dbo.outright o WITH(NOLOCK) 
                             UNION 
                             SELECT o14.orid, o14.eventdate 
                             FROM   dbo.outright14 o14 WITH(NOLOCK))o 
                         ON rd.matchid = o.orid 
          WHERE  o.eventdate BETWEEN @FromDate AND @ToDate 
          GROUP  BY rd.requestid, r.IssueTypeId
      END 

    INSERT INTO @tmpResult (requestid) 
    SELECT rd.requestid
    FROM   ticketvoiding_requestdetail rd WITH(NOLOCK)
			INNER JOIN dbo.ticketvoiding_request r WITH(NOLOCK) 
								ON rd.requestid = r.RequestId
			INNER JOIN (SELECT m.matchid, m.eventdate 
						FROM   dbo.match m WITH(NOLOCK) 
						UNION 
						SELECT m14.matchid, m14.eventdate 
						FROM   dbo.match14 m14 WITH(NOLOCK)) m 
					ON rd.matchid = m.matchid 
    WHERE  m.eventdate BETWEEN @FromDate AND @ToDate 
    GROUP  BY rd.requestid, r.IssueTypeId 
	
	SELECT DISTINCT requestid
	FROM @tmpResult
END
