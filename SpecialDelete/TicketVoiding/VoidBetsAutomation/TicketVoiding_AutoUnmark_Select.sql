/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoUnmark_Select]
(
	@MatchId		VARCHAR(50)		= ''
	,@Sporttype		VARCHAR(100)	= ''
	,@IsExcludeTest BIT				= 1
	,@MarkedBy		INT				= 0
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]
		- 20200226@Max: Confirm Auto Unmark Group By User [Redmine: #129219]
		- 20200302@Max: Hot fix - Order By IsConfirm [Redmine : #129214]
		- 20200226@Max: Auto Void Winning Bets - [Redmine: #129184]
		- 20200313@Max: Support Quarter X, Y, Z on Auto Unmark Page - [Redmine: #130322]
		- 20200320@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200403@Raymond: Auto void for Tennis [Redmind: #131516]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [Redmine: #131670]
		- 20200508@Raymond: Incorporate E-Sports (phase 3) [133121]
		- 20200526@Max: Incorporate E-Sports (phase 3) - Change Group By MarkType [Redmine: #133121]
		
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #MarkedTransaction_tmp(MatchId INT, bettype SMALLINT, UserId INT, MarkedTrans INT, CreateDate DATETIME, MarkType INT, betid BIGINT)

	IF LEN(@MatchId) < 10
	BEGIN
		;WITH CTE_FilterData
		AS (
			SELECT mt.TransId
				,mt.MatchId
				,mt.bettype
				,mt.UserId
				,mt.CreatedDate
				,CASE WHEN mt.MarkType = 2 THEN 2 ELSE 0 END AS MarkType
				,f.IsNameXBettype AS IsCheckBetId
			FROM dbo.MarkedTransaction mt WITH (NOLOCK)
				INNER JOIN dbo.match m WITH (NOLOCK) ON mt.MatchId = m.matchid
				INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				CROSS APPLY (
					SELECT val AS sporttype
					FROM dbo.f_SplitString(@Sporttype, ',')
					WHERE val = m.sporttype
				) AS tmp
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = mt.bettype
			WHERE m.sporttype IN (1, 2 , 9, 43, 5)
				AND ((@IsExcludeTest = 1 AND l.isTest = 0) OR @IsExcludeTest = 0)
				AND ((@MatchId <> '' AND m.matchid = CAST(@MatchId AS INT)) OR @MatchId = '')
				AND ((mt.UserId = @MarkedBy) OR @MarkedBy = 0)
				)
		,CTE_FilterByTicketStatus
		AS (
			SELECT f.TransId
				,f.MatchId
				,f.bettype
				,f.UserId
				,f.CreatedDate
				,f.MarkType
				,CASE WHEN f.IsCheckBetId = 1 AND bm.IsParlay = 1 THEN bm.betcheck
						WHEN f.IsCheckBetId = 1 AND bm.IsParlay IS NULL THEN b.betid 
						ELSE NULL END AS BetId
			FROM CTE_FilterData AS f
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON f.TransId = b.transid	
				OUTER APPLY (
					SELECT TOP 1 m.betcheck
						,1 AS IsParlay
					FROM dbo.bettransm AS m WITH (NOLOCK)
					WHERE m.refno = b.refno
						AND m.statusID NOT IN (101, 102)
						AND b.matchId = 29
				) AS bm
			WHERE 1 = CASE WHEN b.matchid <> 29 AND b.statusID NOT IN (101, 102) THEN 1
							WHEN b.matchid = 29 AND bm.IsParlay = 1 THEN 1 ELSE 0 END
			)
		INSERT INTO #MarkedTransaction_tmp (
			MatchId
			,bettype
			,UserId
			,MarkedTrans
			,CreateDate
			,MarkType
			,betid
			)
		SELECT f.MatchId
			,f.bettype
			,f.UserId
			,COUNT(f.TransId) AS MarkedTrans
			,MAX(f.CreatedDate) AS CreatedDate
			,f.MarkType
			,f.BetId
		FROM CTE_FilterByTicketStatus AS f
		GROUP BY f.MatchId
			,f.bettype
			,f.UserId
			,f.MarkType
			,f.BetId

		-----------------
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
			, m.sporttype
			, CASE WHEN ta_tmp.IsCheck IS NULL OR ta_tmp.IsCheck = 1 THEN 0 --isCheck = 1 --> enable confirm
				   ELSE 1 END AS IsConfirm
			, mt.MarkType
			, mt.betid
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
						AND ISNULL(t.betid, 0) = ISNULL(mt.betid, 0)
					ORDER BY t.CreatedDate DESC
				)ta_tmp		
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = mt.bettype
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = mt.UserId	
		ORDER BY m.kickofftime
			, mt.MatchId
			, mt.MarkType 
			, mt.bettype
			, f.GroupName
			, ISNULL(ta_tmp.IsCheck, 1) DESC
	END
	ELSE RETURN

	DROP TABLE #MarkedTransaction_tmp
END