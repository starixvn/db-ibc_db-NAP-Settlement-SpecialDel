/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoUnmark_Select]
(
	@TransInfoJson		VARCHAR(MAX) = NULL
)
AS
/*	Created by: 20200212@Max
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBCTG/bodb02
	
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
		- 20200608@Charles: Auto Void for remaining sports [Redmine: #131865]
		- 20200729@Zane: Basketball AIO Phase 2 - Fix error when show tickets [Redmine: #137189]
		- 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20211125@July: Change length match [Redmine: #161337]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220628@Max: Confirm Auto Unmark - Auto unmark select Error converting data type nvarchar to bigint [Redmine: #172277]
		- 20220831@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]

	Param's explanation:	
		@TransInfo: <root><r mid="0" t="1" btype ="" us="" crdate="" mt="" bid=""/></root>
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #MarkedTransaction_tmp(MatchId INT, bettype SMALLINT, UserId INT, MarkedTrans INT, CreateDate DATETIME, MarkType INT, betid NVARCHAR(100))
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT 
	  ,bettype SMALLINT
	  ,UserId INT
	  ,CreatedDate DATETIME
	  ,MarkType INT
	  ,betid NVARCHAR(100)
	)
	INSERT INTO #tmpTransInfo( 
		    matchid 
	       ,transid
		   ,bettype
		   ,UserId
		   ,CreatedDate
		   ,MarkType
		   ,betid
	)
	SELECT mid, t, btype, us, crdate, mt, bid
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid, t, btype, us, crdate, mt, CASE WHEN bid = '' THEN NULL ELSE bid END bid
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, btype SMALLINT, us INT, crdate DATETIME, mt INT, bid NVARCHAR(100))
		) tbl
	WHERE f.value <> ''

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
	FROM #tmpTransInfo AS f
	GROUP BY f.MatchId
		,f.bettype
		,f.UserId
		,f.MarkType
		,f.BetId

	SELECT CASE WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID ELSE mt.MatchId END AS MatchId
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
		, CASE WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN mt.MatchId ELSE NULL END AS ChildMatchId 
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
				SELECT TOP 1 CASE WHEN  mt.CreateDate > t.CreatedDate THEN 1 ELSE 0 END AS IsCheck
				FROM TicketVoiding_AutoUnmarkSetting t WITH (NOLOCK)
				WHERE t.Matchid = CASE WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID ELSE mt.MatchId END
					AND t.Bettype = mt.bettype
					AND t.MarkedBy = mt.UserId
					AND CONVERT(NVARCHAR(100),ISNULL(t.betid, 0)) = ISNULL(mt.betid, 0)
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

	DROP TABLE #MarkedTransaction_tmp
	DROP TABLE #tmpTransInfo
END