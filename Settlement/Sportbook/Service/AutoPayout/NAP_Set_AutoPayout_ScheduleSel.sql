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

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @TypeIds TABLE(TypeId TINYINT)
	DECLARE @tmpMatchAuto TABLE(
									MatchId INT, HtHomescore INT, FinalHomescore INT, HtAwayscore INT, FinalAwayscore INT, TypeId TINYINT, 
									IsHalfTimeConfirmed INT, IsFullTimeConfirmed INT, BetStatus NVARCHAR(50), GoalRecord VARCHAR(50), 
									IsHalfTimeCalculated BIT, leagueid INT, SettlementStatus TINYINT, AutoSetting TINYINT
								)

	INSERT INTO @TypeIds(TypeId)
	VALUES(1) --half time
		, (2) --full time

	INSERT INTO @tmpMatchAuto (
								MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, TypeId, IsHalfTimeConfirmed
								, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, t.leagueid, t.SettlementStatus
								, AutoSetting
							)
	SELECT MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, TypeId, IsHalfTimeConfirmed
		, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, t.leagueid, t.SettlementStatus
		, AutoSetting
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
			, m.SettlementStatus
			, ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AS AutoSetting
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
			INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			CROSS APPLY @typeIds f
		WHERE m.eventstatus = 'running' and m.sporttype = 1
			AND (mr.ConfirmHT > 0 OR mr.ConfirmFT > 0)
			AND 17 & ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) IN (1, 16)
			AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.AutoPayoutResult rs WITH(NOLOCK) 
								WHERE rs.MatchId = m.matchid 
									AND f.TypeId = rs.CalculationType AND rs.StatusId IN (1, 2, 3))
			AND NOT EXISTS (SELECT TOP 1 1
								FROM dbo.ResultDetail r WITH(NOLOCK)
								WHERE	r.MatchId = m.matchid
										AND 1 = CASE 
													WHEN r.ResourceId = '00' AND f.TypeId = 2 THEN 1
													WHEN r.ResourceId = '01' AND f.TypeId = 1 THEN 1
													ELSE 0
												END
										AND r.ResultStatusID = 5 -- completed (manual)
							)
	)t
	WHERE IsConfirmed > 0
	ORDER BY t.kickofftime, t.MatchId, t.TypeId

	--TEMPORARY: Insert score into ProviderResultDetail for SourceId = 101 - Direct Autopayout
	DECLARE @currTime DATETIME = GETDATE()

	INSERT INTO ProviderResultDetail(MatchId,SourceId,TypeId,HomeValue,AwayValue,CreatedDate,IsConfirmed)
	SELECT t.MatchId, 101, t.TypeId, 
			CASE WHEN t.TypeId = 1 THEN HtHomescore ELSE FinalHomescore END, 
			CASE WHEN t.TypeId = 1 THEN HtAwayscore ELSE FinalAwayscore END, 
			@currTime, 0
	FROM @tmpMatchAuto t
		OUTER APPLY (
						SELECT MatchId FROM ProviderResultDetail p WITH(NOLOCK)
						WHERE t.MatchId = p.MatchId AND t.TypeId = p.TypeId AND p.SourceId = 101
					) p
	WHERE p.MatchId IS NULL AND 16 & ISNULL(t.AutoSetting, 0) = 16

	-- Return data 
	SELECT t.MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, t.TypeId, IsHalfTimeConfirmed
			, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, t.leagueid, t.SettlementStatus
			, AutoSetting
	FROM @tmpMatchAuto t
		LEFT JOIN ProviderResultDetail p 
			ON t.MatchId = p.MatchId AND t.TypeId = p.TypeId 
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime
			FROM	dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = t.leagueid
					AND ss.AutoType = 5 -- Direct Auto Payout
		) ss
	WHERE 1 = CASE WHEN 16 & ISNULL(t.AutoSetting, 0) = 16 AND p.SourceId = 101 AND p.CreatedDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,1), @currTime) THEN 1
					WHEN 1 & ISNULL(t.AutoSetting, 0) = 1 THEN 1
				END

END
GO