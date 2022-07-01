/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MatchInfo_Select]
(
	@EventDate		DATETIME		= NULL
	,@Sporttype		SMALLINT		= NULL	
	,@MatchId		INT				= NULL
	,@TransIds		VARCHAR(MAX)	= NULL
	,@IsUpdRequest	BIT 			= 0
	,@ActionId		TINYINT 		= 0
	,@ErrorCode		INT				= 0		OUTPUT
	,@ErrorMsg		NVARCHAR(200)	= ''	OUTPUT
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: get match info [Redmine:#90155]
	DB: DBTXN/bodb02
	
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

	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMatchId INT
	DECLARE @transIdTemp TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @query NVARCHAR(MAX) = ''
	DECLARE @execSql NVARCHAR(MAX) = ''
	
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	
	IF @TransIds IS NOT NULL
	BEGIN
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT bettype
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE ProductID = 1 -- Sportsbook
			AND bettype NOT IN (10, 9, 29) -- outright, parlay
			AND SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
			
		INSERT INTO @transIdTemp (transid)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TransIds, ',')
		
		SET @tmpMatchId = (SELECT TOP 1 b.matchid
						FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN @transIdTemp tmp ON b.transid = tmp.transid
						WHERE ( (1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102) THEN 1
										 WHEN @ActionId = 2 AND b.statusID  <> 101 THEN 1
										 ELSE 0 END
								AND @IsUpdRequest = 0) OR @IsUpdRequest = 1)
								AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype))
		
		SET @query = '	SELECT m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype, m.matchcode
						FROM	dbo.match m WITH(NOLOCK) 
						WHERE	m.matchid = @tmpMatchId
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@tmpMatchId INT'' , @tmpMatchId'

		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @tmpMatchId INT', @query, @tmpMatchId
	END	
	ELSE IF @MatchId IS NOT NULL
	BEGIN
		CREATE TABLE #MatchInfo (matchid INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT, eventdate DATETIME, matchcode NVARCHAR(100), ParentId INT)
		SET @query = '	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype, m.eventdate, m.matchcode, m.parentid
					FROM	dbo.match m WITH(NOLOCK)
					WHERE	m.sporttype = @Sporttype
							AND m.matchid = @MatchId
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@Sporttype SMALLINT, @MatchId INT'' , @Sporttype, @MatchId '

		INSERT INTO #MatchInfo(matchid, homeid, awayid, leagueid, sporttype, eventdate, matchcode, ParentId)
		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @Sporttype SMALLINT, @MatchId INT ', @query, @Sporttype, @MatchId	
		
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
END
GO
