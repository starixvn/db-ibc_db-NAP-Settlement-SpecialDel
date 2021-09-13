/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelCompleted] 
	@Date DATETIME
	, @SportType 	SMALLINT = 0
	, @LeagueID 	INT = 0-- 0 for ALL Leagues   
	, @isReLoad 	BIT = 0
	, @IsManualSettlementOnly BIT = 0
	, @IsIncludeTest BIT = 0
AS
/*
	Created by: Kathy
	Date: 
	Task: List FT-completed matches for billing
	DB: DBTXN.BODB02
	Original: Acc_Set_MatchSelCompleted

	Revisions:
		- 20140421@Kathy: get match status in queue
		- 20140428@Kathy: get 1H FGLG ticket info [Redmine:#14449]
		- 20140701@Viet: change goalrecord to varchar(50), matchcode to nvarchar(50)
		- 20140905@Kathy: exclude virtual racing bettype 1231,1232,1233
		- 20140907@Viet: change back left join to inner join
		- 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33),
						 sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
		- 20141008@Jamie: Sportting Solution settlement [Redmine: #23034]
		- 20150422@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212
		- 20150602@Jamie: DisplayCat = 8 ExtraTime 
		- 20150611@Jamie: Remove the contrainst  DisplayCat = 8 ExtraTime 
		- 20150811@Johnson: Exclude bettrade tickets from sportbook [Redmine: 35921]
		- 20150729@Johnson: Exclude Metric Gaming in settlement's sportbook [Redmine: #37688]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160201@Kathy: Exclude tickets of Charge Commission (bettypeid=500) [Redmine:#49727]
		- 20160314@Patrick: Add more filter to support auto-payout [Redmine: #53262]
		- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
		- 20161013@Bobby: #65002 - Update changes for Instant Calculation 
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170316@Bobby: Integrate CashOut bettypes [Redmine:#73404]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180426@Helen: Improve Performance [Redmine:89132]
		- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190610@Kathy: Exclude checking running BetBuilder tickets [Redmine:#114877]
		- 20200225@Sol: Direct Settlement Action for Soccer - [Redmine:#103568]
		- 20200227@Sol: Show Result of SBO on Main Calculate & Main Popup for Soccer - [Redmine:#129780]
		- 20200505@Kathy: Add New Filter Option allowing user to exclude/include test matches [Redmine:#133518]
		- 20200619@Kathy: Duplicate transid on table MarkedTransaction [Redmine:#136146]
		- 20200827@Louisa: Get external score [Redmine:#139979]
		- 20201211@Louisa: remove unused code [Redmine:#146239]
		- 20210310@Kathy: Show Unconfirmed FT Match after KO 30 minutes [Redmine:#147230]
		- 20210205@Louisa: Cricket AIO [Redmine:#148870]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210906@Louisa: Get configuration from table SettlementResultTableSetting [Redmine:#160478]

	Param explanation: 
		@isReLoad: 1: reload partial matches of a league, 0: not reload
*/
BEGIN
	SET NOCOUNT ON
	SELECT @LeagueID = CASE WHEN @isReLoad = 1 THEN ISNULL(@LeagueID, 0)
						ELSE 0 END -- reload partial; search on LeagueID, not reload: get all leagues

	DECLARE @DataTmp TABLE (MatchId INT PRIMARY KEY, leagueid INT, hthomescore INT, htawayscore INT, IsCalculated BIT
		, IsMultiCaled BIT, IsRefund BIT, IsCalRefund BIT, homeid INT, awayid INT, matchcode VARCHAR(50)
		, kickofftime DATETIME, finalhomescore INT, finalawayscore INT, betstatus NVARCHAR(50), eventstatus VARCHAR(50)
		, sporttype SMALLINT, IsNeutral BIT, eventdate DATETIME, goalrecord VARCHAR(50), ConfirmHT INT, IsHTCal BIT
		, SettlementStatus TINYINT, AutoSetting TINYINT, AutoSetting_League TINYINT, ConfirmFT INT, IsExistRunningTicket BIT, IsExistMarkedTicket BIT
		, IsExistingSingle BIT DEFAULT(0), IsExistingParlay BIT DEFAULT(0)
	)
	
	DECLARE @Matchid_tmp INT = 1, @n INT = 2147483647
			, @IsMergedParlay BIT = 0
	
	DECLARE @BettypeFGLG TABLE  (bettype SMALLINT, GroupID SMALLINT)
	
	DECLARE @BetStatus TABLE (matchid INT, betcount BIGINT,cntFGLG INT,cntHTFGLG INT)
	
	DECLARE @SqlQuery VARCHAR(4000)
	
	SELECT	@IsMergedParlay = IsMergedParlay 
	FROM	dbo.SettlementResultTableSetting ss WITH(NOLOCK)
	WHERE ss.Sporttype = @SportType
	
	SET @SqlQuery = ''
	SELECT @SqlQuery = '
	
	SELECT *
	FROM OPENQUERY(DBPRO, ''SELECT m.MatchId, m.leagueid, m.hthomescore, m.htawayscore, mr.calculate
		, mr.multiple, refund, CalRefund, homeid, awayid, matchcode
		, kickofftime, finalhomescore, finalawayscore, betstatus, eventstatus
		, m.sporttype, m.IsNeutral, eventdate, goalrecord, ConfirmHT, IsHTCal
		, m.SettlementStatus, m.AutoSetting, l.AutoSetting AS AutoSetting_League, ConfirmFT
	FROM bodb02.dbo.match m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE m.eventdate = ''''' + CONVERT(VARCHAR(12), @Date, 112) + '''''
		AND m.leagueID = CASE WHEN ''''' + CONVERT(VARCHAR(50), @LeagueID) + ''''' <> 0 THEN ''''' + CONVERT(VARCHAR(50), @LeagueID) + ''''' ELSE m.leagueID END
		AND m.sporttype = CASE WHEN ''''' + CONVERT(VARCHAR(50), @sporttype) + ''''' <> 0 THEN ''''' + CONVERT(VARCHAR(50), @sporttype) + ''''' ELSE m.sporttype END
		AND m.eventstatus <> ''''Completed''''
		AND (m.kickofftime < CASE 
								WHEN ISNULL(l.LeagueGroupID,0) NOT IN (42,74,108) THEN DATEADD(s, - 6000, GETDATE())
								ELSE DATEADD(s, -1800, GETDATE())
							END
				OR mr.ConfirmFT > 0) 
		AND 1 = CASE WHEN ''''' + CONVERT(VARCHAR(10), @IsManualSettlementOnly) + ''''' = 0 THEN 1
				ELSE CASE WHEN m.AutoSetting IS NULL AND (17 & ISNULL(l.AutoSetting, 0) IN (1,16)) THEN 0
							WHEN (17 & ISNULL(m.AutoSetting, 0) IN (1,16)) THEN 0
						ELSE 1 END
				END
		AND l.isTest = CASE WHEN ' + CONVERT(VARCHAR(50),@IsIncludeTest) + ' = 0 THEN 0 ELSE l.isTest END
		AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END''
		
		)'

	INSERT INTO @DataTmp(MatchId, leagueid, hthomescore, htawayscore, IsCalculated
		, IsMultiCaled, IsRefund, IsCalRefund, homeid, awayid, matchcode
		, kickofftime, finalhomescore, finalawayscore, betstatus, eventstatus
		, sporttype, IsNeutral, eventdate, goalrecord, ConfirmHT, IsHTCal
		, SettlementStatus, AutoSetting, AutoSetting_League, ConfirmFT)
	EXEC (@SqlQuery)

	DECLARE @tblSingle TABLE (matchid INT, seqS INT)
	INSERT INTO @tblSingle
	SELECT matchid, MAX(IsCalculating)
	FROM dbo.Single_Calculate_Queue WITH (NOLOCK)
	WHERE Starttime > DATEADD(HH, - 1, GETDATE()) 
		AND IsCalculating IN (1, 0)
	GROUP BY matchid

	CREATE TABLE #tmpAllParentChildMatch (MatchId INT, ParentId INT)
	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId)
	SELECT	m.matchid, m.ParentId
	FROM	@DataTmp t
		CROSS APPLY (
			SELECT	m.matchid, m.ParentId
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.sporttype = 50
					AND m.ChildMatchType = 200
					AND m.ParentID = t.matchid
		)m
	UNION ALL
	SELECT m.matchid, m.matchid FROM @DataTmp m

	INSERT INTO @BettypeFGLG (bettype,GroupID)
	SELECT BetType,GroupID
	FROM dbo.f_Set_GetGroupBettypes()
	WHERE IsFGLG = 1
	
	;WITH Match_cte AS (
		SELECT 
			 m.matchid
			, m.ParentId
			, tmp.bettype
			, tmp.betcount
			, CASE WHEN m.Matchid <> m.ParentId THEN @Date ELSE tmp.winlostdate END AS winlostdate
		FROM (SELECT TOP (@n) matchid, ParentId FROM #tmpAllParentChildMatch ) m 
			CROSS APPLY (SELECT 
								TOP (2147483647) -- It's used for performance tuning, make sure estimated of rows always: 10%
								b.matchid, b.bettype,b.winlostdate, COUNT_BIG(1) as betcount
						FROM dbo.bettrans b WITH (NOLOCK, INDEX = CIX_matchid_bettype) 
						WHERE b.matchid = m.matchid * @Matchid_tmp -- It's used for performance tuning, make sure estimated of rows always: 10%
								AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238, 38)
								AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
								AND b.bettype NOT BETWEEN 901 AND 910
								AND b.bettype NOT BETWEEN 911 AND 920--cashout tickets
								AND b.bettype <> 500 -- Charged commission
								AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
						GROUP BY  b.matchid	, b.bettype,b.winlostdate
					) AS tmp

	)
	INSERT INTO @BetStatus (matchid,betcount,cntFGLG,cntHTFGLG)
	SELECT b.ParentId
		, SUM(betcount) AS betcount
		, SUM(CASE WHEN GroupID IN (2,4) THEN 1 ELSE 0 END) AS cntFGLG
		, SUM(CASE WHEN GroupID IN (1,3) THEN 1 ELSE 0 END) AS cntHTFGLG
	FROM Match_cte b  
		LEFT JOIN @BettypeFGLG fglg ON fglg.bettype = b.bettype
	WHERE winlostdate  = @Date
	GROUP BY b.ParentId
	OPTION (OPTIMIZE FOR (@n = 1))	

	IF @IsMergedParlay = 1
	BEGIN
		MERGE	@BetStatus AS TARGET
		USING (
			SELECT t.ParentId, COUNT(1) parlaycount
			FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN #tmpAllParentChildMatch t
					ON bm.matchid = t.MatchId
			GROUP BY t.ParentId
		) AS SOURCE
			ON TARGET.MatchId = SOURCE.ParentId
		WHEN MATCHED THEN UPDATE SET betcount = TARGET.betcount + SOURCE.parlaycount
		WHEN NOT MATCHED BY TARGET THEN 
			INSERT (matchid,betcount,cntFGLG,cntHTFGLG) VALUES (SOURCE.ParentId, SOURCE.parlaycount, 0, 0);	
	END

	UPDATE m
		SET IsExistingSingle = 1
	FROM	@DataTmp m
		INNER JOIN @BetStatus b
			ON m.MatchId = b.matchid

	UPDATE m 
		SET IsExistingParlay = 1
	FROM	@DataTmp m
	WHERE EXISTS (SELECT TOP 1 1 FROM dbo.bettransm bm WITH(NOLOCK) WHERE bm.matchid = m.MatchId AND bm.statusID <> 101)

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, mt.matchid
	FROM	@DataTmp m
		CROSS APPLY (
			SELECT	mt.TransId, mt.MatchId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt
	WHERE m.sporttype <> 50

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = CASE WHEN m.HasMarkedSingle + m.HasMarkedParlay > 0 THEN 1 ELSE 0 END
		FROM	@tmpMatchMarked mk
			INNER JOIN (
				SELECT	mt.matchId
						,CASE WHEN MIN(ISNULL(bm.IsParlay,0)) = 0 THEN 1 ELSE 0 END AS HasMarkedSingle
						,CASE WHEN MAX(ISNULL(bm.IsParlay,0)) = 1 THEN 1 ELSE 0 END AS HasMarkedParlay
				FROM	#tmpMarkedTransaction mt
					CROSS APPLY (
						SELECT	TOP (1) b.transid, b.refno, b.matchid, b.statusID
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	mt.transid = b.transid
					) b
					OUTER APPLY (
						SELECT TOP 1 1 IsParlay
						FROM	dbo.bettransm bm WITH(NOLOCK)
						WHERE	bm.refno = b.refno
								AND bm.statusid = 0
								AND b.matchid = 29
								AND bm.matchid = mt.matchId
								AND @IsMergedParlay = 1
					)bm
				WHERE	1 = CASE
								WHEN b.matchid <> 29 AND b.statusID = 0 THEN 1
								WHEN b.matchid = 29 AND bm.IsParlay = 1 THEN 1
								ELSE 0
							END
				GROUP BY mt.matchid
			) m
				ON m.matchid = mk.MatchId

		UPDATE m 
			SET IsExistMarkedTicket = t.IsExistMarkedTicket
		FROM	@DataTmp m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId

	END

	SELECT m.matchid
		, m.leagueid
		, hthomescore AS HalfTimeHomeScore
		, htawayscore AS HalfTimeAwayScore
		, ISNULL(m.IsCalculated, 0) AS IsCalculated
		, ISNULL(m.IsMultiCaled, 0) AS IsMultiCaled
		, ISNULL(m.IsRefund, 0) AS IsRefund
		, ISNULL(m.IsCalRefund, 0) AS IsCalRefund
		, m.homeid
		, m.awayid
		, m.matchcode
		, m.kickofftime
		, m.finalhomescore
		, m.finalawayscore
		, m.betstatus
		, m.eventstatus
		, m.sporttype
		, ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		, m.eventdate
		, m.goalrecord
		, ISNULL(ht.username, '') AS suspenderHalfTime
		, ISNULL(ft.username, '') AS suspenderFullTime
		, ISNULL(m.IsHTCal, 0) AS IsHalfTimeCal
		, m.SettlementStatus
		, CASE WHEN ISNULL(b.cntFGLG,0) = 0 THEN 0 ELSE 1 END AS isExistFGLG
		, CASE WHEN ISNULL(b.cntHTFGLG,0) = 0 THEN 0 ELSE 1 END AS isExistHTFGLG
		, ISNULL(b.BetCount,0) AS BetCount
		, t.seqS AS IsCalculatingSingle
		, ISNULL(m.AutoSetting, ISNULL(m.AutoSetting_League, 0)) AS AutoSetting
		, m.IsExistRunningTicket
		, m.IsExistMarkedTicket
	FROM @DataTmp m
		LEFT JOIN @BetStatus b ON m.matchid = b.matchid
		LEFT JOIN CustDB.dbo.custinfo ht WITH (NOLOCK) ON m.ConfirmHT > 0 AND m.ConfirmHT = ht.custid
		LEFT JOIN CustDB.dbo.custinfo ft WITH (NOLOCK) ON m.ConfirmFT > 0 AND m.ConfirmFT = ft.custid
		LEFT JOIN @tblSingle t ON t.matchid = m.matchid
	WHERE	m.IsExistingSingle > 0
		OR m.IsExistingParlay > 0
	ORDER BY m.eventstatus, m.matchcode

	DECLARE @matchidList VARCHAR(MAX) = ''
	    
	SELECT @matchidList =  @matchidList + ',' + CAST(matchid AS VARCHAR(20))
	FROM @DataTmp
	SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))
	    
	EXEC DBPRO.bodb02.dbo.NAP_Set_ResultDetailSel
		@matchidList = @matchidList
  
	
END
GO