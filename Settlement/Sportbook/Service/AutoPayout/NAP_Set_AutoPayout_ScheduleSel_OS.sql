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
		- 20220512@Kathy: Improve performance [Redmine:#172386]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT m.MatchId, m.sporttype, r.SourceId, 2 AS TypeId, r.HomeValue, r.AwayValue, m.SettlementStatus, m.leagueid
	FROM dbo.match m WITH(NOLOCK)
		CROSS APPLY (
			SELECT	r.SourceId, r.HomeValue, r.AwayValue
						,ROW_NUMBER() OVER (PARTITION BY r.MatchId ORDER BY r.CreateDate DESC) AS Ranking
			FROM	dbo.ProviderExternalResultDetail r WITH(NOLOCK)
			WHERE	r.MatchId = m.matchid
					AND r.SourceId = 1 --SBO
					AND r.ResourceId ='00'
		)r
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		OUTER APPLY(
			SELECT	TOP 1 1 AS IsExistAP
			FROM	dbo.AutoPayoutResult rs WITH( NOLOCK)
			WHERE	rs.MatchId = m.matchid
					AND rs.CalculationType = 2
		)rs
	WHERE m.sporttype = 18			
		AND m.eventstatus = 'running'
		AND 1 & ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) = 1
		AND r.Ranking = 1
		AND rs.IsExistAP IS NULL
		AND ISNULL(m.IsDeleted,0) = 0
END
GO