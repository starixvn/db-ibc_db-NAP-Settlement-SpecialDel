/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_ResultDetailByMatchIdSel_OS
	@MatchId INT
	,@SportType SMALLINT
AS
/*
	Creator: 20210311@Max
	Task: Auto Payout for Table Tennis
	DB: DBPRO/BODB02
	
	Revisions:
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
		- 20211206@Louisa: Enhancemant Table Tennis [Redmine:#165659]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpResultDetail TABLE (MatchId INT, TypeId TINYINT, finalhomescore INT, finalawayscore INT )

	IF @SportType = 18 --Table Tennis
	BEGIN
		INSERT INTO @tmpResultDetail (MatchId, TypeId, finalhomescore, finalawayscore)
		SELECT m.MatchId, 2 AS TypeId, m.finalhomescore, m.finalawayscore
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN match_remark mr WITH(NOLOCK)
				ON m.matchid = mr.matchid
		WHERE m.matchid = @MatchId
			AND m.eventstatus = 'running'
			AND mr.ConfirmFT > 0
	END

	SELECT MatchId, TypeId, finalhomescore, finalawayscore
	FROM @tmpResultDetail

END
GO




