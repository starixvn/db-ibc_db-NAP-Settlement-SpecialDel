/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RelatedEvent_Select]
(	
	@MatchId		INT
	,@EventDate		DATETIME = NULL
	,@IsMainMatch	BIT = 1
	,@IssueTypeId	TINYINT = NULL
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200828@Charles: Get linked matches of main match [Redmine: #140339]
		- 20200921@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201113@Charles: Danger Accept/Red Card Enhancement - Phase 5 [Redmine: #145102]
		- 20210608@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20211019@July: [TVS] Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20220114@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220221@July: Modify code get fantasy match [Redmine: #164561] 
		- 20220404@Max: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
		- 20220916@July: Change of TVS regarding to Scale out DBTrans - Change config [Redmine: #175412]

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

		SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.matchcode, m.leagueid, 1 AS MatchType, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.ParentID = @MatchId
		UNION ALL
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.matchcode, m.leagueid, 2 AS MatchType, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		FROM #LinkedMatch_tmp lm
		INNER JOIN dbo.match m WITH(NOLOCK) ON lm.LinkedMatchID = m.matchid
		ORDER BY matchcode ASC

		DROP TABLE #LinkedMatch_tmp
	END
	ELSE
	BEGIN
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.matchcode, m.leagueid, 0 AS MatchType, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.matchid = @MatchId
			AND m.eventdate = @EventDate
			AND m.sporttype IN (1)
		ORDER BY matchcode ASC
	END
	
END
GO

