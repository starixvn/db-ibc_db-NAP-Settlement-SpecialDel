/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_SMP_Selections_Select] 
	@TransId BIGINT = 0
AS
/*
	Created: 20190227@Alan
	Task : Select Selection of Single Match Parlay
	DB: DBPRO/bodb02
	Original:
	Revisions: 
		- 20190227@Alan: Select Selection Bet Builder - [106898]
	
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #SelectionBetBuilder(
		MarketSelectionID	BIGINT,
		SelectionName		VARCHAR(200),
		Result				VARCHAR(20)
	)
	
	INSERT INTO #SelectionBetBuilder(MarketSelectionID, SelectionName, Result)
	SELECT ms.MarketSelectionId, s.SelectionName, ms.Result
	FROM DBPRO.bodb02.dbo.SMP_MarketSelection ms WITH(NOLOCK)
		INNER JOIN DBPRO.bodb02.dbo.SMP_Selection s WITH(NOLOCK) ON  ms.SelectionType = s.SelectionType
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.transid = @TransId AND b.betcheck = ms.MarketId AND b.matchid = ms.MatchId

	SELECT s.MarketSelectionID, s.SelectionName, s.Result
	FROM #SelectionBetBuilder s
	ORDER BY s.MarketSelectionID	
	
	DROP TABLE #SelectionBetBuilder
END
GO