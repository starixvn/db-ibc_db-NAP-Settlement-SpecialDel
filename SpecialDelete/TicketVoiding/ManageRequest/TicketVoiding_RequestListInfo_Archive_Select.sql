/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet,wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestListInfo_Archive_Select] 
(
	@FromDate   DATETIME
	,@ToDate	DATETIME
)
AS
/*	Created by: Zane
	Date 20210112
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBARC/bodb_Archive
	
	Revisions: 		
		- 20210112@Zane: Create new SP [Redmine:#145719]
		- 20210201@Zane: Modify archive process for abnormal Account [Redmine:#149776]
		- 20211118@Kathy: Tuning performance [Redmine:#164819]
		- 20230629@Max: [TVS] Enhance 'Manage Request' performance [Redmine: #190508]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's explanation:
		
*/
BEGIN 
    SET nocount ON 

    DECLARE @tmpResult TABLE (requestid INT, isActivedRequest BIT) 

    IF EXISTS (SELECT TOP 1 1 
               FROM   dbo.TicketVoiding_Request_bk r WITH(NOLOCK) 
					INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) ON r.RequestId = rd.RequestId AND rd.MatchId IN ( 9, 29, 2799, 10449 )
            WHERE CONVERT(DATE, r.CreatedDate) BETWEEN @FromDate AND @ToDate
		) 
    BEGIN      
        INSERT INTO @tmpResult (requestid) 
		SELECT r.requestid
		FROM  dbo.TicketVoiding_Request_bk r WITH(NOLOCK) 
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK) ON r.RequestId = rd.RequestId AND rd.MatchId IN ( 9, 29, 2799, 10449 )
		WHERE CONVERT(DATE, r.CreatedDate) BETWEEN @FromDate AND @ToDate 
		GROUP  BY r.requestid
    END 

    IF EXISTS (SELECT TOP 1 rd.requestid, o.eventdate 
               FROM   ticketvoiding_requestdetail_bk rd WITH(NOLOCK) 
                      INNER JOIN (SELECT o.orid, o.eventdate 
                                  FROM   dbo.outright_bk o WITH(NOLOCK))o 
                              ON rd.matchid = o.orid 
               WHERE  o.eventdate BETWEEN @FromDate AND @ToDate) 
    BEGIN 
        INSERT INTO @tmpResult (requestid, isActivedRequest)
        SELECT rd.requestid
			,CASE WHEN r.RequestId IS NULL THEN 1
					ELSE NULL END AS isActivedRequest
        FROM   ticketvoiding_requestdetail_bk rd WITH(NOLOCK)
				LEFT JOIN dbo.ticketvoiding_request_bk r WITH(NOLOCK) 
							ON rd.requestid = r.RequestId
                INNER JOIN (SELECT o.orid, o.eventdate 
                            FROM   dbo.outright_bk o WITH(NOLOCK) )o 
                        ON rd.matchid = o.orid 
        WHERE  o.eventdate BETWEEN @FromDate AND @ToDate 
        GROUP  BY rd.requestid, r.IssueTypeId, rd.Usernames, r.RequestId
    END 

    INSERT INTO @tmpResult (requestid, isActivedRequest) 
    SELECT rd.requestid
			,CASE WHEN r.RequestId IS NULL THEN 1
					ELSE NULL END AS isActivedRequest
    FROM   ticketvoiding_requestdetail_bk rd WITH(NOLOCK)
			LEFT JOIN dbo.ticketvoiding_request_bk r WITH(NOLOCK) 
								ON rd.requestid = r.RequestId
			INNER JOIN (SELECT m.matchid, m.eventdate 
						FROM   dbo.match_bk m WITH(NOLOCK)) m 
					ON rd.matchid = m.matchid 
    WHERE  m.eventdate BETWEEN @FromDate AND @ToDate 
    GROUP  BY rd.requestid, r.IssueTypeId , rd.Usernames, r.RequestId

	SELECT DISTINCT requestid, isActivedRequest
	FROM @tmpResult

END 
