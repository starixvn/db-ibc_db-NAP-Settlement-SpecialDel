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
		  , @FromDate_Request		DATETIME

	SET @FromDate_Request = DATEADD(MONTH,-3, @FromDate)

    DECLARE @tmpResult TABLE (RequestID INT, Eventdate DATETIME)

	INSERT INTO @tmpResult (RequestID, Eventdate) 
    SELECT s.RequestID, MIN(s.Winlostdate)
    FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK) 
    WHERE  s.matchid IN ( 9, 29, 2799, 10449 ) 
			AND s.Winlostdate BETWEEN @FromDate AND @ToDate
    GROUP  BY s.RequestID

	;WITH CTE_MatchInfo AS
	(
		SELECT matchid,eventdate
		FROM dbo.match_bk WITH(NOLOCK)
		WHERE eventdate BETWEEN @FromDate AND @ToDate
		UNION all 
		SELECT orid, eventdate
		FROM dbo.outright_bk WITH(NOLOCK)
		WHERE eventdate BETWEEN @FromDate AND @ToDate
	) 
	INSERT INTO @tmpResult (RequestID,  Eventdate)
    SELECT r.RequestID
		  ,MIN(c.Eventdate) AS Eventdate
	FROM  TicketVoiding_Request_bk  r WITH(NOLOCK)
		INNER LOOP JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK) ON rd.requestid = r.RequestId
		INNER JOIN CTE_MatchInfo c ON c.matchid = rd.matchid
	where r.CreatedDate >= @FromDate_Request  
	GROUP  BY r.RequestID

	/***********************************************************************/
	-- Return table request archive
	SET @RequestInfoArchive = COMPRESS((
		SELECT DISTINCT RequestId AS 'req'
			  ,MIN(Eventdate) AS 'e'
		FROM @tmpResult
		GROUP BY RequestID
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfoArchive, 1) AS RequestInfoArchive

END 
