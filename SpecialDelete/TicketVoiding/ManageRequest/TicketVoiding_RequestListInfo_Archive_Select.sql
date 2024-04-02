/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestListInfo_Archive_Select] 
(
	@FromDate   DATETIME
	,@ToDate	DATETIME
)
AS
/*	Created by: 20210112@Zane
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBARC/bodb_Archive
	
	Revisions: 		
		- 20210112@Zane: Create new SP [Redmine:#145719]
		- 20210201@Zane: Modify archive process for abnormal Account [Redmine:#149776]
		- 20211118@Kathy: Tuning performance [Redmine:#164819]
		- 20230629@Max: [TVS] Enhance 'Manage Request' performance [Redmine: #190508]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240319@July: [TVS] SP tuning for EC2024 [Redmine: #200840]

	Param's explanation:
		
*/
BEGIN 
    SET NOCOUNT ON 

	DECLARE @RequestInfoActive		VARBINARY(MAX) = NULL
	      , @RequestInfoArchive		VARBINARY(MAX) = NULL

    DECLARE @tmpResult TABLE (RequestID INT, isActivedRequest BIT, Eventdate DATETIME)

    IF EXISTS (SELECT TOP 1 1 
               FROM dbo.TicketVoiding_RequestDetail_bk WITH(NOLOCK) 
               WHERE MatchId IN ( 9, 29, 2799, 10449 )) 
    BEGIN 
		INSERT INTO @tmpResult (RequestID, Eventdate) 
        SELECT s.RequestID, MIN(b.winlostdate)
        FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK) 
				INNER JOIN dbo.bettrans_bk b WITH(NOLOCK) ON s.transid = b.transid AND s.MatchId = b.matchid AND s.CustId = b.CustId AND s.Bettype = b.Bettype
        WHERE  s.matchid IN ( 9, 29, 2799, 10449 ) 
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
        GROUP  BY s.RequestID
	END

  IF EXISTS (SELECT TOP 1 rd.requestid, o.eventdate 
               FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK) 
                      INNER JOIN dbo.outright_bk o WITH(NOLOCK) ON rd.MatchId = o.orid 
               WHERE  o.eventdate BETWEEN @FromDate AND @ToDate) 
    BEGIN 
        INSERT INTO @tmpResult (RequestID, isActivedRequest, Eventdate)
        SELECT rd.RequestID
			  ,CASE WHEN r.RequestId IS NULL THEN 1 ELSE NULL END AS isActivedRequest
			  ,MIN(o.Eventdate) AS Eventdate
		FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				LEFT JOIN dbo.TicketVoiding_Request_bk r WITH(NOLOCK) 
						ON rd.requestid = r.RequestId
                INNER JOIN dbo.outright_bk o WITH(NOLOCK) 
                        ON rd.matchid = o.orid 
        WHERE  o.eventdate BETWEEN @FromDate AND @ToDate 
        GROUP  BY rd.requestid, r.IssueTypeId, rd.Usernames, r.RequestId
    END 

    INSERT INTO @tmpResult (RequestID, isActivedRequest, Eventdate)
    SELECT rd.RequestID
		  ,CASE WHEN r.RequestId IS NULL THEN 1 ELSE NULL END AS isActivedRequest
		  ,MIN(m.Eventdate) AS Eventdate
	FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
			LEFT JOIN dbo.TicketVoiding_Request_bk r WITH(NOLOCK) 
					ON rd.requestid = r.RequestId
			INNER JOIN dbo.match_bk m WITH(NOLOCK)
					ON rd.matchid = m.matchid 
    WHERE  m.eventdate BETWEEN @FromDate AND @ToDate
    GROUP  BY rd.RequestID, r.IssueTypeId , rd.Usernames, r.RequestId

	/***********************************************************************/
	--1. Return table request active
	SET @RequestInfoActive = COMPRESS((
		SELECT DISTINCT RequestId AS 'req'
			  ,MIN(Eventdate) AS 'e'
		FROM @tmpResult
		WHERE isActivedRequest = 1
		GROUP BY RequestID
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfoActive, 1) AS RequestInfoActive

	--2. Return table request archive
	SET @RequestInfoArchive = COMPRESS((
		SELECT DISTINCT RequestId AS 'req'
			  ,MIN(Eventdate) AS 'e'
		FROM @tmpResult
		WHERE isActivedRequest IS NULL
		GROUP BY RequestID
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfoArchive, 1) AS RequestInfoArchive

END 
