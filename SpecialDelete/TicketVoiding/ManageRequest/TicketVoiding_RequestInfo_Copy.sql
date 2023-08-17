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
		- 20230712@July: TVS - Add provider to the quickly copy request info function [Redmine: #191058]
		- 20230817@Max: [TVS] Support Suspenders quickly copy request info to send mail/lestalk [Redmine: #185493]

	Param's explanation:
		Affected issue type: Danger Accepted, Red Card, Wrong Score
	
	Noted: Case issue Wrong Score have scores -> get min voidtime of scores
		
*/
BEGIN
	
	DECLARE @IsNeutral BIT
		  , @GlobalShowTime SMALLDATETIME
		  , @IsHasSettledTicket BIT = 0

	DECLARE @tmpRequestInfo TABLE (
		 RequestId			INT
		,MatchId			INT
		,LeagueId			INT
		,HomeId				INT
		,AwayId				INT
		,FilterBy			INT
		,RequestExtraInfo	VARCHAR(MAX)
		,Provider			NVARCHAR(400)
		,StartVoidTime		DATETIME
		,IssueTypeName		VARCHAR(100)
		,SubIssueTypeName	VARCHAR(100)
		,OperatorInfo		XML
		,Remark				VARCHAR(MAX)
		,UserId				INT
	)

	SELECT @IsHasSettledTicket = MAX(ISNULL(vh_xml.IsHasSettledTicket,0))
	FROM (
		SELECT MAX(VoidingHistoryId) AS VoidingHistoryId
		FROM dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK)
		WHERE v.RequestId = @RequestId
			AND v.StatusId <> 3
	)vh
	CROSS APPLY (
		SELECT v.BroadcastSessionId
		FROM dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK)
		WHERE v.VoidingHistoryId = vh.VoidingHistoryId
	)vb
	CROSS APPLY (
		SELECT v.VoidData
		FROM dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK)
		WHERE v.BroadcastSessionId = vb.BroadcastSessionId
	)vd
	CROSS APPLY (
		SELECT CASE WHEN ISNULL(t.c.value('@IsHasSettledTicket','VARCHAR(50)'),0) = 'True' THEN 1 ELSE 0 END AS IsHasSettledTicket			
		FROM vd.VoidData.nodes('VoidData') t(c)	
		WHERE vd.VoidData IS NOT NULL
	)vh_xml

	INSERT INTO @tmpRequestInfo
	(
		 RequestId 
		,MatchId 
		,LeagueId
		,HomeId
		,AwayId
		,FilterBy 
		,RequestExtraInfo
		,Provider
		,StartVoidTime 
		,IssueTypeName
		,SubIssueTypeName 
		,OperatorInfo
		,Remark
		,UserId
	)
	SELECT TOP(1) 
		 rd.RequestId
		,rd.MatchId
		,rd.LeagueId
		,rd.HomeId
		,rd.AwayId
		,rd.FilterBy
		,rd.TransIds AS RequestExtraInfo
		,r.Provider
		,rd.VoidFromTime AS StartVoidTime
		,i.IssueTypeName
		,s.SubIssueTypeName
		,(SELECT	o.OperatorId AS '@OperatorId', o.OperatorTypeId AS '@TypeId'
				FROM	dbo.TicketVoiding_OperatorInfo o WITH(NOLOCK)
				WHERE	o.RequestId = @RequestId
				FOR XML PATH ('r'), ROOT('root')) AS OperatorInfo
		,r.Remark
		,r.UserId
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
		  ,@GlobalShowTime AS GlobalShowTime
		  ,@IsNeutral AS IsNeutral
		  ,FilterBy 
		  ,RequestExtraInfo
		  ,Provider
		  ,StartVoidTime 
		  ,IssueTypeName
		  ,SubIssueTypeName 
		  ,OperatorInfo
		  ,t.Remark
		  ,c.username AS RequestedBy
		  ,@IsHasSettledTicket AS IsHasSettledTicket
	FROM @tmpRequestInfo t
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = t.UserId
END
