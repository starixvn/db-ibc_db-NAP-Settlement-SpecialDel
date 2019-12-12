/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_MatchInfo_Select]
(
	@EventDate		DATETIME		= NULL
	,@Sporttype		SMALLINT		= NULL	
	,@LeagueId		INT				= 0
	,@TransIds		VARCHAR(MAX)	= NULL
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: get match info [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191112@Max: AdnormalBet TVS [Redmine:#123691]
		
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @matchID INT
	DECLARE @transIdTemp TABLE (transid BIGINT NULL)
	DECLARE @query NVARCHAR(MAX) = ''
	DECLARE @execSql NVARCHAR(MAX) = ''
		
	IF @TransIds IS NOT NULL
	BEGIN
		INSERT INTO @transIdTemp (transid)
		SELECT DISTINCT val
		FROM dbo.f_SplitString(@TransIds, ',')
		OPTION (MAXRECURSION 0)
	
		SET @matchID = (SELECT TOP 1 bt.matchid
						FROM @transIdTemp AS tmp
							CROSS APPLY (
										SELECT TOP 1 matchid
										FROM dbo.bettrans WITH (NOLOCK)
										WHERE transid = tmp.transid
										)bt
						)
				
		SET @query = '	SELECT m.matchid, m.homeid, m.awayid, m.leagueid, m.sporttype AS SportType
						FROM	dbo.match m WITH(NOLOCK) 
						WHERE	m.matchid = @matchID
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@matchid INT'' , @matchid'

		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @matchid INT', @query, @matchid
	END
	ELSE IF (@LeagueId = 0 AND @TransIds IS NULL)
	BEGIN
		SET @query = '	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid
						FROM	dbo.match m WITH(NOLOCK)
						WHERE	m.eventdate = @EventDate
								AND m.sporttype = @Sporttype
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@Sporttype SMALLINT, @EventDate DATETIME'' , @Sporttype, @EventDate '
		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @Sporttype SMALLINT, @EventDate DATETIME ', @query, @Sporttype, @EventDate
		
	END
	ELSE
	BEGIN
		SET @query = '	SELECT	m.matchid, m.homeid, m.awayid, m.leagueid
					FROM	dbo.match m WITH(NOLOCK)
					WHERE	m.eventdate = @EventDate
							AND m.sporttype = @Sporttype
							AND m.leagueid = @LeagueId
									'
		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@Sporttype SMALLINT, @EventDate DATETIME, @LeagueId INT'' , @Sporttype, @EventDate, @LeagueId '
		EXECUTE	sys.sp_executesql @execSql, N'@query NVARCHAR(MAX), @Sporttype SMALLINT, @EventDate DATETIME, @LeagueId INT ', @query, @Sporttype, @EventDate, @LeagueId
	
	END
END
GO
