/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_SMP_Selections_Select] 
	@TransId BIGINT = 0
AS
/*
	Created: 20190227@Alan
	Task : Select Selection of Single Match Parlay
	DB: DBTXN/bodb02
	Original:
	Revisions: 
		- 20190227@Alan: Select Selection Bet Builder - [106898]
	
*/
BEGIN
	SET NOCOUNT ON	
	DECLARE @BetCheck NVARCHAR(50), @MatchID INT
	SELECT top 1 @BetCheck = b.betcheck, @MatchID = matchid
	FROM bettrans b WITH(NOLOCK) 
	WHERE b.transid = @TransId

	DECLARE @SQL NVARCHAR(MAX)
	SELECT @SQL = N''
	SELECT @SQL = N'
	SELECT MarketSelectionId, SelectionName, Result
	FROM OPENQUERY(DBPRO, ''
		SELECT ms.MarketSelectionId, s.SelectionName, ms.Result
		FROM bodb02.dbo.SMP_MarketSelection AS ms WITH(NOLOCK)
		INNER JOIN bodb02.dbo.SMP_Selection AS s WITH(NOLOCK) ON ms.SelectionType = s.SelectionType
		WHERE ms.MarketId = '''''+ @BetCheck +''''' AND ms.MatchId = '+ CONVERT(NVARCHAR(50),@MatchID) +'
		ORDER BY ms.MarketSelectionID
	'')'

	EXECUTE	sys.sp_executesql @SQL
END
GO