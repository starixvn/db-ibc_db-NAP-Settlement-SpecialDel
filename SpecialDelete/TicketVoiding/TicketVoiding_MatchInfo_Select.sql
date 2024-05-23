/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MatchInfo_Select]
(
	@EventDate		DATETIME		= NULL
	,@Sporttype		SMALLINT		= NULL	
	,@MatchId		INT				= NULL
	,@IsUpdRequest	BIT 			= 0
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

	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #MatchInfo (matchid INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT, eventdate DATETIME, matchcode NVARCHAR(100), ParentId INT, Kickofftime DATETIME)
	INSERT INTO #MatchInfo(matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, ParentId, Kickofftime)
	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype, m.eventdate, m.matchcode, m.parentid, m.kickofftime
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	(m.sporttype = @Sporttype OR @Sporttype IS NULL)
			AND m.matchid = @MatchId 
			AND 1 = CASE WHEN @Sporttype = 50 AND m.ChildMatchType = 200 THEN 0 --Exclude child match Cricket
					     ELSE 1 END
	UNION 
	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype, m.eventdate, m.matchcode, m.parentid, m.kickofftime
	FROM	dbo.match14 m WITH(NOLOCK)
	WHERE	m.sporttype = @Sporttype 
			AND m.matchid = @MatchId 
			AND 1 = CASE WHEN @Sporttype = 50 AND m.ChildMatchType = 200 THEN 0 --Exclude child match Cricket
					     ELSE 1 END

	SELECT matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, ISNULL(parentid,matchid) AS parentid, Kickofftime
	FROM #MatchInfo

	IF NOT EXISTS (SELECT TOP 1 1 FROM #MatchInfo) AND @IsUpdRequest = 0
	BEGIN
		SELECT @ErrorCode = 1, @ErrorMsg = 'Invalid MatchId.'
	END
	ELSE IF EXISTS (SELECT TOP 1 1 FROM #MatchInfo WHERE @EventDate IS NOT NULL AND eventdate <> @EventDate) AND @IsUpdRequest = 0
	BEGIN
		SELECT @ErrorCode = 1, @ErrorMsg = 'Wrong Event Date.'
	END
	DROP TABLE #MatchInfo
END
GO
