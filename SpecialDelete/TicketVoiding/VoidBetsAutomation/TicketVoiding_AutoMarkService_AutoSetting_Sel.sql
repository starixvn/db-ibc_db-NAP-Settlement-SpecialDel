/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_AutoMarkService_AutoSetting_Sel]
(
	@MatchId		VARCHAR(50)		= ''
	,@Sporttype		INT
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
	
	CREATE TABLE #match_tmp(matchid INT, sporttype INT, kickofftime DATETIME, homeid INT, awayid INT, hthomescore INT, htawayscore INT, finalhomescore INT, finalawayscore INT)
	
	IF LEN(@MatchId) < 10
	BEGIN
		INSERT INTO #match_tmp (matchid, sporttype, kickofftime, homeid, awayid, hthomescore, htawayscore, finalhomescore, finalawayscore)
		SELECT m.matchid, m.sporttype, m.kickofftime, m.homeid, m.awayid, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore
		FROM dbo.match m WITH (NOLOCK)
			INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
		WHERE ((@IsExcludeTest = 1 AND l.isTest = 0) OR @IsExcludeTest = 0)
			AND ((@MatchId IS NOT NULL AND m.matchid = @MatchId) OR @MatchId IS NULL)
			AND m.sporttype = @Sporttype
			AND m.eventstatus <> 'completed'

		SELECT m.MatchId
			, m.kickofftime
			, m.sporttype
			, m.homeid
			, m.awayid
			, ISNULL(CAST(rdHT.hthomescore AS VARCHAR(10)) + '-' + CAST(rdHT.htawayscore AS VARCHAR(10)), '-') AS 'HTScore'
			, ISNULL(CAST(rdFT.finalhomescore AS VARCHAR(10)) + '-' + CAST(rdFT.finalawayscore AS VARCHAR(10)), '-') AS 'FTScore'
			, mt.MarkedTrans
			, ISNULL(ta.Enabled, 1) AS IsAutoMark
		FROM #match_tmp m
			OUTER APPLY ( 
						SELECT COUNT(1) AS MarkedTrans
						FROM dbo.MarkedTransaction m1 WITH (NOLOCK)
							INNER JOIN dbo.bettrans b WITH (NOLOCK) ON m1.TransId = b.transid 
						WHERE m1.MatchId = m.matchid
							AND b.statusID NOT IN (101, 102)
							AND m1.MarkType = 2
					)mt	
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
			OUTER APPLY (
						SELECT t.Enabled
						FROM dbo.TicketVoiding_AutoMarkService_AutoSetting t WITH (NOLOCK)
						WHERE t.MatchID = m.MatchId
					)ta
		ORDER BY ISNULL(ta.Enabled, 1)
			, m.kickofftime
			, m.MatchId
	END
	ELSE RETURN

	DROP TABLE #match_tmp

END