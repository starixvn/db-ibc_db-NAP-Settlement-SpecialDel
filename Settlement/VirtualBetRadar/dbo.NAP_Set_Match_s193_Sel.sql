/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_Match_s193_Sel]
    @MatchID    INT
AS
/*
    Created: 20220719@Kathy
    Task : get match VS betradar information
    DB: DBPRO/bodb02
   

    Revisions:
      - 20220928@Kathy: Update Send Mail Notification Rule for VS BetRadar [Redmine:#178262]
		
    Parameters Explanation:


*/
BEGIN
    SET NOCOUNT ON

	SELECT	calculate, calrefund, multiple, refund
	FROM	dbo.match_remark WITH(NOLOCK)
	WHERE	matchid = @MatchId

END
GO