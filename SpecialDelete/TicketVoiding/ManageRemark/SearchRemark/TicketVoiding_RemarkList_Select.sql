/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RemarkList_Select]
	 @FromDate			DATETIME	= NULL
	,@ToDate			DATETIME	= NULL
	,@MatchId			INT			= NULL
	,@RemarkId			INT			= NULL
	,@ActionIds			VARCHAR(50)	= NULL
	,@IsExcludeTest		BIT			= 1
	,@CreatedBy			INT			= 0
AS
/*
	Created by: 20251119@Lani
	Task: Manage Remark - New function [Redmine: #234937]
	DB: DBCTG-bodb02

	Revisions: 
		- 20251119@Lani: [TVS] Create new SP [Redmine: #234937]

	Parameters Explanation: 
		- @ActionIds:
			+ ActionId = 0: Refund
			+ ActionId = 1: Waiting
			+ ActionId = 2: Take note
			+ ActionId = 3: Void Ticket

*/
BEGIN 
	SET NOCOUNT ON

	DECLARE	@FilterBy	 TINYINT
		   ,@TmpFromDate DATETIME
		   ,@TmpToDate	 DATETIME

	DECLARE @TmpActionIds AS TABLE (ActionId INT)

	CREATE TABLE #TmpListRemark (
		RemarkId		INT
	   ,MatchId			INT
	)
	
	IF @ActionIds IS NOT NULL
	BEGIN
		INSERT INTO @TmpActionIds(ActionId)
		SELECT CAST(value AS INT)
		FROM STRING_SPLIT(@ActionIds,',')
		WHERE value <> ''
	END

	SELECT @FilterBy = CASE WHEN @RemarkId IS NOT NULL THEN 1
							WHEN @MatchId IS NOT NULL THEN 2
							WHEN @FromDate IS NOT NULL AND @ToDate IS NOT NULL THEN 3
					   END
	
	IF @FilterBy = 3
	BEGIN
		SELECT @TmpFromDate = @FromDate, @TmpToDate = @ToDate
	END

	IF @FilterBy = 1
	BEGIN
		INSERT INTO #TmpListRemark(RemarkId, MatchId)
		SELECT r.RemarkId, r.MatchId
		FROM TicketVoiding_Remark AS r WITH (NOLOCK)
		WHERE r.RemarkId = @RemarkId
	END
	ELSE IF @FilterBy = 2
	BEGIN
		INSERT INTO #TmpListRemark (RemarkId, MatchId)
		SELECT r.RemarkId, m.MatchId
		FROM TicketVoiding_Remark AS r WITH (NOLOCK)
		CROSS APPLY (
			SELECT m.matchid
			FROM dbo.match AS m WITH (NOLOCK)
			WHERE m.matchid = r.MatchId
			UNION ALL
			SELECT m14.matchid
			FROM dbo.match14 AS m14 WITH (NOLOCK)
			WHERE m14.matchid = r.MatchId
		) AS m
		WHERE r.MatchId = @MatchId
	END
	ELSE IF @FilterBy = 3
	BEGIN
		INSERT INTO #TmpListRemark (RemarkId, MatchId)
		SELECT r.RemarkId, m.matchid
		FROM TicketVoiding_Remark AS r WITH (NOLOCK)
		CROSS APPLY (
			SELECT m.matchid, m.eventdate
			FROM dbo.match AS m WITH (NOLOCK)
			WHERE m.matchid = r.MatchId
			UNION ALL
			SELECT m14.matchid, m14.eventdate
			FROM dbo.match14 AS m14 WITH (NOLOCK)
			WHERE m14.matchid = r.MatchId
		) AS m
		WHERE m.eventdate BETWEEN @TmpFromDate AND @TmpToDate
	END

	SELECT t.RemarkId
		  ,t.MatchId
		  ,m.matchcode
		  ,r.Description
		  ,r.IsCheckedVar
		  ,m.sporttype
		  ,m.HomeId
		  ,m.AwayId
		  ,m.LeagueId
		  ,mr.SettlementStatus AS SettlementStatus
		  ,m.KickOffTime
		  ,m.EventDate
		  ,c1.UserName AS CreatedBy
		  ,r.CreatedDate
		  ,r.MistakenBy
		  ,r.DecidedBy
		  ,r.PerformedBy
		  ,r.TV_IPTV AS Iptv
		  ,o.Suspender
		  ,o.Trader
		  ,c2.username AS CloseCaseBy
		  ,r.ActionId
		  ,r.Remark
		  ,r.Provider
		  ,r.Source
		  ,r.Message
	FROM #TmpListRemark AS t WITH (NOLOCK)
	INNER JOIN TicketVoiding_Remark AS r WITH (NOLOCK) ON t.RemarkId = r.RemarkId AND t.MatchId = r.MatchId
	LEFT JOIN CustDB.dbo.Customer AS c1 WITH (NOLOCK) ON c1.CustId = r.UserId
	LEFT JOIN CustDB.dbo.Customer AS c2 WITH (NOLOCK) ON c2.CustId = r.LastModifiedBy
	CROSS APPLY
	(
		SELECT m.MatchId, m.MatchCode, m.Sporttype, m.HomeId, m.AwayId, m.LeagueId, m.FinalHomeScore, m.FinalAwayScore, m.HtHomeScore, m.HtAwayScore, m.KickOffTime, m.EventDate
		FROM dbo.match AS m WITH (NOLOCK)
		WHERE m.MatchId = t.MatchId
		UNION ALL
		SELECT m14.MatchId, m14.MatchCode, m14.Sporttype, m14.HomeId, m14.AwayId, m14.LeagueId, m14.FinalHomeScore, m14.FinalAwayScore, m14.HtHomeScore, m14.HtAwayScore, m14.KickOffTime, m14.EventDate
		FROM dbo.match14 AS m14 WITH (NOLOCK)
		WHERE m14.matchid = t.MatchId
	) AS m
	OUTER APPLY (
		SELECT CASE WHEN mr.calculate = 1 THEN 'FT: ' + CAST(m.FinalHomeScore AS VARCHAR(10)) + '-' + CAST(m.FinalAwayScore AS VARCHAR(10))
					WHEN mr.IsHTCal = 1 THEN 'HT: ' + CAST(m.HtHomeScore AS VARCHAR(10)) + '-' + CAST(m.HtAwayScore AS VARCHAR(10))
					ELSE 'HT: _-_' END AS SettlementStatus
		FROM dbo.match_remark AS mr WITH (NOLOCK)
		WHERE mr.matchid = t.MatchId
	) AS mr
	OUTER APPLY (
		SELECT STRING_AGG(CASE WHEN o.OperatorTypeId = 1 THEN c.UserName ELSE NULL END,', ') AS Trader
			  ,STRING_AGG(CASE WHEN o.OperatorTypeId = 2 THEN c.UserName ELSE NULL END,', ') AS Suspender
		FROM dbo.TicketVoiding_OperatorInfo AS o WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON o.OperatorId = c.custid
		WHERE t.RemarkId = o.RemarkId
	) AS o
	WHERE (r.UserId = @CreatedBy OR @CreatedBy = 0)
		AND ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
		AND EXISTS (SELECT TOP 1 1 FROM @TmpActionIds AS a WHERE a.ActionId = r.ActionId)

	DROP TABLE #TmpListRemark
END