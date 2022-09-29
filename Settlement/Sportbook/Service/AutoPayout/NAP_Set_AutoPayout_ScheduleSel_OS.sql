/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_ScheduleSel_OS] 
AS
/*	
	Creator: 20210311@Max
	Task: Auto Payout for Table Tennis
	DB: DBPRO/BODB02
	
	Revisions:
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
		- 20211206@Louisa: Enhancemant Table Tennis [Redmine:#165659]
		- 20220216@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
		- 20220309@Louisa: Return more info [Redmine:#168346]
		- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatchAuto TABLE	(	MatchId INT, sporttype SMALLINT, SourceId SMALLINT, HomeValue VARCHAR(50), AwayValue VARCHAR(50), SettlementStatus TINYINT, leagueid INT, Ranking INT	)

	INSERT INTO @tmpMatchAuto(	MatchId, sporttype, SourceId, HomeValue, AwayValue, SettlementStatus, leagueid, Ranking)
	SELECT r.MatchId, m.sporttype, r.SourceId, r.HomeValue, r.AwayValue, m.SettlementStatus, m.leagueid
		 , ROW_NUMBER() OVER (PARTITION BY r.MatchId ORDER BY r.CreateDate DESC) AS Ranking
	FROM dbo.ProviderExternalResultDetail r WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON r.MatchId = m.matchid
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE m.sporttype = 18
		AND r.SourceId = 1 --SBO
		AND r.ResourceId ='00'
		AND m.eventstatus = 'running'
		AND 1 & ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) = 1
		AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.AutoPayoutResult rs WITH(NOLOCK) 
								WHERE rs.MatchId = m.matchid 
									AND rs.CalculationType = 2)
		AND ISNULL(m.IsDeleted,0) = 0
	
	
	SELECT tmp.MatchId, tmp.sporttype, tmp.SourceId, 2 AS TypeId, tmp.HomeValue, tmp.AwayValue, tmp.SettlementStatus, tmp.leagueid
	FROM @tmpMatchAuto tmp
	WHERE tmp.Ranking = 1


END
GO
