CREATE PROCEDURE [dbo].[NAP_Set_BetDaq_MatchSel]
	@MatchID		INT
AS
/*
	Created: Dan
	Date: 2012-11-02
	Task: Find available matches for moving BetDaq ticket
	DB: DB02.BODB02 
	Original: [Acc_Set_BetDaq_MatchSel]

	Revisions: 
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
				

	Param's Explanation: 
		@MatchID: current match 

*/
SET NOCOUNT ON
DECLARE	@awayID			INT,
		@homeID			INT,
		@leagueID		INT,
		@eventdate		DATETIME,
		@rc				INT
		

SELECT	@awayID		= awayID,
		@homeID		= homeID,
		@leagueID	= leagueID,
		@eventdate	= eventdate
FROM	Match WITH (NOLOCK)
WHERE	matchid = @MatchID 

SELECT	matchcode, matchid, eventdate   
FROM	match WITH (NOLOCK) 
WHERE	homeid = @HomeID
		AND awayid = @AwayID
		AND	leagueid = @LeagueID 
		AND eventdate >= @Eventdate 
		AND matchid <> @MatchID 
		AND matchcode NOT LIKE '%hedge%'
		AND ISNULL(IsDeleted,0) = 0
ORDER BY eventdate

GO
GRANT EXECUTE ON [dbo].[NAP_Set_BetDaq_MatchSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Set_BetDaq_MatchSel] TO [vnteam] 
