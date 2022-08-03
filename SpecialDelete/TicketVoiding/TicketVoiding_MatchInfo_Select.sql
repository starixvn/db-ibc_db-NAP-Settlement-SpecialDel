/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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
/*	Created by: Kathy
	Date 20181212
	Task: get match info [Redmine:#90155]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191112@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200826@Zane: TVS - Enhance for Danger Accept [#140339]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200921@Charles: TVS - HotFix - Edit request [#142009]
		- 20210201@Zane: TVS - Danger Accept/Red Card Enhancement [#146330]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220321@July: TVS - Danger Accept Enhancement - Phase 11 [Redmine: #164562]
		- 20220418@July: TVS - Get column matchcode [Redmine: #170220]
		- 20220617@July: Add column ParentId support get Provider of match [Redmine: #173229]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #MatchInfo (matchid INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT, eventdate DATETIME, matchcode NVARCHAR(100), ParentId INT)
	INSERT INTO #MatchInfo(matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, ParentId)
	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype, m.eventdate, m.matchcode, m.parentid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.sporttype = @Sporttype
			AND m.matchid = @MatchId
		
	SELECT matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, ISNULL(parentid,matchid) AS parentid
	FROM #MatchInfo

	IF NOT EXISTS (SELECT TOP 1 1 FROM #MatchInfo) AND @IsUpdRequest = 0
	BEGIN
		SELECT @ErrorCode = 1, @ErrorMsg = 'Invalid MatchID.'
	END
	ELSE IF EXISTS (SELECT TOP 1 1 FROM #MatchInfo WHERE eventdate <> @EventDate) AND @IsUpdRequest = 0
	BEGIN
		SELECT @ErrorCode = 1, @ErrorMsg = 'Wrong Event Date.'
	END
	DROP TABLE #MatchInfo
END
GO
