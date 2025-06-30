/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MatchInfo_Select]
(
	@EventDate		DATETIME		= NULL
	,@Sporttype		SMALLINT		= NULL	
	,@MatchId		INT				= NULL
	,@ProductIds	VARCHAR(50)		= NULL
	,@ErrorCode		INT				= 0		OUTPUT
	,@ErrorMsg		NVARCHAR(200)	= ''	OUTPUT
)
AS
/*	Created by: 20181212@Kathy
	Task: get match info [Redmine:#90155]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20220706@July: Add column Kickofftime get linklog Poolhouse ticket [Redmine: #172486]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]
		- 20240521@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240618@July: [TVS] Support void wrong odds of Home/Away or Over/Under at the same time [Redmine: #205558]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]
		- 20250324@Max: [TVS] Virtual Sports 7 (Kiron Virtual Sports) [Redmine: #219045]
		- 20250630@Lani: [TVS] Recover Ticket - Support Recover More Products - Sub Parlay [Redmine: #227829]

	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #MatchInfo (matchid INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT
		, eventdate DATETIME, matchcode NVARCHAR(100), ParentId INT, Kickofftime DATETIME
		, VendorMatchId VARCHAR(50), RaceId VARCHAR(10))
	
	DECLARE @ProductIdTbl TABLE (ProductId TINYINT)

	INSERT INTO @ProductIdTbl (ProductId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ProductIds,',')
	WHERE value <> ''
	
	IF @Sporttype NOT IN (147,177,198,125,126,127) OR @Sporttype IS NULL
	BEGIN
		INSERT INTO #MatchInfo(matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, ParentId, Kickofftime)
		SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype, m.eventdate, m.matchcode, m.parentid, m.kickofftime
		FROM	dbo.match m WITH(NOLOCK)
		WHERE	(m.sporttype = @Sporttype OR @Sporttype IS NULL)
				AND m.matchid = @MatchId 
				AND 1 = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN 0 --Exclude child match Cricket
							 ELSE 1 END
				AND 1 = CASE WHEN @ProductIds IS NOT NULL AND NOT EXISTS (SELECT TOP 1 1 
																		  FROM SportBettypeMatrix s WITH (NOLOCK) 
																		  WHERE s.SportType = m.sporttype AND s.ProductID IN (SELECT ProductId FROM @ProductIdTbl)) THEN 0
							ELSE 1 END
		UNION 
		SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype, m.eventdate, m.matchcode, m.parentid, m.kickofftime
		FROM	dbo.match14 m WITH(NOLOCK)
		WHERE	m.sporttype = @Sporttype 
				AND m.matchid = @MatchId 
				AND 1 = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN 0 --Exclude child match Cricket
							 ELSE 1 END
	END

	--VS5
	IF @Sporttype = 147
	BEGIN
		INSERT INTO #MatchInfo(matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, Kickofftime) 
		SELECT	m.Match3rdId, m.homeid, m.awayid, m.League3rdId, m.sporttype, m.eventdate, m.matchcode, m.StartTime
		FROM	dbo.match3rd m WITH(NOLOCK)
		WHERE	m.sporttype = @Sporttype 
				AND m.Match3rdId = @MatchId 
		UNION 
		SELECT	m.Match3rdId, m.homeid, m.awayid, m.League3rdId, m.sporttype, m.eventdate, m.matchcode, m.StartTime
		FROM	dbo.match3rd14 m WITH(NOLOCK)
		WHERE	m.sporttype = @Sporttype 
				AND m.Match3rdId = @MatchId
	END

	-- Virtual Horse Racing & Virtual Dog Racing, VS7
	IF @Sporttype IN (177,198,125,126,127)
	BEGIN 
		INSERT INTO #MatchInfo(matchid, leagueid, sporttype, eventdate, Kickofftime, VendorMatchId, RaceId) 
		SELECT DISTINCT	m.EventID, m.leagueid, m.sporttype, o.eventdate, m.EventTime, VendorMatchId, m.Distance
		FROM	dbo.VSRaceInfo m WITH(NOLOCK)
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON m.EventID = o.EventID
		WHERE	m.sporttype = @Sporttype 
				AND m.EventID = @MatchId 
		UNION
		SELECT DISTINCT	m.EventID, m.leagueid, m.sporttype, o.eventdate, m.EventTime, VendorMatchId, m.Distance
		FROM	dbo.VSRaceInfo14 m WITH(NOLOCK)
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON m.EventID = o.EventID
		WHERE	m.sporttype = @Sporttype 
				AND m.EventID = @MatchId 

	END

	SELECT m.matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, CASE WHEN ISNULL(m.parentid,0) = 0 THEN m.matchid ELSE m.ParentId END AS parentid, Kickofftime, mr.SubType, VendorMatchId, RaceId
	FROM #MatchInfo m
		LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid

	IF NOT EXISTS (SELECT TOP 1 1 FROM #MatchInfo)
	BEGIN
		SELECT @ErrorCode = 1, @ErrorMsg = 'Invalid MatchId.'
	END
	ELSE IF EXISTS (SELECT TOP 1 1 FROM #MatchInfo WHERE @EventDate IS NOT NULL AND eventdate <> @EventDate)
	BEGIN
		SELECT @ErrorCode = 1, @ErrorMsg = 'Wrong Event Date.'
	END
	DROP TABLE #MatchInfo
END
GO
