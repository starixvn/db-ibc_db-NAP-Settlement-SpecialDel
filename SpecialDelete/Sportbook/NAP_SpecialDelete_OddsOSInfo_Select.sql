/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_OddsOSInfo_Select]
(	
	@MatchId INT = 0
	,@BetTypes VARCHAR(2000) = ''
)
AS 
/*	
	Created by: 20220228@Max
	Task: [TVS] Integrate new bet types of Cricket
	DB: DBPRO-bodb02
	
	Revisions:
		- 20220228@Max: Create new SP [Redmine: #168080]
		- 20220804@Max: TVS HotFix Filter Player Cricket [Redmine: #176290]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		- 20221221@July: [TVS] Update message template for Not Participate case [Redmine: #181628]
		
	Param's explanation:		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpBettype AS TABLE (bettype SMALLINT)
	
	INSERT INTO @tmpBettype (bettype)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@BetTypes, ',')
	WHERE value <> ''

	CREATE TABLE #tblOddsOSInfo 
	(
		Oddsid INT,
		BettypeId SMALLINT,
		BetChoice VARCHAR(20),
		PlayerId INT,
		PlayerName NVARCHAR(200),
		PlayNamesChineseTraditional NVARCHAR(200),
		PlayNamesChineseSimplified NVARCHAR(200)
	)
	INSERT INTO #tblOddsOSInfo (Oddsid, BettypeId, BetChoice, PlayerId, PlayerName)
	SELECT DISTINCT CASE WHEN t.bettype IN (9662, 9664, 9666, 9663, 9665, 9667) THEN o.oddsid ELSE NULL END AS oddsid
		, o.bettype AS BettypeId
		, os.betChoice
		, STUFF(os.OddsInfo, CHARINDEX(',', os.OddsInfo), LEN(os.OddsInfo), '') AS PlayerId
		, STUFF(os.OddsInfo, 1, CHARINDEX(',', os.OddsInfo), '') AS PlayerName
	FROM dbo.oddsOS o WITH (NOLOCK)
		INNER JOIN dbo.oddsOS_flex os WITH (NOLOCK) ON os.oddsid = o.oddsid
		INNER JOIN @tmpBettype t ON t.bettype = o.bettype
	WHERE o.matchid = @MatchId
		AND os.OddsInfo <> ''

	UPDATE os
	SET os.PlayNamesChineseTraditional = t.teamnamec_uni,
		os.PlayNamesChineseSimplified = t.teamnamecn
	FROM #tblOddsOSInfo os
		INNER JOIN dbo.team t WITH(NOLOCK) ON os.PlayerId = t.teamid

	SELECT Oddsid, BettypeId, BetChoice, PlayerId, PlayerName, PlayNamesChineseTraditional, PlayNamesChineseSimplified
	FROM #tblOddsOSInfo

	DROP TABLE #tblOddsOSInfo
END

