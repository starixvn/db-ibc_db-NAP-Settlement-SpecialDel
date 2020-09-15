/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RelatedEvent_Select]
(	
	@MatchId		INT
	,@EventDate		DATETIME = NULL
	,@IsMainMatch	BIT = 1
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200828@Charles: Get linked matches of main match [Redmine: #140339]
	
	Param's explanation:
		- @IsMainMatch: 1: Get child match and linked match
						0: Get normal match
		
*/
BEGIN
	SET NOCOUNT ON
	
	IF @IsMainMatch = 1
	BEGIN
		DECLARE @query NVARCHAR(MAX) = ''
		DECLARE @ExecuteSQL NVARCHAR(MAX) = ''
		CREATE TABLE #LinkedMatch_tmp (MainMatchID INT, LinkedMatchID INT)
		
		SET @query = '	SELECT MainMatchID, LinkedMatchID
						FROM	dbo.Dot_Admin_LinkedMatch WITH(NOLOCK) '
		SET @ExecuteSQL = 'DBPRO.bodb02.dbo.sp_executesql @query'
		INSERT INTO #LinkedMatch_tmp (MainMatchID, LinkedMatchID)
		EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

		SELECT m.matchid, m.eventdate, m.homeid, m.awayid
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.ParentID = @MatchId
		UNION
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid
		FROM #LinkedMatch_tmp lm
		INNER JOIN dbo.match m WITH(NOLOCK) ON lm.LinkedMatchID = m.matchid
		WHERE lm.MainMatchID = @MatchId

		DROP TABLE #LinkedMatch_tmp
	END
	ELSE
	BEGIN
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.matchid = @MatchId
			AND m.eventdate = @EventDate
			AND m.sporttype IN (1)
	END
	
END
GO

