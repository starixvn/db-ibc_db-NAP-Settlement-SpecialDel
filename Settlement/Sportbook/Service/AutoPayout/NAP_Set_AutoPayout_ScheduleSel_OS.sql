/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_AutoPayout_ScheduleSel_OS] 
AS
/*	
	Creator: 20210311@Max
	Task: Auto Payout for Table Tennis
	DB: DBPRO/BODB02
	
	Revisions:
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @TypeId TINYINT
	SET @TypeId = 2

	DECLARE @tmpMatchAuto TABLE(
									MatchId INT, HtHomescore INT, FinalHomescore INT, HtAwayscore INT, FinalAwayscore INT, TypeId TINYINT, 
									IsHalfTimeConfirmed INT, IsFullTimeConfirmed INT, BetStatus NVARCHAR(50), GoalRecord VARCHAR(50), 
									IsHalfTimeCalculated BIT, leagueid INT, SettlementStatus TINYINT, AutoSetting TINYINT
								)


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
			, @TypeId AS TypeId
			, mr.ConfirmFT	AS IsConfirmed
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
		WHERE m.eventstatus = 'running' 
			AND m.sporttype IN (18) --Table Tennis
			AND mr.ConfirmFT > 0
			AND 1 & ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) = 1
			AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.AutoPayoutResult rs WITH(NOLOCK) 
								WHERE rs.MatchId = m.matchid 
									AND rs.CalculationType = 2)
		)t
	WHERE IsConfirmed > 0
	ORDER BY t.kickofftime, t.MatchId
	
	-- Return data 
	SELECT t.MatchId, HtHomescore, FinalHomescore, HtAwayscore, FinalAwayscore, t.TypeId, IsHalfTimeConfirmed
			, IsFullTimeConfirmed, BetStatus, GoalRecord, IsHalfTimeCalculated, t.leagueid, t.SettlementStatus
			, AutoSetting
	FROM @tmpMatchAuto t
		LEFT JOIN dbo.ProviderExternalResultDetail p 
			ON t.MatchId = p.MatchId AND p.ResourceId = '00'

END
GO