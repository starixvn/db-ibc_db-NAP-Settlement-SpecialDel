/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SelectionTypeSel] 
    @MatchId    INT 
AS

	/*  
    Created: 20200817@July  
    Task : Ticket Listing - Bet Builder Enhancement  [Redmine: #138555]
    DB: DBPRO/bodb02
	
	Revisions: 
		- 20200817@July: Select SelectionType belong to MatchID Bet Builder - [Redmine: #138555]

	*/
BEGIN
    SELECT DISTINCT ms.SelectionType ,
			s.SelectionName
	FROM dbo.SMP_MarketSelection ms WITH(NOLOCK)
		INNER JOIN  dbo.SMP_Selection s WITH(NOLOCK) 
			ON ms.SelectionType=s.SelectionType
	WHERE ms.matchid = @MatchId	
	ORDER BY SelectionName
END

GO