/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_Match3rdSel]
    @MatchID    INT
AS
/*
    Created: 20220719@Kathy
    Task : get match3rd information
    DB: DBPRO/bodb02
   

    Revisions:
       - 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		
    Parameters Explanation:


*/
BEGIN
    SET NOCOUNT ON

	SELECT	EventStatus
	FROM	dbo.Match3rd WITH(NOLOCK)
	WHERE	match3rdId = @MatchId

END
GO