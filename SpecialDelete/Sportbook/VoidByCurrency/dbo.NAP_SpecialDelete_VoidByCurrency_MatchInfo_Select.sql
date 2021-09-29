/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_MatchInfo_Select]
(
	@MatchId INT = 0
)
AS
/*
	Created: 20210827@Max
	Task : [TVS] Support Outright on Void By Currency [Redmine: #159540]
	DB: DBPRO/bodb02
	Original:
	Revisions: 
		- 20210827@Max: Create SP - [Redmine: #159540]

	Param's explanation:	
	
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @tmpMatch_info AS TABLE (
		matchid INT
		, homeid INT
		, awayid INT
		, matchcode VARCHAR(100)
		, eventdate DATETIME
		, leagueid INT
		, IsNeutral BIT
		, showtime NVARCHAR(100)
		, kickofftime DATETIME
		, sporttype SMALLINT
		, IsOutright BIT
	)

	INSERT INTO @tmpMatch_info(matchid, homeid, awayid, matchcode, eventdate, leagueid, IsNeutral, showtime, kickofftime, sporttype, IsOutright)
	SELECT	m.matchid
		,m.homeid
		,m.awayid
		,m.matchcode
		,m.eventdate
		,m.leagueid
		,isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		,m.showtime
		,m.kickofftime
		,m.sporttype
		,0 AS IsOutright
	FROM	dbo.match AS m WITH (NOLOCK) 
	WHERE	m.matchid = @matchID

	IF NOT EXISTS (SELECT TOP(1) 1 FROM @tmpMatch_info)
	BEGIN
		INSERT INTO @tmpMatch_info(matchid, homeid, awayid, matchcode, eventdate, leagueid, IsNeutral, showtime, kickofftime, sporttype, IsOutright)
		SELECT o.orid as matchid,
			o.teamid AS homeid,
			0 AS awayid,
			o.matchcode,
			o.eventdate,
			o.leagueid,
			CONVERT(BIT,0) AS IsNeutral,
			NULL AS showtime,
			o.kickofftime as kickofftime,
			l.sporttype,
			1 AS IsOutright
		FROM dbo.Outright AS o WITH (NOLOCK)
			INNER JOIN dbo.League l WITH (NOLOCK) ON o.leagueid = l.leagueid
		WHERE o.orid = @matchID
	END

	SELECT matchid, homeid, awayid, matchcode, eventdate, leagueid, IsNeutral, showtime, kickofftime, sporttype, IsOutright
	FROM @tmpMatch_info

END
GO