/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestInfo_Copy]
(
	 @RequestId		INT				= NULL
	,@MatchId		INT				= NULL
)
AS
/*	Created by: 20221024@July
	Task: [TVS] Support copy request info in Manage Request [Redmine:#179332]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20221024@July: Create new SP [Redmine:#179332]
		- 20221108@July: Change value KickOffTime to GlobalShowTime (GMT+8) [Redmine:#179332]
		- 20221111@July: TVS - VAR message [Redmine: #178088]

	Param's explanation:
		Affected issue type: Danger Accepted, Red Card, Wrong Score
	
	Noted: Case issue Wrong Score have scores -> get min voidtime of scores
		
*/
BEGIN
	
	DECLARE @IsNeutral BIT
		  , @GlobalShowTime SMALLDATETIME

	DECLARE @tmpRequestInfo TABLE (
		 RequestId			INT
		,MatchId			INT
		,LeagueId			INT
		,HomeId				INT
		,AwayId				INT
		,FilterBy			INT
		,RequestExtraInfo	VARCHAR(MAX)
		,StartVoidTime		DATETIME
		,IssueTypeName		VARCHAR(100)
		,SubIssueTypeName	VARCHAR(100)
	)

	INSERT INTO @tmpRequestInfo
	(
		 RequestId 
		,MatchId 
		,LeagueId
		,HomeId
		,AwayId
		,FilterBy 
		,RequestExtraInfo
		,StartVoidTime 
		,IssueTypeName
		,SubIssueTypeName 
	)
	SELECT TOP(1) 
		 rd.RequestId
		,rd.MatchId
		,rd.LeagueId
		,rd.HomeId
		,rd.AwayId
		,rd.FilterBy
		,rd.TransIds AS RequestExtraInfo
		,rd.VoidFromTime AS StartVoidTime
		,i.IssueTypeName
		,s.SubIssueTypeName
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON rd.RequestId = r.RequestId
		INNER JOIN dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
		INNER JOIN dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON rd.SubIssueTypeId = s.SubIssueTypeId
	WHERE rd.RequestId = @RequestId
	   AND rd.MatchId = @MatchId
	ORDER BY rd.VoidFromTime ASC

	SELECT @IsNeutral = MAX(CASE WHEN m.IsNeutral = 1 THEN 1 ELSE 0 END)
	     , @GlobalShowTime = MAX(m.GlobalShowTime)
	FROM @tmpRequestInfo ri
		CROSS APPLY (
					SELECT m.matchid, m.IsNeutral, m.GlobalShowTime
					FROM dbo.match m WITH(NOLOCK)
					WHERE ri.MatchId = m.matchid
					UNION
					SELECT m14.matchid, m14.IsNeutral, m14.GlobalShowTime
					FROM dbo.match14 m14 WITH(NOLOCK)
					WHERE ri.MatchId = m14.matchid
		) m

	SELECT RequestId 
		  ,MatchId 
		  ,LeagueId 
		  ,HomeId 
		  ,AwayId 
		  ,@GlobalShowTime AS KickOffTime
		  ,@IsNeutral AS IsNeutral
		  ,FilterBy 
		  ,RequestExtraInfo
		  ,StartVoidTime 
		  ,IssueTypeName
		  ,SubIssueTypeName 
	FROM @tmpRequestInfo
END
