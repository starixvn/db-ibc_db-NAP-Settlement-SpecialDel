/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GetChildMatchByParent (
	@MatchId	INT
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
	
	DECLARE @Sporttype TINYINT

	SELECT @Sporttype = 50

	SELECT m.MatchId
	FROM dbo.match m WITH(NOLOCK)
	WHERE ParentID = @MatchId
		AND ISNULL( m.ChildMatchType, 0) = 200
		AND m.sporttype = @Sporttype

END

GO