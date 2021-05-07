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
        - 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]

	Param's explanation:
	
	Sample execution:
	EXEC TicketVoiding_RequestListInfo_Select @FromDate = '2021-03-01', @ToDate = '2021-03-28'
		
*/
BEGIN 
    SET NOCOUNT ON 

    DECLARE @tmpResult TABLE (requestid INT) 

	DECLARE @FromDate_tmp DATETIME, @ToDate_tmp DATETIME

	SELECT @FromDate_tmp = @FromDate, @ToDate_tmp = @ToDate

    IF EXISTS (SELECT TOP 1 1 
               FROM   ticketvoiding_requestdetail rd WITH(NOLOCK) 
               WHERE  matchid IN ( 9, 29, 2799 )) 
      BEGIN 
			--BETTRANS
            INSERT INTO @tmpResult (requestid) 
            SELECT s.requestid
            FROM   dbo.ticketvoiding_requestdetailticket_single s WITH(NOLOCK) 
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON s.transid = b.transid 
            WHERE  s.matchid IN ( 9, 29, 2799 ) AND b.winlostdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
            GROUP  BY s.requestid
            
			--BETTRANS14
            INSERT INTO @tmpResult (requestid) 
            SELECT s.requestid 
            FROM   dbo.ticketvoiding_requestdetailticket_single s WITH(NOLOCK) 
					INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) ON s.transid = b14.transid 
            WHERE  s.matchid IN ( 9, 29, 2799 ) 
                    AND b14.winlostdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
            GROUP  BY s.requestid
      END 
	
	 IF EXISTS (SELECT TOP 1 rd.requestid, o.eventdate 
               FROM   ticketvoiding_requestdetail rd WITH(NOLOCK) 
                      INNER JOIN (SELECT o.orid, o.eventdate 
                                  FROM   dbo.outright o WITH(NOLOCK) 
                                  UNION 
                                  SELECT o14.orid, o14.eventdate 
                                  FROM   dbo.outright14 o14 WITH(NOLOCK))o 
                              ON rd.matchid = o.orid 
               WHERE  o.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp ) 
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
          WHERE  o.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 
          GROUP  BY rd.requestid, r.IssueTypeId
      END 
	
    INSERT INTO @tmpResult (requestid) 
    SELECT rd.requestid
    FROM   ticketvoiding_requestdetail rd WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK) ON rd.matchid = m.matchid 
	WHERE m.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 						
    GROUP  BY rd.requestid
	UNION ALL
	SELECT rd.requestid
    FROM   ticketvoiding_requestdetail rd WITH(NOLOCK)
			INNER JOIN dbo.match14 m14 WITH(NOLOCK) ON rd.matchid = m14.matchid 
	WHERE m14.eventdate BETWEEN @FromDate_tmp AND @ToDate_tmp 					
    GROUP  BY rd.requestid
    
	SELECT DISTINCT requestid
	FROM @tmpResult
END
