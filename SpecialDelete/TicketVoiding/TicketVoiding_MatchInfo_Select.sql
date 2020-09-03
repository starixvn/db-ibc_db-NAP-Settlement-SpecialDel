/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_MatchInfo_Select]
(
	@EventDate		DATETIME		= NULL
	,@Sporttype		SMALLINT		= NULL	
	,@MatchId		INT				= NULL
	,@TransIds		VARCHAR(MAX)	= NULL
	,@IsUpdRequest	BIT = 0
	,@ActionId		TINYINT
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
		SELECT DISTINCT val
		FROM dbo.f_SplitString(@TransIds, ',')
		OPTION (MAXRECURSION 0)
		
		SET @tmpMatchId = (SELECT TOP 1 b.matchid
						FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN @transIdTemp tmp ON b.transid = tmp.transid
						WHERE ( (1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102) THEN 1
										 WHEN @ActionId = 2 AND b.statusID  <> 101 THEN 1
										 ELSE 0 END
								AND @IsUpdRequest = 0) OR @IsUpdRequest = 1)
								AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype))
		
		SET @query = '	SELECT m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype AS SportType
						FROM	dbo.match m WITH(NOLOCK) 
						WHERE	m.matchid = @tmpMatchId
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@tmpMatchId INT'' , @tmpMatchId'

		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @tmpMatchId INT', @query, @tmpMatchId
	END
	ELSE IF (@MatchId IS NULL AND @TransIds IS NULL)
	BEGIN
		SET @query = '	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype AS SportType
						FROM	dbo.match m WITH(NOLOCK)
						WHERE	m.eventdate = @EventDate
								AND m.sporttype = @Sporttype
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@Sporttype SMALLINT, @EventDate DATETIME'' , @Sporttype, @EventDate '
		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @Sporttype SMALLINT, @EventDate DATETIME ', @query, @Sporttype, @EventDate
		
	END
	ELSE
	BEGIN
		SET @query = '	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype AS SportType
					FROM	dbo.match m WITH(NOLOCK)
					WHERE	m.eventdate = @EventDate
							AND m.sporttype = @Sporttype
							AND m.matchid = @MatchId
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@Sporttype SMALLINT, @EventDate DATETIME, @MatchId INT'' , @Sporttype, @EventDate, @MatchId '
		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @Sporttype SMALLINT, @EventDate DATETIME, @MatchId INT ', @query, @Sporttype, @EventDate, @MatchId
	
	END
END
GO
