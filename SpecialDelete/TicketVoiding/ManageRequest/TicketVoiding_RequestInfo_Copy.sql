/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestInfo_Copy]
(
	 @RequestId		INT				= NULL
	,@MatchId		INT				= NULL
	,@RequestDetailId   INT			= NULL --Support WMO(12) issuetype
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
		- 20240523@July: [TVS] New issue type Wrong Market Offered & Technical Error [Redmine: #197051/194093]
		- 20240727@July: Modify betid return [Redmine:#197051]
		- 202407256@Max: Change validation for transdesc [Redmine: #197051]
		- 20240916@Max: [TVS] Support void wrong odds for Sportsbook [Redmine: #186029]
		- 20241113@July: Enhance the way to add request for suspenders - [Redmine: #185495]
		- 20241122@July: Wrong Market Offered - Enhance the way to add request & Update 'copy' message template [Redmine: #212928]
		- 20241212@Lani: [TVS] Add new column returned (ServiceAcceptTime, InputtedFromTime, MinAllowanceTime) - [Redmine: #215049]
		- 20241227@Lani: [TVS] Change data of 'MinAllowanceTime' column returned - [Redmine: #215946]
		- 20250110@July: Set default NULL to 0 - [Redmine: #213398]
		- 20250121@Lani: [TVS] Return MinAcceptType column for Danger Accept/Red Card/Wrong Score issue type - [Redmine: #216153]
		- 20250318@Lani: [TVS] Copy request info - Support more issue type [Redmine: #219039]
		- 20250318@Lani: [TVS] Copy request info - Support Wrong HDP - Home/Away Virtual Head Reverse sub types [Redmine: #222346]

	Param's explanation:
		Affected issue type: Danger Accepted, Red Card, Wrong Score
					         Reduced Overs, Not Participate, Abandoned
							 Wrong Market Offered, Technical Error, WrongOU/1st, WrongHDP/1stHDP, WrongOdds

	Noted: Case issue Wrong Score have scores -> get min voidtime of scores
		
*/
BEGIN
	
	DECLARE @IsNeutral			BIT
		  , @GlobalShowTime		SMALLDATETIME
		  , @IsHasSettledTicket BIT = 0
		  , @IssueTypeId		TINYINT
		  , @LiveStatus		    VARCHAR(50)
		  , @TotalCancelCashOutCount INT

	DECLARE @tmpRequestInfo TABLE (
		 RequestId			INT
		,MatchId			INT
		,Sporttype			SMALLINT
		,LeagueId			INT
		,HomeId				INT
		,AwayId				INT
		,FilterBy			INT
		,RequestExtraInfo	VARCHAR(MAX)
		,Provider			NVARCHAR(400)
		,IssueDetail		NVARCHAR(MAX)
		,MistakenBy			NVARCHAR(400)
		,IssueTypeId		TINYINT
		,SubIssueTypeId		TINYINT
		,IssueTypeName		VARCHAR(100)
		,SubIssueTypeName	VARCHAR(100)
		,OperatorInfo		XML
		,Remark				VARCHAR(MAX)
		,UserId				INT
		,FilterFromTranstime	DATETIME
		,VoidFromTime		DATETIME
		,VoidToTime			DATETIME
		,TotalSingleCount	INT
		,TotalParlayCount	INT
		,TotalCancelCashOutCount INT
	)
	
	DECLARE @tmpBettypeCount TABLE(
	     BetTypeId			SMALLINT
	    ,InputtedRuns       VARCHAR(100)
	    ,PlayerAndOdds		VARCHAR(100)
		,BetId				VARCHAR(100) --betcheck(subparlay)
		,PlayerId			VARCHAR(MAX)
		,PlayerName         VARCHAR(100)
	    ,TicketsCount       INT
	)

	DECLARE @tmpTicketInfo TABLE(
	     TransId			BIGINT
	    ,Transdesc			NVARCHAR(1000)
		,Bettype			SMALLINT
	    ,LiveIndicator      BIT
		,BetId				NVARCHAR(50)  
		,Betteam			VARCHAR(20)
		,OddsId				VARCHAR(50)
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
		,Sporttype
		,LeagueId
		,HomeId
		,AwayId
		,FilterBy 
		,RequestExtraInfo
		,Provider
		,IssueDetail
		,MistakenBy
		,IssueTypeId
		,IssueTypeName
		,SubIssueTypeId
		,SubIssueTypeName 
		,OperatorInfo
		,Remark
		,UserId
		,FilterFromTranstime
		,VoidFromTime
		,VoidToTime
		,TotalSingleCount
		,TotalParlayCount
	)
	SELECT TOP(1) 
		 rd.RequestId
		,rd.MatchId
		,CASE WHEN r.IssueTypeId IN (4,5) AND rd.SubIssueTypeId NOT IN (8,9) THEN rd.Sporttype ELSE NULL END AS Sporttype
		,rd.LeagueId
		,rd.HomeId
		,rd.AwayId
		,rd.FilterBy
		,rd.TransIds AS RequestExtraInfo
		,r.Provider
		,rd.IssueDetail
		,CASE WHEN r.IssueTypeId IN (2,4,5,6,7,12) THEN r.MistakenBy ELSE NULL END AS MistakenBy --Wrong Market Offered, Wrong HDP/1stHDP, WrongOU, Wrong Odds
		,r.IssueTypeId
		,i.IssueTypeName
		,CASE WHEN r.IssueTypeId IN (2) THEN s.SubIssueTypeId ELSE NULL END AS SubIssueTypeId
		,s.SubIssueTypeName
		,(SELECT	o.OperatorId AS '@OperatorId', o.OperatorTypeId AS '@TypeId'
				FROM	dbo.TicketVoiding_OperatorInfo o WITH(NOLOCK)
				WHERE	o.RequestId = @RequestId
				FOR XML PATH ('r'), ROOT('root')) AS OperatorInfo
		,r.Remark
		,r.UserId
		,rd.FilterFromTransTime
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
	   AND (rd.Id = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)
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

	IF @IssueTypeId IN (1,10,3) --DA,RC,WC
	BEGIN
		DECLARE @TvDetectionValue VARCHAR(10)
               ,@MinuteOffset VARCHAR(10)
               ,@SecondOffset VARCHAR(10)
			   ,@IssueDetail NVARCHAR(MAX)
			   ,@ServiceAcceptTime VARCHAR(11)
			   ,@MinAllowanceTime SMALLINT
			   ,@AcceptType SMALLINT
			   ,@MinAcceptTypeName NVARCHAR(50)
		
		SELECT @AcceptType = CAST(RequestExtraInfo AS XML).value('(/r/@MinType)[1]', 'SMALLINT')
		FROM @tmpRequestInfo

		;WITH Cte AS (
			SELECT CAST(RequestExtraInfo AS XML).value('(/r/@AA)[1]', 'VARCHAR(10)') AS AA
				  ,CAST(RequestExtraInfo AS XML).value('(/r/@PA)[1]', 'VARCHAR(10)') AS PA
				  ,CAST(RequestExtraInfo AS XML).value('(/r/@SA)[1]', 'VARCHAR(10)') AS SA
			FROM @tmpRequestInfo
		)
		SELECT @MinAllowanceTime = CASE WHEN @AcceptType = 1 THEN AA
										WHEN @AcceptType = 2 THEN SA
										ELSE PA END
			 , @MinAcceptTypeName = CASE WHEN @AcceptType = 1 THEN 'Auto Accept'
											 WHEN @AcceptType = 2 THEN 'Second Accept'
											 ELSE 'Pending Accept' END
		FROM Cte

		SELECT @IssueDetail = IssueDetail
		FROM @tmpRequestInfo

		SELECT @TvDetectionValue = IIF(CHARINDEX('TvDetectionValue:',@IssueDetail) > 0
										, SUBSTRING(@IssueDetail, CHARINDEX('TvDetectionValue:',@IssueDetail) + LEN('TvDetectionValue:'), CHARINDEX(';ServiceAcceptTime:',@IssueDetail) - (CHARINDEX('TvDetectionValue:',@IssueDetail) + LEN('TvDetectionValue:')))
										, '')
			 , @MinuteOffset = IIF(CHARINDEX('MinuteOffset:',@IssueDetail) > 0
			                     , SUBSTRING(@IssueDetail, CHARINDEX('MinuteOffset:',@IssueDetail) + LEN('MinuteOffset:'), CHARINDEX(';SecondOffset:',@IssueDetail) - (CHARINDEX('MinuteOffset:',@IssueDetail) + LEN('MinuteOffset:')))
								 , '')
			 , @SecondOffset = IIF(CHARINDEX('SecondOffset:',@IssueDetail) > 0
								 , SUBSTRING(@IssueDetail, CHARINDEX('SecondOffset:',@IssueDetail) + LEN('SecondOffset:'), LEN(@IssueDetail))
								 , '')
			 , @ServiceAcceptTime = IIF(CHARINDEX('ServiceAcceptTime:',@IssueDetail) > 0
			                     , SUBSTRING(@IssueDetail, CHARINDEX('ServiceAcceptTime:',@IssueDetail) + LEN('ServiceAcceptTime:'), CHARINDEX(';ActualTime:',@IssueDetail) - (CHARINDEX('ServiceAcceptTime:',@IssueDetail) + LEN('ServiceAcceptTime:')))
								 , '')
	END
	
	IF @IssueTypeId IN (19,21,23,12,24,25,2,4,5,6,7) --Reduced Overs, Not Participate, Abandoned, Wrong Market Offered, Technical Error, Wrong odds SB, Wrong HDP/1stHDP, WrongOU/1stOU, Wrong Odds
	BEGIN
		INSERT INTO @tmpTicketInfo (TransId, Transdesc, Bettype, LiveIndicator, BetId, Betteam, OddsId)
		SELECT s.TransId, ISNULL(b.Transdesc,''), b.Bettype, b.liveindicator, CONVERT(NVARCHAR(50), b.betid) AS BetId, betteam, oddsid
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON s.TransId = b.TransId
		WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)
		UNION ALL
		SELECT s.TransId, ISNULL(b.Transdesc,''), b.Bettype, b.liveindicator, CONVERT(NVARCHAR(50), b.betid) AS BetId, betteam, oddsid
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON s.TransId = b.TransId
		WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)
		
		IF EXISTS (SELECT TOP 1 1 
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) 
				WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0))
		BEGIN
			INSERT INTO @tmpTicketInfo (TransId, Transdesc, Bettype, LiveIndicator, BetId, Betteam, OddsId)
			SELECT s.TransId, ISNULL(b.Transdesc,''), b.Bettype, b.liveindicator, CASE WHEN ISNULL(b.betcheck,'') = '' THEN 0 ELSE b.betcheck END AS BetId, betteam, oddsid
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
				INNER JOIN dbo.bettransm b WITH (NOLOCK) ON s.TransId = b.TransId
			WHERE s.RequestId = @RequestId AND s.MatchId = @MatchId AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)
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
		
		
		SELECT @TotalCancelCashOutCount = SUM(CASE WHEN s.IsCancelCO = 1 THEN 1 ELSE 0 END)
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
		WHERE RequestId = @RequestId AND MatchId = @MatchId AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)

		INSERT INTO @tmpBettypeCount (BetTypeId, BetId, TicketsCount)
		SELECT s.BetType, s.BetId, COUNT(1) AS TicketsCount
		FROM  @tmpTicketInfo s 
		WHERE s.Bettype NOT IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc())
		GROUP BY s.BetType, s.BetId

		IF EXISTS (SELECT TOP 1 1 FROM @tmpTicketInfo WHERE Bettype IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc())) --Cricket
		BEGIN
			INSERT INTO @tmpBettypeCount (BetTypeId, PlayerId, TicketsCount)
			SELECT s.BetType, s.Transdesc, COUNT(1) AS TicketsCount
			FROM  @tmpTicketInfo s 
			WHERE s.Bettype IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc() WHERE TypeId = 0)
			GROUP BY s.BetType, s.Transdesc
			
			UPDATE b
			SET b.PlayerName = t.teamname
			FROM @tmpBettypeCount b
				LEFT JOIN dbo.Team t WITH(NOLOCK) ON b.PlayerId = t.teamid

			INSERT INTO @tmpBettypeCount (BetTypeId, PlayerAndOdds, TicketsCount)
			SELECT s.BetType, s.Betteam +'$'+ s.OddsId, COUNT(1) AS TicketsCount
			FROM  @tmpTicketInfo s 
			WHERE s.Bettype IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc() WHERE TypeId = 1)
			GROUP BY s.BetType, s.Betteam +'$'+ s.OddsId

		END
			
		IF @IssueTypeId IN (19, 23, 21)
		BEGIN
			DECLARE @tmpInputtedRuns TABLE (BetTypeId SMALLINT, InputtedRuns VARCHAR(100))
			
			INSERT INTO @tmpInputtedRuns (BetTypeId, InputtedRuns)
			SELECT DISTINCT b.BetTypeId, infor.Runs
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
					CROSS APPLY (
							SELECT CONVERT(XML, rd.TransIds)
						) AS t1(xDATA)
					CROSS APPLY (
							SELECT ISNULL(t.c.value('@BetTypeIds','VARCHAR(MAX)'),0) AS BetTypeIds
								  ,ISNULL(t.c.value('@Runs','VARCHAR(20)'),NULL) AS Runs
							FROM t1.xDATA.nodes('/r') t(c)
						) AS infor
					CROSS APPLY (
							SELECT DISTINCT value AS BetTypeId
							FROM STRING_SPLIT(infor.BetTypeIds, ',')
							WHERE value <> ''
						) b
			WHERE rd.RequestId = @RequestId AND rd.MatchId = @MatchId
		
			
			UPDATE b
			SET b.InputtedRuns = r.InputtedRuns
			FROM @tmpBettypeCount b
				LEFT JOIN @tmpInputtedRuns r ON b.BetTypeId = r.BetTypeId
			WHERE r.InputtedRuns IS NOT NULL
		END
	END
	
	IF @IssueTypeId IN (4,5,6,7) --Wrong HDP/1stHDP, WrongOU/1stOU
	BEGIN
		DECLARE @FilterFavoriteType VARCHAR(50)
				,@FavoriteValue     VARCHAR(50)
				,@RequestExtraInfo  VARCHAR(MAX)
				,@ActualMarket		VARCHAR(50)
				,@WrongMarket		VARCHAR(50)
				,@HdpValue			VARCHAR(50)

		SELECT @RequestExtraInfo = RequestExtraInfo FROM @tmpRequestInfo

		IF (@IssueTypeId IN (4,5))
		BEGIN
			SELECT @FilterFavoriteType = CASE WHEN CHARINDEX('HomeFavorite=',@RequestExtraInfo) > 0 THEN 'h'
											  WHEN CHARINDEX('AwayFavorite=',@RequestExtraInfo) > 0 THEN 'a'
											  ELSE NULL
										 END,
				  @FavoriteValue = CASE WHEN (CHARINDEX('HomeFavorite=',@RequestExtraInfo) > 0) THEN CAST(@RequestExtraInfo AS XML).value('(/r/@HomeFavorite)[1]', 'VARCHAR(50)')
										WHEN (CHARINDEX('AwayFavorite=',@RequestExtraInfo) > 0) THEN CAST(@RequestExtraInfo AS XML).value('(/r/@AwayFavorite)[1]', 'VARCHAR(50)')
										ELSE NULL
								   END,
				  @ActualMarket = CASE WHEN (CHARINDEX('HomeFavorite=',@RequestExtraInfo) > 0) OR (CHARINDEX('AwayFavorite=',@RequestExtraInfo) > 0) THEN CAST(@RequestExtraInfo AS XML).value('(/r/@ActualMarket)[1]', 'VARCHAR(50)')
									   ELSE NULL
								  END,
				  @HdpValue = CASE WHEN CHARINDEX('HdpValue=',@RequestExtraInfo) > 0 THEN CAST(@RequestExtraInfo AS XML).value('(/r/@HdpValue)[1]', 'VARCHAR(50)')
								   ELSE NULL
							  END
		END
		ELSE
		BEGIN
			SELECT @WrongMarket = CAST(@RequestExtraInfo AS XML).value('(/r/@WrongMarket)[1]', 'VARCHAR(50)'),
				   @ActualMarket = CAST(@RequestExtraInfo AS XML).value('(/r/@ActualMarket)[1]', 'VARCHAR(50)')
		END
	END


	IF @IssueTypeId IN (2) --WrongOdds
	BEGIN
		DECLARE @FromOddsNotVoidHomeOver   VARCHAR(10)
				,@ToOddsNotVoidHomeOver    VARCHAR(10)
				,@FromOddsNotVoidAwayUnder VARCHAR(10)
				,@ToOddsNotVoidAwayUnder   VARCHAR(10)
				,@CorrectOddsHomeOver	   VARCHAR(10)
				,@CorrectOddsAwayUnder	   VARCHAR(10)

		SELECT @RequestExtraInfo = RequestExtraInfo FROM @tmpRequestInfo

		SELECT @FromOddsNotVoidHomeOver = CAST(@RequestExtraInfo AS XML).value('(/r/@FromOddsNotVoidHomeOver)[1]', 'VARCHAR(10)'),
			   @ToOddsNotVoidHomeOver = CAST(@RequestExtraInfo AS XML).value('(/r/@ToOddsNotVoidHomeOver)[1]', 'VARCHAR(10)'),
			   @FromOddsNotVoidAwayUnder = CAST(@RequestExtraInfo AS XML).value('(/r/@FromOddsNotVoidAwayUnder)[1]', 'VARCHAR(10)'),
			   @ToOddsNotVoidAwayUnder = CAST(@RequestExtraInfo AS XML).value('(/r/@ToOddsNotVoidAwayUnder)[1]', 'VARCHAR(10)'),
			   @CorrectOddsHomeOver =  CAST(@RequestExtraInfo AS XML).value('(/r/@CorrectOddsHomeOver)[1]', 'VARCHAR(10)'),
			   @CorrectOddsAwayUnder = CAST(@RequestExtraInfo AS XML).value('(/r/@CorrectOddsAwayUnder)[1]', 'VARCHAR(10)')

	END
	/*****************Return table **************************/
	-- 1. Table infor request
	SELECT RequestId 
		  ,MatchId
		  ,Sporttype
		  ,LeagueId 
		  ,HomeId 
		  ,AwayId 
		  ,@GlobalShowTime AS GlobalShowTime
		  ,@IsNeutral AS IsNeutral
		  ,FilterBy 
		  ,RequestExtraInfo
		  ,ISNULL(Provider,'') AS Provider
		  ,MistakenBy
		  ,IssueTypeId
		  ,IssueTypeName
		  ,SubIssueTypeId
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
		  ,@TotalCancelCashOutCount AS TotalCancelCashOutCount
		  ,@TvDetectionValue AS TvDetectionValue
		  ,@MinuteOffset AS MinuteOffset
		  ,@SecondOffset AS SecondOffset
		  ,@ServiceAcceptTime AS ServiceAcceptTime
		  ,FilterFromTranstime
		  ,@MinAllowanceTime AS MinAllowanceTime
		  ,@MinAcceptTypeName AS MinAcceptType
		  ,@FilterFavoriteType AS FilterFavoriteType
		  ,@FavoriteValue AS FavoriteValue
		  ,@ActualMarket AS ActualMarket
		  ,@WrongMarket AS WrongMarket
		  ,@HdpValue AS HdpValue
		  ,@FromOddsNotVoidHomeOver AS FromOddsNotVoidHomeOver
		  ,@ToOddsNotVoidHomeOver AS ToOddsNotVoidHomeOver
		  ,@FromOddsNotVoidAwayUnder AS FromOddsNotVoidAwayUnder
		  ,@ToOddsNotVoidAwayUnder AS ToOddsNotVoidAwayUnder
		  ,@CorrectOddsHomeOver AS CorrectOddsHomeOver
		  ,@CorrectOddsAwayUnder AS CorrectOddsAwayUnder
	FROM @tmpRequestInfo t
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = t.UserId

	-- 2. Table infor bettypes 
	SELECT BetTypeId
		  ,b.typenamee AS OriginalBetTypeName
		  ,InputtedRuns
		  ,BetId
		  ,PlayerName
		  ,PlayerAndOdds
		  ,TicketsCount
	FROM @tmpBettypeCount c
		INNER JOIN dbo.bettype b WITH (NOLOCK) ON c.BetTypeId = b.typeid
	WHERE ISNULL(TicketsCount,0) <> 0
	ORDER BY BetTypeId, InputtedRuns, BetId ASC

END
