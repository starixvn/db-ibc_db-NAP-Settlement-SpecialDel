/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
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

	Param's explanation:
		
*/
BEGIN 
    SET nocount ON 

    DECLARE @tmpResult TABLE (requestid INT, isActivedRequest BIT) 

    IF EXISTS (SELECT TOP 1 1 
               FROM   ticketvoiding_requestdetail_bk rd WITH(NOLOCK) 
            WHERE  matchid IN ( 9, 29, 2799 )) 
    BEGIN      

        INSERT INTO @tmpResult (requestid, isActivedRequest) 
		SELECT rd.requestid
			,CASE WHEN r.RequestId IS NULL THEN 1
					ELSE NULL END AS isActivedRequest
		FROM   ticketvoiding_requestdetail_bk rd WITH(NOLOCK)
				LEFT JOIN dbo.ticketvoiding_request_bk r WITH(NOLOCK) 
						ON rd.requestid = r.RequestId 
				INNER JOIN dbo.ticketvoiding_requestdetailticket_single_bk s WITH(NOLOCK) 
						ON rd.requestid = s.requestid 
				CROSS APPLY(
					SELECT 	TOP 1 b.transid, b.winlostdate
					FROM	dbo.bettrans_bk b WITH(NOLOCK)
					WHERE	b.transid = s.transid
				)b
		WHERE  rd.matchid IN ( 9, 29, 2799 ) 
				AND b.winlostdate BETWEEN @FromDate AND @ToDate 
		GROUP  BY rd.requestid, r.IssueTypeId, rd.Usernames, r.RequestId
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
