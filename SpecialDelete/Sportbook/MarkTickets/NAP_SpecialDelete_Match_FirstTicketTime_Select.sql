
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_SpecialDelete_Match_FirstTicketTime_Select] @MatchId INT = 0
AS

/*
    Created by: Alan
	Date: 20190327
	Task: Get First Ticket Time 
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20190327@Alan: - Get First Ticket Time [108826]
*/

         BEGIN
             SET NOCOUNT ON;
             SELECT MIN(transdate) transdate
             FROM bettrans WITH (NOLOCK)
             WHERE matchid = @MatchId;
             SET NOCOUNT OFF;
         END;
GO
