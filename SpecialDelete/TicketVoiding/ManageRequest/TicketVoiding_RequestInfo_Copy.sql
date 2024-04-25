/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
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
		- 20240415@July: [TVS] Quickly copy request info for Traders of Cricket [Redmine: #202943]

	Param's explanation:
		Affected issue type: Danger Accepted, Red Card, Wrong Score
					         Reduced Overs, Not Participate, Abandoned
	
	Noted: Case issue Wrong Score have scores -> get min voidtime of scores
		
*/
BEGIN
	
	DECLARE @IsNeutral			BIT
		  , @GlobalShowTime		SMALLDATETIME
		  , @IsHasSettledTicket BIT = 0
		  , @IssueTypeId		TINYINT
		  , @LiveStatus		    VARCHAR(50)

	DECLARE @tmpRequestInfo TABLE (
		 RequestId			INT
		,MatchId			INT
		,LeagueId			INT
		,HomeId				INT
		,AwayId				INT
		,FilterBy			INT
		,RequestExtraInfo	VARCHAR(MAX)
		,Provider			NVARCHAR(400)
		,IssueTypeId		TINYINT
		,IssueTypeName		VARCHAR(100)
		,SubIssueTypeName	VARCHAR(100)
		,OperatorInfo		XML
		,Remark				VARCHAR(MAX)
		,UserId				INT
		,VoidFromTime		DATETIME
		,VoidToTime			DATETIME
		,TotalSingleCount	INT
		,TotalParlayCount	INT
	)
	
	DECLARE @tmpBettypeCount TABLE(
	     BetTypeId			SMALLINT
	    ,InputtedRuns       VARCHAR(20)
	    ,WicketOver			VARCHAR(20)
		,PlayerId			INT
		,PlayerName         VARCHAR(50)
	    ,TicketsCount       INT
	)

	DECLARE @tmpTicketInfo TABLE(
	     TransId			BIGINT
	    ,Transdesc			NVARCHAR(1000)
		,Bettype			SMALLINT
	    ,LiveIndicator      BIT
		,FilterSet          NVARCHAR(50)  
	)
	SELECT @IsHasSettledTicket = MAX(ISNULL(vh_xml.IsHasSettledTicket,0))
	FROM (
		SELECT VoidingHistoryId
		FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
		WHERE s.RequestId = @RequestId
			AND s.matchID = @MatchId
			AND s.StatusId <> 3
	)vh
	CROSS APPLY (
		SELECT v.VoidData
		FROM dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK)
		WHERE v.VoidingHistoryId = vh.VoidingHistoryId
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
		,IssueTypeId
		,IssueTypeName
		,SubIssueTypeName 
		,OperatorInfo
		,Remark
		,UserId
		,VoidFromTime
		,VoidToTime
		,TotalSingleCount
		,TotalParlayCount
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
		,r.IssueTypeId
		,i.IssueTypeName
		,s.SubIssueTypeName
		,(SELECT	o.OperatorId AS '@OperatorId', o.OperatorTypeId AS '@TypeId'
				FROM	dbo.TicketVoiding_OperatorInfo o WITH(NOLOCK)
				WHERE	o.RequestId = @RequestId
				FOR XML PATH ('r'), ROOT('root')) AS OperatorInfo
		,r.Remark
		,r.UserId
		,rd.VoidFromTime
		,rd.VoidToTime
		,rd.SingleCount AS TotalSingleCount
		,rd.MainParlayCount AS TotalParlayCount
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON rd.RequestId = r.RequestId
		INNER JOIN dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
		INNER JOIN dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON rd.SubIssueTypeId = s.SubIssueTypeId
	WHERE rd.RequestId = @RequestId
	   AND rd.MatchId = @MatchId
	ORDER BY rd.VoidFromTime ASC

	SELECT @IsNeutral = MAX(CASE WHEN m.IsNeutral = 1 THEN 1 ELSE 0 END)
	     , @GlobalShowTime = MAX(m.GlobalShowTime)
		 , @IssueTypeId = MAX(ri.IssueTypeId)
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

	IF @IssueTypeId IN (19,21,23) --Reduced Overs, Not Participate, Abandoned
	BEGIN
		INSERT INTO @tmpBettypeCount (BetTypeId, InputtedRuns, PlayerId, WicketOver)
		SELECT DISTINCT b.BetTypeId, infor.Runs, infor.PlayerId, infor.WicketOver
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				CROSS APPLY (
						SELECT CONVERT(XML, rd.TransIds)
					) AS t1(xDATA)
				CROSS APPLY (
						SELECT ISNULL(t.c.value('@PlayerId','VARCHAR(MAX)'),0) AS PlayerId	
							  ,ISNULL(t.c.value('@BetTypeIds','VARCHAR(MAX)'),0) AS BetTypeIds
							  ,ISNULL(t.c.value('@Runs','VARCHAR(20)'),NULL) AS Runs
							  ,ISNULL(t.c.value('@WicketOver','VARCHAR(20)'),NULL) AS WicketOver
						FROM t1.xDATA.nodes('/r') t(c)
					) AS infor
				CROSS APPLY (
						SELECT DISTINCT value AS BetTypeId
						FROM STRING_SPLIT(infor.BetTypeIds, ',')
						WHERE value <> ''
					) b
		WHERE rd.RequestId = @RequestId AND rd.MatchId = @MatchId

		INSERT INTO @tmpTicketInfo (TransId, Transdesc, Bettype, LiveIndicator, FilterSet)
		SELECT s.TransId, b.Transdesc, b.Bettype, b.liveindicator, CONVERT(NVARCHAR(50), b.betid) AS FilterSet
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON s.TransId = b.TransId
		WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId
		UNION ALL
		SELECT s.TransId, b.Transdesc, b.Bettype, b.liveindicator, CONVERT(NVARCHAR(50), b.betid) AS FilterSet
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON s.TransId = b.TransId
		WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId
		
		IF EXISTS (SELECT TOP 1 1 
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) 
				WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId)
		BEGIN
			INSERT INTO @tmpTicketInfo (TransId, Transdesc, Bettype, LiveIndicator, FilterSet)
			SELECT s.TransId, b.Transdesc, b.Bettype, b.liveindicator, b.betcheck AS FilterSet
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
				INNER JOIN dbo.bettransm b WITH (NOLOCK) ON s.TransId = b.TransId
			WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId
		END
		
		SELECT @LiveStatus = CASE WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt > 0 THEN ' '
								  WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt = 0 THEN ' live '
						          WHEN kq.Live_cnt = 0 AND kq.NonLive_cnt > 0 THEN ' non-live '
							 END
		FROM (
			SELECT COUNT(CASE WHEN liveindicator = 1 THEN liveindicator ELSE NULL END) AS Live_cnt 
			      ,COUNT(CASE WHEN liveindicator = 0 THEN liveindicator ELSE NULL END) AS NonLive_cnt
			FROM @tmpTicketInfo
		)kq

		IF @IssueTypeId IN (19, 23)
		BEGIN
			UPDATE b
			SET b.TicketsCount = a.TicketsCount
			FROM @tmpBettypeCount b
			CROSS APPLY  (
				SELECT s.BetType, c.WicketOver, COUNT(1) AS TicketsCount
				FROM  @tmpBettypeCount c
					INNER JOIN @tmpTicketInfo s ON c.BetTypeId = s.Bettype  
				WHERE (c.WicketOver = '' OR s.FilterSet LIKE '%' + c.WicketOver)
				GROUP BY s.BetType, c.WicketOver
			)a WHERE b.bettypeid = a.BetType AND b.WicketOver = a.WicketOver
			
		END
		IF @IssueTypeId = 21
		BEGIN
			UPDATE b
			SET b.TicketsCount = a.TicketsCount
			FROM @tmpBettypeCount b
			CROSS APPLY  (
				SELECT s.BetType, s.transdesc, COUNT(1) AS TicketsCount
				FROM  @tmpBettypeCount c
					INNER JOIN @tmpTicketInfo s ON c.BetTypeId = s.Bettype
				WHERE s.transdesc = CAST(c.PlayerId AS VARCHAR(20)) 
				GROUP BY s.BetType, s.transdesc
			)a WHERE b.bettypeid = a.BetType AND a.transdesc = CAST(b.PlayerId AS VARCHAR(20))
			
			UPDATE b
			SET b.PlayerName = t.teamname
			FROM @tmpBettypeCount b
				INNER JOIN dbo.Team t WITH(NOLOCK) ON b.PlayerId = t.teamid
		END
	END
	/*****************Return table **************************/
	-- 1. Table infor request
	SELECT RequestId 
		  ,MatchId 
		  ,LeagueId 
		  ,HomeId 
		  ,AwayId 
		  ,@GlobalShowTime AS GlobalShowTime
		  ,@IsNeutral AS IsNeutral
		  ,FilterBy 
		  ,RequestExtraInfo
		  ,ISNULL(Provider,'') AS Provider
		  ,IssueTypeId
		  ,IssueTypeName
		  ,SubIssueTypeName 
		  ,OperatorInfo
		  ,ISNULL(t.Remark,'') AS Remark
		  ,c.username AS RequestedBy
		  ,@IsHasSettledTicket AS IsHasSettledTicket
		  ,@LiveStatus AS LiveStatus
		  ,VoidFromTime
		  ,VoidToTime
		  ,TotalSingleCount
		  ,TotalParlayCount
	FROM @tmpRequestInfo t
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = t.UserId

	-- 2. Table infor bettypes 
	SELECT BetTypeId
		  ,b.typenamee AS BetTypeName
		  ,InputtedRuns
		  ,WicketOver
		  ,PlayerName
		  ,TicketsCount
	FROM @tmpBettypeCount c
		INNER JOIN dbo.bettype b WITH (NOLOCK) ON c.BetTypeId = b.typeid
	WHERE ISNULL(TicketsCount,0) <> 0
	ORDER BY BetTypeId, InputtedRuns, WicketOver ASC

END
