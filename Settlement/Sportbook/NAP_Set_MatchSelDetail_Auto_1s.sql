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
		Old SP is located on DBTXN

*/
BEGIN
    SET NOCOUNT ON 

	DECLARE @tmpAutoBettypes TABLE (ResourceId VARCHAR(20) ,OrdNo SMALLINT)
	
	INSERT INTO @tmpAutoBettypes (ResourceId, OrdNo)
	SELECT	s.ResourceID,MAX(s.OrdNo) AS OrdNo
	FROM	dbo.f_Set_GetGroupBettypes() f
		INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			ON	f.BetType = s.BetType
	WHERE	f.GroupId = 8
			AND s.SportType = 1
			AND s.SettleType = 'EAR'
	GROUP BY s.ResourceID
	

	SELECT  r.ResourceId
			,r.HomeValue
			,r.AwayValue
			,r.ResultStatusID
			,r.SettlementStatusID
			,ISNULL( r.ResultSetting, 0) AS ResultSetting   
			,t.OrdNo
	FROM    dbo.ResultDetail r WITH (NOLOCK)
		INNER JOIN @tmpAutoBettypes t
			ON t.ResourceId = r.ResourceId
	WHERE	r.MatchId =  @MatchID
	
END
GO