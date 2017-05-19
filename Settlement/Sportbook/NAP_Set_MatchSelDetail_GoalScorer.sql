ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_GoalScorer]
	 @MatchID		INT
	,@Bettype		INT 

AS
/*	Creator: Jamie
	Date: 20150401
	Task: BetRadar - Settlement detail - Get Goal Scorer 
	DB: DBPRO/BODB02
	Original: 
	
	Revisions:

	Param's Explanation:
		+ @Bettype: 216: Goal Scorer - Anytime; 217: Goal- First 
*/
BEGIN
	SET NOCOUNT ON 

	SELECT	DISTINCT 
			 o.bettype
			,x.betChoice 
			,x.OddsInfo
	FROM	[dbo].[odds_flex] x WITH (NOLOCK)
			INNER JOIN [dbo].[odds] o WITH (NOLOCK) ON x.oddsid = o.oddsid
	WHERE	o.MatchID = @MatchID
			AND o.Bettype = @Bettype
	ORDER BY o.bettype, x.betChoice ASC   

END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_MatchSelDetail_GoalScorer] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Set_MatchSelDetail_GoalScorer] TO [vnteam] AS [dbo]