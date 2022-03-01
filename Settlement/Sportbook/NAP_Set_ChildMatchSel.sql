/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
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
*/
BEGIN
	SET NOCOUNT ON;

	SELECT   m.matchid
			,m.matchcode
			,m.sporttype
			,m.leagueid
			,m.eventstatus
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
	WHERE m.sporttype = 6
		AND ParentID IS NOT NULL
		AND m.ParentID = @MatchId
		AND ISNULL(m.ChildMatchType, 0) IN (11, 12, 14, 15, 16, 17)
		AND ISNULL(m.IsDeleted,0) = 0

END
GO