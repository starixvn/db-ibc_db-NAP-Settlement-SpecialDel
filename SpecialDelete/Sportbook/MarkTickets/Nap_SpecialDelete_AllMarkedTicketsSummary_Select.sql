
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Select]
AS

/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion
		
	Explanation's Param:
*/

     SET NOCOUNT ON;
     CREATE TABLE #Tickets
                  (Total   INT,
                   MatchId INT
                  );
     INSERT INTO #Tickets
            (Total,
             MatchId
            )
            SELECT COUNT(m.TransId),
                   m.MatchId
            FROM dbo.MarkedTransaction m WITH (NOLOCK)
                 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = m.TransId
                                                            AND b.MatchId = m.MatchId
            WHERE b.statusID IN(0, 1) -- running, waiting
            GROUP BY m.MatchId;
     SELECT t.MatchId,
            t.Total,
            m.HomeId,
            m.AwayId,
            m.IsNeutral,
            m.SportType
     FROM #Tickets t
          INNER JOIN dbo.match m WITH (NOLOCK) ON m.MatchId = t.MatchId;
     DROP TABLE #Tickets;
     SET NOCOUNT OFF;
GO
