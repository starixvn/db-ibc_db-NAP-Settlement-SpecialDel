/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RelatedEvent_Select]
(	
	@MatchId		INT
	,@EventDate		DATETIME = NULL
	,@IsMainMatch	BIT = 1
	,@IssueTypeId	TINYINT = NULL
	,@Sporttype		SMALLINT = 1
)
AS
/*	
	Created by: 20220916@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20220916@July: Change config DBTXN -> DBPRO [Redmine: #175412]
		- 20231013@July: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]
		- 20240514@July: [TVS] EKO/WKOT - Add message template to the Add Request page [Redmine: #203776]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20250306@Lani: [TVS] Return more columns (match_remark.subtype) [Redmine: #216151]

	Param's explanation:
		- @IsMainMatch: 1: Get child match and linked match
						0: Get normal match
		
*/
BEGIN
	SET NOCOUNT ON
	
	IF @IsMainMatch = 1
	BEGIN
		CREATE TABLE #LinkedMatch_tmp (MainMatchID INT, LinkedMatchID INT)
		INSERT INTO #LinkedMatch_tmp (MainMatchID, LinkedMatchID)
		SELECT MainMatchID, LinkedMatchID
		FROM dbo.Dot_Admin_LinkedMatch WITH(NOLOCK)
		WHERE MainMatchID = @MatchId 

		IF @IssueTypeId IN (4,5,6,7)
		BEGIN
			DECLARE @fantasymatch_tmp TABLE (fantasy_match INT, value VARCHAR(200))

			INSERT INTO @fantasymatch_tmp (fantasy_match, value)
			SELECT  m.MatchId, ','+ m.Value +','
			FROM dbo.Match_Property m WITH(NOLOCK)
			WHERE m.Value LIKE '%'+ CAST(@MatchId AS VARCHAR(20)) +'%' AND m.[Key] = 'fantasy'

			IF EXISTS ( SELECT TOP 1 1 FROM @fantasymatch_tmp)
			BEGIN
				INSERT INTO #LinkedMatch_tmp (MainMatchID, LinkedMatchID)
				SELECT @MatchId, f.fantasy_match 
				FROM @fantasymatch_tmp f
				WHERE f.Value LIKE '%,' + CAST(@MatchId AS VARCHAR(20)) +',%' 
			END
		END

		SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.matchcode, m.leagueid, 1 AS MatchType, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral, m.sporttype, mr.SubType
		FROM dbo.match m WITH (NOLOCK)
		INNER JOIN match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
		WHERE 1 = CASE WHEN m.sporttype NOT IN (50,8) AND m.ParentID = @MatchId THEN 1
					WHEN m.sporttype IN (50,8) AND m.ParentID = @MatchId AND m.ChildMatchType <> 200 THEN 1
				ELSE 0 END
		UNION ALL
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.matchcode, m.leagueid, 2 AS MatchType, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral, m.sporttype, mr.SubType
		FROM #LinkedMatch_tmp lm
		INNER JOIN dbo.match m WITH(NOLOCK) ON lm.LinkedMatchID = m.matchid
		INNER JOIN match_remark mr WITH (NOLOCK) ON mr.matchid = lm.LinkedMatchID
		ORDER BY matchcode ASC

		DROP TABLE #LinkedMatch_tmp
	END
	ELSE
	BEGIN
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.matchcode, m.leagueid, 0 AS MatchType, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral, m.sporttype, mr.SubType
		FROM dbo.match m WITH (NOLOCK)
		INNER JOIN match_remark mr WITH (NOLOCK) ON  m.matchid = mr.matchid
		WHERE m.matchid = @MatchId
			AND m.eventdate = @EventDate
			AND 1 = CASE WHEN m.sporttype NOT IN (50,8) THEN 1
					WHEN m.sporttype IN (50,8) AND m.ChildMatchType <> 200 THEN 1
				ELSE 0 END
			AND m.sporttype = @Sporttype
		ORDER BY matchcode ASC
	END
	
END
GO

