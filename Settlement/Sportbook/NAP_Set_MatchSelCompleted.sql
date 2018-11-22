/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelCompleted] 
	@Date DATETIME
	, @SportType 	SMALLINT = 0
	, @LeagueID 	INT = 0-- 0 for ALL Leagues   
	, @isReLoad 	BIT = 0
	, @IsManualSettlementOnly BIT = 0
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
		, SettlementStatus TINYINT, AutoSetting TINYINT, AutoSetting_League TINYINT, ConfirmFT INT)
	
	DECLARE @Matchid_tmp INT = 1, @n INT = 2147483647
	
	DECLARE @BettypeFGLG TABLE  (bettype SMALLINT, GroupID SMALLINT)
	
	DECLARE @BetStatus TABLE (matchid INT, betcount BIGINT,cntFGLG INT,cntHTFGLG INT )
	
	DECLARE @SqlQuery VARCHAR(4000)
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
		AND (m.kickofftime < DATEADD(s, - 6000, GETDATE()) OR mr.ConfirmFT > 0)
		AND 1 = CASE WHEN ''''' + CONVERT(VARCHAR(10), @IsManualSettlementOnly) + ''''' = 0 THEN 1
				ELSE CASE WHEN m.AutoSetting IS NULL AND (1 & ISNULL(l.AutoSetting, 0) = 1) THEN 0
							WHEN (1 & ISNULL(m.AutoSetting, 0) = 1) THEN 0
						ELSE 1 END
				END'')'

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

	INSERT INTO @BettypeFGLG (bettype,GroupID)
	SELECT BetType,GroupID
	FROM dbo.f_Set_GetGroupBettypes()
	WHERE IsFGLG = 1
	
	;WITH Match_cte AS (
		SELECT 
			 m.matchid
			, tmp.bettype
			, tmp.betcount
			, tmp.winlostdate
		FROM (SELECT TOP (@n) matchid FROM @DataTmp ) m 
			CROSS APPLY (SELECT 
								TOP (2147483647) -- It's used for performance tuning, make sure estimated of rows always: 10%
								b.matchid, b.bettype,b.winlostdate, COUNT_BIG(1) as betcount 
						FROM dbo.bettrans b WITH (NOLOCK, INDEX = CIX_matchid_bettype) 
						WHERE b.matchid = m.matchid * @Matchid_tmp -- It's used for performance tuning, make sure estimated of rows always: 10%
								AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238)
								AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
								AND b.bettype NOT BETWEEN 901 AND 910
								AND b.bettype NOT BETWEEN 911 AND 920--cashout tickets
								AND b.bettype <> 500 -- Charged commission
								AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
						GROUP BY  b.matchid	, b.bettype,b.winlostdate
					) AS tmp
	)
	INSERT INTO @BetStatus (matchid,betcount,cntFGLG,cntHTFGLG)
	SELECT b.matchid
		, SUM(betcount) AS betcount
		, SUM(CASE WHEN GroupID IN (2,4) THEN 1 ELSE 0 END) AS cntFGLG
		, SUM(CASE WHEN GroupID IN (1,3) THEN 1 ELSE 0 END) AS cntHTFGLG
	FROM Match_cte b  
		LEFT JOIN @BettypeFGLG fglg ON fglg.bettype = b.bettype
	WHERE  winlostdate = @Date
	GROUP BY b.matchid
	OPTION (OPTIMIZE FOR (@n = 1))	
	
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
		, CASE WHEN b.cntFGLG = 0 THEN 0 ELSE 1 END AS isExistFGLG
		, CASE WHEN b.cntHTFGLG = 0 THEN 0 ELSE 1 END AS isExistHTFGLG
		, b.BetCount
		, t.seqS AS IsCalculatingSingle
		, ISNULL(m.AutoSetting, ISNULL(m.AutoSetting_League, 0)) AS AutoSetting
	FROM @DataTmp m
		INNER JOIN @BetStatus b ON m.matchid = b.matchid
		LEFT JOIN CustDB.dbo.custinfo ht WITH (NOLOCK) ON m.ConfirmHT > 0 AND m.ConfirmHT = ht.custid
		LEFT JOIN CustDB.dbo.custinfo ft WITH (NOLOCK) ON m.ConfirmFT > 0 AND m.ConfirmFT = ft.custid
		LEFT JOIN @tblSingle t ON t.matchid = m.matchid
	ORDER BY m.eventstatus, m.matchcode

	-- Get TENNIS, BASKETBALL RESULT 
	SELECT	MatchId
			, ResourceId
			, HomeValue
			, AwayValue
			, ResultStatusID
			, SettlementStatusID
	FROM	DBPRO.BODB02.dbo.ResultDetail rs WITH (NOLOCK) 
	WHERE	@Sporttype IN (0, 2, 5)
			AND EXISTS (SELECT TOP 1 1 FROM @DataTmp m WHERE rs.MatchId = m.MatchId)
			AND (ResourceId LIKE '0[0-5]' -- Tennis
				OR ResourceId LIKE 'Q[1-4]' OR ResourceId = 'OT' -- Basketball: 00, 01, Q1, Q2, Q3, Q4, OT
			)
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_MatchSelCompleted] TO [bodbAdminNet]
GO
