/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_ScheduleSel] 
AS
/*	Creator: 20160303@Patrick
	Task: Get list matches use for auto-pay-out service
	DB: DBPRO/BODB02
	
	Revisions:
		- 20161019@Bobby: @#65002 - Add checking AutoSetting on match & league
		- 20170314@Kathy: Not allow to process Auto Payout HT/FT if keyscore calculated HT/FT manually [Redmine:#73218]
		- 20170817@Kathy: Get LeagueId [Redmine:#80704]
		- 20181002@Kathy: get SettlementStatus [Redmine:#102028]
		- 20181205@Vicky: Add New Undecided Option for MTD team [Redmine:#104948]
		- 20190704@Sol: Auto payout phase 3 - Modify returned fields [Redmine:#116073]
		- 20200225@Sol: Direct Settlement Action for Soccer - [Redmine:#103568]
		- 20200412@Sol: Allow User to Set Timeout for Direct Settlement - [Redmine:#132138]
		- 20200723@Kathy: Exclude ET and PEN matches [Redmine:#136350]
		- 20200915@Kathy: Exclude HT score of SABA Soccer match from the Auto Payout's Direct Settlement flow [Redmine:#141340]
		- 20210116@Louisa: Exclude HT score of SABA Soccer LeagueGroupID 108 [Redmine:#145597]
		- 20210912@Helen: fix score NULL [Redmine:#161472]
		- 20220512@Kathy: Improve performance [Redmine:#172386]
		- 20220520@Louisa: Direct Settlement for HT & FT on Some Saba Virtual Soccer Leagues [Redmine:#172907]
		- 20220613@Louisa: Auto Payout for matches TOTAL CORNER & TOTAL GOAL [Redmine:#171261]
		- 20220929@Louisa: check deployment flag [Redmine:#178765]
		- 20230616@Aries: Support Direct Payout for Soccer Fantasy Matches [Redmine:#189493]
		- 20240115@Aries: Apply Direct Payout Corner Winner [Redmine:#198823]
		- 20240502@Louisa: Direct for new league SABA [Redmine:#204369]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@currentdate	DATETIME
			,@fromdate		DATETIME
			,@todate		DATETIME
			,@checktime		DATETIME
			,@procName		SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT = 0

	SET @currentdate = CAST(GETDATE() AS DATE)
	SELECT	@fromdate = DATEADD(DAY,-1,@currentdate)
			,@todate = DATEADD(DAY,1,@currentdate)
			,@checktime = DATEADD(HOUR, 3, GETDATE())

	DECLARE @tmpMatchAuto TABLE(
									MatchId INT, HtHomescore INT, FinalHomescore INT, HtAwayscore INT, FinalAwayscore INT, TypeId TINYINT, 
									IsHalfTimeConfirmed INT, IsFullTimeConfirmed INT, BetStatus NVARCHAR(50), GoalRecord VARCHAR(50), 
									IsHalfTimeCalculated BIT, leagueid INT, LeagueGroupID SMALLINT, ChildMatchType TINYINT, SettlementStatus TINYINT, 
									AutoSetting TINYINT, ChildLeagueType INT, MainType TINYINT, SubType SMALLINT
								)

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, TypeId, IsHalfTimeConfirmed
			, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, leagueid, LeagueGroupID, ChildMatchType, SettlementStatus
			, AutoSetting, ChildLeagueType, MainType, SubType
		FROM @tmpMatchAuto

		RETURN
	END
	

	INSERT INTO @tmpMatchAuto (
								MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, TypeId, IsHalfTimeConfirmed
								, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, leagueid, LeagueGroupID, ChildMatchType, SettlementStatus
								, AutoSetting, ChildLeagueType, MainType, SubType
							)
	SELECT MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, TypeId, IsHalfTimeConfirmed
		, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, t.leagueid, t.LeagueGroupID, t.ChildMatchType, t.SettlementStatus
		, AutoSetting, ChildLeagueType, MainType, SubType
	FROM (
			SELECT m.matchid AS MatchId
				, m.hthomescore
				, m.finalhomescore
				, m.htawayscore
				, m.finalawayscore
				, f.TypeId
				, CASE WHEN f.TypeId = 1 THEN mr.ConfirmHT
						WHEN f.TypeId = 2 THEN mr.ConfirmFT
						ELSE 0 END AS IsConfirmed
				, mr.ConfirmHT AS IsHalfTimeConfirmed
				, mr.ConfirmFT AS IsFullTimeConfirmed
				, m.betstatus AS BetStatus
				, m.GoalRecord
				, mr.IsHTCal AS IsHalfTimeCalculated
				, m.kickofftime
				, l.leagueid
				, l.LeagueGroupID
				, ISNULL(m.ChildMatchType,0) AS ChildMatchType
				, m.SettlementStatus
				, ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AS AutoSetting
				, ls.ChildLeagueType
				, mr.MainType
				, mr.SubType
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN dbo.match_remark mr WITH(NOLOCK)
					ON	m.matchid = mr.matchid
				INNER JOIN dbo.League l WITH(NOLOCK) 
					ON	m.leagueid = l.leagueid
				CROSS APPLY (
					SELECT f.TypeId
					FROM (VALUES (1),(2)) AS f(TypeId)
				) f
				OUTER APPLY (	
						SELECT TOP 1 ls.ChildLeagueType 
						FROM dbo.LeagueSetting ls WITH(NOLOCK)
						WHERE l.LeagueId = ls.Leagueid
				) ls
				OUTER APPLY (
					SELECT TOP 1 1 AS IsExistAP 
					FROM	dbo.AutoPayoutResult rs WITH(NOLOCK) 
					WHERE	rs.MatchId = m.matchid 
							AND f.TypeId = rs.CalculationType 
							AND rs.StatusId IN (1, 2, 3)
				)rs
				OUTER APPLY (
					SELECT	TOP 1 1 AS IsExistResultDetail
					FROM	dbo.ResultDetail r WITH(NOLOCK)
					WHERE	r.MatchId = m.matchid
							AND 1 = CASE 
										WHEN r.ResourceId = '00' AND f.TypeId = 2 THEN 1
										WHEN r.ResourceId = '01' AND f.TypeId = 1 THEN 1
										ELSE 0
									END
							AND r.ResultStatusID = 5 -- completed (manual)
				)r
			WHERE	m.eventstatus = 'running' 
					AND m.sporttype = 1
					AND m.eventdate BETWEEN @fromdate AND @todate 
					AND GlobalShowTime <= @checktime
					AND ISNULL(m.ChildMatchType,0) <> 201
					AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) IN ( 202, 203 ) THEN CASE WHEN ISNULL(l.LeagueGroupID,0) IN ( 42, 74 ) AND l.leagueid IN (95730,95731,96666) AND f.TypeId = 2 THEN 1
																						   ELSE 0
																						   END								 
								 WHEN ISNULL(l.LeagueGroupID,0) IN ( 42, 74, 108) THEN CASE WHEN f.TypeId = 2 THEN 1
																							WHEN l.leagueid IN (95730,95731,96666,135822) AND f.TypeId = 1 THEN 1
																							ELSE 0
								  															END
								 WHEN (mr.SubType BETWEEN 2101 AND 2199 OR mr.SubType BETWEEN 2601 AND 2699) THEN IIF(f.TypeId = 2,1,0)  -- Child-match Next Corner
								 WHEN l.leagueid IN (16371,65550,89611)	  THEN 0 -- Exclude Fantasy Match
								 ELSE 1
								 END

					AND (mr.ConfirmHT > 0 OR mr.ConfirmFT > 0)
					AND 1 = CASE WHEN mr.ConfirmHT > 0 AND (m.hthomescore IS NULL OR m.htawayscore IS NULL) THEN 0
								 WHEN mr.ConfirmFT > 0 AND (m.finalhomescore IS NULL OR m.finalawayscore IS NULL) THEN 0
								 ELSE 1
							END
					AND 17 & ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) IN (1, 16)
					AND rs.IsExistAP IS NULL
					AND r.IsExistResultDetail IS NULL
	)t
	WHERE	IsConfirmed > 0
	ORDER BY t.kickofftime, t.MatchId, t.TypeId

	--TEMPORARY: Insert score into ProviderResultDetail for SourceId = 101 - Direct Autopayout
	DECLARE @currTime DATETIME = GETDATE()

	-- Return data 
	SELECT t.MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, t.TypeId, IsHalfTimeConfirmed
			, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, t.leagueid, t.LeagueGroupID, t.ChildMatchType, t.SettlementStatus
			, AutoSetting, ChildLeagueType, MainType, SubType
	FROM @tmpMatchAuto t
		LEFT JOIN ProviderResultDetail p 
			ON t.MatchId = p.MatchId AND t.TypeId = p.TypeId 
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime
			FROM	dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = t.leagueid
					AND ss.AutoType = 5 -- Direct Auto Payout
		) ss
	WHERE 1 = CASE WHEN p.ProviderResultDetailId IS NOT NULL AND 16 & ISNULL(t.AutoSetting, 0) = 16 AND p.SourceId = 101 AND p.CreatedDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,1), @currTime) THEN 1
					WHEN 1 & ISNULL(t.AutoSetting, 0) = 1 THEN 1
				END

END
GO
