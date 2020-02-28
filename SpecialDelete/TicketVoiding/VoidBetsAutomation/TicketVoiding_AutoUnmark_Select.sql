/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoUnmark_Select]
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]
		- 20200226@Max: Confirm Auto Unmark Group By User [Redmine: #129219]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	SET NOCOUNT ON
	CREATE TABLE #MarkedTransaction_tmp(MatchId INT, bettype SMALLINT, UserId INT, MarkedTrans INT, CreateDate DATETIME)
	INSERT INTO #MarkedTransaction_tmp(MatchId, bettype, UserId, MarkedTrans, CreateDate)
	SELECT mt.MatchId
		, mt.bettype
		, mt.UserId
		, COUNT(mt.TransId) AS MarkedTrans
		, MAX(mt.CreatedDate) AS CreatedDate
	FROM dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN dbo.match m WITH (NOLOCK) ON mt.MatchId = m.matchid
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON mt.TransId = b.transid
	WHERE m.sporttype IN (1)
		AND b.statusID NOT IN (101, 102)
	GROUP BY mt.MatchId
		, mt.bettype
		, mt.UserId
	

	SELECT mt.MatchId
		, m.kickofftime
		, m.homeid
		, m.awayid
		, ISNULL(CAST(rdHT.hthomescore AS VARCHAR(10)) + '-' + CAST(rdHT.htawayscore AS VARCHAR(10)), '-') AS 'HTScore'
		, ISNULL(CAST(rdFT.finalhomescore AS VARCHAR(10)) + '-' + CAST(rdFT.finalawayscore AS VARCHAR(10)), '-') AS 'FTScore'
		, mt.bettype
		, mt.MarkedTrans
		, mt.UserId
		, c.username AS MarkedBy
		, CASE WHEN ta_tmp.IsCheck IS NULL OR ta_tmp.IsCheck = 1 THEN 0
			   ELSE 1 END AS IsConfirm
	FROM #MarkedTransaction_tmp mt WITH (NOLOCK)
		INNER JOIN dbo.match m WITH (NOLOCK) ON mt.MatchId = m.matchid
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
				SELECT TOP 1 CASE WHEN  mt.CreateDate > t.CreatedDate THEN 1
								ELSE 0 
							END AS IsCheck
				FROM TicketVoiding_AutoUnmarkSetting t WITH (NOLOCK)
				WHERE t.Matchid = mt.MatchId
					AND t.Bettype = mt.bettype
					AND t.MarkedBy = mt.UserId
				ORDER BY t.CreatedDate DESC
			)ta_tmp		
		INNER JOIN f_Set_GetGroupBettypes() f ON f.BetType = mt.bettype
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = mt.UserId
	ORDER BY m.kickofftime
		, mt.MatchId
		, mt.bettype
		, f.GroupName
		, ta_tmp.IsCheck

	DROP TABLE #MarkedTransaction_tmp

END