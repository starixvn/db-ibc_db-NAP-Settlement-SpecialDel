ALTER PROCEDURE [dbo].[NAP_PlayerSelect] 
	@MatchID		INT			= 0,
	@Bettype		VARCHAR(20)	= ''
AS
/*  
	Created: 20150401@Dominic  
	Task : Get players joining in a specified match  
	DB: DBPRO/bodb02  
	
	Revisions:   
	    - @20151110@Kathy: Move SP to DBPRO
	Param's Explanation:  
		- @Bettype: Comma seperated list of bet types, delimeter character is '^'

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @BetTypeTbl TABLE(
		BetType SMALLINT
	)
	
	INSERT @BetTypeTbl(BetType)
	SELECT val as BetType
	FROM dbo.strSplit(@Bettype,'^')
	
	SELECT DISTINCT OddsInfo,BetChoice
	FROM [dbo].[odds_flex] x WITH (NOLOCK)
	   INNER JOIN [dbo].[odds] o WITH (NOLOCK) ON x.oddsid = o.oddsid
	   INNER JOIN @BetTypeTbl bt ON bt.BetType = o.BetType
	 WHERE o.MatchID = @MatchID
	 ORDER BY OddsInfo
END


GO
GRANT EXECUTE ON [dbo].[NAP_PlayerSelect] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PlayerSelect] TO [vnteam] AS [dbo]