/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_OddsOSInfo_Select]
(	
	@MatchId INT = 0
	,@BetTypes VARCHAR(2000) = ''
)
AS 
/*	
	Created by: Max
	Date 20220228
	Task: [TVS] Integrate new bet types of Cricket
	DB: DBPRO-bodb02
	
	Revisions:
		- 20220228@Max: Create new SP [Redmine: #168080]
		- 20220804@Max: TVS HotFix Filter Player Cricket [Redmine: #176290]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		
	Param's explanation:		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpBettype AS TABLE (bettype SMALLINT)
	
	INSERT INTO @tmpBettype (bettype)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@BetTypes, ',')
	WHERE value <> ''

	SELECT DISTINCT CASE WHEN t.bettype IN (9662, 9664, 9666, 9663, 9665, 9667) THEN o.oddsid ELSE NULL END AS oddsid
		, o.bettype AS BettypeId
		, os.betChoice
		, STUFF(os.OddsInfo, 1, CHARINDEX(',', os.OddsInfo), '') AS PlayerName
		, STUFF(os.OddsInfo, CHARINDEX(',', os.OddsInfo), LEN(os.OddsInfo), '') AS PlayerId
	FROM dbo.oddsOS o WITH (NOLOCK)
		INNER JOIN dbo.oddsOS_flex os WITH (NOLOCK) ON os.oddsid = o.oddsid
		INNER JOIN @tmpBettype t ON t.bettype = o.bettype
	WHERE o.matchid = @MatchId
		AND os.OddsInfo <> ''

END

