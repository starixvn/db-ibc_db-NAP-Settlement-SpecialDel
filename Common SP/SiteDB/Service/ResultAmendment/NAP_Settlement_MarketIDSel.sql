/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Settlement_MarketIDSel]
	 @MatchId					INT		
	 ,@SelectionTypes			VARCHAR(MAX) = ''
AS
/*	
	Created by: 20250604@Hughie
	Task: Settlement  
	DB: DBPRO-bodb02
	
	Revisions:
		- 20250604@Hughie: Settle - Integrate - Result Amendment -Betbuilder [Redmine:#224372]
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @tmp table (SelectionType INT) 

	INSERT INTO @tmp (SelectionType)
	SELECT CAST(value AS INT) FROM  STRING_SPLIT(@SelectionTypes, ',')

	IF EXISTS (SELECT 1 FROM @tmp )
	BEGIN
		SELECT DISTINCT A.MarketId, C.SelectionType
		FROM SMP_MarketSelection A WITH (NOLOCK)
		INNER JOIN SMP_Market B WITH (NOLOCK) ON B.MarketId = A.MarketId AND B.MatchId = A.MatchId 
		INNER JOIN @tmp C ON A.SelectionType = C.SelectionType
		WHERE A.MatchId = @MatchId
	END
END