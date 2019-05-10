
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
		- 20190510@Alan: - Get Kick Off Time [112480]
*/

     SET NOCOUNT ON;
     DECLARE @MinTransDate DATETIME, @KickOffTime DATETIME;
     SELECT @MinTransDate = MIN(transdate)
     FROM bettrans WITH (NOLOCK)
     WHERE matchid = @MatchId;
     SELECT @KickOffTime = kickofftime
     FROM dbo.[match] WITH (NOLOCK)
     WHERE matchid = @MatchId;
     SELECT @MinTransDate AS MinTransDate,
            @KickOffTime AS KickOffTime;
     SET NOCOUNT OFF;
GO
