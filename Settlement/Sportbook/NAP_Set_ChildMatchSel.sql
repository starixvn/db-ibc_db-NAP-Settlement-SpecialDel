/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ChildMatchSel]
(
	 @MatchId INT
)
AS
/* 
	Created by: 20210906@Louisa
    Task: 20210906@Louisa: Settle by profile for Volleyball, Squash, Sepak Takraw [Redmine:#160478]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210906@Louisa: Get child match for Volleyball [Redmine:#160478]
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
	WHERE ISNULL(m.ParentID,0) = @MatchId

END
GO