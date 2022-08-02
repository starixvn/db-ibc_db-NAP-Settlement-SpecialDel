/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Auto_1s]
    @MatchID        INT
AS
/*    
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
    
    Revisions:
        - 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON 

	SELECT  r.ResourceId
			,r.HomeValue
			,r.AwayValue
			,r.ResultStatusID
			,r.SettlementStatusID
			,ISNULL( r.ResultSetting, 0) AS ResultSetting                      
	FROM    dbo.ResultDetail r WITH (NOLOCK)
	WHERE	r.MatchId =  @MatchID


END
GO