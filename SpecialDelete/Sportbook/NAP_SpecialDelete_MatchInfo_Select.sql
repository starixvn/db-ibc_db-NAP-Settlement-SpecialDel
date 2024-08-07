/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_MatchInfo_Select] 
	@matchID INT,
	@IsExcludeChildMatchCricket BIT = 0, --1: mark/unmark only
	@IsMatch3rd BIT = 0,	
	@Language VARCHAR(2) = 'E',
	@Type INT = 0
AS
/*
	Created: 20180305@Helen
	Task : View match info
	DB: DBPRO/bodb02
	Original:
	Revisions: 
		- 20180305@Helen: Initialize - [Redmine: 90153]
		- 20190228@Kathy: Support get match info in table match14 [Redmine:#90155]
		- 20210106@Charles: Support get match info for another product [Redmine:#143666]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20220221@July: Add column LeagueGroupID detect China View Licensee [Redmine: #168651]
		- 20230112@July: [TVS] Add more send Letstalk info when an abnormal request added [Redmine: #182392]
		- 20230324@Max: [TVS] Manage Request enhancement - Phase 13 [Redmine: #185237]
		- 20230427@July: Invalid matchid when input child match Cricket [Redmine: #187052]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]

	Param's explanation:	
		- @Type: 0 - Normal (get match from match table)
				 1 - Outright
				 2 - Virtual Sport \ Horse Racing
	
*/
BEGIN

	SET NOCOUNT ON
	DECLARE @bettype INT

	IF @bettype = 10
		SELECT
			match.orid as matchid,
			MATCH.teamid AS homeid,
			0 AS awayid,
			MATCH.matchcode,
			MATCH.eventdate,
			MATCH.leagueid,
			GETDATE() AS DATETIME,
			CONVERT(BIT,0) AS IsNeutral,
			CONVERT(NVARCHAR(50),MATCH.kickofftime) as showtime
		FROM dbo.Outright AS MATCH WITH (NOLOCK)
		WHERE MATCH.orid = @matchID
	ELSE
	BEGIN
		IF @IsMatch3rd = 1
		BEGIN
			SELECT 
					match.Match3rdId AS matchid,
					match.homeid,
					match.awayid,
					NULL AS matchcode, 
					match.eventdate, 
					match.League3rdId leagueid,
					NULL AS IsNeutral,
					NULL AS showtime,
					NULL AS kickofftime,
					match.sporttype,
					match.StartTime,
					match.EndTime
				FROM dbo.Match3rd AS match WITH (NOLOCK) 
				WHERE match.Match3rdId = @matchID
		END
		ELSE IF @Type = 0
		BEGIN
			SELECT	m.matchid
					,m.homeid
					,m.awayid
					,m.matchcode
					,m.eventdate
					,m.leagueid
					,isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
					,m.showtime
					,m.kickofftime
					,m.sporttype
					,l.LeagueGroupID
					,m.GlobalShowTime
					,mr.NumberOfCorner
			FROM	dbo.match AS m WITH (NOLOCK) 
				INNER JOIN dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
				OUTER APPLY (
					SELECT RIGHT(mr.SubType, 2) AS NumberOfCorner					FROM match_remark mr WITH (NOLOCK)					WHERE mr.matchid = m.matchid						AND mr.MainType = 1						AND mr.SubType LIKE '21__'
				)mr
			WHERE	m.matchid = @matchID
				AND 1 = CASE WHEN @IsExcludeChildMatchCricket = 1 AND m.sporttype = 50 AND m.ChildMatchType = 200 THEN 0 --Exclude child match Cricket
							 ELSE 1 END 
			UNION ALL
			SELECT	m14.matchid
					,m14.homeid
					,m14.awayid
					,m14.matchcode
					,m14.eventdate
					,m14.leagueid
					,isnull(m14.isNeutral, CONVERT(BIT,0)) as IsNeutral
					,m14.showtime
					,m14.kickofftime
					,m14.sporttype
					,l.LeagueGroupID
					,m14.globalshowtime
					,mr.NumberOfCorner
			FROM	dbo.match14 AS m14 WITH (NOLOCK) 
				INNER JOIN dbo.league AS l WITH(NOLOCK) ON m14.leagueid = l.leagueid
				OUTER APPLY (
					SELECT RIGHT(mr.SubType, 2) AS NumberOfCorner					FROM match_remark mr WITH (NOLOCK)					WHERE mr.matchid = m14.matchid						AND mr.MainType = 1						AND mr.SubType LIKE '21__'
				)mr
			WHERE	m14.matchid = @matchID	
				AND 1 = CASE WHEN @IsExcludeChildMatchCricket = 1 AND m14.sporttype = 50 AND m14.ChildMatchType = 200 THEN 0 --Exclude child match Cricket
							 ELSE 1 END 

			UNION ALL --VS5
			SELECT 
				match.Match3rdId AS matchid,
				match.homeid,
				match.awayid,
				NULL AS matchcode, 
				match.eventdate, 
				match.League3rdId leagueid,
				NULL AS IsNeutral,
				NULL AS showtime,
				NULL AS kickofftime,
				match.sporttype,
				NULL AS LeagueGroupID,
				match.StartTime,
				NULL AS NumberOfCorner
			FROM dbo.Match3rd AS match WITH (NOLOCK) 
			WHERE match.Match3rdId = @matchID
			UNION ALL --VS5
			SELECT 
				match.Match3rdId AS matchid,
				match.homeid,
				match.awayid,
				NULL AS matchcode, 
				match.eventdate, 
				match.League3rdId leagueid,
				NULL AS IsNeutral,
				NULL AS showtime,
				NULL AS kickofftime,
				match.sporttype,
				NULL AS LeagueGroupID,
				match.StartTime,
				NULL AS NumberOfCorner
			FROM dbo.Match3rd14 AS match WITH (NOLOCK) 
			WHERE match.Match3rdId = @matchID
		END
		ELSE IF @Type = 1
		BEGIN
			SELECT
				match.orid as matchid,
				MATCH.teamid AS homeid,
				0 AS awayid,
				MATCH.matchcode,
				MATCH.eventdate,
				MATCH.leagueid,
				CONVERT(BIT,0) AS IsNeutral,
				MATCH.kickofftime as kickofftime
			FROM dbo.Outright AS MATCH WITH (NOLOCK)
			WHERE MATCH.orid = @matchID
		END
		ELSE IF @Type = 2
		BEGIN
			SELECT
				o.Orid as matchid,
				o.RacerID AS homeid,
				0 AS awayid,
				o.RacerNum AS matchcode,
				o.EventDate,
				r.leagueid,
				CONVERT(BIT,0) AS IsNeutral,
				o.KickoffTime as kickofftime
			FROM dbo.VSOutright o WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.Orid = @matchID
		END
	END		

END
GO