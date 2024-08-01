/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ChildMatchSel]
(
	 @MatchId INT
)
AS
/* 
	Created by: 20210906@Louisa
    Task: 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210906@Louisa: Get child match for Volleyball [Redmine:#160478]
		- 20211108@Louisa: In-house Replicator: Delete Action [Redmine:#164393] 
		- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100] 
*/
BEGIN
	SET NOCOUNT ON;

	SELECT   m.matchid
			,m.matchcode
			,m.sporttype
			,m.leagueid
			,m.eventstatus
			,m.kickofftime
			,m.SettlementStatus
			,m.ChildMatchType
			,r.ResourceID
			,r.HomeValue
			,r.AwayValue
			,r.SettlementStatusID
			,r.ResultStatusID
			,r.ResultSetting
	FROM dbo.match m WITH(NOLOCK)
		LEFT JOIN dbo.ResultDetailOS r WITH(NOLOCK)
			ON m.matchid = r.MatchID
			AND r.ResourceID = '00'
	WHERE  m.ParentID = @MatchId
		AND ISNULL(m.IsDeleted,0) = 0
		AND 1 = CASE WHEN m.sporttype = 6 AND ISNULL(m.ChildMatchType, 0) IN (11, 12, 14, 15, 16, 17) THEN 1
					 WHEN m.sporttype = 18 AND ISNULL(m.ChildMatchType, 0) IN (11, 12, 14, 15, 16, 17, 18, 19) THEN 1
					 ELSE 0
				END
					
		

END
GO