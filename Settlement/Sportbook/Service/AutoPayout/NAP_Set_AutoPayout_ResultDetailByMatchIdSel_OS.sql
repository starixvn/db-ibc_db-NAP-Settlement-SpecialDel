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
		- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
		- 20220512@Louisa: Auto settle for Badminton [Redmine:#171676]
		- 20221124@Louisa: Do not get data if FT score of Table Tennis is null [Redmine:#180306]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpResultDetail TABLE (MatchId INT, TypeId TINYINT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )

	IF @SportType = 18 --Table Tennis
	BEGIN
		INSERT INTO @tmpResultDetail (MatchId, TypeId, ResourceId, HomeValue, AwayValue)
		SELECT m.MatchId, 2 AS TypeId, '00' , CAST(m.finalhomescore AS VARCHAR(50) ), CAST(m.finalawayscore AS VARCHAR(50) )
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN match_remark mr WITH(NOLOCK)
				ON m.matchid = mr.matchid
		WHERE m.matchid = @MatchId
			AND mr.ConfirmFT > 0
			AND m.finalhomescore IS NOT NULL
			AND m.finalawayscore IS NOT NULL
	END

	ELSE IF @SportType IN ( 6,9)
	BEGIN
		INSERT INTO @tmpResultDetail (MatchId, ResourceId, HomeValue, AwayValue )
		SELECT r.MatchId, r.ResourceID, r.HomeValue, r.AwayValue 
		FROM dbo.ResultDetailOS r WITH(NOLOCK)
		WHERE r.matchid = @MatchId
			AND r.ResultStatusID = 3			
	END

	SELECT MatchId, TypeId, ResourceId, HomeValue, AwayValue
	FROM @tmpResultDetail

END
GO




