/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GetChildMatchByParent (
	@MatchIds	VARCHAR(MAX)
	,@Mode		VARCHAR(20) ='CAL'
)
AS
/*
	Creator	: 20210205@Louisa
	Task	: Cricket AIO [Redmine:#148870]						
	DB		: DBTXN/bodb02

	Revisions:
		20210205@Louisa: initial Function

	Param's Explanation:
		@MatchId: Parent's Matchid
		@Mode	: CAL
				  CAL-MP

*/
BEGIN
	
	SET NOCOUNT ON
	
	DECLARE @Sporttype TINYINT
	DECLARE @tmpChildMatch TABLE ( MatchId INT)
	SELECT @Sporttype = 50

	IF @@ROWCOUNT> 0
	INSERT INTO @tmpChildMatch( MatchId)
	SELECT m.MatchId
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.f_SplitString(@MatchIds, ',') tmp ON m.ParentID = tmp.val
	WHERE ISNULL( m.ChildMatchType, 0) = 200
		AND m.sporttype = @Sporttype
		AND m.eventstatus = 'completed'
	OPTION (MAXRECURSION 0)

	IF @Mode ='CAL-MP'
	BEGIN
		SELECT m.Matchid
		FROM @tmpChildMatch m
			INNER JOIN dbo.Bettransm bm ON m.matchid = bm.matchid
		GROUP BY m.matchid

	END

	IF @Mode ='CAL'
	BEGIN
		SELECT m.matchid FROM @tmpChildMatch m
	END


END

GO