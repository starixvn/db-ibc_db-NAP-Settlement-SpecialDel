/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Set_GetRelatedMatchDetail (
	@ParentMatchId INT
	,@SportType SMALLINT = 1
	,@Type TINYINT = 33
)
AS
/*
	Creator: 20220613@Louisa
	Task: Auto Payout for match Soccer Total Goal and Total Corner
	DB: DBPRO/BODB02
	
	Revisions:
		- 20220613@Louisa: Initial [Redmine:#171261]

	Param's Explanation:
*/
declare @ParentMatchId INT
		,@SportType SMALLINT = 1
		,@Type TINYINT
		--if Type = 33 , @MatchId is ParentId in table match

BEGIN
	SET NOCOUNT ON

	--SELECT @ParentMatchId = 70037584	
	--		,@Type  = 33

	DECLARE @tmpMathInfo TABLE ( MatchId INT, ChildMatchType TINYINT)

	INSERT INTO @tmpMathInfo (MatchId, ChildMatchType)
	SELECT m.matchid, m.ChildMatchType
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid =  @ParentMatchId
		OR (m.ParentID IS NOT NULL AND m.ParentID = @ParentMatchId AND ISNULL(m.ChildMatchType,0) = 204)
	
	SELECT matchid, ChildMatchType FROM @tmpMathInfo

	SELECT r.MatchId, r.ResourceId, r.HomeValue, r.AwayValue, r.ResultStatusID, r.SettlementStatusID 
	FROM dbo.ResultDetail r WITH(NOLOCK)
		INNER JOIN @tmpMathInfo m
			ON r.MatchId = m.MatchId
	WHERE r.ResourceId IN ( '00', '01' )

END
GO