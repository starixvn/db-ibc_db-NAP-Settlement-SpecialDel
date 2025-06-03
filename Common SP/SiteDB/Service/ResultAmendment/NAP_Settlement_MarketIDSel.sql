/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Settlement_MarketIDSel]
	 @MatchId					INT		
	 ,@SelectionType			INT
AS
/*	
	Created by: 20250418@Hughie
	Task: Settlement  
	DB: DBPRO-bodb02
	
	Revisions:
		- 20250418@Hughie: Settle - Integrate - Result Amendment -Betbuilder [Redmine:#224372]
*/
BEGIN	
	SET NOCOUNT ON

	SELECT @MatchId AS MatchId, A.MarketId, @SelectionType AS SelectionType
	FROM SMP_MarketSelection A WITH (NOLOCK)
	INNER JOIN SMP_Market B WITH (NOLOCK) ON B.MarketId = A.MarketId AND B.MatchId = A.MatchId
	where B.MatchId = @MatchId
END