/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GetChildMatch (
	@MatchIds	VARCHAR(MAX)
)
AS
/*
	Creator	: 20210205@Louisa
	Task	: Cricket AIO [Redmine:#148870]						
	DB		: DBPRO/bodb02

	Revisions:
		20210205@Louisa: initial Function

*/
BEGIN
	
	SET NOCOUNT ON
	
	DECLARE @tblMatchInfo TABLE ( MatchId INT, ParentId INT)

	INSERT INTO @tblMatchInfo (MatchId, ParentId )
	SELECT	val , val
	FROM	dbo.f_SplitString(@MatchIds, ',')
	OPTION (MAXRECURSION 0)

	INSERT INTO @tblMatchInfo (MatchId, ParentId)
	SELECT m.MatchId , m.ParentID
	FROM dbo.match m WITH(NOLOCK)
	WHERE ParentID IN ( SELECT tmp.MatchId FROM @tblMatchInfo tmp )
		AND ISNULL( m.ChildMatchType, 0) = 200
		AND m.sporttype = 50

	SELECT * FROM @tblMatchInfo

END

GO
