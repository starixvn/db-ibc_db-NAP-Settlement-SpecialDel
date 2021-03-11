/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_AutoPayout_ResultDetailByMatchIdSel_OS
	@MatchId INT
AS
/*
	Creator: 20210311@Max
	Task: Auto Payout for Table Tennis
	DB: DBPRO/BODB02
	
	Revisions:
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	SELECT MatchId, SourceId, 2 AS TypeId, HomeValue, AwayValue
	FROM dbo.ProviderExternalResultDetail WITH (NOLOCK)
	WHERE  MatchId = @MatchId
END
GO