/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_AutoMarkService_AutoSetting_Sel]
(
	@MatchId		INT				= NULL
	,@Sporttype		VARCHAR(100)	= ''
	,@IsExcludeTest BIT				= 1
)
AS
/*	Created by: Max
	Date 20200228
	Task: Auto Void Winning Bets [Redmine: #129184]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200228@Max: Create new SP [Redmine: #129184]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT mt.MatchId
		, m.kickofftime
		, m.sporttype
		, m.homeid
		, m.awayid
		, ISNULL(CAST(rdHT.hthomescore AS VARCHAR(10)) + '-' + CAST(rdHT.htawayscore AS VARCHAR(10)), '-') AS 'HTScore'
		, ISNULL(CAST(rdFT.finalhomescore AS VARCHAR(10)) + '-' + CAST(rdFT.finalawayscore AS VARCHAR(10)), '-') AS 'FTScore'
		, COUNT(mt.TransId) AS MarkedTrans
		, ISNULL(ta.Enabled, 1) AS IsAutoMark
	FROM dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN dbo.match m WITH (NOLOCK) ON mt.MatchId = m.matchid
		INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON mt.TransId = b.transid
		OUTER APPLY (
							SELECT TOP 1 m.hthomescore, m.htawayscore
							FROM dbo.match_remark mr WITH (NOLOCK)
							WHERE IsHTCal = 1 
								AND mr.matchid = m.matchid			
						)rdHT
		OUTER APPLY (
					SELECT TOP 1 m.finalhomescore, m.finalawayscore
					FROM dbo.match_remark mr WITH (NOLOCK)
					WHERE mr.calculate = 1 
						AND mr.matchid = m.matchid			
				)rdFT
		CROSS APPLY (SELECT val AS sporttype
						FROM dbo.f_SplitString(@Sporttype, ',')
						WHERE val = m.sporttype
					) AS tmp
		OUTER APPLY (
					SELECT t.Enabled
					FROM dbo.TicketVoiding_AutoMarkService_AutoSetting t WITH (NOLOCK)
					WHERE t.MatchID = mt.MatchId
				)ta
	WHERE tmp.sporttype IN (1, 2, 9 ,43)
		AND b.statusID NOT IN (101, 102)
		--AND mt.MarkType = 2
		AND ((@IsExcludeTest = 1 AND l.isTest = 0) OR @IsExcludeTest = 0)
		AND ((@MatchId IS NOT NULL AND m.matchid = @MatchId) OR @MatchId IS NULL)
		AND m.eventstatus <> 'completed'
	GROUP BY mt.MatchId
		, m.kickofftime
		, m.homeid
		, m.awayid
		, rdHT.hthomescore
		, rdHT.htawayscore
		, rdFT.finalhomescore
		, rdFT.finalawayscore
		, m.sporttype
		, ta.Enabled
	ORDER BY m.kickofftime
		, mt.MatchId

END