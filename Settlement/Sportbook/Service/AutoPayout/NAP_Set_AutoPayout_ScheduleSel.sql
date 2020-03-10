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

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @TypeIds TABLE(TypeId TINYINT)

	INSERT INTO @TypeIds(TypeId)
	VALUES(1) --half time
		, (2) --full time

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
			, m.AutoSetting
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
END
GO